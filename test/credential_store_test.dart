import 'dart:io';

import 'package:convomail/platform/credential_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('InMemoryCredentialStore round-trips and deletes', () async {
    final s = InMemoryCredentialStore();
    expect(await s.read('k'), isNull);
    await s.write('k', 'v');
    expect(await s.read('k'), 'v');
    await s.delete('k');
    expect(await s.read('k'), isNull);
  });

  test('WindowsCredentialStore round-trips through Credential Manager', () async {
    // Uses a distinct prefix so it never touches real account entries.
    final s = WindowsCredentialStore(prefix: 'ConvoMailTest/');
    const key = 'unit-test.password';
    await s.delete(key);
    expect(await s.read(key), isNull);

    await s.write(key, 'sécrét-app-password-😀');
    expect(await s.read(key), 'sécrét-app-password-😀');

    await s.write(key, 'rotated');
    expect(await s.read(key), 'rotated');

    await s.delete(key);
    expect(await s.read(key), isNull);
    await s.delete(key); // deleting a missing key is not an error
  }, skip: Platform.isWindows ? false : 'Windows only');
}
