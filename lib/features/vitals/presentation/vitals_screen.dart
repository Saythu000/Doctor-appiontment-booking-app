import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/core/widgets/motion.dart';
import 'package:phia_flutter/features/home/presentation/widgets/body_baseline_card.dart';
import 'package:phia_flutter/features/home/presentation/widgets/vitals_summary_card.dart'
    show kActiveMinutesGoal, stepGoalOf;
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:phia_flutter/features/vitals/domain/body_units.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/device_manager_sheet.dart';
import 'package:phia_flutter/features/vitals/presentation/widgets/activity_rings.dart';
import 'package:phia_flutter/features/vitals/presentation/widgets/sync_status_strip.dart';
import 'package:provider/provider.dart';

/// Today's activity, heart, oxygen and sleep from Health Connect.
/// Every value is real or "--"; nothing is estimated.
class VitalsScreen extends StatelessWidget {
  /// True when shown as a bottom-navigation tab (no back arrow).
  final bool isTab;
  const VitalsScreen({super.key, this.isTab = false});

  Future<void> _refresh(BuildContext context) async {
    final vm = context.read<ActivityViewModel>();
    await vm.syncOpenWearablesVitals('Android Health Connect');
    await vm.initDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    var i = 0;
    Widget enter(Widget child) => FadeSlideIn(delay: Duration(milliseconds: 50 * i++), child: child);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !isTab,
        title: const Text('Vitals'),
        actions: [
          IconButton(
            tooltip: 'Health Connect',
            icon: const Icon(Icons.watch_outlined),
            onPressed: () => DeviceManagerSheet.show(context),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        // A short, fixed set of cards: built once so the entrance stagger
        // plays once, not again for each card scrolled into view.
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              enter(SyncStatusStrip(onManage: () => DeviceManagerSheet.show(context))),
              const SizedBox(height: AppSpacing.lg),
              enter(const _ActivityCard()),
              const SizedBox(height: AppSpacing.lg),
              enter(const _VitalTiles()),
              const SizedBox(height: AppSpacing.lg),
              enter(const _SleepCard()),
              const SizedBox(height: AppSpacing.lg),
              enter(const BodyBaselineCard()),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ActivityViewModel>();
    final goal = stepGoalOf(context.watch<SettingsViewModel>());
    final colors = context.colors;
    final steps = vm.currentSteps;
    final active = vm.currentActiveMins;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text('Activity today', style: context.text.titleMedium)),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: ActivityRings(
              size: 150,
              strokeWidth: 13,
              semanticLabel: 'Steps ${steps > 0 ? VitalsFormat.thousands(steps) : 'not synced'} of '
                  '${VitalsFormat.thousands(goal)} goal. Active time ${active > 0 ? '$active minutes' : 'not synced'} '
                  'of $kActiveMinutesGoal minute goal.',
              rings: [
                RingData(steps / goal, colors.vitalSteps),
                RingData(active / kActiveMinutesGoal, colors.vitalActive),
              ],
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(VitalsFormat.count(steps), style: context.text.titleLarge),
                  Text('steps', style: context.text.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _LegendRow(
            color: colors.vitalSteps,
            label: 'Steps',
            value: VitalsFormat.count(steps),
            note: 'Goal ${VitalsFormat.thousands(goal)}',
          ),
          _LegendRow(
            color: colors.vitalActive,
            label: 'Active time',
            value: active > 0 ? '$active min' : '--',
            note: 'Goal $kActiveMinutesGoal min',
          ),
          _LegendRow(
            color: colors.vitalSteps,
            icon: Icons.straighten_rounded,
            label: 'Distance',
            value: vm.dashboardDistanceKm > 0 ? '${vm.dashboardDistanceKm.toStringAsFixed(2)} km' : '--',
          ),
          _LegendRow(
            color: colors.vitalCalories,
            icon: Icons.local_fire_department_rounded,
            label: 'Calories burned',
            value: vm.currentCalories > 0 ? '${VitalsFormat.thousands(vm.currentCalories)} kcal' : '--',
            note: 'Includes resting calories',
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String label;
  final String value;
  final String? note;

  const _LegendRow({required this.color, required this.label, required this.value, this.icon, this.note});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: '$label: ${value == '--' ? 'not synced' : value}${note == null ? '' : '. $note'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
        child: Row(
          children: [
            SizedBox(
              width: AppSizes.iconMd,
              child: icon == null
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                    )
                  : Icon(icon, size: AppSizes.iconSm, color: color),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.text.bodyMedium),
                  if (note != null) Text(note!, style: context.text.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: context.text.titleSmall!.copyWith(color: colors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Heart rate, HRV and blood oxygen as tiles: two per row, one per row when
/// the text is very large. Heights follow the content (no fixed ratio).
class _VitalTiles extends StatelessWidget {
  const _VitalTiles();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ActivityViewModel>();
    final colors = context.colors;
    final hasRange = vm.dashboardMinHr != null && vm.dashboardMaxHr != null && vm.dashboardMaxHr! > 0;

    final tiles = [
      _VitalTile(
        icon: Icons.favorite_rounded,
        color: colors.vitalHeart,
        label: 'Heart rate',
        value: vm.dashboardHr > 0 ? '${vm.dashboardHr.round()}' : '--',
        unit: 'bpm',
        note: hasRange ? 'Low ${vm.dashboardMinHr} · High ${vm.dashboardMaxHr}' : null,
      ),
      _VitalTile(
        icon: Icons.monitor_heart_outlined,
        color: colors.vitalHeart,
        label: 'Heart rate variability',
        value: vm.dashboardHrv > 0 ? vm.dashboardHrv.toStringAsFixed(0) : '--',
        unit: 'ms',
      ),
      _VitalTile(
        icon: Icons.air_rounded,
        color: colors.vitalOxygen,
        label: 'Blood oxygen',
        value: (vm.dashboardSpo2 ?? 0) > 0 ? vm.dashboardSpo2!.round().toString() : '--',
        unit: '%',
        note: (vm.dashboardSpo2 ?? 0) > 0 ? "Today's reading" : null,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1) >= 260;
        if (!twoColumns) {
          return Column(
            children: [
              for (final t in tiles) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: t),
            ],
          );
        }
        final w = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

class _VitalTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;
  final String? note;

  const _VitalTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final known = value != '--';
    return AppCard(
      semanticLabel: '$label: ${known ? '$value $unit' : 'not synced'}${note == null ? '' : '. $note'}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: AppSizes.iconMd, color: color),
            const SizedBox(height: AppSpacing.sm),
            Text(label, style: context.text.labelMedium!.copyWith(color: colors.textSecondary)),
            const SizedBox(height: AppSpacing.xxs),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value, style: context.text.headlineSmall),
                  if (known) TextSpan(text: ' $unit', style: context.text.bodySmall),
                ],
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(note!, style: context.text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _SleepCard extends StatelessWidget {
  const _SleepCard();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ActivityViewModel>();
    final colors = context.colors;
    final totalMin = (vm.currentSleep * 60).round();

    final stages = [
      ('Deep', vm.deepSleepMinutes, colors.brandNavy),
      ('Light', vm.lightSleepMinutes, colors.vitalSleep),
      ('REM', vm.remSleepMinutes, colors.accentSky),
      ('Awake', vm.awakeMinutes, colors.vitalCalories),
    ];
    final stageSum = stages.fold<int>(0, (s, e) => s + e.$2);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bedtime_rounded, size: AppSizes.iconMd, color: colors.vitalSleep),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Semantics(header: true, child: Text('Sleep', style: context.text.titleMedium))),
              Text(VitalsFormat.minutes(totalMin), style: context.text.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (totalMin <= 0)
            Text(
              'No sleep recorded for last night. Wear your watch to bed and let its app sync to Health Connect.',
              style: context.text.bodyMedium!.copyWith(color: colors.textSecondary),
            )
          else if (stageSum <= 0)
            Text(
              'Your watch did not report sleep stages for this night.',
              style: context.text.bodyMedium!.copyWith(color: colors.textSecondary),
            )
          else ...[
            Semantics(
              label: 'Sleep stages: ${stages.map((s) => '${s.$1} ${VitalsFormat.minutes(s.$2)}').join(', ')}',
              image: true,
              child: ClipRRect(
                borderRadius: AppRadius.smAll,
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      for (final s in stages)
                        if (s.$2 > 0) Expanded(flex: s.$2, child: ColoredBox(color: s.$3)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ExcludeSemantics(
              child: Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final s in stages)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: s.$3, borderRadius: AppRadius.smAll),
                        ),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: '${s.$1} ', style: context.text.bodySmall),
                                TextSpan(text: VitalsFormat.minutes(s.$2), style: context.text.labelMedium),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
