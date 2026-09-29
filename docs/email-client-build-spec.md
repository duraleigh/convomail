# Sender-Centric Email Client — Full Product & Build Specification

## 0. How to Use This Document

This document is the complete product specification for a native email client application. It is being handed to you (Claude Code) as the starting brief for a real, from-scratch software build. It describes every feature, every screen, and every interaction the finished product must support, modeled on two existing Apple-only apps (Unibox and ChatInbox) that we are reimplementing independently for platforms they do not support.

**Do not write any code yet.** Your first task, described in Section 9, is to produce a detailed, phased development plan for the **Windows desktop version only**. Android work does not begin until the Windows app is fully built, tested, and finalized.

---

## 1. Project Overview & Vision

We are building a native email client centered on **people, not folders**. Instead of the traditional reverse-chronological inbox where every message is an isolated row regardless of who sent it, this app groups all correspondence by sender/contact, presenting each relationship as a single scrollable conversation — similar in feel to a text-messaging or chat app.

This concept already exists as two Apple-exclusive products:
- **Unibox** (by eightloops GmbH) — the original people-centric email client for Mac/iOS, first released in the early 2010s, now largely unmaintained.
- **ChatInbox** (by Innovatism LLC) — a newer, actively maintained successor that keeps Unibox's core idea and adds task-board organization, snoozing, calendar extraction, and privacy tooling.

Neither app is available on Windows or Android, and their developers have stated no intention of building for those platforms. Rather than attempt to port or wrap the Apple apps (which is fragile and unreliable), we are building **our own native applications from the ground up**: one for **Android** and one for **Windows desktop**, replicating and combining everything both reference apps do, adapted to each platform's native UI conventions.

---

## 2. Target Platforms & Build Order

- **Phase 1 (build first): Windows desktop/laptop app.** Must be fully functional, tested, and finalized before any mobile work begins.
- **Phase 2 (build second): Android mobile app.** Begins only after Phase 1 is signed off.

The Windows framework is **not assumed**: the Phase 1 plan must propose one with reasoning, and the proposal must state what it implies for Phase 2 (how much of the Windows codebase the Android app can reuse). For Android, a native Kotlin app remains the presumed default unless the Phase 1 framework choice makes a shared codebase the better path — flag that explicitly rather than deciding it silently.

---

## 3. Core Design Philosophy

1. **People first.** The primary navigation unit is a contact, not a folder or a subject line.
2. **One person, one conversation.** A contact's row holds the messages that contact *sent*, plus the messages the user sent *to* that contact, in a single scrollable view, most recent at the bottom or top (to be decided in design phase, but consistent with the chat metaphor). A message is filed under its sender only; being a recipient of someone else's message never places that message in a contact's row. See 4.3, 4.19, and 4.20 for the filing and threading rules.
3. **Minimal, uncluttered visual language.** Generous whitespace, soft rounded corners, muted accent colors, avatar-driven identity (photo or colored initials), pill-shaped filter chips.
4. **Local-first and private by default.** No proprietary cloud relay for email data. The app talks directly to the user's mail provider (IMAP/SMTP or provider API/OAuth) from the device. No third-party server stores or reads message content.
5. **Familiar messaging-app interaction patterns.** Reply, forward, swipe actions, and search should feel like a modern chat app, not a legacy desktop mail client.

---

## 4. Complete Feature Specification

### 4.1 Account Setup & Email Provider Connectivity

- Support IMAP/SMTP for: Gmail, iCloud/me.com/mac.com, Yahoo! Mail, Outlook.com/Hotmail/Live.com, Microsoft Exchange (where IMAP is enabled), Fastmail, and any self-hosted/custom IMAP server.
- **Automatic configuration**: user enters email + password/OAuth, app attempts to auto-detect IMAP/SMTP host, port, and security settings from known provider profiles.
- **Manual configuration fallback**: full form for IMAP host/port/security (SSL/TLS/STARTTLS), SMTP host/port/security, username, and authentication method.
- **OAuth2 authentication** for providers that require or prefer it (Gmail, Outlook/Microsoft 365) rather than raw password storage, since app-password/basic-auth support is increasingly restricted by major providers. Fall back to app-specific passwords where OAuth isn't offered (e.g., some IMAP-only providers).
- **Multiple accounts**: user can add any number of accounts across any mix of providers.
- **Account aliases**: a single account can send from multiple "From" identities/aliases, each optionally with its own SMTP server, matching Unibox's alias behavior.
- Credentials and tokens stored using the platform's secure credential storage (**Windows Credential Manager or DPAPI-encrypted storage** in Phase 1; Android Keystore-backed encrypted storage in Phase 2) — never in plain text, never transmitted to any server other than the mail provider itself.

### 4.2 People-Centric Inbox (Core Navigation Screen)

This is the main/home screen, equivalent to Unibox's contact sidebar and ChatInbox's "Chats" screen.

- **Header**: a Material 3 flexible top app bar — a row of icon buttons (menu icon left for account switching; filter icon and account avatar right) above a large left-aligned headline ("Chats"). Compose is a floating action button (FAB) at the bottom right, not an app-bar icon.
- **Bottom navigation bar** (Material 3 navigation bar) on every top-level screen with four destinations: Chats, Boards, Planner, Settings. The active destination shows a filled icon inside a pill-shaped indicator.
- **Search bar**: persistent, placeholder text "Search people and mail," always visible at the top of the list.
- **Filter chip row**: Material 3 filter chips — All, Unread, Starred, This Week, Sent, Has attachments, From contacts, and any user-created custom tags. On Windows the chips wrap to as many rows as the pane width needs; on Android (Phase 2) they scroll horizontally. Exactly one filter active at a time (or "All" by default); selected chip is visually highlighted (filled, contrasting color) versus unselected chips (outlined/muted).
- **No pinned-contacts strip.** The reference apps show a horizontal row of avatars above the list; this app does not. Pinning a contact (via swipe action) keeps that contact's row at the top of the main list instead, marked with a small pin icon.
- **Main contact list**: vertically scrolling list, each row containing:
  - Circular avatar (contact photo if available via device contacts/synced address book, otherwise colored circle with the contact's initials — color assigned deterministically per contact so it's consistent across sessions)
  - Contact display name (bold if unread messages exist)
  - Most recent message preview (single line, truncated with ellipsis)
  - Timestamp of the most recent message, right-aligned (relative format: "9:41 AM" for today, "Yesterday," weekday name for this week, date for older)
  - Unread count badge (colored circle with number) if applicable
  - Each contact appears **exactly once** in this list, regardless of how many messages they've sent — sorted by the recency of the most recent message *that contact sent*. When a new reply arrives in a multi-person thread, only the replier's row moves to the top; the other participants' rows stay where they were.
  - **User-defined group rows** (see 4.19) appear in this same list and behave identically to contact rows: one row, sorted by recency, with an unread badge, swipe actions, and pinning.
  - The app **never auto-generates a group row**. Multi-recipient mail follows the sender-only filing rule unless the user has explicitly created a matching group in Settings.
