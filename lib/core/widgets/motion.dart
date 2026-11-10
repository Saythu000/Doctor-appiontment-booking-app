import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';

/// Fades and slightly lifts its child into place when first shown.
///
/// Use [delay] to stagger items in a list (for example 60 ms apart).
/// Respects the Android "Remove animations" accessibility setting.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double offsetY;

  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero, this.offsetY = 12});

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: AppMotion.entrance);
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: AppMotion.emphasizedDecelerate);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(offset: Offset(0, widget.offsetY * (1 - _curve.value)), child: child),
      ),
    );
  }
}

/// A slow, gentle "heartbeat" scale pulse (used for the brand mark and live
/// indicators). Stays still when animations are turned off.
class Heartbeat extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration period;

  const Heartbeat({
    super.key,
    required this.child,
    this.scale = 1.06,
    this.period = const Duration(milliseconds: 1400),
  });

  @override
  State<Heartbeat> createState() => _HeartbeatState();
}

class _HeartbeatState extends State<Heartbeat> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.period);

  // Two quick beats then rest, like a pulse ("lub-dub").
  late final Animation<double> _beat = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: widget.scale).chain(CurveTween(curve: Curves.easeOut)), weight: 12),
    TweenSequenceItem(tween: Tween<double>(begin: widget.scale, end: 1).chain(CurveTween(curve: Curves.easeIn)), weight: 12),
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1 + (widget.scale - 1) * 0.6), weight: 10),
    TweenSequenceItem(tween: Tween<double>(begin: 1 + (widget.scale - 1) * 0.6, end: 1), weight: 12),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 54),
  ]).animate(_controller);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _beat, child: widget.child);
}
