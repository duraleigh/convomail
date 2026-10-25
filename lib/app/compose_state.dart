import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the user asked to compose. `new` opens the right-pane composer;
/// replies and forwards open the inline composer at the bottom of the
/// conversation (spec 4.4, 5.3).
class ComposeRequest {
  ComposeRequest.newMessage({this.to = const [], this.subject = '', this.body = ''})
      : kind = 'new',
        messageId = null,
        rowKey = null,
        _nonce = _counter++;

  ComposeRequest.reply(this.messageId, {required this.rowKey, bool all = false})
      : kind = all ? 'replyAll' : 'reply',
        to = const [],
        subject = '',
        body = '',
        _nonce = _counter++;

  ComposeRequest.forward(this.messageId, {required this.rowKey})
      : kind = 'forward',
        to = const [],
        subject = '',
        body = '',
        _nonce = _counter++;

  /// `new`, `reply`, `replyAll`, `forward`.
  final String kind;

  /// The message replied to / forwarded (local id).
  final int? messageId;

  /// The People-list row the request came from.
  final String? rowKey;

  /// Prefill for new messages (mailto: handling in M10 uses these).
  final List<String> to;
  final String subject;
  final String body;

  bool get isNew => kind == 'new';
  bool get isForward => kind == 'forward';
  bool get isReplyAll => kind == 'replyAll';

  /// Distinguishes requests so re-requesting the same reply re-focuses the
  /// composer instead of being ignored by equality.
  final int _nonce;
  static int _counter = 0;

  @override
  bool operator ==(Object other) => other is ComposeRequest && other._nonce == _nonce;
  @override
  int get hashCode => _nonce;
}

/// `--compose` / `--reply` startup flags (screenshot verification): open
/// the new-message pane, or the inline reply on the auto-opened first row.
final autoComposeProvider = Provider<bool>((ref) => false);

/// A prefilled new-message request from a `mailto:` launch argument.
final autoComposeRequestProvider = Provider<ComposeRequest?>((ref) => null);
final autoReplyProvider = Provider<bool>((ref) => false);

/// `--files` (with `--open-first`): open the Files panel on the first row.
final autoFilesProvider = Provider<bool>((ref) => false);

/// The new-message composer occupying the right pane, or null.
final composeProvider = NotifierProvider<ComposeNotifier, ComposeRequest?>(ComposeNotifier.new);

class ComposeNotifier extends Notifier<ComposeRequest?> {
  @override
  ComposeRequest? build() => null;
  void open([ComposeRequest? r]) => state = r ?? ComposeRequest.newMessage();
  void close() => state = null;
}

/// The inline reply/forward composer request for the open conversation,
/// or null when the reply bar is collapsed.
final replyRequestProvider = NotifierProvider<ReplyRequestNotifier, ComposeRequest?>(ReplyRequestNotifier.new);

class ReplyRequestNotifier extends Notifier<ComposeRequest?> {
  @override
  ComposeRequest? build() => null;
  void open(ComposeRequest r) => state = r;
  void close() => state = null;
}
