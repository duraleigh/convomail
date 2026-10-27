# Windows Desktop App — Phase 1 Development Plan

**Status:** Approved September 29, 2026; all thirteen milestones M0–M12 implemented as of October 26, 2026 (per-milestone notes in `README.md`). Still unverified: a real SMTP send from the owner's account and its rendering in Gmail web / Outlook / Apple Mail (M4), the 24-hour tray soak (M10), toasts and tray on screen beyond widget tests (M10), an MSIX install on a second PC (M12). Microsoft OAuth (M11) is not implemented; the Outlook preset says so.
**Companion documents:** `email-client-build-spec.md` (behavior and structure), `email-client-visual-mockups.html` (visual tokens and screens).
**Date:** September 29, 2026

---

## 1. Framework and Architecture Proposal

### 1.1 Recommendation: Flutter (Dart) for Windows, shared with Android in Phase 2

The spec presumed a native Kotlin Android app and asked for the Windows framework to be proposed with reasoning and with its Phase 2 implications stated. This section does that. **The recommendation departs from the Kotlin presumption**, so it is listed as Open Decision 1 in Section 4 rather than assumed.

Three candidates were evaluated against the spec's requirements (Section 6): Material 3 Expressive fidelity, Windows desktop maturity, a robust IMAP/SMTP/MIME library with OAuth2 and IDLE, a block-based editor, safe HTML rendering, Windows integration, MSIX packaging, and Phase 2 reuse.

