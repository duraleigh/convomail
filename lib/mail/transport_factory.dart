import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'imap_transport.dart';
import 'mail_transport.dart';

/// Creates a fresh transport per connection. Tests override this with a
/// fake server.
final transportFactoryProvider = Provider<MailTransport Function()>((ref) => () => ImapTransport());
