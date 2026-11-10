import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// A full-width message strip used on the intake screens: information,
/// progress ("Saving for your doctor…") or an error with an action.
class IntakeNotice extends StatelessWidget {
  final String message;
  final StatusTone tone;
  final IconData? icon;
  final bool showProgress;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const IntakeNotice({
    super.key,
    required this.message,
    this.tone = StatusTone.info,
    this.icon,
    this.showProgress = false,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.colors.tone(tone);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
        decoration: BoxDecoration(color: t.background, borderRadius: AppRadius.mdAll),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showProgress)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: t.foreground),
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 20, color: t.foreground),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(message, style: context.text.bodyMedium!.copyWith(color: t.foreground)),
                ),
              ],
            ),
            if (actionLabel != null && onAction != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onAction,
                  style: TextButton.styleFrom(foregroundColor: t.foreground),
                  icon: Icon(actionIcon ?? Icons.refresh_rounded, size: 18),
                  label: Text(actionLabel!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