| Requirement | **Flutter (Dart)** | Kotlin + Compose Multiplatform (JVM) | .NET + WinUI 3 |
|---|---|---|---|
| Material 3 Expressive | Material 3 is Flutter's native design system. Expressive components are arriving in Flutter releases; any not yet shipped (button groups, floating toolbar, wavy progress) are small to build on the existing M3 token system. | Google's own `compose-material3` is the reference implementation of Expressive, so fidelity is highest. | Fluent, not Material. The entire M3 look would be hand-built. |
| Windows desktop maturity | Stable since 2022; used in shipping desktop apps. | Production-quality (JetBrains' own tools use it). JVM runtime: heavier memory, slower cold start. | Native. Best OS fit. |
| IMAP/SMTP/MIME + OAuth2 + IDLE | `enough_mail`: actively maintained pure-Dart IMAP, SMTP, MIME, IDLE, XOAUTH2. Works unchanged on Android. | Jakarta Mail: the most battle-tested IMAP library anywhere. On Android it needs a fork (`android-mail`) that lags; K-9 wrote its own. Phase 2 risk. | MailKit: excellent. No Android path. |
| Block-based editor (4.4) | `appflowy_editor`: an open-source Notion-style block editor in Flutter, desktop-ready. Directly matches the spec's "Notion-like" requirement. | No mature block editor. Would be built from `BasicTextField` primitives. Large effort. | None block-based. |
| Safe HTML email rendering (4.13) | Sanitize locally, then render in WebView2 (`webview_windows`). WebView2 ships with Windows 11 and is a small bootstrap on Windows 10. | Embedded Chromium (KCEF) adds ~150 MB, or JavaFX WebView with awkward interop. | WebView2 native. |
| Windows integration | Packages exist for each: Credential Manager (`flutter_secure_storage`), toast (`local_notifier` / `windows_notification`), taskbar badge (`windows_taskbar`), tray (`system_tray`), `mailto:` (`protocol_handler`). | Each requires JNA bindings to Win32/WinRT written by hand. Toast notifications are the hardest. | Native APIs. |
| MSIX packaging | `msix` package produces a signed MSIX in one command. | jpackage makes MSI/EXE; MSIX needs the Packaging Tool or a commercial tool. | Native. |
| **Phase 2 (Android) reuse** | **Near-total.** Same Dart code; only the platform layer (notifications, keystore, share sheet) changes. | UI reuses well; the mail layer is the risk noted above. | Effectively none. |

**Why Flutter over Compose Multiplatform:** Compose has the more faithful Expressive components, but every other row favors Flutter, and three of them are the project's hardest features: the block editor, HTML rendering, and Windows integration. The Expressive gap is closable with a few hundred lines of custom widgets on top of Flutter's complete M3 token system. Compose's gaps (editor, notifications, Android mail library) are each multi-week efforts with no off-the-shelf answer.

**Why not WinUI 3:** it would be the most native Windows app, but the spec's design system is Material 3 Expressive, and there is no Android reuse. It optimizes for the thing the spec does not ask for.

**What this implies for Phase 2:** the Android app becomes the same Flutter codebase with an Android platform layer, not a separate native Kotlin app. This is the explicit flag the spec asked for.

### 1.2 Architecture

Layered, with the domain rules from spec 4.3, 4.11, 4.14, 4.19 and 4.20 isolated in pure Dart so they are unit-testable without a mail server or UI.

```
ui/            Material 3 Expressive theme, navigation rail, three-pane shell, all screens
app/           state management (Riverpod), routing, view models, keyboard shortcuts
domain/        pure Dart, no I/O:
                 identity.dart      alias + address resolution (4.14)
                 filing.dart        sender-only filing, group exact-match (4.3, 4.19)
                 threading.dart     hybrid thread reconstruction (4.20)
                 classifier.dart    People/Feeds rules, exceptions, overrides (4.11)
                 rules.dart         user-accepted correction rules, rule proposal (4.11)
                 search.dart        query parsing, Include-Feeds scoping (4.6)
                 snooze.dart, planner.dart, kanban.dart
store/         drift (SQLite) schema, DAOs, FTS5 index, migrations
sync/          per-account sync engine: folder discovery, UIDVALIDITY handling,
               incremental header fetch, body/attachment fetch on demand, flag
               reconciliation, IDLE loop with reconnect/backoff, outbox for SMTP
mail/          enough_mail wrappers: IMAP session, SMTP session, MIME build/parse,
               OAuth2 token flows (Google, Microsoft), provider auto-configuration
platform/      windows/: Credential Manager, toast, taskbar badge, tray, mailto,
               file preview, WebView2 host. (android/ added in Phase 2)
```

Key design rules:
- **Stable message identity.** Every message row carries its RFC Message-ID, account, folder and UID. Filing, threading and all user metadata (tags, snooze, Kanban column, category) key off Message-ID, so a future cross-device sync or a re-sync after UIDVALIDITY change does not orphan user data.
- **Filing and threading stored separately** (spec 4.20): `message_row_assignment` (which People/Feeds/group row a message lives in) and `thread_membership` are distinct tables. Changing one rule never rewrites the other.
- **All classification decisions are logged** (`classification_events`: message, rule that fired, user override, timestamp) to satisfy spec 4.15's training-data requirement.
- **No network call leaves the app except to the user's mail providers and the OAuth endpoints of Google/Microsoft.** Provider auto-configuration uses a bundled snapshot of the open ISPDB data plus DNS SRV lookup, not a live lookup (Open Decision 4).
- **HTML mail is sanitized before rendering:** scripts, forms, external stylesheets and remote `<img>`/CSS-background URLs are stripped; each removed remote host is recorded in `tracker_log`; the placeholder and "Load images" flow (4.13) re-inserts them on demand. The sanitized document renders in WebView2 with navigation disabled and a strict CSP.

### 1.3 Data model (principal tables)

`accounts`, `identities` (aliases, per-identity SMTP), `folders`, `messages`, `message_bodies`, `message_participants` (role To/CC/From, resolved contact id), `attachments`, `contacts`, `contact_addresses`, `me_addresses`, `groups`, `group_members`, `message_row_assignment`, `threads`, `thread_membership`, `categories`, `sender_category_default`, `message_category`, `sender_classification` (People/Feeds + override flag + count-toward-unread flag), `classification_rules`, `classification_events`, `tags`, `kanban_columns`, `kanban_cards`, `snoozes`, `reminders`, `events`, `event_links`, `tracker_log`, `drafts`, `outbox`, `settings`, plus an FTS5 virtual table over subject, body text, sender and participant names.

---

## 2. Milestones

Complexity is S / M / L / XL. Risk is Low / Medium / High with the main risk named. Each milestone ends with its tests green and a working build you can run.

### M0 — Foundations and design system (M, Low)
- Repository, Flutter Windows project, CI (build + test on every push), lint rules.
- Material 3 Expressive theme from the mockups' tokens: color scheme (light/dark), shape scale, type scale, plus custom widgets for connected button group, floating toolbar, wavy progress, grouped list segments.
- App shell: window, navigation rail, resizable three-pane layout, keyboard shortcut registry, empty states.
- SQLite via drift with migrations; settings store.
- **Done when:** the shell runs, switches destinations, themes follow Windows light/dark, and golden tests cover the theme.

### M1 — Accounts, credentials, and sync engine (XL, High: sync correctness and OAuth)
- Provider auto-configuration (bundled ISPDB snapshot + SRV + common-host probing), manual IMAP/SMTP form, connection test.
- **Gmail via app password first** (requires 2-Step Verification on the Google account; no Google Cloud project needed). App passwords also cover iCloud, Yahoo, Fastmail and generic IMAP. Credential Manager storage.
- OAuth2 via loopback PKCE is built behind the same sign-in interface but is **deferred**: Google OAuth until a Google Cloud project exists (only needed for the sign-in-with-Google flow or for distribution), and Microsoft OAuth until there is a Microsoft account to test against. The product owner has only Gmail, so Microsoft OAuth is not on the Phase 1 critical path and is tracked as a later milestone item (see M11).
- Sync engine: folder discovery, initial header sync with paging, incremental sync by UID and MODSEQ where supported, body fetch on open, flag reconciliation both ways, IDLE with reconnect, outbox retry.
- Identity resolution (4.14): me-addresses across accounts, contact address merging, device-contacts import from Windows People (via vCard export, since there is no public Windows contacts API for desktop apps).
- **Done when:** the product owner's real Gmail account and a local test IMAP server each sync a 20k-message mailbox with no loss or duplication, survive network drop and sleep/resume, and reflect flag changes made in another client within seconds under IDLE.

### M2 — People list and filing (L, Medium: performance at scale)
- Sender-only filing (4.3), one row per contact, ordering by newest sent message, unread badges, pin.
- Grouped-list UI in the middle pane, filter chips (All, Unread, Starred, This Week, Sent, Has attachments, From contacts), hover actions, context menu, keyboard navigation.
- Row actions: archive/trash/mark-read all from sender with selective keep (4.16), undo window.
- **Done when:** the list opens in under 300 ms with 50k cached messages and updates live as mail arrives.

### M3 — Conversation view and threading (L, High: HTML rendering)
- Right-pane conversation: date grouping, collapsed thread rows, expanded message cards with To/CC, attachments, inline action bar.
- Hybrid threading (4.20) with the edge cases as unit tests; thread view overlay panel; "View thread (N)" control.
- HTML sanitizer, tracker log, image-blocking placeholder and "Load images", privacy strip, aggregate privacy stats.
- WebView2 host with disabled navigation and strict CSP; plain-text fallback.
- **Done when:** a corpus of 200 real-world HTML emails (newsletters, receipts, Outlook-generated, Apple Mail, Gmail) renders without layout escape, and no remote request is made unless the user loads images.

### M4 — Compose, reply, and send (L, High: editor)
- `appflowy_editor` integration: headings, lists, bold/italic/underline, inline images, file attachments by picker, drag-and-drop and paste.
- Filled From/To/Subject fields with recipient autocomplete; identity selector; signatures per identity.
- Inline reply at the bottom of the conversation; new-message compose in the right pane; drafts autosave; SMTP send with wavy progress and failure feedback.
- MIME building: multipart/alternative with HTML and plain text, inline CID images, attachments.
- **Done when:** messages composed here render correctly in Gmail web, Outlook desktop, and Apple Mail.

### M5 — Attachments (M, Low)
- Per-contact attachments panel: List/Grid button group, featured card, grouped file list with type icons, photo grid.
- In-app preview overlay for images and PDFs (PDF via `pdfrx`), Save As.
- **Done when:** all attachment types listed in 4.5 preview or hand off to the OS correctly.

### M6 — Search and filters (M, Medium: FTS relevance)
- FTS5 index maintained by the sync engine; global search from the middle pane; in-conversation search; result highlighting.
- Include Feeds switch (off by default); filter-chip scoping of results.
- **Done when:** search over 50k messages returns in under 200 ms.

### M7 — User-defined groups and Settings (M, Low)
- People Groups settings: create, edit members, delete; exact-match filing (4.19) with re-filing on edit; stacked-avatar rows.
- Settings destination: Accounts, Appearance (light/dark/system, dynamic color), Notifications, Privacy, Groups & Tags, Default mail app.
- **Done when:** the Simon/Sarah/Joann examples from spec 4.19 pass as automated tests against a seeded mailbox.

### M8 — People vs Feeds (L, Medium: false positives)
- Rules classifier (4.11) with the full signal list; per-message personal-signal exceptions; permanent overrides; count-toward-unread per sender.
- Categories: five defaults, custom categories, sender defaults, per-message assignment.
- Correction flow: propose a rule in plain language, Accept / Edit / Just this once; rule list in Settings; retroactive apply.
- Feeds view in the middle pane, "N filed" banner, category pills, bell marker.
- Classification event log for future ML.
- **Done when:** on a labeled test corpus of 2,000 messages the rules place at least 95% of bulk mail in Feeds and no human-to-human reply in Feeds.

### M9 — Boards, snooze, reminders, planner (XL, High: event extraction)
- Kanban: tags with sub-tags, columns, drag-and-drop with lift, card → conversation side panel, counts.
- Snooze presets and custom picker; hidden-until-due; resurfacing with notification and re-sort. Reminders.
- Planner: week grid, manual events and to-dos, **rules-based event extraction** from message text (dates, times, "meeting", "call", calendar invites via iCalendar attachments, which cover most real cases), bidirectional links.
- **Done when:** iCalendar invites and explicit date-time phrases produce events; ambiguous text does not.

### M10 — Notifications and Windows integration (M, Medium: toast/badge APIs)
- Toast notifications for new mail with per-account and per-contact mute; snooze wake-ups; click-to-open.
- Taskbar overlay badge and tray icon with unread count; badge scope setting; per-sender opt-in.
- `mailto:` protocol registration; launch-at-login option; single-instance enforcement.
- **Done when:** the app behaves correctly when minimized to tray for 24 hours.

### M11 — Multi-account (M, Medium)
- Unified People list across accounts, per-account view, account indicator on rows and messages, cross-account contact merge, cross-account threads.
- Microsoft OAuth (Outlook.com / Microsoft 365) lands here if a Microsoft test account becomes available; otherwise it ships untested and marked experimental in the account-setup screen.
- **Done when:** the same contact writing to two of your addresses appears once, and a thread spanning two accounts is one thread. Tested with two Gmail accounts, or Gmail plus the local test server.

### M12 — Polish, performance, packaging (L, Medium: signing)
- Spring motion, shape morphs, empty states, accessibility (screen reader labels, focus order, contrast).
- Large-mailbox soak test (200k messages), memory and startup budgets.
- MSIX packaging, code signing, auto-update channel, first-run onboarding, crash reporting that stores logs locally only.
- Full regression pass against the Section 7 definition of done.

### Stretch (after M12, not Phase 1 blockers)
- Relationship graph (4.12).
- On-device AI (4.15) via ONNX Runtime or Windows Foundry Local, trained/evaluated against the classification event log.

### Milestone summary

| # | Milestone | Complexity | Risk |
|---|---|---|---|
| M0 | Foundations & design system | M | Low |
| M1 | Accounts, credentials, sync | XL | High |
| M2 | People list & filing | L | Medium |
| M3 | Conversation & threading | L | High |
| M4 | Compose & send | L | High |
| M5 | Attachments | M | Low |
| M6 | Search & filters | M | Medium |
| M7 | Groups & Settings | M | Low |
| M8 | People vs Feeds | L | Medium |
| M9 | Boards, snooze, planner | XL | High |
| M10 | Notifications & Windows integration | M | Medium |
| M11 | Multi-account | M | Medium |
| M12 | Polish, performance, packaging | L | Medium |

Order rationale: M1 through M4 form the minimum usable mail client and carry the highest risk, so they come first. M5 through M8 complete the people-centric feature set. M9 is large but independent, so it follows. M10 through M12 are integration and hardening.

---

## 3. Testing Strategy

- **Domain unit tests** (pure Dart, table-driven): filing, group exact-match, identity resolution, threading edge cases from 4.20, classifier signals and exceptions, rule proposal. These are written alongside each rule and are the acceptance tests for spec Appendix A.
- **Sync integration tests** against a local IMAP/SMTP server (GreenMail standalone, or Dovecot in Docker) seeded with generated mailboxes, plus the product owner's real Gmail account. A second free Gmail account is recommended for multi-account testing. No Microsoft account is available, so Outlook.com paths are covered only by the local server's generic IMAP behavior.
- **HTML corpus tests**: a stored set of real-world emails run through the sanitizer; assertions on stripped content and recorded tracker hosts.
- **Widget and golden tests** for every screen in light and dark.
- **Performance fixtures**: generated 50k and 200k message mailboxes with timing assertions on list open, search, and sync.
- **Manual acceptance** per milestone against the "Done when" line above, recorded in a checklist file in the repo.

---

## 4. Open Decisions Requiring the Product Owner

1. **Framework.** Approve Flutter (recommended, Section 1.1), or choose Kotlin + Compose Multiplatform accepting the editor, notification, and Android mail-library gaps. This decides whether Phase 2 is a shared codebase or a native Kotlin app.
2. **Premium gating.** Spec 4.6 and 4.8 mention premium tiers for advanced search and unlimited tags. Phase 1 can build everything ungated with a feature-flag layer, or omit gating entirely. Nothing in the plan depends on this, but the flag layer is cheaper to add at M0 than later.
3. **HTML rendering dependency.** WebView2 is present on Windows 11 and most Windows 10 machines. Approve the WebView2 dependency (with a runtime bootstrap in the installer), or require a pure-Flutter renderer with reduced fidelity for complex newsletters.
4. **Provider auto-configuration source.** Recommended: a bundled snapshot of the open ISPDB data plus DNS SRV lookup, refreshed with app releases, so no third party ever sees the user's domain. Alternative: live ISPDB lookup, which sends only the domain to Mozilla but is a third-party call.
5. **Cross-device state for Phase 2.** Tags, Kanban columns, snooze times, categories, groups and planner items are not stored by IMAP. Phase 1 keeps them local. For Phase 2, the options are: store them in a hidden IMAP folder as an encrypted document (local-first, no third party), use IMAP custom keywords for the subset that fits, or keep devices independent with export/import. The schema in 1.3 is designed to support the first option later; no decision is needed now, but it affects how much Phase 2 costs.
6. **Distribution and signing.** Direct MSIX download requires a code-signing certificate. Microsoft Store distribution avoids that but adds Store review. Personal use only can use a self-signed certificate. This affects M12 and the Gmail item below.
7. **Gmail sign-in method.** For a personal build, a Gmail **app password** is enough: turn on 2-Step Verification, generate an app password, paste it into the app. No Google Cloud project, no Microsoft Entra registration, nothing to register anywhere. The OAuth "Sign in with Google" flow is optional; it needs a Google Cloud project, and beyond 100 users Google requires app verification and a paid security assessment. Recommended: app password for Phase 1; revisit OAuth only if the app is ever distributed.
8. **Windows 10 support.** Supporting Windows 10 adds the WebView2 bootstrap and older-API fallbacks. Recommended: Windows 10 21H2 and later, Windows 11 primary.

---

## 5. What Happens After Approval

1. Create the repository and the M0 project skeleton.
2. Set up the local IMAP test server. On your side: enable 2-Step Verification on your Gmail account and generate an app password for the app (Google Account → Security → 2-Step Verification → App passwords).
3. Work through M0 → M12 in order, delivering a runnable build at the end of each milestone for your review.
4. No Android work until Section 7's definition of done is met and you sign off.
