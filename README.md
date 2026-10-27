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
| M6 Search & filters | **Done** (2026-10-24) | FTS5 index (`message_fts`, schema v7) over subject, sender, and body, maintained by SQLite triggers and backfilled on upgrade; HTML-only mail gets a derived text body for indexing. Search-results mode in the middle pane (People matches + ranked message hits with highlighted subject/snippet), scoped by the active filter, Include Feeds switch (persisted, no effect until M8 classification). Opening a hit selects the row, expands and scrolls to the message. In-conversation search field with match count, card filtering, and `<mark>` highlighting inside rendered bodies. Debug-mode test: 50k messages searched in under 20 ms. |
| M7 Groups & Settings | **Done** (2026-10-25) | Settings → People Groups: create / rename / edit members / delete with contact autocomplete, validation (2+ members, never the user), stacked-avatar rows, "N conversations filed", jump to the row. Group changes re-file only the affected messages (exact-match rule, spec 4.19) with the Simon/Joann/Sarah examples as tests. Settings → Notifications (global switch, badge scope, per-account mute; delivery in M10). Settings → Default mail app: per-user `mailto:` registration in HKCU plus a link to Windows Default apps; `mailto:` launch arguments open the composer prefilled. |
| M8 People vs Feeds | **Done** (2026-10-25) | Rules classifier (`lib/domain/classifier.dart`): bulk headers (List-Unsubscribe/Id/Post, Feedback-ID, Precedence, Auto-Submitted), automated local parts, bundled sending-domain list; People signals (wrote to them, address book) override; per-message exceptions (reply to my mail, salutation by name). Schema v8: signals on messages, sender bucket/category/counts-toward-unread on contacts, per-bucket row summaries, categories, rules, event log. Header fetch now includes list headers; pre-M8 mail gets a signal backfill pass. People/Feeds tabs with category pills, bell marker, "N filed" banner; permanent manual moves; correction flow proposing a rule (Accept / Edit / Just this once, retroactive apply); Settings → Feeds (badge scope, counting senders, categories CRUD, rules, overrides). Corpus test: 96.7% of 1,200 bulk senders → Feeds, 0 human replies → Feeds. |
| M9 Boards, snooze, planner | **Done** (2026-10-26) | Boards: renameable columns (Next / In Progress / Done seeded), cards per thread with subject, sender avatar, tags, counts; drag with lift-and-tilt between and within columns; tag filter; side panel with the thread; Settings -> Groups & Tags with unlimited sub-tags. Snooze: presets + date-time picker (S), hidden until due, Snoozed filter, resurfaces sorted as new with an in-app notice; reminders fire once without hiding. Planner: mini month, to-dos, reminders, week grid with hour rows, overlap columns, now-line, color keys; detail panel with Open conversation, Keep / Not an event; linked-item chips under messages. Rules-based extraction: iCalendar parts (incl. updates/cancellations) and explicit date-time phrases; vague phrasing ignored; runs on body fetch and a bounded pass over recent People mail. Schema v9. |
| M10 Notifications & Windows integration | **Done** (2026-10-26) | Windows toasts for new People mail after the first sync (grouped per sender; honors the global switch, badge scope, per-account mute, per-row mute, snooze, and counts-toward-unread senders), click opens the row; snooze wake-ups and reminders as toasts. Tray icon with menu (Open / New message / Quit) and unread tooltip; taskbar overlay badge 1–9+ (bundled icons) with a hide setting; close-to-tray; start with Windows (minimized); single instance over a loopback socket with mailto: forwarding. |
| M11 Multi-account | **Done** (2026-10-26) | Unified People list stays the default; account switcher on the rail avatar (All accounts / each account / Add account) scopes rows, messages, search, and the compose From default to one account, with a removable scope chip in the Chats header. Account color dots on rows and a "via account" marker on messages when more than one account exists. Settings → Accounts: reorder and pause/resume syncing. Cross-account contact merge and threads (same contact at two addresses is one row; a thread spanning two accounts is one thread) covered by tests with two fake servers. Microsoft OAuth remains unimplemented and the Outlook preset says so; no Microsoft test account was available. |
| M12 Polish, performance, packaging | **Done** (2026-10-26) | Local-only diagnostics log (`%APPDATA%\com.convomail\convomail\logs`, seven days, exceptions and stack traces only) wired to FlutterError and uncaught async errors, with Open folder / Clear in Settings → About & updates and a note in Privacy. First-run welcome screen with Add your account / Explore first. Manual update check against a user-supplied https JSON feed (no telemetry, no background download). Screen-reader labels on People rows, tooltips on rail controls. `--bench-size=N` soak run (see Performance). MSIX packaging via `dart run msix:create` with the package's test certificate (no code-signing certificate available; see Install). |

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

## Performance

Release-binary benchmarks on the development PC, October 26, 2026 (`convomail.exe --bench-people [--bench-size=N]`, `--bench-search`; results land in `%TEMP%`).

| Scenario | Result |
|---|---|
| People list, 50k messages / 5k senders | median 170 ms per list query (5 runs); full summary build 199 ms; incremental refresh after 500 changed messages 66 ms |
| People list, 200k messages / 20k senders (soak) | median 676 ms per list query; full summary build 730 ms; incremental refresh 201 ms |
| Full-text search, 50k messages | 12–21 ms per query with 100 hits; FTS seeding with triggers 3.1 s |

The 200k unified list is the trigger-maintained `row_summaries` path. The per-account scoped list (M11) recomputes its summary per query and is slower on large mailboxes; it is meant for occasional use.

## Install

`flutter build windows` produces a portable folder at `build\windows\x64\runner\Release\` (run `convomail.exe` from there). `dart run msix:create` wraps that folder into `build\msix\convomail.msix` using the `msix_config` block in `pubspec.yaml`. Because no code-signing certificate is available, the package is signed with the msix tool's test certificate: before double-clicking the `.msix`, install that certificate into **Local Machine → Trusted People** (right-click the `.msix` → Properties → Digital Signatures → Details → View Certificate → Install Certificate), or run `dart run msix:create --install-certificate true` once from an elevated prompt. A real certificate goes in `certificate_path` / `certificate_password` with `publisher` set to its subject.

Without trusting any certificate, a PC with Developer Mode on can register the unpacked package in place (this is how the package was tested on the development PC): unzip `convomail.msix` into a folder (it is a zip; `Expand-Archive` refuses the extension, Python's `zipfile` or 7-Zip work), then

```
Add-AppxPackage -Register <folder>\AppxManifest.xml
```

That gives the Start menu entry, the `convomail` execution alias under `%LOCALAPPDATA%\Microsoft\WindowsApps`, and the `mailto:` protocol registration, running from that folder (so do not delete it). The packaged app uses the same `%APPDATA%\com.convomail` data folder as the portable build. `Remove-AppxPackage com.convomail.app_<hash>` uninstalls it. Updates: Settings → About & updates takes the https address of a JSON file `{"version","url","notes"}` and compares it with the running version on demand.

## Build

Requires Flutter stable (3.47+) and Visual Studio 2022 Build Tools with the "Desktop development with C++" workload.

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run -d windows
```
