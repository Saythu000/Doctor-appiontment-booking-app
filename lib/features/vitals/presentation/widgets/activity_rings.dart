import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// One ring: how far a value is towards its goal.
class RingData {
  final double progress; // 0..1
  final Color color;
  const RingData(this.progress, this.color);
}

/// Concentric progress rings that fill once when first shown (and glide to
/// new values after a sync). Screen readers hear [semanticLabel] instead.
class ActivityRings extends StatelessWidget {
  final List<RingData> rings;
  final double size;
  final double strokeWidth;
  final String semanticLabel;
  final Widget? center;

  const ActivityRings({
    super.key,
    required this.rings,
    required this.semanticLabel,
    this.size = 120,
    this.strokeWidth = 10,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final track = context.colors.surfaceMuted;
    final reduced = AppMotion.reduced(context);
    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: reduced ? Duration.zero : const Duration(milliseconds: 900),
          curve: AppMotion.emphasizedDecelerate,
          builder: (context, t, child) => CustomPaint(
            painter: _RingsPainter(
              progress: [for (final r in rings) r.progress.clamp(0.0, 1.0) * t],
              colors: [for (final r in rings) r.color],
              track: track,
              strokeWidth: strokeWidth,
            ),
            child: child,
          ),
          child: center == null ? null : Center(child: ExcludeSemantics(child: center!)),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final List<double> progress;
  final List<Color> colors;
  final Color track;
  final double strokeWidth;

  _RingsPainter({required this.progress, required this.colors, required this.track, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final gap = strokeWidth * 0.35;
    for (var i = 0; i < progress.length; i++) {
      final r = size.shortestSide / 2 - strokeWidth / 2 - i * (strokeWidth + gap);
      if (r <= 0) break;
      final rect = Rect.fromCircle(center: c, radius: r);
      final base = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(c, r, base..color = track);
      if (progress[i] > 0) {
        canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress[i], false, base..color = colors[i]);
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.track != track || old.strokeWidth != strokeWidth || !_listEq(old.progress, progress) || !_listEq(old.colors, colors);

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
