import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/status_badge.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/widgets/sync_status_strip.dart';
import 'package:provider/provider.dart';

/// Health Connect: what it reads, when it last synced, and a Sync button.
/// Sized to its content.
class DeviceManagerSheet extends StatelessWidget {
  const DeviceManagerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      builder: (_) => const DeviceManagerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ActivityViewModel>();
    final colors = context.colors;
    final status = SyncStatus.of(vm);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: AppRadius.mdAll),
                child: Icon(Icons.health_and_safety_rounded, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text('Health Connect', style: context.text.titleLarge)),
                    Text(
                      'Works with any watch that syncs to Health Connect',
                      style: context.text.bodySmall!.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            liveRegion: true,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(label: status.title, tone: status.tone, icon: status.icon),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'DrGodly reads heart rate, heart rate variability, steps, sleep and blood oxygen that your watch app '
            '(for example Samsung Health, Noise or boAt) writes to Health Connect.',
            style: context.text.bodyMedium!.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          const _Point(icon: Icons.visibility_outlined, text: 'Read-only: DrGodly never changes your Health Connect data.'),
          const _Point(icon: Icons.verified_user_outlined, text: 'Synced readings are saved to your DrGodly health record.'),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: vm.lastSyncAt == null ? 'Connect and sync' : 'Sync now',
            icon: Icons.sync_rounded,
            isLoading: vm.isSyncing,
            onPressed: vm.isSyncing ? null : () => syncHealthConnect(context),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Point({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSizes.iconSm, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: context.text.bodySmall)),
        ],
      ),
    );
  }
}
