import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class PhiaTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String placeholder;
  final bool isPassword;

  const PhiaTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.placeholder,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: PhiaColors.outlineVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: PhiaColors.outlineVariant),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword,
            style: const TextStyle(
              color: PhiaColors.white,
              fontSize: 16,
              fontFamily: 'Geist',
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(12),
              border: InputBorder.none,
              hintText: placeholder.toUpperCase(),
              hintStyle: const TextStyle(
                color: PhiaColors.outlineVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
