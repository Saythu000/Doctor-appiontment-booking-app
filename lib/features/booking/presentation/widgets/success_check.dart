import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// A green circle that grows in, then a check mark that draws itself.
/// Shown once; with "Remove animations" on it appears complete at once.
class SuccessCheck extends StatefulWidget {
  final double size;
  const SuccessCheck({super.key, this.size = 96});

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else {
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
    final tone = context.colors.success;
    final circle = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.55, curve: AppMotion.emphasizedDecelerate),
    );
    final tick = CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1, curve: Curves.easeOut));

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Transform.scale(
            scale: 0.6 + 0.4 * circle.value,
            child: Opacity(
              opacity: circle.value,
              child: DecoratedBox(
                decoration: BoxDecoration(color: tone.background, shape: BoxShape.circle),
                child: CustomPaint(painter: _TickPainter(progress: tick.value, color: tone.foreground)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  final double progress;
  final Color color;

  _TickPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.29, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.66)
      ..lineTo(size.width * 0.72, size.height * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.08
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.progress != progress || old.color != color;
}
