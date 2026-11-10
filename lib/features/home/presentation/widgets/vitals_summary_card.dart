import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:phia_flutter/features/vitals/domain/body_units.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/widgets/activity_rings.dart';
import 'package:provider/provider.dart';

/// The daily step goal from the user's alert limits (default 10,000).
int stepGoalOf(SettingsViewModel settings) {
  final g = settings.vitalsThresholds['steps']?['max'] ?? 10000;
  return g > 0 ? g.round() : 10000;
}

/// Daily active-minutes goal (WHO: 150 min a week, about 30 a day).
const int kActiveMinutesGoal = 30;

/// Today at a glance; tapping opens the Vitals tab.
class VitalsSummaryCard extends StatelessWidget {
  final VoidCallback onOpen;
  const VitalsSummaryCard({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ActivityViewModel>();
    final goal = stepGoalOf(context.watch<SettingsViewModel>());
    final colors = context.colors;

    final steps = vm.currentSteps;
    final active = vm.currentActiveMins;
    final ringsLabel = 'Steps ${steps > 0 ? VitalsFormat.thousands(steps) : 'not synced'} of '
        '${VitalsFormat.thousands(goal)} goal. Active time ${active > 0 ? '$active minutes' : 'not synced'} '
        'of $kActiveMinutesGoal minute goal.';

    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Semantics(header: true, child: Text('Today', style: context.text.titleMedium))),
              Text('See all', style: context.text.labelLarge!.copyWith(color: colors.primary)),
              Icon(Icons.chevron_right_rounded, color: colors.primary, size: AppSizes.iconMd),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              ActivityRings(
                size: 96,
                strokeWidth: 9,
                semanticLabel: ringsLabel,
                rings: [
                  RingData(steps / goal, colors.vitalSteps),
                  RingData(active / kActiveMinutesGoal, colors.vitalActive),
                ],
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GoalLine(
                      color: colors.vitalSteps,
                      label: 'Steps',
                      value: VitalsFormat.count(steps),
                      goal: 'Goal ${VitalsFormat.thousands(goal)}',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _GoalLine(
                      color: colors.vitalActive,
                      label: 'Active time',
                      value: active > 0 ? '$active min' : '--',
                      goal: 'Goal $kActiveMinutesGoal min',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MiniStat(
                icon: Icons.favorite_rounded,
                color: colors.vitalHeart,
                label: 'Heart rate',
                value: vm.dashboardHr > 0 ? '${vm.dashboardHr.round()} bpm' : '--',
              ),
              _MiniStat(
                icon: Icons.bedtime_rounded,
                color: colors.vitalSleep,
                label: 'Sleep',
                value: VitalsFormat.minutes((vm.currentSleep * 60).round()),
              ),
              _MiniStat(
                icon: Icons.local_fire_department_rounded,
                color: colors.vitalCalories,
                label: 'Calories*',
                value: vm.currentCalories > 0 ? '${VitalsFormat.thousands(vm.currentCalories)} kcal' : '--',
              ),
            ],
          ),
          if (vm.currentCalories > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('* Includes calories your body burns at rest.', style: context.text.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _GoalLine extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final String goal;
  const _GoalLine({required this.color, required this.label, required this.value, required this.goal});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.labelMedium!.copyWith(color: colors.textSecondary)),
              Text(value, style: context.text.titleMedium),
              Text(goal, style: context.text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _MiniStat({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: '${label.replaceAll('*', '')}: ${value == '--' ? 'not synced' : value}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: AppRadius.mdAll),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.iconSm, color: color),
            const SizedBox(width: AppSpacing.xs + 2),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$label  ', style: context.text.bodySmall),
                    TextSpan(text: value, style: context.text.labelLarge!.copyWith(color: colors.textPrimary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
