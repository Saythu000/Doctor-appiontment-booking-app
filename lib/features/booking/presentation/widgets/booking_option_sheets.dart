import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';

/// Asks whether the patient wants to describe their symptoms first (chat or
/// voice) or go straight to choosing a time.
///
/// [doctorArgs] holds `specialist`, `name`, `role` and `imageUrl`; it is
/// passed on unchanged to the next screen.
Future<void> showBookingOptionsSheet(BuildContext context, Map<String, dynamic> doctorArgs) {
  final name = doctorArgs['name'] as String? ?? 'your doctor';
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _SheetBody(
      title: 'How would you like to book?',
      message: 'Telling us how you feel first helps $name prepare for your visit.',
      options: [
        _Option(
          icon: Icons.assignment_rounded,
          title: 'Describe my symptoms first',
          subtitle: 'A few short questions by chat or voice.',
          recommended: true,
          onTap: () {
            Navigator.pop(sheetContext);
            _showIntakeMethodSheet(context, doctorArgs);
          },
        ),
        _Option(
          icon: Icons.event_rounded,
          title: 'Skip and choose a time',
          subtitle: 'Go straight to the calendar.',
          onTap: () {
            Navigator.pop(sheetContext);
            context.push(AppRoutes.bookingTime, extra: doctorArgs);
          },
        ),
      ],
    ),
  );
}

Future<void> _showIntakeMethodSheet(BuildContext context, Map<String, dynamic> doctorArgs) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _SheetBody(
      title: 'Chat or voice?',
      message: 'Choose how you want to answer. You can review everything before booking.',
      options: [
        _Option(
          icon: Icons.mic_rounded,
          title: 'Talk',
          subtitle: 'Answer out loud, like a phone call.',
          onTap: () {
            Navigator.pop(sheetContext);
            context.push(AppRoutes.voiceIntake, extra: doctorArgs);
          },
        ),
        _Option(
          icon: Icons.chat_rounded,
          title: 'Type',
          subtitle: 'Answer in a chat, at your own pace.',
          onTap: () {
            Navigator.pop(sheetContext);
            context.push(AppRoutes.chatIntake, extra: doctorArgs);
          },
        ),
      ],
    ),
  );
}

class _Option {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool recommended;
  final VoidCallback onTap;

  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.recommended = false,
  });
}

class _SheetBody extends StatelessWidget {
  final String title;
  final String message;
  final List<_Option> options;

  const _SheetBody({required this.title, required this.message, required this.options});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text(title, style: context.text.titleLarge)),
            const SizedBox(height: AppSpacing.xs),
            Text(message, style: context.text.bodyMedium!.copyWith(color: colors.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
            for (final o in options) ...[
              AppCard(
                onTap: o.onTap,
                semanticLabel: '${o.title}. ${o.subtitle}',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
                      child: Icon(o.icon, color: colors.onPrimaryContainer),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.title, style: context.text.titleSmall),
                          if (o.recommended)
                            Text(
                              'Recommended',
                              style: context.text.labelMedium!.copyWith(color: colors.success.foreground),
                            ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(o.subtitle, style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colors.textMuted),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}
