import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// What the voice call is doing, as shown by the orb.
enum OrbMode {
  /// No call yet, or the call ended.
  idle,

  /// Connecting or thinking: a slow pulse.
  connecting,

  /// Ready and listening to the patient: slow breathing.
  listening,

  /// The assistant is talking: waves ripple outwards.
  speaking,

  /// The patient's microphone is off: dimmed, still.
  muted,

  /// Writing or saving the summary: a slow pulse.
  working,
}

/// The large round "call" visual on the voice intake screen. The motion tells
/// the patient what is happening; with "Remove animations" on it stays still
/// and the status text alone carries the meaning.
class VoiceOrb extends StatefulWidget {
  final OrbMode mode;
  final double size;

  const VoiceOrb({super.key, required this.mode, this.size = 136});

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  bool get _moves => widget.mode != OrbMode.idle && widget.mode != OrbMode.muted;

  void _sync() {
    if (AppMotion.reduced(context) || !_moves) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(VoiceOrb old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = widget.mode != OrbMode.idle;
    final core = switch (widget.mode) {
      OrbMode.idle => colors.textMuted,
      OrbMode.muted => colors.textMuted,
      _ => colors.primary,
    };
    final icon = switch (widget.mode) {
      OrbMode.muted => Icons.mic_off_rounded,
      OrbMode.speaking => Icons.graphic_eq_rounded,
      OrbMode.working => Icons.edit_note_rounded,
      _ => Icons.mic_rounded,
    };

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _OrbPainter(
              t: _controller.value,
              mode: widget.mode,
              color: core,
              animate: _controller.isAnimating,
            ),
            child: Center(
              child: AnimatedContainer(
                duration: AppMotion.medium,
                width: widget.size * 0.52,
                height: widget.size * 0.52,
                decoration: BoxDecoration(
                  color: active && widget.mode != OrbMode.muted ? colors.primary : colors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: widget.size * 0.24,
                  color: active && widget.mode != OrbMode.muted ? colors.onPrimary : colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  final OrbMode mode;
  final Color color;
  final bool animate;

  _OrbPainter({required this.t, required this.mode, required this.color, required this.animate});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final inner = size.width * 0.26;
    final outer = size.width * 0.5;
    final paint = Paint()..style = PaintingStyle.fill;

    switch (mode) {
      case OrbMode.idle:
      case OrbMode.muted:
        paint.color = color.withValues(alpha: 0.10);
        canvas.drawCircle(center, inner + (outer - inner) * 0.45, paint);
      case OrbMode.speaking:
        // Three rings travelling outwards and fading.
        for (var i = 0; i < 3; i++) {
          final p = animate ? (t * 2 + i / 3) % 1.0 : 0.3 + i * 0.25;
          paint.color = color.withValues(alpha: 0.22 * (1 - p));
          canvas.drawCircle(center, inner + (outer - inner) * p, paint);
        }
      case OrbMode.listening:
        // Slow breathing: one soft halo grows and shrinks.
        final b = animate ? (1 - math.cos(t * 2 * math.pi)) / 2 : 0.5;
        paint.color = color.withValues(alpha: 0.12 + 0.06 * b);
        canvas.drawCircle(center, inner + (outer - inner) * (0.45 + 0.3 * b), paint);
      case OrbMode.connecting:
      case OrbMode.working:
        // Slow pulse: one ring goes out once per cycle.
        final p = animate ? Curves.easeOut.transform(t) : 0.5;
        paint.color = color.withValues(alpha: 0.18 * (1 - p));
        canvas.drawCircle(center, inner + (outer - inner) * p, paint);
        paint.color = color.withValues(alpha: 0.10);
        canvas.drawCircle(center, inner + (outer - inner) * 0.3, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.t != t || old.mode != mode || old.color != color || old.animate != animate;
}
