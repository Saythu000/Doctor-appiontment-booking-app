import 'package:flutter/material.dart';

class ScanlineEffect extends StatefulWidget {
  const ScanlineEffect({super.key});

  @override
  State<ScanlineEffect> createState() => _ScanlineEffectState();
}

class _ScanlineEffectState extends State<ScanlineEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: MediaQuery.of(context).size.height * _controller.value,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        );
      },
    );
  }
}
