import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:win32/win32.dart';

/// Secret storage for account passwords and tokens (spec 4.1).
///
/// On Windows this is the Credential Manager (generic credentials), so
/// secrets are encrypted by the OS under the user's login and visible to
/// the user in Control Panel → Credential Manager. Nothing is written to the
/// database or any file.
abstract interface class CredentialStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  static String passwordKey(int accountId) => 'account.$accountId.password';
}

/// Windows Credential Manager via advapi32 (CredWriteW/CredReadW/CredDeleteW).
class WindowsCredentialStore implements CredentialStore {
  WindowsCredentialStore({this.prefix = 'ConvoMail/'});

  /// Prefix for the credential's target name so entries are recognizable.
  final String prefix;

  static const int _errorNotFound = 1168; // ERROR_NOT_FOUND

  String _target(String key) => '$prefix$key';

  @override
  Future<String?> read(String key) async {
    return using((arena) {
      final target = _target(key).toNativeUtf16(allocator: arena);
      final out = arena<Pointer<CREDENTIAL>>();
      final result = CredRead(PCWSTR(target), CRED_TYPE_GENERIC, out);
      if (!result.value) {
        if (result.error == _errorNotFound) return null;
        throw CredentialStoreException('CredRead failed (${result.error})');
      }
      final cred = out.value;
      try {
        final size = cred.ref.CredentialBlobSize;
        if (size == 0) return '';
        final bytes = cred.ref.CredentialBlob.asTypedList(size);
        return utf8.decode(bytes);
      } finally {
        CredFree(cred);
      }
    });
  }

  @override
  Future<void> write(String key, String value) async {
    using((arena) {
      final bytes = utf8.encode(value);
      final blob = arena<Uint8>(bytes.length);
      blob.asTypedList(bytes.length).setAll(0, bytes);
      final cred = arena<CREDENTIAL>();
      cred.ref
        ..Type = CRED_TYPE_GENERIC
        ..TargetName = PWSTR(_target(key).toNativeUtf16(allocator: arena))
        ..Comment = PWSTR('Stored by ConvoMail'.toNativeUtf16(allocator: arena))
        ..CredentialBlobSize = bytes.length
        ..CredentialBlob = blob
        ..Persist = CRED_PERSIST_LOCAL_MACHINE
        ..UserName = PWSTR(key.toNativeUtf16(allocator: arena));
      final result = CredWrite(cred, 0);
      if (!result.value) throw CredentialStoreException('CredWrite failed (${result.error})');
    });
  }

  @override
  Future<void> delete(String key) async {
    using((arena) {
      final target = _target(key).toNativeUtf16(allocator: arena);
      final result = CredDelete(PCWSTR(target), CRED_TYPE_GENERIC);
      if (!result.value && result.error != _errorNotFound) {
        throw CredentialStoreException('CredDelete failed (${result.error})');
      }
    });
  }
}

class CredentialStoreException implements Exception {
  const CredentialStoreException(this.message);
  final String message;
  @override
  String toString() => 'CredentialStoreException: $message';
}

class InMemoryCredentialStore implements CredentialStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  bool contains(String key) => _values.containsKey(key);
}

final credentialStoreProvider = Provider<CredentialStore>((ref) {
  if (Platform.isWindows) return WindowsCredentialStore();
  // Android (Phase 2) gets a Keystore-backed implementation; until then an
  // in-memory store keeps other platforms running for development.
  return InMemoryCredentialStore();
});
