import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// A green circle that grows in, then a check mark that draws itself.
/// Plays once. With "Remove animations" on it appears finished at once.
class SuccessCheck extends StatefulWidget {
  final double size;
  const SuccessCheck({super.key, this.size = 88});

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else if (_controller.value == 0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.colors.tone(StatusTone.success);
    return Semantics(
      label: 'Saved',
      image: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final grow = Curves.easeOutBack.transform((_controller.value / 0.5).clamp(0.0, 1.0));
          final draw = Curves.easeOut.transform(((_controller.value - 0.4) / 0.6).clamp(0.0, 1.0));
          return Transform.scale(
            scale: 0.6 + 0.4 * grow,
            child: Opacity(
              opacity: grow.clamp(0.0, 1.0),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(color: t.background, shape: BoxShape.circle),
                child: CustomPaint(painter: _CheckPainter(progress: draw, color: t.foreground)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.30, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.66)
      ..lineTo(size.width * 0.71, size.height * 0.38);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.075
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress || old.color != color;
}