- **List behavior**: pull-to-refresh triggers a manual sync; list updates live as new mail arrives (push or periodic poll, see 4.17).
- **Row actions**: Archive, Delete/Trash all messages from this sender, Mark all as read, Snooze, Pin/Unpin. On Windows these appear as hover-revealed icon buttons at the right edge of the row and in a right-click context menu, with keyboard shortcuts. On Android (Phase 2) they are swipe-to-reveal.

### 4.3 Conversation View (Selecting a Contact)

Tapping a contact opens their dedicated conversation screen.

- **Header**: back button, contact name (tap to open contact detail/info panel), search-within-conversation icon, overflow menu (⋯) for additional actions (block sender, export conversation, view all attachments, etc.).
- **Date-grouped message list**: messages grouped under day headers ("Today," "Yesterday," "Last Tuesday," or full date for older), matching the grouping style both reference apps use.
- **Message rows are collapsed by default** when there are multiple exchanges on the same subject/thread: each row shows the subject line, a reply-count indicator, the latest sender's avatar/name, a one-line preview of the latest message, and its timestamp. Tapping a row expands it inline to show the full message.
- **Expanded message view** shows: sender name and avatar, "To:" and "CC:" recipient(s) in full, full timestamp, folder/label context (e.g., "Inbox"), complete message body (rendered HTML where safe, with remote images blocked by default — see 4.13), and any attachments displayed as inline preview cards (thumbnail, filename, file size).
- **Filing rule**: a message appears in the conversation of the person who **sent** it, and nowhere else (unless it matches a user-defined group — see 4.19). If Simon emails the user, Sarah, and Joann, that message lives under Simon. If Sarah replies, her reply lives under Sarah. Simon's and Joann's rows are not touched by Sarah's reply.
- **Multi-participant threads and the "View thread" control**: any message that belongs to a thread containing more than one message shows a **"View thread (N)"** control (N = message count). Tapping it opens a **thread view** listing every message in that thread from every participant, including the user, in chronological order, regardless of which contact rows those messages are filed under. The thread view is read/reply-capable like the conversation view. Thread membership is determined by the threading model in 4.20 and is independent of filing.
- **The user's own sent messages** appear inline in each recipient's conversation (a message the user sent to Simon and Joann appears in both Simon's and Joann's rows), with the same "View thread" control.
- **Inline action bar** under each expanded message: Reply, Forward, Star/Favorite, View thread (when applicable), and an overflow (⋯) for Delete, Mark unread, Move, etc.
- **Composing a reply** happens inline at the point of the message — no separate popup window (matching Unibox's single-window philosophy).

### 4.4 Compose & Reply

- **Single-window editing**: composing a new message or replying never opens a separate window/activity that loses context — it expands in place within the current screen.
- **Rich, block-based editor** (ChatInbox-style, Notion-like): supports headings, bulleted/numbered lists, bold/italic/underline, inline images, and drag-and-drop file attachment, all within a distraction-free canvas.
- **Attachments**: add via file picker, drag-and-drop (desktop), or paste; each attached file shown as a removable chip/card with filename and size before sending.
- **Signature**: user-configurable per account/alias, auto-inserted into new messages and replies (editable before send).
- **From/identity selector**: when an account has multiple aliases, a dropdown lets the user choose which identity to send from before composing/sending.
- **Send progress indicator**: a visible progress bar or spinner while the message is transmitting (matching a detail noted in Unibox reviews as a nice touch), with clear success/failure feedback.
- **Draft autosave**: in-progress compositions are saved automatically and recoverable if the app is closed or backgrounded.

### 4.5 Attachments & File Management

- **Per-contact attachment views**: within any conversation, a dedicated screen lists every attachment ever exchanged with that contact.
- **Two view modes**:
  - **List view**: filename, file-type icon/badge (color-coded by type: PDF, XLS, PPT, DOC, CSV, JPG, etc.), file size, and date, in a scrollable table.
  - **Grid view**: visual thumbnail grid for images/photos specifically, with a larger featured preview card at the top showing the most recent or most relevant file (filename, sender, size, date, and a "Quick Look"-style full-preview button).
- **In-app preview**: tapping a file opens a native quick-look/preview without leaving the app or requiring an external app, where the platform supports it (image, PDF, common document types at minimum).
- **Download/save**: explicit action to save an attachment to local device storage.

### 4.6 Search

- **Global search**: accessible from the main inbox screen, searches across all contacts and all message content/subjects across all connected accounts.
- **In-conversation search**: scoped search within a single contact's message history.
- **Filter combination**: search results respect active filter chips (e.g., searching while "Starred" is selected only searches starred items).
- **Include Feeds switch**: the search results screen carries an "Include Feeds" toggle, **off by default**. Off: results come from People rows only. On: results also include Feeds senders and messages (see 4.11), each marked with its category tag.
- Advanced/premium tier: more powerful query support (e.g., search by attachment type, date range) — flagged as a "premium" feature to design for, consistent with ChatInbox's tiering, but exact gating logic is a business decision to confirm before implementation, not something to assume.

### 4.7 Filters & Smart Views

- **Unread**: contacts/messages with unread items only.
- **Starred**: messages the user has explicitly flagged.
- **This Week**: messages received within the last 7 days.
- **Sent**: the user's sent messages already appear inline in each recipient's conversation (4.3). The Sent chip filters the People list down to the rows that contain mail the user sent, and the conversation view under that chip shows only the user's outgoing messages to that contact.
- **Has attachments**: filter to contacts/messages with file attachments (from Unibox's filter set).
- **From address book / known contacts**: filter to only show senders present in the user's contacts (from Unibox's filter set).
- **Custom tags**: user-defined filters (see Kanban board, 4.8) also surface here as quick filter chips.

### 4.8 Kanban Task Board ("Boards")

- A separate screen/tab that presents tagged conversations as draggable cards across user-defined workflow columns (default suggestion: "Next," "In Progress," "Done" — but fully renameable/configurable).
- Each card shows: subject/conversation title, sender avatar (colored initials or photo), and sender name.
- **Drag-and-drop** to move a card between columns, which updates the underlying tag/status on that conversation.
- **Tagging system**: any conversation can be tagged with one or more labels; tags can have **unlimited sub-tags** (e.g., a "Work" tag with sub-tags "Design," "Finance," "Engineering") for premium users, limited tag count for free-tier users (exact free/premium split to be confirmed as a business decision, not assumed here).
- Column counts displayed as a badge (e.g., "Next 6," "In Progress 5").
- **Kanban tags are a separate system from Feeds categories** (4.11). Tags describe what the user is *doing* with a conversation; Feeds categories describe what a message *is*. Neither list is shown in the other's UI, and a Kanban board never fills with newsletters.

### 4.9 Snooze & Reminders

- Any message/conversation can be **snoozed**: it disappears from the main inbox list and automatically reappears at a chosen future time.
- **Snooze options**: quick presets (e.g., "Tomorrow 8:00 AM," "Next Monday 8:00 AM") plus a custom date/time picker ("Pick a date…").
- When a snoozed item resurfaces, it should generate a local notification (see 4.17) and return to its normal position in the inbox list, sorted as if newly received.
- **Reminders** are a related but distinct concept: user-set reminders tied to a specific email/task that alert at a specified time without necessarily hiding the item from the inbox in the interim (used for the linked to-do/calendar feature below).

### 4.10 Calendar & Daily Planner

- A dedicated **Planner** screen showing a weekly calendar grid (days as columns, hours as rows) populated automatically with **events extracted from email content** (e.g., a message mentioning a meeting time/date is parsed and surfaced as a calendar block).
- Manually created events and to-dos also appear alongside auto-extracted ones.
- **Bidirectional linking**: a to-do or calendar event can be linked back to the specific email conversation it originated from, and vice versa — tapping the event opens the source conversation, and tapping the conversation shows any linked events/to-dos.
- Color-coded event blocks by category/type (personal, work, etc.) — categorization logic to be defined during design, not assumed here.
- Day-navigation controls (previous/next day or week, "today" jump button).

### 4.11 People vs. Feeds Auto-Categorization

- A toggle (segmented control) between **People** and **Feeds** views on the main inbox.
- **People**: the primary, human-to-human conversations — "the inbox that matters."
- **Feeds**: automatically detected non-human/transactional senders — newsletters, receipts, automated notifications/bots — sorted out of the main People view automatically, each tagged with a category. The Feeds screen uses the same one-row-per-sender layout as People.
- A visible counter/indicator (e.g., "24 filed to Feeds automatically") communicates how much volume has been auto-sorted, reinforcing the value of the feature.

**Classification granularity — per sender, with per-message exceptions**
- The People/Feeds decision is made for the **sender**: a sender's row lives entirely in People or entirely in Feeds.
- Exception: an individual message from a Feeds sender that carries **strong personal signals** is pulled into People for that message. Strong signals are: the message is a direct reply to mail the user sent (In-Reply-To matches a user-sent Message-ID); the message is addressed to the user by name in the body salutation and has no bulk-mail headers; or the message comes from a human-named address at a Feeds sender's domain (e.g., a support agent replying from a company that otherwise sends receipts). Such a message appears under the sender's row in People for that message only; the sender stays in Feeds.

**Classification method — Phase 1 is deterministic rules; ML is deferred**
- Phase 1 classifies with on-device, header- and history-based rules. A sender is routed to Feeds when it matches any of:
  - Presence of `List-Unsubscribe`, `List-Id`, `List-Post`, or `Feedback-ID` headers.
  - `Precedence: bulk` or `Precedence: list`, or `Auto-Submitted` with any value other than `no`.
  - Local-part patterns: `noreply`, `no-reply`, `donotreply`, `do-not-reply`, `notifications`, `notify`, `alerts`, `mailer-daemon`, `postmaster`, `newsletter`, `digest`, `updates`, `info@`, `hello@` (the last two only when combined with a bulk header).
  - Sender domain on a maintained, locally bundled list of known bulk/transactional/ESP sending domains (updatable with app releases, never fetched from a third-party service at runtime).
- A sender is routed to **People** when any of these hold, and they override the Feeds rules above: the user has ever sent mail to that address; the address is in the device address book; the user has manually moved the sender to People.
- All signals are readable from the message on the device. No server-side classification, no Gmail/Outlook category labels (which are API-only and unavailable over IMAP), and no network calls.
- **On-device machine learning is a later milestone**, gated on confirming what runs on the target devices (see 4.15). Until then, every manual move and category correction is stored as labeled data for that future model.

**Manual override — permanent until changed**
- The user can move any sender between People and Feeds from the row's swipe actions or overflow menu.
- A manual move is **permanent**: the rules never re-classify an overridden sender. The user can move it back at any time. Overrides are listed and editable in Settings → Feeds.

**Categories**
- Default categories: **Newsletter, Receipt, Notification, Social, Promotion**.
- The user can **create custom categories** (e.g., "OTP", "Shipping") and rename or delete any category, including defaults.
- Categories attach at the **message level**, with a **sender-level default**: assigning a category to a sender sets the default for that sender's future messages; individual messages may carry a different category (a bank's noreply address sends both one-time passcodes tagged OTP and statements tagged Notification).
- Categories are **separate from Kanban tags** (4.8). They never appear on the board and Kanban tags never appear in Feeds.
- Each Feeds row shows its sender-default category as a pill; a message row inside the conversation shows its own category when it differs.

