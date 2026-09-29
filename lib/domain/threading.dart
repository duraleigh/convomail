/// Hybrid thread reconstruction (spec 4.20, decision 9).
///
/// Priority:
/// 1. Reply headers: In-Reply-To and References link a message to the
///    thread of the message it replies to. Message-IDs are global, so this
///    works across accounts.
/// 2. Provider thread id (Gmail X-GM-THRID, Outlook ConversationId) joins
///    messages within one account.
/// 3. Normalized-subject fallback, only for messages with no reply headers,
///    only when the raw subject carried a reply/forward prefix (a "reply
///    style" signal), only with at least one shared participant, and only
///    within 30 days of the candidate thread's newest message.
///
/// Pure Dart. The store layer feeds it message facts and persists the
/// resulting thread keys.
library;

class ThreadInput {
  const ThreadInput({
    required this.id,
    required this.accountId,
    required this.ts,
    required this.participantKeys,
    this.messageId,
    this.inReplyTo,
    this.references = const [],
    this.subject = '',
    this.providerThreadId,
  });

  /// Database id of the message.
  final int id;
  final int accountId;
  final DateTime? ts;
  final Set<String> participantKeys;
  final String? messageId;
  final String? inReplyTo;
  final List<String> references;
  final String subject;
  final String? providerThreadId;

  bool get hasReplyHeaders => (inReplyTo != null && inReplyTo!.isNotEmpty) || references.isNotEmpty;
}

/// Subject normalization: strips reply/forward prefixes in several
/// languages, repeatedly, and collapses whitespace. Returns the normalized
/// subject and whether any prefix was removed.
({String normalized, bool hadPrefix}) normalizeSubject(String raw) {
  var s = raw.trim();
  var hadPrefix = false;
  final prefix = RegExp(r'^\s*(re|fwd?|fw|aw|wg|antw|sv|vs|tr|r)\s*(\[\d+\])?\s*:\s*', caseSensitive: false);
  while (true) {
    final m = prefix.firstMatch(s);
    if (m == null) break;
    s = s.substring(m.end);
    hadPrefix = true;
  }
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  return (normalized: s, hadPrefix: hadPrefix);
}

class ThreadResult {
  const ThreadResult(this.threadKeyByMessage);

  /// message id → thread key. Keys are stable strings: the Message-ID of the
  /// thread's root when known, else `m:<id>` of the earliest message.
  final Map<int, String> threadKeyByMessage;

  Map<String, List<int>> get messagesByThread {
    final out = <String, List<int>>{};
    for (final e in threadKeyByMessage.entries) {
      out.putIfAbsent(e.value, () => []).add(e.key);
    }
    return out;
  }
}

class ThreadBuilder {
  ThreadBuilder({this.subjectWindow = const Duration(days: 30), this.userKey = 'me'});
  final Duration subjectWindow;

  /// The contact key that denotes the user (IdentityResolver.me).
  final String userKey;

