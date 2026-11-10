import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:phia_flutter/core/theme/colors.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';

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
    String v(String metric, String bound, double fallback) =>
        (th[metric]?[bound] ?? fallback).toInt().toString();

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
    if (_saving || !_formKey.currentState!.validate()) return;

    final steps = double.parse(_stepsController.text.trim());
    final sysMax = double.parse(_sysMaxController.text.trim());
    final diaMax = double.parse(_diaMaxController.text.trim());
    final hrMin = double.parse(_hrMinController.text.trim());
    final hrMax = double.parse(_hrMaxController.text.trim());

    final messenger = ScaffoldMessenger.of(context);
    if (hrMin >= hrMax) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Lowest heart rate must be below the highest.'),
        backgroundColor: PhiaColors.pulseRed,
      ));
      return;
    }
    if (diaMax >= sysMax) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Diastolic limit must be below the systolic limit.'),
        backgroundColor: PhiaColors.pulseRed,
      ));
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
      messenger.showSnackBar(const SnackBar(content: Text('Alert limits saved.')));
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't save your limits. Please try again."),
        backgroundColor: PhiaColors.pulseRed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Vital Alert Limits',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                "You'll get an alert when a reading from your watch goes outside these limits. "
                'These alerts do not replace advice from your doctor.',
                style: GoogleFonts.inter(fontSize: 13, color: PhiaColors.textSecondary, height: 1.45),
              ),
              const SizedBox(height: 16),
              _section(
                title: 'Heart rate',
                note: 'A typical adult resting heart rate is 60–100 BPM.',
                children: [
                  _field('Lowest', _hrMinController, 'BPM', _range(30, 120)),
                  const SizedBox(width: 12),
                  _field('Highest', _hrMaxController, 'BPM', _range(60, 220)),
                ],
              ),
              _section(
                title: 'Blood pressure (upper limits)',
                note: 'Above 140/90 mmHg is generally considered high blood pressure.',
                children: [
                  _field('Systolic', _sysMaxController, 'mmHg', _range(90, 250)),
                  const SizedBox(width: 12),
                  _field('Diastolic', _diaMaxController, 'mmHg', _range(50, 150)),
                ],
              ),
              _section(
                title: 'Daily steps goal',
                note: 'Many guidelines suggest 7,000–10,000 steps a day.',
                children: [
                  _field('Steps', _stepsController, 'steps', _range(1000, 50000)),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PhiaColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text('Save Limits', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required String note, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PhiaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhiaColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: PhiaColors.navyAnchor,
            ),
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          const SizedBox(height: 8),
          Text(note, style: GoogleFonts.inter(fontSize: 12, color: PhiaColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String suffix,
    String? Function(String?) validator,
  ) {
    return Expanded(
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.inter(fontSize: 15, color: PhiaColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          filled: true,
          fillColor: PhiaColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: PhiaColors.borderSubtle),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: PhiaColors.borderSubtle),
          ),
        ),
      ),
    );
  }
}
