import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class PhiaButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const PhiaButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: PhiaColors.white,
        foregroundColor: PhiaColors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          fontFamily: 'Bebas Neue',
        ),
      ),
    );
  }
}
