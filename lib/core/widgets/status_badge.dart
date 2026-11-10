import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// Small coloured label, for example "CONFIRMED" or "Synced".
/// Colours come from the theme's [StatusTone], so contrast is always readable.
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final IconData? icon;

  const StatusBadge({super.key, required this.label, required this.tone, this.icon});

  @override
  Widget build(BuildContext context) {
    final t = context.colors.tone(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: t.background, borderRadius: AppRadius.smAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: t.foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: context.text.labelSmall!.copyWith(color: t.foreground, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}
