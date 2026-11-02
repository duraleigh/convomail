import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

/// True in the running app on Windows, where the system title bar is hidden
/// and [WindowBar] stands in for it. Tests leave it off.
final windowChromeProvider = Provider<bool>((ref) => false);

/// Height of the invisible strip along the top of the window.
const double windowBarHeight = 30;

/// Stands in for the title bar: an invisible strip that moves the window
/// when dragged (and maximizes on a double-click), with minimize, maximize
/// and close at the right edge that show only while the pointer is over
/// them. There is no title.
class WindowBar extends StatefulWidget {
  const WindowBar({super.key});

  @override
  State<WindowBar> createState() => _WindowBarState();
}

class _WindowBarState extends State<WindowBar> with WindowListener {
  bool _hover = false;
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((m) {
      if (mounted) setState(() => _maximized = m);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: windowBarHeight,
      child: Row(
        children: [
          const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
          MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: AnimatedOpacity(
              opacity: _hover ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CaptionButton(key: const ValueKey('window-minimize'), icon: Icons.remove_rounded, tooltip: 'Minimize', onPressed: windowManager.minimize),
                  _CaptionButton(
                    key: const ValueKey('window-maximize'),
                    icon: _maximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
                    tooltip: _maximized ? 'Restore' : 'Maximize',
                    onPressed: () => _maximized ? windowManager.unmaximize() : windowManager.maximize(),
                  ),
                  _CaptionButton(key: const ValueKey('window-close'), icon: Icons.close_rounded, tooltip: 'Close', onPressed: windowManager.close, danger: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.danger = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Close turns red under the pointer, as Windows does.
  final bool danger;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = !_hover ? Colors.transparent : (widget.danger ? const Color(0xFFC42B1C) : scheme.onSurface.withValues(alpha: 0.08));
    final foreground = _hover && widget.danger ? Colors.white : scheme.onSurfaceVariant;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 46,
            height: windowBarHeight,
            color: background,
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 16, color: foreground),
          ),
        ),
      ),
    );
  }
}
