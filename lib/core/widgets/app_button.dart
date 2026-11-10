import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

enum AppButtonVariant { primary, secondary, text, danger }

/// The app's one button.
///
/// [isLoading] shows a spinner and disables the button, so an action can
/// never be sent twice by tapping again while it runs.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final AppButtonVariant variant;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.variant = AppButtonVariant.primary,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.text;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final action = isLoading ? null : onPressed;
    final spinnerColor = switch (variant) {
      AppButtonVariant.primary => colors.onPrimary,
      AppButtonVariant.danger => Colors.white,
      _ => colors.primary,
    };

    final Widget content = AnimatedSwitcher(
      duration: AppMotion.fast,
      child: isLoading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: AppSizes.iconMd,
              height: AppSizes.iconMd,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: spinnerColor),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AppSizes.iconMd),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(onPressed: action, child: content),
      AppButtonVariant.secondary => OutlinedButton(onPressed: action, child: content),
      AppButtonVariant.text => TextButton(onPressed: action, child: content),
      AppButtonVariant.danger => FilledButton(
          onPressed: action,
          style: FilledButton.styleFrom(
            backgroundColor: context.isDark ? colors.danger.background : colors.danger.foreground,
            foregroundColor: context.isDark ? colors.danger.foreground : Colors.white,
          ),
          child: content,
        ),
    };

    return Semantics(
      button: true,
      enabled: action != null,
      label: isLoading ? '$label, in progress' : null,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
