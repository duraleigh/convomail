# ConvoMail (working name)

A sender-centric email client for Windows, built with Flutter and Material 3 Expressive.
People, not folders: every contact is one row, every row is one conversation.

Specification: `docs/email-client-build-spec.md`. Development plan: `docs/email-client-windows-dev-plan.md`.
Visual reference: `docs/email-client-visual-mockups.html`.

## Status

| Milestone | State | Notes |
|---|---|---|
| M0 Foundations & design system | **Done** (2026-09-29) | Shell, theme, custom M3 Expressive widgets, settings store, 16 tests, release build runs |
| M1 Accounts, credentials, sync | **Done** (2026-09-29) | Data model, identity resolution, filing, IMAP transport, sync engine with IDLE, Credential Manager storage, account setup screen, send-as alias discovery. Verified against the owner's Gmail (11k messages) and a local pymap server. |
| M2 People list & filing | **Done** (2026-09-29) | Grouped People list with filters, search, pin, hover/context actions, keyboard nav; archive/trash/mark-read with undo and selective keep; trigger-maintained summary table. Release benchmark: 240 ms median list over 50k messages / 5k senders (`--bench-people`). |
| M3 Conversation & threading | **Done** (2026-09-29) | Hybrid threading (headers → provider id → subject fallback), conversation pane with day groups and thread cards, cross-participant thread overlay, HTML sanitizer with remote-image blocking, tracker log and privacy stats, WebView2 rendering with CSP and link interception, Settings → Privacy. |
| M4 Compose & send | **Done** (2026-09-29) | Block editor (appflowy_editor, vendored with a one-line Flutter 3.47 patch) with floating M3 toolbar, inline images and pasted screenshots, drag-and-drop and picked attachments; From/To/Cc/Bcc with contact autocomplete; signatures per identity in Settings; inline reply / reply-all / forward with quoted original, right-pane new message; drafts autosave and resume; SMTP send with wavy progress, Sent-copy APPEND for servers that need it, answered flag, thread continuity. Not yet verified against Gmail web / Outlook / Apple Mail rendering (needs a real send from the owner's account). |
| M5 Attachments | **Done** (2026-10-20) | On-demand attachment download over IMAP into `%APPDATA%\com.convomail\convomailttachments`, inline `cid:` images embedded as data URIs (never fetched from the network), per-person Files overlay (List/Grid, featured newest file, month groups, color-coded type badges, photo grid), quick-look preview for images and PDFs (pdfrx), Save As and Open with, attachment chips with download state. pdfrx needs Windows Developer Mode to build (it was already on). |
| M6 Search & filters | **Done** (2026-10-24) | FTS5 index (`message_fts`, schema v7) over subject, sender, and body, maintained by SQLite triggers and backfilled on upgrade; HTML-only mail gets a derived text body for indexing. Search-results mode in the middle pane (People matches + ranked message hits with highlighted subject/snippet), scoped by the active filter chip, Include Feeds switch (persisted, no effect until M8 classification). Opening a hit selects the row, expands and scrolls to the message. In-conversation search field with match count, card filtering, and `<mark>` highlighting inside rendered bodies. Debug-mode test: 50k messages searched in under 20 ms. |
| M7 Groups & Settings | Next | |
| M7–M12 | Planned | See `docs/email-client-windows-dev-plan.md` section 2 |

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
