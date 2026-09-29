# ConvoMail (working name)

A sender-centric email client for Windows, built with Flutter and Material 3 Expressive.
People, not folders: every contact is one row, every row is one conversation.

Specification: `docs/email-client-build-spec.md`. Development plan: `docs/email-client-windows-dev-plan.md`.
Visual reference: `docs/email-client-visual-mockups.html`.

## Status

Milestone 0 — foundations and design system. See `docs/email-client-windows-dev-plan.md` section 2.

## Layout

```
lib/
  main.dart            entry point, window setup, MaterialApp
  app/                 state (Riverpod), destinations, keyboard shortcuts, settings
  domain/              pure Dart rules: filing, identity, threading, classifier (from M1)
  store/               drift database, settings store
  sync/                IMAP sync engine (from M1)
  mail/                enough_mail wrappers, OAuth (from M1)
  platform/windows/    Credential Manager, toasts, taskbar, mailto (from M1/M10)
  ui/theme/            M3 Expressive tokens and ThemeData
  ui/widgets/          connected button group, floating toolbar, wavy progress, grouped list, avatars
  ui/shell/            navigation rail shell, split pane
  ui/screens/          one file per destination
test/                  unit and widget tests
```

## Build

Requires Flutter stable (3.47+) and Visual Studio 2022 Build Tools with the "Desktop development with C++" workload.

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run -d windows
```
