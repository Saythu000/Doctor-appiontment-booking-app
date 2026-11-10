import 'package:flutter/material.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:provider/provider.dart';

/// Units the app shows weight and height in. Data is always stored in kg/cm;
/// only the display and input change.
class ClinicalUnitsScreen extends StatelessWidget {
  const ClinicalUnitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsVM = context.watch<SettingsViewModel>();

    Future<void> save(String key, String value) async {
      try {
        await context.read<SettingsViewModel>().saveSetting(key, value);
      } catch (_) {
        if (context.mounted) {
          showAppMessage(context, "Couldn't change the unit. Please try again.", type: FeedbackType.error);
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Units')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Choose how weight and height are shown across the app.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            _UnitCard(
              icon: Icons.monitor_weight_outlined,
              title: 'Weight',
              selected: settingsVM.weightUnit == 'lbs' ? 'lbs' : 'kg',
              options: const [('kg', 'Kilograms (kg)'), ('lbs', 'Pounds (lb)')],
              onChanged: (v) => save('weightUnit', v),
            ),
            const SizedBox(height: AppSpacing.md),
            _UnitCard(
              icon: Icons.height_rounded,
              title: 'Height',
              selected: settingsVM.heightUnit == 'cm' ? 'cm' : 'in.',
              options: const [('cm', 'Centimetres (cm)'), ('in.', 'Feet and inches')],
              onChanged: (v) => save('heightUnit', v),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String selected;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  const _UnitCard({
    required this.icon,
    required this.title,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
            child: Row(
              children: [
                Icon(icon, color: colors.primary, size: AppSizes.iconMd),
                const SizedBox(width: AppSpacing.sm),
                Semantics(header: true, child: Text(title, style: context.text.titleMedium)),
              ],
            ),
          ),
          RadioGroup<String>(
            groupValue: selected,
            onChanged: (v) {
              if (v != null && v != selected) onChanged(v);
            },
            child: Column(
              children: [
                for (final (value, label) in options)
                  RadioListTile<String>(
                    value: value,
                    title: Text(label, style: context.text.bodyLarge),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
