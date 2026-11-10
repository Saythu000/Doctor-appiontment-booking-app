import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/app_feedback.dart';
import 'package:phia_flutter/core/widgets/form_feedback.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:phia_flutter/features/vitals/domain/body_units.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:provider/provider.dart';

/// Opens the "Edit body" sheet. Values are shown and typed in the user's
/// units and saved in kg and cm.
Future<void> showBodyMetricsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    builder: (_) => BodyMetricsSheet(hostContext: context),
  );
}

class BodyMetricsSheet extends StatefulWidget {
  /// Context that outlives the sheet, for the result message.
  final BuildContext hostContext;
  const BodyMetricsSheet({super.key, required this.hostContext});

  @override
  State<BodyMetricsSheet> createState() => _BodyMetricsSheetState();
}

class _BodyMetricsSheetState extends State<BodyMetricsSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _age;
  late final String _weightUnit;
  late final String _heightUnit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final vm = context.read<ActivityViewModel>();
    final settings = context.read<SettingsViewModel>();
    _weightUnit = settings.weightUnit;
    _heightUnit = settings.heightUnit;
    _height = TextEditingController(
      text: BodyUnits.inputText(BodyUnits.heightToDisplay(vm.userHeight, _heightUnit), decimals: 0),
    );
    _weight = TextEditingController(text: BodyUnits.inputText(BodyUnits.weightToDisplay(vm.userWeight, _weightUnit)));
    _age = TextEditingController(text: vm.userAge > 0 ? '${vm.userAge}' : '');
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    _age.dispose();
    super.dispose();
  }

  String? Function(String?) _rangeValidator(String what, (num, num) range, String unit, {bool whole = false}) {
    return (raw) {
      final text = raw?.trim() ?? '';
      if (text.isEmpty) return 'Enter your $what';
      final v = whole ? int.tryParse(text) : double.tryParse(text);
      if (v == null) return whole ? 'Use whole numbers only' : 'Use numbers only';
      if (v < range.$1 || v > range.$2) {
        return 'Use a value between ${range.$1.round()} and ${range.$2.round()}$unit';
      }
      return null;
    };
  }

  Future<void> _save() async {
    if (_saving || !validateForm(context, _form)) return;
    setState(() => _saving = true);
    final vm = context.read<ActivityViewModel>();
    final serverOk = await vm.saveBioData(
      weight: BodyUnits.weightFromDisplay(double.parse(_weight.text.trim()), _weightUnit),
      height: BodyUnits.heightFromDisplay(double.parse(_height.text.trim()), _heightUnit),
      age: int.parse(_age.text.trim()).toDouble(),
    );
    if (!mounted) return;
    Navigator.pop(context);
    final host = widget.hostContext;
    if (!host.mounted) return;
    if (serverOk) {
      showAppMessage(host, 'Body details saved.', type: FeedbackType.success);
    } else {
      showAppMessage(
        host,
        "Saved on this phone, but we couldn't update your health record. Check your connection and save again.",
        type: FeedbackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wLabel = BodyUnits.weightLabel(_weightUnit);
    final hLabel = BodyUnits.heightLabel(_heightUnit);
    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}(\.\d{0,1})?'))];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text('Edit body details', style: context.text.titleLarge)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your doctor uses these to read your vitals correctly.',
                style: context.text.bodySmall!.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextFormField(
                controller: _height,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: decimal,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'Height', suffixText: hLabel),
                validator: _rangeValidator('height', BodyUnits.heightRange(_heightUnit), ' $hLabel'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: decimal,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: 'Weight', suffixText: wLabel),
                validator: _rangeValidator('weight', BodyUnits.weightRange(_weightUnit), ' $wLabel'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _age,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(labelText: 'Age', suffixText: 'years'),
                validator: _rangeValidator('age', BodyUnits.ageRange, ' years', whole: true),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(label: 'Save', isLoading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
