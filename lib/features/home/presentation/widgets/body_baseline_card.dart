import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_colors.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/core/widgets/status_badge.dart';
import 'package:phia_flutter/features/home/presentation/widgets/body_metrics_sheet.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:phia_flutter/features/vitals/domain/body_units.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:provider/provider.dart';

/// Height, weight, age and BMI, in the user's units, with an Edit action.
class BodyBaselineCard extends StatelessWidget {
  const BodyBaselineCard({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ActivityViewModel>();
    final settings = context.watch<SettingsViewModel>();
    final colors = context.colors;
    final bmi = Bmi.from(weightKg: vm.userWeight, heightCm: vm.userHeight);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Semantics(header: true, child: Text('Body', style: context.text.titleMedium))),
              TextButton.icon(
                onPressed: () => showBodyMetricsSheet(context),
                icon: const Icon(Icons.edit_outlined, size: AppSizes.iconSm),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _Stat(label: 'Height', value: BodyUnits.formatHeight(vm.userHeight, settings.heightUnit))),
              Expanded(child: _Stat(label: 'Weight', value: BodyUnits.formatWeight(vm.userWeight, settings.weightUnit))),
              Expanded(child: _Stat(label: 'Age', value: vm.userAge > 0 ? '${vm.userAge} yrs' : '--')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('BMI', style: context.text.labelMedium!.copyWith(color: colors.textSecondary)),
              Text(bmi == null ? '--' : bmi.value.toStringAsFixed(1), style: context.text.titleMedium),
              if (bmi == null)
                const StatusBadge(label: 'Not set', tone: StatusTone.neutral)
              else
                StatusBadge(label: bmi.label, tone: bmi.tone),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: ${value == '--' ? 'not set' : value}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.labelMedium!.copyWith(color: context.colors.textSecondary)),
          const SizedBox(height: AppSpacing.xxs),
          Text(value, style: context.text.titleSmall),
        ],
      ),
    );
  }
}
