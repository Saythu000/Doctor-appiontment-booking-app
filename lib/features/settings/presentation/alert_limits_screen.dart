import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/core/widgets/form_feedback.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:provider/provider.dart';

/// Limits that trigger a vitals alert (heart rate, blood pressure) and the
/// daily steps goal.
class AlertLimitsScreen extends StatefulWidget {
  const AlertLimitsScreen({super.key});

  @override
  State<AlertLimitsScreen> createState() => _AlertLimitsScreenState();
}

class _AlertLimitsScreenState extends State<AlertLimitsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _stepsController;
  late final TextEditingController _sysMaxController;
  late final TextEditingController _diaMaxController;
  late final TextEditingController _hrMinController;
  late final TextEditingController _hrMaxController;

  // Lower BP limits are not editable here; keep whatever is stored.
  late final double _sysMin;
  late final double _diaMin;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final th = context.read<SettingsViewModel>().vitalsThresholds;
    String v(String metric, String bound, double fallback) => (th[metric]?[bound] ?? fallback).toInt().toString();

    _stepsController = TextEditingController(text: v('steps', 'max', 10000));
    _sysMaxController = TextEditingController(text: v('systolic', 'max', 140));
    _diaMaxController = TextEditingController(text: v('diastolic', 'max', 90));
    _hrMinController = TextEditingController(text: v('heart_rate', 'min', 50));
    _hrMaxController = TextEditingController(text: v('heart_rate', 'max', 100));
    _sysMin = th['systolic']?['min'] ?? 90;
    _diaMin = th['diastolic']?['min'] ?? 60;
  }

  @override
  void dispose() {
    _stepsController.dispose();
    _sysMaxController.dispose();
    _diaMaxController.dispose();
    _hrMinController.dispose();
    _hrMaxController.dispose();
    super.dispose();
  }

  String? Function(String?) _range(int min, int max) => (value) {
        final n = int.tryParse(value?.trim() ?? '');
        if (n == null) return 'Enter a number';
        if (n < min || n > max) return 'Use $min–$max';
        return null;
      };

  Future<void> _save() async {
    if (_saving || !validateForm(context, _formKey)) return;

    final steps = double.parse(_stepsController.text.trim());
    final sysMax = double.parse(_sysMaxController.text.trim());
    final diaMax = double.parse(_diaMaxController.text.trim());
    final hrMin = double.parse(_hrMinController.text.trim());
    final hrMax = double.parse(_hrMaxController.text.trim());

    if (hrMin >= hrMax) {
      showAppMessage(context, 'Lowest heart rate must be below the highest.', type: FeedbackType.error);
      return;
    }
    if (diaMax >= sysMax) {
      showAppMessage(context, 'Diastolic limit must be below the systolic limit.', type: FeedbackType.error);
      return;
    }

    setState(() => _saving = true);
    final settingsVM = context.read<SettingsViewModel>();
    try {
      await settingsVM.saveThreshold('steps', 0, steps);
      await settingsVM.saveThreshold('systolic', _sysMin, sysMax);
      await settingsVM.saveThreshold('diastolic', _diaMin, diaMax);
      await settingsVM.saveThreshold('heart_rate', hrMin, hrMax);
      if (!mounted) return;
      showAppMessage(context, 'Alert limits saved.', type: FeedbackType.success);
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppMessage(context, "Couldn't save your limits. Please try again.", type: FeedbackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vital alert limits')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          // Not a lazy ListView: every field must stay built so the Form
          // validates fields that are scrolled out of view.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "You'll get an alert when a reading from your watch goes outside these limits. "
                  'These alerts do not replace advice from your doctor.',
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                _LimitSection(
                  icon: Icons.favorite_outline_rounded,
                  title: 'Heart rate',
                  note: 'A typical adult resting heart rate is 60–100 BPM.',
                  fields: [
                    _LimitField('Lowest', _hrMinController, 'BPM', _range(30, 120)),
                    _LimitField('Highest', _hrMaxController, 'BPM', _range(60, 220)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _LimitSection(
                  icon: Icons.bloodtype_outlined,
                  title: 'Blood pressure (upper limits)',
                  note: 'Above 140/90 mmHg is generally considered high blood pressure.',
                  fields: [
                    _LimitField('Systolic', _sysMaxController, 'mmHg', _range(90, 250)),
                    _LimitField('Diastolic', _diaMaxController, 'mmHg', _range(50, 150)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _LimitSection(
                  icon: Icons.directions_walk_rounded,
                  title: 'Daily steps goal',
                  note: 'Many guidelines suggest 7,000–10,000 steps a day.',
                  fields: [
                    _LimitField('Steps', _stepsController, 'steps', _range(1000, 50000)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: 'Save limits', isLoading: _saving, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LimitField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String suffix;
  final String? Function(String?) validator;

  const _LimitField(this.label, this.controller, this.suffix, this.validator);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }
}

class _LimitSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String note;
  final List<Widget> fields;

  const _LimitSection({required this.icon, required this.title, required this.note, required this.fields});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary, size: AppSizes.iconMd),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(header: true, child: Text(title, style: context.text.titleMedium)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              // Side by side when there is room, stacked on narrow phones or large text.
              final stack =
                  fields.length > 1 && (constraints.maxWidth < 260 || MediaQuery.textScalerOf(context).scale(10) > 13);
              if (stack || fields.length == 1) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.md),
                      fields[i],
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.md),
                    Expanded(child: fields[i]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(note, style: context.text.bodySmall),
        ],
      ),
    );
  }
}
