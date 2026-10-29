import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app_log.dart';
import 'app/bench.dart';
import 'app/compose_state.dart';
import 'app/destinations.dart';
import 'app/diag.dart';
import 'app/onboarding.dart';
import 'app/people_state.dart';
import 'app/settings.dart';
import 'app/settings_navigation.dart';
import 'app/version.dart';
import 'platform/mailto_registration.dart';
import 'platform/single_instance.dart';
import 'platform/windows_integration.dart';
import 'sync/notification_center.dart';
import 'sync/schedule_service.dart';
import 'sync/sync_controller.dart';
import 'ui/shell/app_shell.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/tokens.dart';

/// Startup arguments. `--destination=<chats|boards|planner|settings>` and
/// `--inbox=<people|feeds>` pick the initial screen; the `mailto:` handler
/// (milestone 10) builds on the same mechanism.
class StartupArgs {
  const StartupArgs({this.destination, this.inbox, this.addAccount = false});
  final Destination? destination;
  final InboxMode? inbox;

  /// `--add-account` opens Settings → Accounts with the add panel expanded.
  final bool addAccount;

  /// `--open-first` selects the first People row and expands its newest
  /// thread. Used to verify rendering from a script.
  bool get openFirst => _openFirst;
  static bool _openFirst = false;

  /// `--compose` opens the new-message pane; `--reply` (with `--open-first`)
  /// opens the inline reply on the first row.
  static bool _compose = false;
  static bool _reply = false;
  static bool _files = false;

  /// `--minimized`: start hidden in the tray (launch at login uses it).
  static bool minimized = false;

  /// `--search=<text>` starts in search-results mode (screenshots).
  static String? _search;

  /// A `mailto:` argument (Windows passes the clicked link as argv[1]).
  static MailtoLink? _mailto;

  static StartupArgs parse(List<String> args) {
    Destination? destination;
    InboxMode? inbox;
    var addAccount = false;
    for (final a in args) {
      if (a.startsWith('--destination=')) {
        final v = a.substring('--destination='.length);
        destination = Destination.values.where((d) => d.name == v).firstOrNull;
      } else if (a.startsWith('--inbox=')) {
        final v = a.substring('--inbox='.length);
        inbox = InboxMode.values.where((m) => m.name == v).firstOrNull;
      } else if (a == '--add-account') {
        addAccount = true;
        destination = Destination.settings;
      } else if (a == '--open-first') {
        _openFirst = true;
      } else if (a == '--compose') {
        _compose = true;
      } else if (a == '--reply') {
        _reply = true;
        _openFirst = true;
      } else if (a == '--files') {
        _files = true;
        _openFirst = true;
      } else if (a.startsWith('--search=')) {
        _search = a.substring('--search='.length);
      } else if (a == '--minimized') {
        minimized = true;
      } else if (a.toLowerCase().startsWith('mailto:')) {
        _mailto = MailtoLink.parse(a);
        destination = Destination.chats;
      }
    }
    return StartupArgs(destination: destination, inbox: inbox, addAccount: addAccount);
  }

  List<Override> get overrides => [
        if (destination != null) destinationProvider.overrideWith(() => DestinationNotifier(initial: destination)),
        if (inbox != null) inboxModeProvider.overrideWith(() => InboxModeNotifier(initial: inbox)),
        if (addAccount) settingsAddAccountRequestProvider.overrideWith(() => AddAccountRequestNotifier(initial: true)),
        if (_openFirst) autoOpenFirstProvider.overrideWith((ref) => true),
        if (_compose) autoComposeProvider.overrideWith((ref) => true),
        if (_reply) autoReplyProvider.overrideWith((ref) => true),
        if (_files) autoFilesProvider.overrideWith((ref) => true),
        if (_search != null) peopleSearchProvider.overrideWith(() => PeopleSearchNotifier(initial: _search!)),
        if (_mailto != null) ...[
          autoComposeProvider.overrideWith((ref) => true),
          autoComposeRequestProvider.overrideWith((ref) => ComposeRequest.newMessage(to: [..._mailto!.to, ..._mailto!.cc], subject: _mailto!.subject, body: _mailto!.body)),
        ],
      ];
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (args.contains('--bench-people')) {
    final sizeArg = args.where((a) => a.startsWith('--bench-size=')).map((a) => int.tryParse(a.substring('--bench-size='.length))).whereType<int>().firstOrNull;
    await runPeopleBench(count: sizeArg ?? 50000);
    exit(0);
  }
  if (args.contains('--bench-search')) {
    await runSearchBench();
    exit(0);
  }
  if (args.contains('--diag-signals') || args.contains('--diag-classify')) {
    await runDiag(classify: args.contains('--diag-classify'));
    exit(0);
  }
  final startup = StartupArgs.parse(args);

