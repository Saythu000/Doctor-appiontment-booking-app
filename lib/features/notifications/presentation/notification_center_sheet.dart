import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/core/widgets/state_views.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:provider/provider.dart';

/// Opens the alerts list as a bottom sheet.
Future<void> showNotificationCenter(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    builder: (_) => const NotificationCenterSheet(),
  );
}

/// How an alert type is shown. Unknown types get a neutral style.
class AlertKind {
  final String label;
  final IconData icon;
  final StatusTone tone;
  const AlertKind(this.label, this.icon, this.tone);

  static AlertKind of(String? type) => switch ((type ?? '').toUpperCase()) {
        'VITALS_WARNING' => const AlertKind('Vitals', Icons.monitor_heart_outlined, StatusTone.danger),
        'APPOINTMENT_STATUS' => const AlertKind('Visit', Icons.event_note_rounded, StatusTone.info),
        'MILESTONE' => const AlertKind('Visit', Icons.event_note_rounded, StatusTone.info),
        _ => const AlertKind('Update', Icons.notifications_none_rounded, StatusTone.neutral),
      };
}

class NotificationCenterSheet extends StatefulWidget {
  const NotificationCenterSheet({super.key});

  @override
  State<NotificationCenterSheet> createState() => _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends State<NotificationCenterSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SettingsViewModel>().fetchInAppNotifications();
    });
  }

  Future<void> _clearAll(SettingsViewModel vm) async {
    final ok = await confirmAction(
      context,
      title: 'Clear all alerts?',
      message: 'This removes every alert from this list. It cannot be undone.',
      confirmLabel: 'Clear all',
      destructive: true,
    );
    if (ok) await vm.clearAllInAppNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final logs = vm.inAppNotificationsList;
    final height = MediaQuery.sizeOf(context).height * 0.75;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.sm, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(child: Semantics(header: true, child: Text('Alerts', style: context.text.titleLarge))),
                if (logs.isNotEmpty)
                  TextButton(onPressed: () => _clearAll(vm), child: const Text('Clear all')),
              ],
            ),
          ),
          Expanded(
            child: logs.isEmpty
                ? const EmptyView(
                    icon: Icons.notifications_none_rounded,
                    title: 'No alerts',
                    message: 'Heart rate warnings and visit updates will appear here.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                    itemCount: logs.length,
                    itemBuilder: (context, i) => _AlertTile(log: logs[i], vm: vm),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final Map<String, dynamic> log;
  final SettingsViewModel vm;
  const _AlertTile({required this.log, required this.vm});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final id = log['id']?.toString() ?? '';
    final title = log['title']?.toString() ?? '';
    final body = log['body']?.toString() ?? '';
    final kind = AlertKind.of(log['type']?.toString());
    final tone = colors.tone(kind.tone);
    final isRead = (int.tryParse(log['is_read']?.toString() ?? '') ?? 0) == 1;
    final at = DateTime.tryParse(log['timestamp']?.toString() ?? '')?.toLocal();
    final time = at == null ? '' : DateFormat('d MMM, h:mm a').format(at);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Dismissible(
        key: ValueKey(id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.xl),
          decoration: BoxDecoration(color: colors.tone(StatusTone.danger).background, borderRadius: AppRadius.mdAll),
          child: Icon(Icons.delete_outline_rounded, color: colors.tone(StatusTone.danger).foreground),
        ),
        onDismissed: (_) => vm.deleteInAppNotification(id),
        child: Semantics(
          label: '${isRead ? '' : 'Unread. '}${kind.label}. $title. $body. $time',
          hint: 'Swipe left to delete',
          excludeSemantics: true,
          child: Material(
            color: isRead ? colors.surface : colors.surfaceMuted,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll, side: BorderSide(color: colors.border)),
            child: InkWell(
              borderRadius: AppRadius.mdAll,
              onTap: isRead ? null : () => vm.markNotificationAsRead(id),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: tone.background, shape: BoxShape.circle),
                      child: Icon(kind.icon, size: AppSizes.iconMd, color: tone.foreground),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.sm,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(kind.label, style: context.text.labelMedium!.copyWith(color: tone.foreground)),
                              if (time.isNotEmpty) Text(time, style: context.text.bodySmall),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            title,
                            style: context.text.titleSmall!.copyWith(
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                            ),
                          ),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(body, style: context.text.bodySmall!.copyWith(color: colors.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                    if (!isRead)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.sm, top: AppSpacing.xs),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
