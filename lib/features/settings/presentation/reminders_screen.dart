import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/core/widgets/motion.dart';
import 'package:phia_flutter/core/widgets/state_views.dart';
import 'package:phia_flutter/core/widgets/status_badge.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:phia_flutter/features/settings/presentation/widgets/reminder_editor_sheet.dart';
import 'package:provider/provider.dart';

/// Medicine and vitals-check reminders.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reminders = context.watch<SettingsViewModel>().remindersList;

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      floatingActionButton: reminders.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showReminderEditor(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add reminder'),
            ),
      body: SafeArea(
        child: reminders.isEmpty
            ? LayoutBuilder(
                // Centred, but scrolls on small phones with large text.
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: EmptyView(
                        icon: Icons.notifications_none_rounded,
                        title: 'No reminders yet',
                        message: 'Get a gentle nudge to take your medicine or check your vitals.',
                        actionLabel: 'Add reminder',
                        onAction: () => showReminderEditor(context),
                      ),
                    ),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
                itemCount: reminders.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final rem = reminders[index];
                  return FadeSlideIn(
                    delay: Duration(milliseconds: 50 * index.clamp(0, 6)),
                    child: _ReminderTile(key: ValueKey(rem['id']), reminder: rem),
                  );
                },
              ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final Map<String, dynamic> reminder;
  const _ReminderTile({super.key, required this.reminder});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final id = reminder['id'] as String;
    final title = (reminder['title'] as String?) ?? '';
    final type = (reminder['type'] as String?) ?? reminderTypeMedication;
    final days = (reminder['days'] as String?) ?? 'Daily';
    final isActive = (reminder['is_active'] as int? ?? 0) == 1;

    var timeLabel = '--';
    final parts = ((reminder['time'] as String?) ?? '').split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) timeLabel = TimeOfDay(hour: h, minute: m).format(context);
    }

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(color: colors.danger.background, borderRadius: AppRadius.lgAll),
        child: Icon(Icons.delete_outline_rounded, color: colors.danger.foreground),
      ),
      confirmDismiss: (_) => confirmDeleteReminder(context, title),
      onDismissed: (_) async {
        final vm = context.read<SettingsViewModel>();
        showAppMessage(context, title.isEmpty ? 'Reminder deleted.' : '"$title" reminder deleted.');
        await vm.deleteReminder(id);
      },
      child: AppCard(
        onTap: () => showReminderEditor(context, reminder: reminder),
        semanticLabel: '$title, $timeLabel, ${describeReminderDays(days)}, ${isActive ? 'on' : 'off'}. Tap to edit.',
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isActive ? colors.primaryContainer : colors.surfaceMuted,
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(reminderTypeIcon(type), color: isActive ? colors.primary : colors.textMuted),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeLabel,
                    style: context.text.titleLarge!.copyWith(
                      color: isActive ? colors.textPrimary : colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(title, style: context.text.bodyLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(describeReminderDays(days), style: context.text.bodySmall),
                      if (!isActive) const StatusBadge(label: 'Off', tone: StatusTone.neutral),
                    ],
                  ),
                ],
              ),
            ),
            // Spoken by TalkBack, so the switch says what it controls.
            Semantics(
              label: title.isEmpty ? 'Reminder at $timeLabel' : '$title reminder',
              child: Switch(
                value: isActive,
                onChanged: (val) async {
                  try {
                    await context.read<SettingsViewModel>().toggleReminder(id, val);
                  } catch (_) {
                    if (context.mounted) {
                      showAppMessage(context, "Couldn't change the reminder. Please try again.",
                          type: FeedbackType.error);
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
