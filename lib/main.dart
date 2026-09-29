import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:window_manager/window_manager.dart';

import 'app/destinations.dart';
import 'app/settings.dart';
import 'ui/shell/app_shell.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/tokens.dart';

/// Startup arguments. `--destination=<chats|boards|planner|settings>` and
/// `--inbox=<people|feeds>` pick the initial screen; the `mailto:` handler
/// (milestone 10) builds on the same mechanism.
class StartupArgs {
  const StartupArgs({this.destination, this.inbox});
  final Destination? destination;
  final InboxMode? inbox;

  static StartupArgs parse(List<String> args) {
    Destination? destination;
    InboxMode? inbox;
    for (final a in args) {
      if (a.startsWith('--destination=')) {
        final v = a.substring('--destination='.length);
        destination = Destination.values.where((d) => d.name == v).firstOrNull;
      } else if (a.startsWith('--inbox=')) {
        final v = a.substring('--inbox='.length);
        inbox = InboxMode.values.where((m) => m.name == v).firstOrNull;
      }
    }
    return StartupArgs(destination: destination, inbox: inbox);
  }

  List<Override> get overrides => [
        if (destination != null) destinationProvider.overrideWith(() => DestinationNotifier(initial: destination)),
        if (inbox != null) inboxModeProvider.overrideWith(() => InboxModeNotifier(initial: inbox)),
      ];
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final startup = StartupArgs.parse(args);
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1280, 800),
      minimumSize: AppLayout.minWindowSize,
      center: true,
      title: 'ConvoMail',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  runApp(ProviderScope(overrides: startup.overrides, child: const ConvoMailApp()));
}

class ConvoMailApp extends ConsumerWidget {
  const ConvoMailApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'ConvoMail',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const AppShell(),
    );
  }
}
