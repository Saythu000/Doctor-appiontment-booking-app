import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/features/vitals/domain/body_units.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:provider/provider.dart';

bool _connecting = false;

/// Asks for Health Connect access (no dialog if already granted), syncs once,
/// and tells the user honestly what happened.
Future<void> syncHealthConnect(BuildContext context) async {
  final vm = context.read<ActivityViewModel>();
  // One sync per tap: ignore taps while the permission check or a sync runs.
  if (vm.isSyncing || _connecting) return;
  _connecting = true;
  final bool granted;
  try {
    granted = await vm.requestHealthConnectAuthorization();
  } finally {
    _connecting = false;
  }
  if (!context.mounted) return;
  if (!granted) {
    showAppMessage(
      context,
      'Health Connect access was not given. Allow access in Health Connect to bring in your watch data.',
      type: FeedbackType.error,
    );
    return;
  }
  final ok = await vm.syncOpenWearablesVitals('Android Health Connect');
  if (!context.mounted) return;
  if (ok) {
    showAppMessage(context, 'Synced from Health Connect.', type: FeedbackType.success);
  } else if (vm.lastSyncOutcome == VitalsSyncOutcome.noData) {
    showAppMessage(
      context,
      'No new data in Health Connect for today. Open your watch app so it syncs, then try again.',
    );
  } else {
    showAppMessage(context, "Couldn't sync. Check your connection and try again.", type: FeedbackType.error);
  }
}

/// Describes the current sync state in plain words.
class SyncStatus {
  final String title;
  final StatusTone tone;
  final IconData icon;

  const SyncStatus(this.title, this.tone, this.icon);

  static SyncStatus of(ActivityViewModel vm, {DateTime? now}) {
    final last = vm.lastSyncAt;
    final when = last == null ? null : VitalsFormat.ago(last, now: now);
    if (vm.isSyncing) {
      return const SyncStatus('Syncing from Health Connect…', StatusTone.info, Icons.sync_rounded);
    }
    switch (vm.lastSyncOutcome) {
      case VitalsSyncOutcome.failed:
        return SyncStatus(
          when == null ? 'Sync failed' : 'Sync failed · last synced $when',
          StatusTone.danger,
          Icons.sync_problem_rounded,
        );
      case VitalsSyncOutcome.noData:
        return SyncStatus(
          when == null ? 'No data in Health Connect yet' : 'No new data · last synced $when',
          StatusTone.warning,
          Icons.watch_off_outlined,
        );
      case VitalsSyncOutcome.synced:
      case VitalsSyncOutcome.none:
        if (vm.isOpenWearablesSynced && when != null) {
          return SyncStatus('Synced from Health Connect · $when', StatusTone.success, Icons.check_circle_rounded);
        }
        if (when != null) {
          return SyncStatus('Last synced $when', StatusTone.neutral, Icons.history_rounded);
        }
        return const SyncStatus('Not synced yet', StatusTone.neutral, Icons.watch_outlined);
    }
  }
}

/// One line that says where the numbers come from and how fresh they are,
/// with a Sync button. Replaces the old always-green "Active" pill.
class SyncStatusStrip extends StatelessWidget {
  /// Optional: open the device sheet instead of syncing straight away.
  final VoidCallback? onManage;

  const SyncStatusStrip({super.key, this.onManage});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ActivityViewModel>();
    final colors = context.colors;
    final status = SyncStatus.of(vm);
    final tone = colors.tone(status.tone);

    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            // Status and icon together form one 48dp-high target that opens
            // the device sheet.
            Expanded(
              child: InkWell(
                onTap: onManage,
                borderRadius: AppRadius.mdAll,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.sm),
                    child: Row(
                      children: [
                        if (vm.isSyncing)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: tone.foreground),
                          )
                        else
                          Icon(status.icon, size: 18, color: tone.foreground),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            status.title,
                            style: context.text.labelMedium!.copyWith(color: tone.foreground),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: vm.isSyncing ? null : () => syncHealthConnect(context),
              style: TextButton.styleFrom(
                foregroundColor: tone.foreground,
                minimumSize: const Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget),
              ),
              child: Text(vm.lastSyncOutcome == VitalsSyncOutcome.failed ? 'Retry' : 'Sync'),
            ),
          ],
        ),
      ),
    );
  }
}