**Correcting a misclassification — propose a rule, user confirms**
- When the user changes a message's category or moves a sender, the app **proposes the rule it would write** to prevent the same mistake, stated in plain language (e.g., "Subject contains 'passcode' or 'verification code' from noreply@bank.com → OTP"), and offers three choices: **Accept** (save the rule and apply it to future mail, with an option to apply retroactively), **Edit** (adjust the matched fields, words, or scope before saving), or **Just this once** (fix only this message; no rule is created).
- Rules the user has accepted are listed in Settings → Feeds → Classification rules, where they can be edited or deleted. The app never creates a rule silently.

**Unread counting**
- Whether Feeds unread mail counts toward the app-icon badge is a Settings toggle, **default off** (People only).
- Independently, any Feeds sender can be marked **"counts toward unread"** from its row. That sender stays in Feeds, but its unread messages are included in the badge and unread indicators. Example: the user marks a daily newspaper so its unread issues count, while the rest of Feeds does not.

**Search**
- Feeds senders and messages are included in global search only when the "Include Feeds" switch on the results screen is on (4.6). Default off.

### 4.12 Relationship Graph (Stretch Feature)

- An interactive visual network map showing how the user's contacts connect to one another (e.g., contacts who appear together as co-recipients on the same threads are linked visually).
- The graph is **derived from thread participant data** (4.20) purely for visualization. It never affects where a message is filed; filing follows the sender-only rule in 4.3 and the group rule in 4.19.
- Lower priority than the core features above — include in the full plan but appropriately sequenced as a later-phase/stretch feature rather than a Phase 1 blocker, since it is analytically and visually complex relative to its usage value.

### 4.13 Privacy & Tracking Protection

- **Remote image/tracking-pixel blocking**, on by default: images embedded in incoming HTML email are not auto-loaded; instead, the message shows an "Image blocked" placeholder with a "Load Images" button the user can tap to override on a per-message basis.
- **Blocked tracker log**: a visible list of specific tracking domains that were blocked in a given message (e.g., pixel-serving analytics domains), so the user can see concretely what was stopped.
- **Aggregate privacy stats**: running counters such as "X trackers blocked this week" and "X senders that know you've read their email" (i.e., senders whose tracking pixels were NOT blocked/were allowed), to make the privacy value tangible.
- **Toggle**: a global on/off switch for remote-image blocking, with the understanding that turning it off restores default image auto-loading.
- **No third-party data relay of any kind**: consistent with the "local-first" principle in Section 3 — this isn't just a UI feature, it's an architectural constraint that must hold for the whole app, not only the image-blocking feature.

### 4.14 Multi-Account Management

