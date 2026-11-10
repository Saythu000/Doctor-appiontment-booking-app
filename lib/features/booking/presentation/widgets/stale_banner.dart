import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// Shown above a cached list when the refresh failed, so old data is never
/// mistaken for fresh data.
class StaleDataBanner extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;
  const StaleDataBanner({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final tone = context.colors.warning;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
        decoration: BoxDecoration(color: tone.background, borderRadius: AppRadius.mdAll),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: tone.foreground, size: AppSizes.iconMd),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: context.text.bodySmall!.copyWith(color: tone.foreground),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
