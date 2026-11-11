import 'dart:ffi';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:win32_registry/win32_registry.dart';

/// Registers the app as a `mailto:` handler for the current user (spec
/// 4.18 "Default mail client registration"), so it appears in Windows
/// Settings → Default apps → Email. Per-user keys only; no elevation.
///
/// Windows does not let an app make itself the default: after registering,
/// the user picks it in Settings, which [openDefaultAppsSettings] opens.
abstract interface class MailtoRegistration {
  bool get isRegistered;
  void register();
  void unregister();
}

final mailtoRegistrationProvider = Provider<MailtoRegistration>((ref) => Platform.isWindows ? WindowsMailtoRegistration() : const NoopMailtoRegistration());

class WindowsMailtoRegistration implements MailtoRegistration {
  WindowsMailtoRegistration({String? exePath}) : exePath = exePath ?? Platform.resolvedExecutable;

  final String exePath;
  static const progId = 'Precis.Mailto';

  /// Names used before the app was renamed; cleared on unregister.
  static const legacyProgId = 'ConvoMail.Mailto';
  static const legacyAppName = 'ConvoMail';
  static const appName = 'Précis';

  @override
  bool get isRegistered {
    try {
      final key = Registry.openPath(RegistryHive.currentUser, path: r'Software\Classes\' + progId + r'\shell\open\command');
      final cmd = key.getStringValue('');
      key.close();
      return cmd != null && cmd.toLowerCase().contains(exePath.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  @override
  void register() {
    final hkcu = Registry.currentUser;
    final cmd = '"$exePath" "%1"';

    final prog = hkcu.createKey(r'Software\Classes\' + progId);
    prog.createValue(const RegistryValue.string('', 'Précis email link'));
    prog.createValue(const RegistryValue.string('URL Protocol', ''));
    prog.createValue(const RegistryValue.string('FriendlyTypeName', appName));
    prog.close();
    final icon = hkcu.createKey(r'Software\Classes\' + progId + r'\DefaultIcon');
    icon.createValue(RegistryValue.string('', '"$exePath",0'));
    icon.close();
    final open = hkcu.createKey(r'Software\Classes\' + progId + r'\shell\open\command');
    open.createValue(RegistryValue.string('', cmd));
    open.close();

    // Default Programs registration (what the Default apps page lists).
    final caps = hkcu.createKey(r'Software\Precis\Capabilities');
    caps.createValue(const RegistryValue.string('ApplicationName', appName));
    caps.createValue(const RegistryValue.string('ApplicationDescription', 'Sender-centric email client'));
    caps.close();
    final assoc = hkcu.createKey(r'Software\Precis\Capabilities\URLAssociations');
    assoc.createValue(const RegistryValue.string('mailto', progId));
    assoc.close();
    final registered = hkcu.createKey(r'Software\RegisteredApplications');
    registered.createValue(const RegistryValue.string(appName, r'Software\Precis\Capabilities'));
    registered.close();
    _declareLinkType();
    _tellWindows();
  }

  /// Whether Windows has `mailto` on its list of link types at all.
  static bool get linkTypeKnown {
    try {
      Registry.openPath(RegistryHive.classesRoot, path: 'mailto').close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Windows offers apps for a link type only when it knows the type. On a
  /// PC where an earlier mail app took the `mailto` entry with it when it
  /// was removed, the Default apps page shows no MAILTO and offers no app,
  /// whatever is registered. This puts the bare entry back for this user.
  /// It names no app: the user still chooses one in Windows Settings.
  static void _declareLinkType() {
    if (linkTypeKnown) return;
    try {
      final scheme = Registry.currentUser.createKey(r'Software\Classes\mailto');
      scheme.createValue(const RegistryValue.string('', 'URL:MailTo Protocol'));
      scheme.createValue(const RegistryValue.string('URL Protocol', ''));
      scheme.close();
    } catch (_) {
      // Registered all the same; Windows may list it once the type exists.
    }
  }

  /// Tells Windows that which apps open which links has changed, so the
  /// Default apps page lists Précis at once instead of after the next
  /// sign-in. Changes no setting.
  static void _tellWindows() {
    try {
      const assocChanged = 0x08000000; // SHCNE_ASSOCCHANGED
      final notify = DynamicLibrary.open('shell32.dll').lookupFunction<Void Function(Int32, Uint32, Pointer<Void>, Pointer<Void>), void Function(int, int, Pointer<Void>, Pointer<Void>)>('SHChangeNotify');
      notify(assocChanged, 0, nullptr, nullptr);
    } catch (_) {
      // Windows still picks the change up later by itself.
    }
  }

  @override
  void unregister() {
    final hkcu = Registry.currentUser;
    try {
      hkcu.deleteKey(r'Software\Classes\' + progId, recursive: true);
    } catch (_) {}
    try {
      hkcu.deleteKey(r'Software\Precis', recursive: true);
    } catch (_) {}
    try {
      final registered = hkcu.createKey(r'Software\RegisteredApplications');
      registered.deleteValue(appName);
      registered.close();
    } catch (_) {}
    // Anything registered under the old name.
    try {
      hkcu.deleteKey(r'Software\Classes\' + legacyProgId, recursive: true);
    } catch (_) {}
    try {
      hkcu.deleteKey(r'Software\' + legacyAppName, recursive: true);
    } catch (_) {}
    try {
      final registered = hkcu.createKey(r'Software\RegisteredApplications');
      registered.deleteValue(legacyAppName);
      registered.close();
    } catch (_) {}
    _tellWindows();
  }
}

class NoopMailtoRegistration implements MailtoRegistration {
  const NoopMailtoRegistration();
  @override
  bool get isRegistered => false;
  @override
  void register() {}
  @override
  void unregister() {}
}

/// Parses `mailto:` per RFC 6068 into recipients, subject, and body.
class MailtoLink {
  const MailtoLink({this.to = const [], this.cc = const [], this.subject = '', this.body = ''});
  final List<String> to;
  final List<String> cc;
  final String subject;
  final String body;

  static MailtoLink? parse(String raw) {
    final s = raw.trim();
    if (!s.toLowerCase().startsWith('mailto:')) return null;
    final rest = s.substring(7);
    final q = rest.indexOf('?');
    final addrPart = q < 0 ? rest : rest.substring(0, q);
    final query = q < 0 ? '' : rest.substring(q + 1);
    final to = <String>[for (final a in Uri.decodeComponent(addrPart).split(',')) if (a.trim().isNotEmpty) a.trim()];
    final cc = <String>[];
    var subject = '';
    var body = '';
    for (final pair in query.split('&')) {
      if (pair.isEmpty) continue;
      final eq = pair.indexOf('=');
      final k = Uri.decodeQueryComponent(eq < 0 ? pair : pair.substring(0, eq)).toLowerCase();
      final v = eq < 0 ? '' : Uri.decodeQueryComponent(pair.substring(eq + 1));
      switch (k) {
        case 'to':
          to.addAll(v.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty));
        case 'cc':
          cc.addAll(v.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty));
        case 'subject':
          subject = v;
        case 'body':
          body = v;
      }
    }
    return MailtoLink(to: to, cc: cc, subject: subject, body: body);
  }
}
