import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';

/// "Prepare for your visit": describe symptoms by voice or chat so the doctor
/// gets a summary before the visit.
class PrepareVisitCard extends StatelessWidget {
  const PrepareVisitCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text('Prepare for your visit', style: context.text.titleMedium)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tell us how you feel. Your doctor gets a clear summary before you meet.',
            style: context.text.bodySmall!.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          _Option(
            icon: Icons.mic_rounded,
            title: 'Talk it through',
            subtitle: 'Answer out loud, like a call',
            onTap: () => context.push(AppRoutes.voiceIntake),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Option(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Type your answers',
            subtitle: 'Chat at your own pace',
            onTap: () => context.push(AppRoutes.chatIntake),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Option({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceMuted,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget + 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
                    child: Icon(icon, size: AppSizes.iconMd, color: colors.onPrimaryContainer),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.text.titleSmall),
                        Text(subtitle, style: context.text.bodySmall!.copyWith(color: colors.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: colors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
