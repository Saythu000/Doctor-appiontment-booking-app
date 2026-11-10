import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';

/// A card holding a list of [SettingsTile]s separated by thin dividers.
class SettingsGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const SettingsGroup({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Semantics(header: true, child: Text(title!, style: context.text.titleSmall)),
          ),
        Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll, side: BorderSide(color: colors.border)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(indent: AppSpacing.lg + 40 + AppSpacing.md, color: colors.border),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One row in a settings list: tinted icon, title, optional value, chevron.
/// The whole row is a single 56dp+ tap target.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showChevron;
  final Widget? trailing;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.destructive = false,
    this.showChevron = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = destructive ? colors.danger.foreground : colors.primary;
    final bg = destructive ? colors.danger.background : colors.primaryContainer;

    return Semantics(
      button: onTap != null,
      label: value == null ? title : '$title, $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: bg, borderRadius: AppRadius.mdAll),
                  child: Icon(icon, size: AppSizes.iconMd, color: fg),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.text.bodyLarge!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: destructive ? colors.danger.foreground : colors.textPrimary,
                        ),
                      ),
                      if (value != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(value!, style: context.text.bodyMedium),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
                if (trailing == null && showChevron && onTap != null)
                  Icon(Icons.chevron_right_rounded, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
