import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// Call status ("Connecting...", "Ready — you can speak") with a coloured dot.
/// The words carry the meaning; the dot only repeats it. Wraps on large text.
class CallStatusPill extends StatelessWidget {
  final String label;
  final StatusTone tone;
  const CallStatusPill({super.key, required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final t = context.colors.tone(tone);
    return Semantics(
      liveRegion: true,
      label: 'Call status: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        decoration: BoxDecoration(color: t.background, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: t.foreground, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: context.text.labelMedium!.copyWith(color: t.foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
