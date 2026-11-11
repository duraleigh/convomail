// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:path/path.dart' as p;
import 'package:tray_manager/legacy.dart';
import 'package:win32_registry/win32_registry.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

import '../sync/notification_center.dart';

/// Windows toasts through local_notifier (spec 4.17). Clicking a toast
/// reports through [notificationClickProvider]; the shell opens the row.
class WindowsNotificationSink implements NotificationSink {
  WindowsNotificationSink(this._ref);
  final Ref _ref;
  bool _ready = false;

  Future<void> _ensure() async {
    if (_ready) return;
    await localNotifier.setup(appName: 'Précis', shortcutPolicy: ShortcutPolicy.requireCreate);
    _ready = true;
  }

  @override
  Future<void> show(OutgoingNotification n) async {
    try {
      await _ensure();
      final toast = LocalNotification(identifier: n.id, title: n.title, body: n.body);
      toast.onClick = () => _ref.read(notificationClickProvider.notifier).clicked(n);
      await toast.show();
    } catch (e) {
      debugPrint('toast failed: $e');
    }
  }
}

/// Tray icon with unread tooltip and menu, taskbar overlay badge,
/// close-to-tray, and launch-at-login (spec 4.17, 5.3, plan M10).
class WindowsIntegration with TrayListener, WindowListener {
  WindowsIntegration({required this.onOpen, required this.onCompose, required this.onQuit});

  final VoidCallback onOpen;
  final VoidCallback onCompose;
  final VoidCallback onQuit;

  bool _trayReady = false;
  bool closeToTray = true;
  int _lastBadge = -1;
  bool _showBadge = true;

  Future<void> start() async {
    if (!Platform.isWindows) return;
    try {
      await trayManager.setIcon('assets/tray.ico');
      await trayManager.setToolTip('Précis');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'open', label: 'Open Précis'),
        MenuItem(key: 'compose', label: 'New message'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit'),
      ]));
      trayManager.addListener(this);
      _trayReady = true;
    } catch (e) {
      debugPrint('tray unavailable: $e');
    }
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    launchAtStartup.setup(appName: 'Précis', appPath: Platform.resolvedExecutable, args: ['--minimized']);
    await _carryOverOldName();
  }

  /// The app used to be called ConvoMail. Windows still holds a
  /// "start with Windows" entry and a Start menu shortcut under that name,
  /// both pointing at the old program file. Move the first to the new name
  /// and remove the second (the alerts add-on makes a fresh one).
  Future<void> _carryOverOldName() async {
    const old = 'ConvoMail';
    try {
      final run = Registry.openPath(RegistryHive.currentUser, path: r'Software\Microsoft\Windows\CurrentVersion\Run', desiredAccessRights: AccessRights.allAccess);
      final had = run.getStringValue(old) != null;
      if (had) run.deleteValue(old);
      run.close();
      if (had) {
        try {
          final approved = Registry.openPath(RegistryHive.currentUser, path: r'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run', desiredAccessRights: AccessRights.allAccess);
          approved.deleteValue(old);
          approved.close();
        } catch (_) {}
        await launchAtStartup.enable();
      }
    } catch (e) {
      debugPrint('startup entry carry-over failed: $e');
    }
    try {
      final appData = Platform.environment['APPDATA'];
      if (appData != null) {
        final link = File(p.join(appData, 'Microsoft', 'Windows', 'Start Menu', 'Programs', '$old.lnk'));
        if (link.existsSync()) link.deleteSync();
      }
    } catch (e) {
      debugPrint('old shortcut removal failed: $e');
    }
  }

  Future<void> stop() async {
    windowManager.removeListener(this);
    if (_trayReady) {
      trayManager.removeListener(this);
      await trayManager.destroy();
    }
  }

  /// Updates the taskbar overlay and tray tooltip. Icons for 1–9 and 9+ are
  /// bundled; 0 clears the overlay.
  Future<void> setUnread(int count, {bool? showBadge}) async {
    if (showBadge != null) _showBadge = showBadge;
    if (!Platform.isWindows) return;
    final effective = _showBadge ? count : 0;
    if (effective == _lastBadge) return;
    _lastBadge = effective;
    try {
      if (effective <= 0) {
        await WindowsTaskbar.resetOverlayIcon();
      } else {
        final name = effective > 9 ? 'badge_9plus' : 'badge_$effective';
        await WindowsTaskbar.setOverlayIcon(ThumbnailToolbarAssetIcon('assets/badges/$name.ico'), tooltip: '$count unread');
      }
      if (_trayReady) await trayManager.setToolTip(count == 0 ? 'Précis' : 'Précis · $count unread');
    } catch (e) {
      debugPrint('badge failed: $e');
    }
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideWindow() => windowManager.hide();

  Future<bool> setLaunchAtLogin(bool on) async {
    try {
      return on ? await launchAtStartup.enable() : await launchAtStartup.disable();
    } catch (e) {
      debugPrint('launch at login failed: $e');
      return false;
    }
  }

  Future<bool> isLaunchAtLoginEnabled() async {
    try {
      return await launchAtStartup.isEnabled();
    } catch (_) {
      return false;
    }
  }

  // ---- TrayListener ----------------------------------------------------------

  @override
  void onTrayIconMouseDown() => onOpen();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        onOpen();
      case 'compose':
        onCompose();
      case 'quit':
        onQuit();
    }
  }

  // ---- WindowListener --------------------------------------------------------

  @override
  void onWindowClose() async {
    if (closeToTray && _trayReady) {
      await windowManager.hide();
    } else {
      onQuit();
    }
  }
}

final windowsIntegrationProvider = Provider<WindowsIntegration?>((ref) => null);
