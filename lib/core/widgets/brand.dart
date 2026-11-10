import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// The DrGodly logo tile.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'DrGodly',
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.10),
              blurRadius: size * 0.3,
              offset: Offset(0, size * 0.08),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.24),
          child: Image.asset('assets/app_logo.jpeg', width: size, height: size, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

/// Logo with the app name beside it, for screen headers.
class BrandHeader extends StatelessWidget {
  final double markSize;
  const BrandHeader({super.key, this.markSize = 36});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize),
        const SizedBox(width: AppSpacing.sm + 2),
        Flexible(
          child: ExcludeSemantics(
            child: Text('DrGodly', style: context.text.titleLarge, overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
        ),
      ],
    );
  }
}

/// An ECG-style heartbeat trace that draws itself from left to right and
/// then fades, on a loop. It stands for the app's idea: your heart and
/// health followed continuously. Used as the splash loading indicator.
///
/// With [loop] false it draws once and stays. When the user turned off
/// animations it shows the full line without moving.
class PulseLine extends StatefulWidget {
  final double width;
  final double height;
  final Color? color;
  final bool loop;
  final double strokeWidth;

  const PulseLine({
    super.key,
    this.width = 160,
    this.height = 40,
    this.color,
    this.loop = true,
    this.strokeWidth = 2.5,
  });

  @override
  State<PulseLine> createState() => _PulseLineState();
}

class _PulseLineState extends State<PulseLine> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.value = 0.6; // fully drawn, fully visible
    } else if (!_controller.isAnimating) {
      widget.loop ? _controller.repeat() : _controller.animateTo(0.6);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.colors.primary;
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _PulsePainter(
              progress: _controller.value,
              color: color,
              strokeWidth: widget.strokeWidth,
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  /// 0.0-0.6: the line draws in. 0.6-1.0: it fades out (loop only).
  final double progress;
  final Color color;
  final double strokeWidth;

  _PulsePainter({required this.progress, required this.color, required this.strokeWidth});

  /// One heartbeat: flat, small P wave, sharp QRS spike, T wave, flat.
  static const List<Offset> _beat = [
    Offset(0.00, 0.60), Offset(0.22, 0.60), Offset(0.27, 0.52), Offset(0.32, 0.60),
    Offset(0.38, 0.60), Offset(0.42, 0.70), Offset(0.48, 0.08), Offset(0.54, 0.92),
    Offset(0.58, 0.60), Offset(0.66, 0.60), Offset(0.73, 0.46), Offset(0.80, 0.60),
    Offset(1.00, 0.60),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i < _beat.length; i++) {
      final p = Offset(_beat[i].dx * size.width, _beat[i].dy * size.height);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }

    final drawn = math.min(progress / 0.6, 1.0);
    final fade = progress <= 0.6 ? 1.0 : 1.0 - Curves.easeIn.transform((progress - 0.6) / 0.4);
    if (drawn <= 0 || fade <= 0) return;

    final metric = path.computeMetrics().first;
    final visible = metric.extractPath(0, metric.length * Curves.easeInOut.transform(drawn));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.15 * fade), color.withValues(alpha: fade)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(visible, paint);

    // Glowing dot at the tip while drawing.
    if (drawn < 1) {
      final tip = metric.getTangentForOffset(metric.length * Curves.easeInOut.transform(drawn))?.position;
      if (tip != null) {
        canvas.drawCircle(tip, strokeWidth * 2.2, Paint()..color = color.withValues(alpha: 0.18));
        canvas.drawCircle(tip, strokeWidth * 1.1, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.progress != progress || old.color != color;
}

/// Status bar and navigation bar icon colours that suit the current theme,
/// for screens without an AppBar (splash, welcome, login).
SystemUiOverlayStyle systemBarsFor(BuildContext context) {
  final dark = context.isDark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: context.colors.background,
    systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
  );
}
