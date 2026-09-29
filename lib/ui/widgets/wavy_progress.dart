import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Material 3 Expressive wavy linear progress indicator.
///
/// The completed portion is a sine wave in the primary color; the remainder
/// is a flat track in primary-container with a stop dot at the end. Pass
/// `value` in 0..1, or null for an indeterminate wave that scrolls.
class WavyLinearProgress extends StatefulWidget {
  const WavyLinearProgress({
    super.key,
    this.value,
    this.height = 14,
    this.amplitude = 3,
    this.wavelength = 20,
    this.strokeWidth = 4,
    this.semanticsLabel,
  });

  final double? value;
  final double height;
  final double amplitude;
  final double wavelength;
  final double strokeWidth;
  final String? semanticsLabel;

  @override
  State<WavyLinearProgress> createState() => _WavyLinearProgressState();
}

class _WavyLinearProgressState extends State<WavyLinearProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: widget.semanticsLabel,
      value: widget.value == null ? null : '${(widget.value! * 100).round()}%',
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _phase,
          builder: (context, _) => CustomPaint(
            painter: _WavePainter(
              value: widget.value,
              phase: _phase.value * 2 * math.pi,
              amplitude: widget.amplitude,
              wavelength: widget.wavelength,
              strokeWidth: widget.strokeWidth,
              active: scheme.primary,
              track: scheme.primaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.value,
    required this.phase,
    required this.amplitude,
    required this.wavelength,
    required this.strokeWidth,
    required this.active,
    required this.track,
  });

  final double? value;
  final double phase;
  final double amplitude;
  final double wavelength;
  final double strokeWidth;
  final Color active;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final gap = strokeWidth * 1.5;
    final progress = (value ?? 0.4).clamp(0.0, 1.0);
    final waveEnd = value == null ? size.width : size.width * progress;

    final wavePaint = Paint()
      ..color = active
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (waveEnd > 0) {
      final path = Path()..moveTo(0, midY + amplitude * math.sin(phase));
      for (var x = 1.0; x <= waveEnd; x += 1) {
        path.lineTo(x, midY + amplitude * math.sin(phase + (x / wavelength) * 2 * math.pi));
      }
      canvas.drawPath(path, wavePaint);
    }

    if (value != null && waveEnd + gap < size.width - gap) {
      canvas.drawLine(Offset(waveEnd + gap, midY), Offset(size.width - gap, midY), trackPaint);
      canvas.drawCircle(Offset(size.width - strokeWidth / 2, midY), strokeWidth / 2, Paint()..color = active);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.value != value || old.phase != phase || old.active != active || old.track != track;
}
