# ConvoMail (working name)

A sender-centric email client for Windows, built with Flutter and Material 3 Expressive.
People, not folders: every contact is one row, every row is one conversation.

Specification: `docs/email-client-build-spec.md`. Development plan: `docs/email-client-windows-dev-plan.md`.
Visual reference: `docs/email-client-visual-mockups.html`.

## Status

| Milestone | State | Notes |
|---|---|---|
| M0 Foundations & design system | **Done** (2026-09-29) | Shell, theme, custom M3 Expressive widgets, settings store, 16 tests, release build runs |
| M1 Accounts, credentials, sync | In progress | Data model, identity resolution, filing, IMAP transport, sync engine with IDLE, Credential Manager storage, account setup screen; 44 unit tests + 3 integration tests against a local pymap server. Remaining: real-Gmail soak test at 20k messages, sleep/resume. |
| M2–M12 | Planned | See `docs/email-client-windows-dev-plan.md` section 2 |

Run with `--destination=<chats|boards|planner|settings>` or `--inbox=<people|feeds>` to open on a given screen.

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

## Tests

```
flutter test --exclude-tags integration      # unit and widget tests
flutter test --tags integration              # real IMAP against a local pymap server
```

The integration tests need `pip install pymap`; on Windows they start it through `tool/pymap_win.py`.

## Build

Requires Flutter stable (3.47+) and Visual Studio 2022 Build Tools with the "Desktop development with C++" workload.

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run -d windows
```
