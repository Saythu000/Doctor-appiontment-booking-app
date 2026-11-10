import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/app_card.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:provider/provider.dart';

/// "Body measurements": height and weight, entered in the user's chosen
/// units and always saved in cm and kg.
class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cm = TextEditingController();
  final _ft = TextEditingController();
  final _in = TextEditingController();
  final _weight = TextEditingController();
  bool _saving = false;
  bool? _pounds;
  bool? _feetInches;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsViewModel>();
    // Prefill (again) whenever the unit changes, converting the stored value.
    if (_pounds != settings.usesPounds || _feetInches != settings.usesFeetInches) {
      _pounds = settings.usesPounds;
      _feetInches = settings.usesFeetInches;
      _prefill(context.read<ActivityViewModel>());
    }
  }

  void _prefill(ActivityViewModel vm) {
    final h = vm.userHeight;
    final w = vm.userWeight;
    _cm.text = h > 0 ? h.toStringAsFixed(0) : '';
    if (h > 0) {
      final (ft, inch) = UnitFormat.cmToFeetInches(h);
      _ft.text = '$ft';
      _in.text = '$inch';
    } else {
      _ft.clear();
      _in.clear();
    }
    _weight.text = w > 0 ? (_pounds! ? UnitFormat.kgToPounds(w) : w).toStringAsFixed(1) : '';
  }

  @override
  void dispose() {
    _cm.dispose();
    _ft.dispose();
    _in.dispose();
    _weight.dispose();
    super.dispose();
  }

  static String? Function(String?) _range(double min, double max, String unit, {bool required = true}) {
    return (v) {
      final text = v?.trim() ?? '';
      if (text.isEmpty) return required ? 'Required' : null;
      final value = double.tryParse(text);
      if (value == null) return 'Enter a number';
      if (value < min || value > max) return 'Enter ${min.toStringAsFixed(0)}–${max.toStringAsFixed(0)} $unit';
      return null;
    };
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final activity = context.read<ActivityViewModel>();

    final heightCm = _feetInches!
        ? UnitFormat.feetInchesToCm(int.parse(_ft.text.trim()), int.tryParse(_in.text.trim()) ?? 0)
        : double.parse(_cm.text.trim());
    final rawWeight = double.parse(_weight.text.trim());
    final weightKg = _pounds! ? UnitFormat.poundsToKg(rawWeight) : rawWeight;

    setState(() => _saving = true);
    try {
      final synced = await activity.saveBioData(
        weight: weightKg,
        height: heightCm,
        age: activity.userAge.toDouble(),
      );
      if (!mounted) return;
      showAppMessage(
        context,
        synced ? 'Height and weight saved.' : 'Saved on this phone. It will be sent to your care team later.',
        type: FeedbackType.success,
      );
    } catch (_) {
      if (mounted) {
        showAppMessage(context, "Couldn't save your measurements. Please try again.", type: FeedbackType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}'))];

    return Scaffold(
      appBar: AppBar(title: const Text('Body measurements')),
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
                  'Used to work out calories and other health numbers. Only you and your care team can see them.',
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(header: true, child: Text('Height', style: context.text.titleMedium)),
                      const SizedBox(height: AppSpacing.md),
                      if (_feetInches!)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                key: const ValueKey('height-ft'),
                                controller: _ft,
                                keyboardType: TextInputType.number,
                                inputFormatters: digits,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(labelText: 'Feet', suffixText: 'ft'),
                                validator: _range(1, 8, 'ft'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: TextFormField(
                                key: const ValueKey('height-in'),
                                controller: _in,
                                keyboardType: TextInputType.number,
                                inputFormatters: digits,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(labelText: 'Inches', suffixText: 'in'),
                                validator: _range(0, 11, 'in', required: false),
                              ),
                            ),
                          ],
                        )
                      else
                        TextFormField(
                          key: const ValueKey('height-cm'),
                          controller: _cm,
                          keyboardType: TextInputType.number,
                          inputFormatters: digits,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Height', suffixText: 'cm'),
                          validator: _range(50, 250, 'cm'),
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      Semantics(header: true, child: Text('Weight', style: context.text.titleMedium)),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        key: const ValueKey('weight'),
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: decimal,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _save(),
                        decoration: InputDecoration(labelText: 'Weight', suffixText: _pounds! ? 'lb' : 'kg'),
                        validator: _pounds! ? _range(5, 880, 'lb') : _range(2, 400, 'kg'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: 'Save', isLoading: _saving, onPressed: _save),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: AppButton.text(
                    label: 'Change units',
                    icon: Icons.straighten_rounded,
                    onPressed: () => context.push(AppRoutes.units),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
