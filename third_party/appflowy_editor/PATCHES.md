# appflowy_editor 6.2.0 (vendored)

Copied from pub.dev `appflowy_editor-6.2.0` (`lib/`, `assets/`, `pubspec.yaml`,
`LICENSE`, `README.md`, `CHANGELOG.md`; the `example/`, `test/`, and
`documentation/` folders were left out). Referenced from the app's
`pubspec.yaml` through `dependency_overrides`.

## Patches

1. `lib/src/editor/editor_component/service/ime/delta_input_service.dart`
   — added `bool onFocusReceived() => false;`. Flutter 3.47 added this member
   to `TextInputClient`, and `DeltaTextInputClient` only implements the
   interface, so the class failed to compile. Remove this override and the
   vendored copy once an upstream release includes the member.

Everything else is unmodified upstream code under the upstream license.
