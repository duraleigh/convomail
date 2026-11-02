import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

/// True in the running app on Windows, where the system title bar and frame
/// are gone and [WindowFrame] stands in for them. Tests leave it off.
final windowChromeProvider = Provider<bool>((ref) => false);

// The frame's sizes match the Flow browser's.

/// Height of the see-through strip along the top of the window, which holds
/// minimize, maximize and close.
const double windowBarHeight = 24;

/// Width of the see-through frame along the left, right and bottom edges.
const double windowFrameEdge = 13;

/// Corner radius of the app inside the frame.
const double windowContentRadius = 15;

/// How far in from the window's edge a drag resizes it.
const double _resizeEdge = 6;

/// A see-through frame around the whole app, as in the Flow browser: the app
/// sits on a rounded panel with a soft shadow, [windowFrameEdge] in from the
/// left, right and bottom and [windowBarHeight] from the top, where
/// [WindowBar] keeps the window buttons. Dragging the frame moves the window;
/// dragging its outer edge resizes it.
class WindowFrame extends StatelessWidget {
  const WindowFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(windowContentRadius));
    return DragToResizeArea(
      resizeEdgeSize: _resizeEdge,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: DragToMoveArea(child: SizedBox.expand())),
            Padding(
              padding: const EdgeInsets.fromLTRB(windowFrameEdge, windowBarHeight, windowFrameEdge, windowFrameEdge),
              child: DecoratedBox(
                // Lifts the app off the desktop: a tight contact shadow plus a
                // softer one that falls downward.
                decoration: const BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(color: Color(0x59000000), offset: Offset(0, 1), blurRadius: 2),
                    BoxShadow(color: Color(0x4D000000), offset: Offset(0, 3), blurRadius: 6),
                    BoxShadow(color: Color(0x73000000), offset: Offset(0, 8), blurRadius: 12, spreadRadius: -2),
                  ],
                ),
                child: ClipRRect(borderRadius: radius, child: child),
              ),
            ),
            const Positioned(top: 0, left: 0, right: 0, child: WindowBar()),
          ],
        ),
      ),
    );
  }
}

/// Stands in for the title bar: a see-through strip that moves the window
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
    final scheme = Theme.of(context).colorScheme;
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
              // A backing of their own, so they read over any desktop.
              child: Container(
                decoration: BoxDecoration(color: scheme.surfaceContainerHigh.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(6)),
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
          ),
          // Lined up with the right edge of the app below.
          const SizedBox(width: windowFrameEdge),
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
            width: 40,
            height: windowBarHeight,
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 15, color: foreground),
          ),
        ),
      ),
    );
  }
}
