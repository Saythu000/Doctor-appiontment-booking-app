import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// A row of equal-width, single-choice options (for example gender).
/// Nothing is selected until the user picks.
class SegmentedChoice<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T> onChanged;
  final String? errorText;

  const SegmentedChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (value, label) in options)
              _Option(
                label: label,
                selected: value == selected,
                hasError: errorText != null,
                onTap: () => onChanged(value),
              ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.md),
            child: Text(errorText!, style: context.text.bodySmall!.copyWith(color: colors.danger.foreground)),
          ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  final String label;
  final bool selected;
  final bool hasError;
  final VoidCallback onTap;

  const _Option({required this.label, required this.selected, required this.hasError, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final border = selected
        ? colors.primary
        : hasError
            ? colors.danger.foreground
            : colors.border;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(color: border, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget, minWidth: 88),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: AppMotion.fast,
                    child: selected
                        ? Padding(
                            key: const ValueKey('on'),
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: Icon(Icons.check_rounded, size: 18, color: colors.onPrimaryContainer),
                          )
                        : const SizedBox.shrink(key: ValueKey('off')),
                  ),
                  Text(
                    label,
                    style: context.text.labelLarge!.copyWith(
                      color: selected ? colors.onPrimaryContainer : colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