  // Local-only diagnostics (plan M12): framework and uncaught errors go to
  // <support>/logs, pruned to a week. Nothing leaves the machine.
  AppLog? log;
  if (Platform.isWindows) {
    log = AppLog(Directory(p.join((await getApplicationSupportDirectory()).path, 'logs')));
    await log.init();
    AppLog.install(log);
    log.info('start v$appVersion+$appBuild args=${args.length}');
  }

  // Single instance: hand our arguments (a mailto: link, usually) to the
  // running app and exit; otherwise become the primary and listen.
  SingleInstance? instance;
  if (Platform.isWindows) {
    instance = SingleInstance(await getApplicationSupportDirectory());
    if (await instance.forwardToRunning(args)) exit(0);
  }

  final integration = Platform.isWindows
      ? WindowsIntegration(
          onOpen: () => _showWindow(),
          onCompose: () => _requestCompose(),
          onQuit: () async {
            await instance?.close();
            await windowManager.destroy();
            exit(0);
          },
        )
      : null;

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
      if (!StartupArgs.minimized) {
        await windowManager.show();
        await windowManager.focus();
      }
    });
  }
  final container = ProviderContainer(overrides: [
    ...startup.overrides,
    if (integration != null) windowsIntegrationProvider.overrideWith((ref) => integration),
    if (Platform.isWindows) notificationSinkProvider.overrideWith((ref) => WindowsNotificationSink(ref)),
    if (log != null) appLogProvider.overrideWith((ref) => log),
    showOnboardingProvider.overrideWith((ref) => true),
  ]);
  _container = container;
  if (instance != null) {
    await instance.becomePrimary((forwarded) {
      final link = forwarded.where((a) => a.toLowerCase().startsWith('mailto:')).map(MailtoLink.parse).whereType<MailtoLink>().firstOrNull;
      if (link != null) {
        container.read(composeProvider.notifier).open(ComposeRequest.newMessage(to: [...link.to, ...link.cc], subject: link.subject, body: link.body));
        container.read(destinationProvider.notifier).select(Destination.chats);
      }
      _showWindow();
    });
  }
  runApp(UncontrolledProviderScope(container: container, child: const ConvoMailApp()));
}

ProviderContainer? _container;

Future<void> _showWindow() async {
  if (!Platform.isWindows) return;
  await windowManager.show();
  await windowManager.focus();
}

void _requestCompose() {
  final c = _container;
  if (c == null) return;
  c.read(destinationProvider.notifier).select(Destination.chats);
  c.read(composeProvider.notifier).open();
  _showWindow();
}

class ConvoMailApp extends ConsumerStatefulWidget {
  const ConvoMailApp({super.key, this.startSync = true});

  /// Whether to start the background sync controller. Widget tests pass
  /// false so no mail server is contacted.
  final bool startSync;

  @override
  ConsumerState<ConvoMailApp> createState() => _ConvoMailAppState();
}

class _ConvoMailAppState extends ConsumerState<ConvoMailApp> {
  @override
  void initState() {
    super.initState();
    if (widget.startSync) {
      ref.read(syncControllerProvider).start();
      ref.read(scheduleServiceProvider).start();
    }
  }

  @override
  Widget build(BuildContext context) {
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