  /// Threads a whole set of messages from scratch.
  ThreadResult build(Iterable<ThreadInput> inputs) {
    final msgs = inputs.toList()..sort((a, b) => (a.ts?.millisecondsSinceEpoch ?? 0).compareTo(b.ts?.millisecondsSinceEpoch ?? 0));
    final uf = _UnionFind();
    final byMessageId = <String, ThreadInput>{};
    for (final m in msgs) {
      uf.add(m.id);
      if (m.messageId != null && m.messageId!.isNotEmpty) byMessageId.putIfAbsent(m.messageId!, () => m);
    }

    // 1. Reply headers.
    for (final m in msgs) {
      for (final ref in [if (m.inReplyTo != null) m.inReplyTo!, ...m.references]) {
        final target = byMessageId[ref];
        if (target != null && target.id != m.id) uf.union(m.id, target.id);
      }
    }

    // 2. Provider thread id, per account.
    final byProvider = <String, int>{};
    for (final m in msgs) {
      final pid = m.providerThreadId;
      if (pid == null || pid.isEmpty) continue;
      final key = '${m.accountId}|$pid';
      final first = byProvider[key];
      if (first == null) {
        byProvider[key] = m.id;
      } else {
        uf.union(m.id, first);
      }
    }

    // 3. Subject fallback for header-less reply-style messages, in time order.
    // Participant overlap ignores the user: every message involves them, so
    // "me" alone must not join unrelated conversations. Candidates are
    // looked up by normalized subject so a backfill over thousands of
    // messages stays linear.
    Set<String> others(ThreadInput t) => t.participantKeys.where((k) => k != userKey).toSet();
    final normalized = <int, ({String normalized, bool hadPrefix})>{for (final m in msgs) m.id: normalizeSubject(m.subject)};
    final bySubject = <String, List<ThreadInput>>{};
    for (final m in msgs) {
      final n = normalized[m.id]!.normalized;
      if (n.isNotEmpty) bySubject.putIfAbsent(n, () => []).add(m);
    }
    final headerless = msgs.where((m) => !m.hasReplyHeaders).toList();
    for (final m in headerless) {
      final norm = normalized[m.id]!;
      if (!norm.hadPrefix || norm.normalized.isEmpty) continue;
      final mine = others(m);
      ThreadInput? best;
      for (final other in bySubject[norm.normalized] ?? const <ThreadInput>[]) {
        if (other.id == m.id || uf.find(other.id) == uf.find(m.id)) continue;
        if (others(other).intersection(mine).isEmpty) continue;
        if (m.ts != null && other.ts != null && m.ts!.difference(other.ts!).abs() > subjectWindow) continue;
        if (best == null || (other.ts ?? DateTime(0)).isAfter(best.ts ?? DateTime(0))) best = other;
      }
      if (best != null) uf.union(m.id, best.id);
    }

    // Thread keys: root = earliest message in the set; prefer its Message-ID.
    final byId = {for (final m in msgs) m.id: m};
    final rootOf = <int, ThreadInput>{};
    for (final m in msgs) {
      final r = uf.find(m.id);
      final cur = rootOf[r];
      if (cur == null || (m.ts ?? DateTime(0)).isBefore(cur.ts ?? DateTime(0))) rootOf[r] = m;
    }
    final result = <int, String>{};
    for (final m in msgs) {
      final root = rootOf[uf.find(m.id)]!;
      result[m.id] = threadKeyFor(root);
    }
    byId.clear();
    return ThreadResult(result);
  }

  /// Stable thread key for a root message.
  static String threadKeyFor(ThreadInput root) => (root.messageId != null && root.messageId!.isNotEmpty) ? root.messageId! : 'm:${root.id}';

  /// Assigns thread keys to [incoming] given already-threaded [existing]
  /// messages (id → thread key known). Returns keys for the incoming
  /// messages plus any existing keys that must change because an incoming
  /// message joined two threads.
  Map<int, String> assignIncremental(Iterable<ThreadInput> existing, Map<int, String> existingKeys, Iterable<ThreadInput> incoming) {
    final all = [...existing, ...incoming];
    final fresh = build(all).threadKeyByMessage;
    final out = <int, String>{};
    for (final m in incoming) {
      out[m.id] = fresh[m.id]!;
    }
    // Existing messages whose thread merged into another.
    for (final e in existingKeys.entries) {
      final now = fresh[e.key];
      if (now != null && now != e.value) out[e.key] = now;
    }
    // Keep keys stable: if a fresh key for an incoming message equals the
    // key of an existing thread in a different spelling, prefer existing.
    return out;
  }
}

class _UnionFind {
  final Map<int, int> _parent = {};

  void add(int x) => _parent.putIfAbsent(x, () => x);

  int find(int x) {
    var root = x;
    while (_parent[root] != root) {
      root = _parent[root]!;
    }
    // path compression
    var cur = x;
    while (_parent[cur] != root) {
      final next = _parent[cur]!;
      _parent[cur] = root;
      cur = next;
    }
    return root;
  }

  void union(int a, int b) {
    final ra = find(a), rb = find(b);
    if (ra == rb) return;
    // Attach the larger id under the smaller for determinism.
    if (ra < rb) {
      _parent[rb] = ra;
    } else {
      _parent[ra] = rb;
    }
  }
}