- **Unified view**: contacts and messages from all connected accounts merge into a single People list by default.
- **Contact merging across accounts**: if the same real-world contact emails the user at both a work and personal address (or the user is CC'd across accounts), that contact should appear as a single unified conversation thread rather than duplicated per account, matching ChatInbox's stated behavior.
- **Identity resolution**: all of the user's own addresses and aliases across every connected account resolve to a single "me" identity. A contact's several addresses (device-contact entries, observed reply-to variants, user-confirmed merges) resolve to a single contact identity. This resolution runs *before* the group exact-match test in 4.19 and before the participant list in the thread view (4.3), so alias or address variation never breaks a group match or splits a thread.
- **Per-account view**: user can filter/switch to see only a single account's contacts and messages when needed.
- **Account indicator**: some visual marker (color tag, small badge, or account initial) on messages/contacts to indicate which account a given message arrived through, especially useful in the unified view.

### 4.15 On-Device AI Writing Assistance

- **Compose-from-prompt**: user describes what they want to say; the app drafts a message body.
- **Proofreading**: grammar/tone suggestions on a drafted message before sending.
- **Auto-triage**: AI-assisted suggestions for categorizing/tagging incoming mail. **Phase 1 ships without a model**: triage uses the deterministic rules in 4.11. Every manual People/Feeds move, category assignment, and accepted correction rule is stored locally and accumulates as labeled training data, so a later on-device model can be evaluated against real user decisions before it replaces or augments the rules.
- Per the "local-first" principle, this should run **on-device** wherever the platform reasonably supports it, rather than sending message content to a third-party cloud AI service. Flag clearly during planning if a fully on-device implementation isn't practical on a given platform/timeline, so a decision can be made explicitly rather than silently defaulting to a cloud-based approach that would violate the privacy principle in Section 3.

### 4.16 Inbox Zero Tools & Bulk Actions

- **Archive, Trash, Mark as Spam** actions available per-message and per-contact (i.e., "archive/trash/spam all messages from this sender" as a single action).
- **Bulk delete by sender** with the ability to selectively keep specific messages rather than only all-or-nothing (explicitly addressing a limitation reviewers noted in Unibox, where users could not keep a few messages while bulk-deleting the rest).
- **Undo**: any destructive bulk action should offer a brief undo window before being finalized.
- **Empty trash** control, with confirmation prompt given its irreversibility.

### 4.17 Notifications & Badging

- **Push or near-real-time notifications** for new mail, respecting per-account and per-contact mute/notification settings.
- **App icon badge** showing total unread count (Windows: taskbar overlay badge on the app's taskbar button, plus the system-tray icon; Android in Phase 2: launcher badge).
- **User-controllable badge visibility**: explicit setting to hide/disable the unread badge count on the app icon if the user doesn't want it — directly addressing a papercut noted in Unibox reviews (no way to hide the Dock badge).
- **Badge scope**: a Settings toggle chooses whether unread Feeds mail counts toward the app-icon badge and the People tab's unread indicators. **Default: People only.** Independently of that toggle, any individual Feeds sender can be marked "counts toward unread" so that sender's unread mail is included while it stays in Feeds (see 4.11).
- **Snooze wake-up notifications** as described in 4.9.

### 4.18 Settings & Customization

- Account management (add/remove/reorder accounts, edit aliases, edit signatures).
- Appearance: light mode, dark mode, and system-default option.
- Notification preferences (global and per-account).
- Contact groups configuration (create/edit/delete groups such as "Travel," "Education," "Work," used for auto-categorization and Kanban tagging).
- **People Groups** (see 4.19): create, rename, and delete user-defined groups; pick members from contacts; view which conversations currently match the group.
- **Feeds** (see 4.11): badge-scope toggle (Feeds count toward badge, default off); the per-sender "counts toward unread" list; the category list with add/rename/delete for custom categories; the classification-rule list with edit/delete for rules the user has accepted.
- Privacy settings (image-blocking toggle, tracker stats reset).
- Default mail client registration (Windows: register as a `mailto:` protocol handler so the app appears in Settings → Default apps; Android in Phase 2: the equivalent intent filter).
- Sort order preferences for the contact list (recency is default; consider alternate sort options during design).

### 4.19 User-Defined Groups

The only way a multi-person "row" ever exists is when the user creates one.

- **Creation**: groups are created, renamed, and deleted only in Settings → People Groups. A group has a display name and a set of **members**, each a contact identity (after the identity resolution in 4.14). Minimum two members. The user's own identity is never a member; the user is implicitly part of every group.
- **Exact-match filing rule**: a message is filed into a group row when the set consisting of **the sender plus every To and CC recipient, minus the user**, after identity resolution, is **exactly equal** to the group's member set. BCC recipients are not visible to the client and are ignored. Any difference — one member missing, one extra participant — means no match, and the message follows the ordinary sender-only rule in 4.3.
  - Example: group "Simon & Joann" = {Simon, Joann}. Simon emails the user and Joann → participants {Simon, Joann} → filed in the group row. Joann emails the user, Simon, and Sarah → participants {Joann, Simon, Sarah} → no match → filed under Joann.
- **Exclusive filing**: a message that matches a group appears in the group row **only**. It does not also appear in the individual members' rows.
- **The user's own messages**: a message the user sends whose To + CC set exactly equals the group's members is filed in the group row (and, per exclusivity, not in each member's row).
- **Behavior**: a group row is indistinguishable from a contact row in every other respect — position in the People list sorted by the newest message in the row, unread badge, swipe actions, pinning, snooze, search, filters, and the conversation view with the "View thread" control (4.3). Its avatar is a stacked pair (or trio) of member avatars.
- **Editing a group** re-runs the match against cached mail so the row's contents update immediately; deleting a group returns its messages to sender-only filing.
- **No auto-creation, ever.** The app must not suggest, infer, or silently create a group from recurring co-recipient patterns. It may show an empty-state hint in Settings → People Groups explaining what groups do.

### 4.20 Threading Model

Threading determines which messages the "View thread" control (4.3) shows together. It is **independent of filing**: filing decides which row a message lives in; threading decides which other messages it is related to.

- **Hybrid reconstruction, in priority order**:
  1. **Headers first.** Use `Message-ID`, `In-Reply-To`, and `References` to link a message to the thread of the message it replies to. This is authoritative when present and works across accounts, because Message-IDs are globally unique.
  2. **Provider thread ID second.** When the account is Gmail or Outlook/Microsoft 365 and the protocol exposes a server-assigned thread/conversation identifier (Gmail `X-GM-THRID` over IMAP; Outlook `ConversationId` via its API), use it to confirm or join threads that headers alone did not connect. Provider IDs are scoped to one account and are never compared across accounts.
  3. **Normalized-subject fallback only for header-less messages.** If a message has no `In-Reply-To` or `References`, strip reply/forward prefixes (`Re:`, `RE:`, `Fwd:`, `FW:`, `AW:`, `WG:`, `Antw:`, and repeated combinations), and join it to an existing thread only when the normalized subject matches **and** at least one participant overlaps **and** the existing thread's newest message is within 30 days. Never apply subject matching to a message that already has reply headers.
- **Edge-case behavior the implementation must honor**:
  - A reply that drops a participant (Sarah replies but removes Joann) stays in the same thread via headers. Filing still follows the sender (Sarah), and group matching (4.19) is evaluated on the new participant set.
  - A **forward** usually carries no `In-Reply-To`. It starts a new thread unless the subject fallback joins it; the subject rule's participant-overlap requirement keeps an unrelated forward from merging.
  - A **subject change** mid-thread does not split the thread when headers are present.
  - A thread that spans **two of the user's accounts** (Simon wrote to the work address; Sarah replied to the personal address) is a single thread via Message-IDs.
  - A **recurring-subject sender** ("Weekly Update" every week, no reply headers) is not merged into one thread, because the subject fallback requires participant overlap and a reply-style relationship; identical periodic subjects from a Feeds sender are treated as separate threads.
- **Thread view contents**: every message in the thread from every participant, including the user, in chronological order, with each message's sender, To/CC, and timestamp shown. Messages are shown in the thread view regardless of whether they live under People, Feeds, or a group row.

---

## 5. GUI / Visual Design Specification

### 5.1 Overall Visual Language — Material 3 Expressive

The design system is **Material 3 Expressive** (Google, 2025). Use its official tokens, components, and motion rather than a custom look. The companion file `email-client-visual-mockups.html` carries the exact token values.

- **Color**: M3 color roles generated from an indigo seed — `primary`, `primary-container`, `secondary-container`, `tertiary-container`, the five `surface-container` tiers (lowest → highest), `on-*` counterparts, `outline-variant`, `error`. Depth comes from **tonal surface containers**, not drop shadows; shadows are reserved for the FAB and a card being dragged. Use `primary` for the FAB, selected button-group segments, unread badges and unread timestamps; `secondary-container` for selected chips, navigation indicators, and the "View thread" tonal button; `tertiary-container` for privacy stats and custom Feeds categories. On Android, support **dynamic color** (Material You wallpaper-derived scheme) with the indigo scheme as the fallback.
- **Shape**: the M3 Expressive shape scale — xs 4, sm 8, md 12, lg 16, lg-increased 20, xl 28, xl-increased 32, full. List items sit in **grouped segments**: 2 dp gaps between items, 4 dp inner corners, 20 dp outer corners on the first and last item of a group. Cards 20 dp; featured containers 28 dp; chips 8 dp; FAB 16 dp; search bar, switches, badges, and button-group ends fully rounded. Icon buttons may **morph shape** on press (round → rounded square), per Expressive.
- **Avatars**: circular, using **tonal pairs** (light container background, dark text) rather than saturated fills with white text — eight deterministic pairs per contact. Non-human Feeds senders use a 12 dp "squircle" instead of a circle so the two lists read differently at a glance. Group rows use two stacked small avatars. Contact photos come from device contacts only (no network lookup, per Section 3).
- **Type**: **Roboto Flex** on Android (Segoe UI Variable on Windows). Emphasis through scale and weight: screen titles use headline-medium at weight 700 with tight tracking; list names title-medium 500 (700 unread); previews body-medium; chips and timestamps label 500–600.
- **Components** (M3 Expressive): flexible top app bar with large headline; docked pill **search bar**; **filter chips** with a leading check when selected; **connected button groups** for two- and three-way toggles (People/Feeds, List/Grid, Light/Dark/System); **FAB** for compose and extended FAB for secondary creates; **navigation bar** with pill indicator (bottom, mobile) and **navigation rail** (desktop); **floating toolbar** in primary-container for the editor formatting controls; **filled text fields** for compose headers; **M3 switch** (52 × 32, check icon on the thumb when on); **wavy linear progress indicator** for send progress; tonal **badges** for counts.
- **Iconography**: **Material Symbols Rounded**, outlined by default, filled for the active navigation destination and selected states.
- **Motion**: M3 Expressive spring-based motion — springy list-item swipe reveals, shape morphs on button-group selection, height animation on message expand, lift-and-tilt on Kanban drag, and the navigation-bar indicator sliding between destinations.

### 5.2 Android (Mobile) — Screen by Screen (Phase 2 reference)

The mobile screens below and the phone frames in the mockups file remain the reference for the Android build in Phase 2. They also define the content of each screen, which the Windows panes in 5.3 present in a three-pane arrangement.

1. **Chats (Home) screen**: flexible top app bar (menu icon, filter icon, account avatar; large "Chats" headline) → pill search bar → horizontally scrollable filter chip row → grouped, vertically scrolling contact list (avatar, name, preview, timestamp, unread badge; group rows with stacked avatars) with swipe-to-reveal actions → compose FAB bottom-right → bottom navigation bar (Chats · Boards · Planner · Settings). No pinned-avatar strip.
2. **Conversation screen**: top app bar with back/contact-name/search/overflow → date-grouped, collapsible message list → inline expand-to-read → inline reply composer anchored at the bottom of the screen.
3. **Compose screen** (new message, not a reply): reachable via the pencil icon; recipient field with autocomplete from contacts, subject field, from/identity selector if applicable, block-based body editor, attachment chips, send button (with progress indicator on tap).
4. **Attachments screen** (per contact): toggle between List and Grid view; featured/most-recent file card at top; full attachment list/grid below.
5. **Boards (Kanban) screen**: horizontally scrollable columns, each vertically scrollable with draggable cards; column header shows name + count badge.
6. **Planner (Calendar) screen**: week-strip navigation at top; vertical day-grid below with color-coded event blocks; linked to-do indicators.
7. **Feeds screen** (via People/Feeds toggle): same visual list style as the main Chats screen but populated with auto-categorized senders, a category pill per row (Newsletter, Receipt, Notification, Social, Promotion, or a user-created category), and a small bell marker on any sender the user has flagged as "counts toward unread."
8. **Settings screen**: standard native list-style settings screen, grouped into sections (Accounts, Appearance, Notifications, Privacy, People Groups, Feeds, Groups & Tags).
9. **Onboarding/account-setup flow**: provider selection or email entry → auto-detect attempt → OAuth handoff or manual configuration form → success confirmation → land on the (initially empty, then syncing) Chats screen.
10. **Search results screen**: back button, the query in an editable search field, an "Include Feeds" switch (off by default) directly beneath it, then result rows in the same style as the Chats list, with Feeds results (when included) carrying their category pill.

### 5.3 Windows (Desktop) — Pane by Pane (Phase 1)

The Windows app is a single window with a Material 3 **navigation rail** on the left and a content area whose arrangement depends on the rail destination. Minimum window size 960 × 640; the layout below describes 1280 × 800 and up. The desktop frame in the mockups file shows the Chats destination.

- **Navigation rail** (88 dp): compose FAB at top; Chats, Boards, Planner destinations with pill indicators; Settings and the account avatar at the bottom. The avatar opens the account switcher (unified view or a single account, per 4.14). At widths under 1100 dp the rail collapses to icons only.
- **Chats destination — three panes**:
  - *Middle pane* (300–360 dp, user-resizable): "Chats" headline with the filter icon; pill search bar; filter chip row (All, Unread, Starred, This Week, Sent, Has attachments, From contacts, custom tags); the **People / Feeds** button group; the "N filed to Feeds" banner when on People; then the grouped contact list from 4.2 (contact rows and user-defined group rows). Hovering a row reveals its action buttons; right-click opens the same actions as a context menu.
  - *Right pane* (remaining width) inside a 28 dp surface container: the selected contact's conversation from 4.3 — contact header with name, To/CC-aware message cards, "View thread" control, inline reply field anchored at the bottom. The thread view (4.20) opens as an overlay panel sliding in from the right edge, not a new window.
  - *Compose* (new message) replaces the right pane's contents in place: From/To/Subject filled fields, the block editor, attachment chips, floating formatting toolbar, and a send button with the wavy progress indicator. Escape or the close icon returns to the conversation; drafts autosave.
  - *Attachments for a contact* opens from the conversation header's folder icon as a panel that replaces the right pane: List/Grid button group, featured file card, grouped file list, photo grid. Preview opens an in-app viewer overlay for images and PDFs.
  - *Privacy detail* for a message (blocked trackers list, Load images) appears as an expandable strip at the top of that message card.
- **Boards destination**: the content area becomes a horizontally scrolling Kanban board with the columns from 4.8; cards drag between columns with a lift-and-tilt; clicking a card opens its conversation in a right-side panel without leaving the board. An extended FAB adds a column.
- **Planner destination**: week view with day columns and hour rows filling the content area; a mini month calendar and the linked to-do list sit in a left sub-pane; clicking an event opens its source conversation in a right-side panel (4.10).
- **Settings destination**: two-pane — section list on the left (Accounts, Appearance, Notifications, Privacy, People Groups, Feeds, Groups & Tags, Default mail app), detail on the right.
- **Search**: typing in the middle-pane search bar turns the middle pane into the results list with the "Include Feeds" switch at its top (4.6); selecting a result opens it in the right pane.
- **Single-window rule**: nothing opens a second OS window. Compose, thread view, attachments, previews, and settings all live inside the main window.
- **Keyboard**: full keyboard navigation of the list and conversation; shortcuts for compose (Ctrl+N), reply (R), reply-all (Shift+R), forward (F), archive (E), delete (Del), snooze (S), search (Ctrl+F or /), and switching destinations (Ctrl+1..4). Shortcuts are listed in Settings.
- **Window chrome**: standard Windows title bar controls; the app supports light, dark, and system themes and follows the Windows accent color when "dynamic color" is enabled.

### 5.4 Color, Typography, Iconography, Motion

- Typography: Roboto Flex on Android, Segoe UI Variable on Windows, using the M3 type scale with Expressive's emphasized headline styles (see 5.1); unread items rendered bold, read items regular weight.
- Motion: M3 Expressive spring motion (see 5.1) — list-item swipe reveals animate with a spring; expanding a collapsed message animates its height rather than snapping; Kanban card drags lift with a shadow and a slight tilt; the navigation indicator slides between destinations.
- Empty states (no messages, empty search results, empty Kanban column) should have friendly, simple illustrations or icon + short text rather than a blank void.

### 5.5 Structural Wireframes (Screen-by-Screen)

These are exact-layout reference diagrams — not visual mockups (no color, imagery, or rendered typography), but precise structural sketches showing element placement, hierarchy, and proportions for each screen described in 5.2 and 5.3. Use these as the literal layout skeleton; visual styling (color, spacing, elevation) follows the language in 5.1 and 5.4.

**Android — Chats (Home) Screen**
```
┌─────────────────────────────────────┐
│ ☰                          ⚙  (Y)   │  <- app bar icons: menu / filter / account avatar
│ Chats                                │  <- large headline (flexible top app bar)
├─────────────────────────────────────┤
│ ( 🔍  Search people and mail       ) │  <- pill search bar
├─────────────────────────────────────┤
│ (✓All) Unread Starred ThisWeek Sent… │  <- filter chips, "All" selected with check
├─────────────────────────────────────┤
│ ○ James Kowalski        1:34 PM      │  <- grouped list: 2dp gaps, 20dp outer corners
│   API Deployment Complete            │
├───────────────────────────────────── │
│ ○ Priya Sharma          1:04 PM  (1) │  <- bold name = unread, badge = unread count
│   Re: Weekly Sync                    │
├───────────────────────────────────── │
│ ◎ Simon & Joann        12:40 PM      │  <- user-defined group row (4.19), stacked avatars
│   Simon: Draft agenda attached       │
├───────────────────────────────────── │
│ ○ Tom Andersen         12:14 PM      │
│   Slides from Yesterday's Talk       │
├───────────────────────────────────── │
│  … (list continues, one row/contact) │
│                              [ ✎ ]   │  <- compose FAB
├─────────────────────────────────────┤
│ (●Chats)  Boards   Planner  Settings │  <- navigation bar, active pill indicator
└─────────────────────────────────────┘
```
Swipe a row left/right to reveal: `[Archive] [Trash] [Snooze] [Pin]` action buttons underneath. A pinned contact stays at the top of the list with a pin icon; there is no separate pinned-avatar strip.

**Android — Conversation Screen**
```
┌─────────────────────────────────────┐
│ ←    Sarah Chen        🔍   ⋯        │  <- back / contact name / search / overflow
├─────────────────────────────────────┤
│ Today                                │  <- date group header
├─────────────────────────────────────┤
│ ┌───────────────────────────────┐   │
│ │ Design Review: Dashboard  (2)>│   │  <- collapsed thread row (tap to expand)
│ │ ○ Alex  These look fantastic..│   │
│ └───────────────────────────────┘   │
│ ┌───────────────────────────────┐   │
│ │ ○ Sarah Chen      Jul 5,3:05PM│   │  <- EXPANDED message
│ │   To: Alex, Joann     Inbox   │   │  <- full To/CC list shown
│ │                                │   │
│ │  The mockups are ready for    │   │
│ │  review — let me know your    │   │
│ │  thoughts on the new layout.  │   │
│ │                                │   │
│ │  [📎 Dashboard_Rev] [📎 Traf]  │   │  <- attachment preview cards
│ │                                │   │
│ │  [ View thread (3) ]          │   │  <- opens full thread, all participants (4.20)
│ │  ↩ Reply   ↪ Forward   ☆   ⋯  │   │  <- inline action bar
│ └───────────────────────────────┘   │
│ ┌───────────────────────────────┐   │
│ │ Figma Library Access      (2)>│   │  <- next collapsed thread row
│ └───────────────────────────────┘   │
├─────────────────────────────────────┤
│ [ Type a reply…              ] [➤]  │  <- inline reply composer, anchored bottom
└─────────────────────────────────────┘
```

**Android — Compose Screen**
```
┌─────────────────────────────────────┐
│ ✕           New Message        [Send]│
├─────────────────────────────────────┤
│ From:  you@work.com ▾                │  <- identity/alias selector
│ To:    [recipient chips…]            │
│ Subject: [                        ]  │
├─────────────────────────────────────┤
│ B I U  H1 H2  • ≡  🖼  📎             │  <- block editor toolbar
│                                       │
│  [ body content — block-based editor]│
│                                       │
│  [📎 attachment.pdf ✕]               │  <- removable attachment chip
├─────────────────────────────────────┤
│ ▓▓▓▓▓▓▓▓░░░░░░░  Sending…            │  <- send progress indicator (on tap)
└─────────────────────────────────────┘
```

**Android — Attachments Screen (per contact)**
```
┌─────────────────────────────────────┐
│ ←   Sarah Chen — Files               │
├─────────────────────────────────────┤
│  [List]  [Grid]                      │  <- view mode toggle
├─────────────────────────────────────┤
│ ┌───────────────────────────────┐   │
│ │  14 files · one contact        │   │  <- featured/most-recent file card
│ │  [ image preview ]             │   │
│ │  Team_Photo.jpg   🔍QuickLook  │   │
│ │  Sarah Chen · 3.8MB · Mar 12   │   │
│ └───────────────────────────────┘   │
│  ALL ATTACHMENTS                     │
│ [PDF] Brand_Guidelines.pdf   4.8MB > │
│ [XLS] Q3_Budget.xlsx         1.2MB > │
│ [PPT] Design_Principles.pptx 12.4MB>│
│ [DOC] Contract_Draft.docx    890KB >│
│  …                                   │
└─────────────────────────────────────┘
```

**Android — Boards (Kanban) Screen**
```
┌─────────────────────────────────────┐
│ ☰        Boards               ⚙      │
├─────────────────────────────────────┤
│  Next (6)      In Progress (5)   ⇢   │  <- horizontally scrollable columns
│ ┌───────────┐ ┌───────────┐          │
│ │Design     │ │Re:Q3      │          │  <- draggable cards
│ │Review     │ │Budget     │          │
│ │(SC)Sarah  │ │(DO)David  │          │
│ └───────────┘ └───────────┘          │
│ ┌───────────┐ ┌───────────┐          │
│ │Monthly    │ │Model      │          │
│ │Finance Rpt│ │Training   │          │
│ │(AB)Anna   │ │(KW)Kevin  │          │
│ └───────────┘ └───────────┘          │
│  …                                   │
└─────────────────────────────────────┘
```

**Android — Planner (Calendar) Screen**
```
┌─────────────────────────────────────┐
│ ≡    July 2026 ▾              ✉  +   │
├─────────────────────────────────────┤
│ S    M    T    W    T    F    S      │
│ [5] [6]  [7]  [8]  [9]  [10] [11]    │  <- week strip, today highlighted
├─────────────────────────────────────┤
│ 10AM ┌──────────────────────┐        │
│      │ Farmers Market       │        │  <- color-coded event block
│ 11AM │                      │        │
├──────┴──────────────────────┴────────┤
│ 12PM ┌──────────────────────┐        │
│      │ Brunch with Priya    │        │
│  1PM │                      │        │
├──────┴──────────────────────┴────────┤
│  2PM ┌──────────────────────┐        │
│      │ Afternoon Hike       │        │
│  3PM │                      │        │
└──────┴──────────────────────┴────────┘
```

**Android — Feeds Screen (People/Feeds toggle)**
```
┌─────────────────────────────────────┐
│ ☰        Chats                 ✎     │
├─────────────────────────────────────┤
│ [ People ]  [  Feeds  ]              │  <- segmented control, "People" active
├─────────────────────────────────────┤
│ ↓ 24 filed to Feeds automatically    │  <- when on People tab
├─────────────────────────────────────┤
│ (D) Design Weekly     🔔 [Newsletter] │  <- when on Feeds tab; 🔔 = counts toward unread
│     This week in product design      │
│ ($) Acme Store            [Receipt] │
│     Your receipt — order #4821       │
│ (CI) Build Bot       [Notification] │
│     Pipeline passed on main          │
│ (S) Shopwave            [Promotion] │
│     Weekend sale — 30% off           │
│ (B) First Bank                [OTP] │  <- user-created category (4.11)
│     Your one-time passcode is 4821   │
└─────────────────────────────────────┘
```

**Android — Search Results Screen**
```
┌─────────────────────────────────────┐
│ ←  🔍 [ budget                 ✕ ]  │  <- editable query
├─────────────────────────────────────┤
│ Include Feeds              [ off ]  │  <- switch, OFF by default (4.6)
├─────────────────────────────────────┤
│ ○ David Okafor          Mon         │
│   Re: Q3 Budget Proposal            │
├───────────────────────────────────── │
│ ○ Anna Bergström        Jul 2       │
│   Monthly Finance Report            │
├───────────────────────────────────── │
│ ◎ Simon & Joann         Jun 28      │  <- group rows are searchable like any row
│   Budget for offsite                │
└─────────────────────────────────────┘
```

**Desktop (Windows) — Three-Pane Layout**
```
┌────┬────────────────────┬──────────────────────────────────┐
│[✎] │ Chats            ⚙  │ (SC) Sarah Chen ▾     🔍  📁  ⋯   │
│ 💬 ├────────────────────┤├──────────────────────────────────┤
│ 📋 │( 🔍 Search… )       │ Today                             │
│ 📅 ├────────────────────┤│ ┌──────────────────────────────┐ │
│    │(✓All)Unread Starred ││ │ ○ Sarah Chen    Jul 5,3:05PM │ │
│    ├────────────────────┤│ │  To: Alex, Joann · Inbox     │ │
│ ⚙  │○ James Kowalski     ││ │  The mockups are ready for   │ │
│ (Y)│  API Deployment...  ││ │  review — let me know...     │ │
│    │  1:34 PM             ││ │  [📎][📎]                     │ │
│    ├────────────────────┤│ │  [ View thread · 3 ]         │ │
│    │○ Priya Sharma  (1)  ││ │  ↩Reply ↪Forward        ⋯    │ │
│    │  Re: Weekly Sync    ││ └──────────────────────────────┘ │
│    │  1:04 PM             ││ ┌──────────────────────────────┐ │
│    │◎ Simon & Joann      ││ │ Figma Library Access     (2) │ │
│    │  …                   │├──────────────────────────────────┤
│    │                      ││ ( Reply to Sarah…          )[➤] │
└────┴────────────────────┴──────────────────────────────────┘
 ^nav rail  ^grouped contact     ^conversation in a 28dp surface
  + FAB      list (middle pane)   container + inline reply (right pane)
```

---

## 6. Technical Considerations (High-Level — Not a Final Architecture)

These are starting points for the planning phase, not final decisions. Confirm or revise each with reasoning during Section 9's planning step.

- **Windows framework**: to be proposed with reasoning in the Phase 1 plan. The proposal must cover: fidelity to Material 3 Expressive (5.1), maturity on Windows desktop, availability of a robust IMAP/SMTP/MIME library with OAuth2 and IDLE, a viable block-based rich-text editor, safe HTML email rendering, Windows integration (Credential Manager, toast notifications, taskbar badge, `mailto:` registration, tray), packaging (MSIX), and how much code Phase 2 (Android) can reuse.
- **Email protocol handling**: a robust IMAP/SMTP client library, plus OAuth2 flows for Gmail/Outlook specifically (desktop loopback/PKCE flow); a background sync engine that stays connected while the app runs and reconciles on launch.
- **Local storage/caching**: a local SQLite database to cache message metadata and bodies and enable fast contact-centric grouping/search (full-text search via FTS5) without re-fetching from the server constantly.
- **Push notifications**: IMAP IDLE per account (desktop stays connected, so IDLE is the primary path), falling back to periodic polling; local scheduling for snooze wake-ups and reminders.
- **Security**: Windows Credential Manager (or DPAPI) for credential/token storage; no analytics SDKs that transmit message content or metadata off-device.
- **Android (Phase 2) notes for later**: Kotlin with Jetpack Compose remains the presumed native default; background sync via WorkManager with IMAP IDLE where the OS allows; Android Keystore for credentials.
- **Threading**: implement the hybrid model in 4.20 — `In-Reply-To`/`References` first, provider thread ID (`X-GM-THRID`, Outlook `ConversationId`) second, normalized-subject fallback only for header-less messages. Store thread membership separately from row filing so the two can evolve independently.
- **People/Feeds classification**: Phase 1 is the deterministic rule set in 4.11, evaluated on-device from headers, sender address, reply history, and device contacts. Design the classifier as a pluggable interface so an on-device model can later be evaluated against the stored manual decisions and swapped in without a schema change.

---

## 7. What Success Looks Like (Definition of Done for Phase 1 — Windows)

The Windows app is considered finalized when:
- A user can connect at least one IMAP/OAuth account and see their real mail organized by sender.
- Every feature in Section 4 is implemented and functional (or explicitly deferred with reasoning documented, in the case of lower-priority stretch features like the relationship graph).
- The GUI matches the visual language in Section 5.1 and the pane-by-pane structure in Section 5.3.
- The app installs from an MSIX package, registers as a `mailto:` handler, shows toast notifications and a taskbar unread badge, and survives sleep/resume and network loss without losing sync state.
- The app has been tested for core reliability: sync accuracy, no message loss/duplication, correct threading/grouping, and stable performance with a realistically large mailbox.
- Known papercuts explicitly called out in this spec (badge-hide option, selective bulk-delete, etc.) are resolved, not just replicated from the flawed originals.

---

## 8. Explicit Non-Goals for Phase 1

- No Android build work of any kind until Phase 1 (Windows) is signed off.
- No cloud-hosted backend service for message storage/relay — the local-first architecture is a hard requirement, not a nice-to-have.
- No feature scope beyond what's described here without an explicit new instruction.

---

## 9. Instructions to Claude Code — Start Here

1. **Do not write implementation code yet.** Your first deliverable is a detailed, phased **development plan** for the Windows desktop application only.
2. The plan should include: proposed technical architecture and framework (with reasoning, not just a stack name, and with the Phase 2 reuse implications stated), a milestone breakdown (e.g., foundations & design system → account setup & sync → core people list → conversation view & threading → compose → attachments → search/filters → groups & settings → feeds/privacy features → Kanban/snooze/planner → notifications & Windows integration → multi-account → polish/packaging/testing), an estimate of build complexity/risk per milestone, and identification of any open decisions that need a call from the product owner before work can proceed (e.g., specific tag/premium gating logic, on-device AI feasibility per Section 4.15, HTML email rendering approach, provider auto-configuration source).
3. Present that plan for review. Do not begin implementation until the plan is explicitly approved.
4. Once approved, build, test, and finalize the Windows app in full before any Android work begins, per Section 2.

---

## Appendix A. Decision Log (September 29, 2026)

Product decisions made by the product owner after the original draft. Where any earlier text in this document appears to conflict with an entry here, the entry here governs.

**Filing, groups, and threading**
1. A message is filed under its **sender only**. Recipients' rows never receive it. — 3, 4.3
2. The app **never auto-creates a group row**. Default is one row per contact. — 4.2, 4.19
3. Any message in a multi-message thread shows a **"View thread (N)"** control that opens the full thread with every participant's messages. — 4.3, 4.20
4. When a reply arrives in a multi-person thread, **only the replier's row** moves to the top of the People list. — 4.2
5. The user's **sent mail appears inline in each recipient's conversation**, with the same View thread control. — 4.3, 4.7
6. **User-defined groups** are created in Settings. A message files into a group row only when sender + To + CC, minus the user, exactly equals the group's members. It then does **not** also appear in members' rows. — 4.19
7. A group row **behaves like a contact row** for ordering, unread badges, swipe actions, and pinning. — 4.2, 4.19
8. All the user's aliases resolve to **"me"**; a contact's several addresses resolve to **one identity**. Resolution runs before the group match. — 4.14
9. Threads use the **hybrid model**: reply headers first, provider thread ID second, normalized-subject fallback only for header-less mail. — 4.20, 6

**People vs Feeds**
10. Classification is **per sender, with per-message exceptions** for strongly personal messages. — 4.11
11. Phase 1 uses **deterministic header/history rules**. On-device ML is a **later milestone** gated on device availability; manual decisions accumulate as its training data. — 4.11, 4.15, 6
12. Manual People/Feeds moves are **permanent until changed**; rules never re-classify an overridden sender. — 4.11
13. Feeds counting toward the badge is a **Settings toggle, default off**; any Feeds sender can individually be marked **"counts toward unread"** while staying in Feeds. — 4.11, 4.17
14. Search covers both tabs via an **"Include Feeds" switch on the results screen, off by default**. — 4.6, 4.11
15. Default categories are **Newsletter, Receipt, Notification, Social, Promotion**; the user can **create custom categories**. Categories attach at the message level with a sender-level default. — 4.11
16. Feeds categories and Kanban tags are **two separate systems**. — 4.8, 4.11
17. On a misclassification correction, the app **proposes the rule it would write**; the user accepts, edits, or applies the fix to that one message only. Rules are never created silently. — 4.11

**Visual design**
18. **No pinned-contacts avatar strip** above the People list. Pinning keeps a contact's row at the top of the list with a pin icon. — 4.2, 5.2, 5.5
19. The UI follows **Material 3 Expressive**: M3 color roles with tonal surface containers, the Expressive shape scale with grouped list segments, Roboto Flex with emphasized headlines, Material Symbols Rounded, FAB for compose, bottom navigation bar (mobile) and navigation rail (desktop), connected button groups, floating toolbar, wavy progress, spring motion. Windows uses Segoe UI Variable. — 5.1, 5.2, 5.3, 5.4

**Build order**
20. **Windows first, Android second.** Phase 1 is the Windows desktop app; no Android work until it is signed off. The Windows framework is proposed in the Phase 1 plan with its Phase 2 reuse implications stated. — 0, 2, 4.1, 4.2, 4.17, 4.18, 5.2, 5.3, 6, 7, 8, 9
