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
| M7 Groups & Settings | **Done** (2026-10-25) | Settings → People Groups: create / rename / edit members / delete with contact autocomplete, validation (2+ members, never the user), stacked-avatar rows, "N conversations filed", jump to the row. Group changes re-file only the affected messages (exact-match rule, spec 4.19) with the Simon/Joann/Sarah examples as tests. Settings → Notifications (global switch, badge scope, per-account mute; delivery in M10). Settings → Default mail app: per-user `mailto:` registration in HKCU plus a link to Windows Default apps; `mailto:` launch arguments open the composer prefilled. |
| M8 People vs Feeds | **Done** (2026-10-25) | Rules classifier (`lib/domain/classifier.dart`): bulk headers (List-Unsubscribe/Id/Post, Feedback-ID, Precedence, Auto-Submitted), automated local parts, bundled sending-domain list; People signals (wrote to them, address book) override; per-message exceptions (reply to my mail, salutation by name). Schema v8: signals on messages, sender bucket/category/counts-toward-unread on contacts, per-bucket row summaries, categories, rules, event log. Header fetch now includes list headers; pre-M8 mail gets a signal backfill pass. People/Feeds tabs with category pills, bell marker, "N filed" banner; permanent manual moves; correction flow proposing a rule (Accept / Edit / Just this once, retroactive apply); Settings → Feeds (badge scope, counting senders, categories CRUD, rules, overrides). Corpus test: 96.7% of 1,200 bulk senders → Feeds, 0 human replies → Feeds. |
| M9 Boards, snooze, planner | **Done** (2026-10-26) | Boards: renameable columns (Next / In Progress / Done seeded), cards per thread with subject, sender avatar, tags, counts; drag with lift-and-tilt between and within columns; tag filter; side panel with the thread; Settings -> Groups & Tags with unlimited sub-tags. Snooze: presets + date-time picker (S), hidden until due, Snoozed filter chip, resurfaces sorted as new with an in-app notice; reminders fire once without hiding. Planner: mini month, to-dos, reminders, week grid with hour rows, overlap columns, now-line, color keys; detail panel with Open conversation, Keep / Not an event; linked-item chips under messages. Rules-based extraction: iCalendar parts (incl. updates/cancellations) and explicit date-time phrases; vague phrasing ignored; runs on body fetch and a bounded pass over recent People mail. Schema v9. |
| M10 Notifications & Windows integration | Next | |
| M10–M12 | Planned | See `docs/email-client-windows-dev-plan.md` section 2 |

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
