import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../viewmodel/settings_viewmodel.dart';

class VitalsThresholdsScreen extends StatefulWidget {
  const VitalsThresholdsScreen({super.key});

  @override
  State<VitalsThresholdsScreen> createState() => _VitalsThresholdsScreenState();
}

class _VitalsThresholdsScreenState extends State<VitalsThresholdsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _stepsController;
  late TextEditingController _sysMaxController;
  late TextEditingController _diaMaxController;
  late TextEditingController _hrMinController;
  late TextEditingController _hrMaxController;

  @override
  void initState() {
    super.initState();
    final settingsVM = context.read<SettingsViewModel>();
    final th = settingsVM.vitalsThresholds;

    _stepsController = TextEditingController(text: (th['steps']?['max'] ?? 10000).toInt().toString());
    _sysMaxController = TextEditingController(text: (th['systolic']?['max'] ?? 140).toInt().toString());
    _diaMaxController = TextEditingController(text: (th['diastolic']?['max'] ?? 90).toInt().toString());
    _hrMinController = TextEditingController(text: (th['heart_rate']?['min'] ?? 50).toInt().toString());
    _hrMaxController = TextEditingController(text: (th['heart_rate']?['max'] ?? 100).toInt().toString());
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

  @override
  Widget build(BuildContext context) {
    final settingsVM = context.watch<SettingsViewModel>();

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'VITALS WARNING THRESHOLDS',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 22,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      children: [
                        Text(
                          'DEFINE PHYSIOLOGICAL SAFETY RANGES. VALUES LOGGED OUTSIDE THESE RANGES WILL HIGHLIGHT RED ACROSS YOUR DASHBOARDS.',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Steps Target
                        _buildThresholdHeader('DAILY PHYSICAL MOBILITY'),
                        _buildInputField(
                          label: 'Daily Steps Goal',
                          controller: _stepsController,
                          suffix: 'steps',
                          helper: 'Standard clinical guidance suggests 8,000 - 10,000 steps daily.',
                        ),
                        const SizedBox(height: 24),

                        // Blood Pressure High Limits
                        _buildThresholdHeader('CARDIOVASCULAR BLOOD PRESSURE LIMITS'),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                label: 'Max Systolic Limit',
                                controller: _sysMaxController,
                                suffix: 'mmHg',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInputField(
                                label: 'Max Diastolic Limit',
                                controller: _diaMaxController,
                                suffix: 'mmHg',
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Systolic > 140 or Diastolic > 90 indicates Hypertension Stage 2 in clinical charts.',
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
                        ),
                        const SizedBox(height: 24),

                        // Heart Rate Limits
                        _buildThresholdHeader('RESTING HEART RATE RANGE'),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                label: 'Min Heart Rate',
                                controller: _hrMinController,
                                suffix: 'BPM',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInputField(
                                label: 'Max Heart Rate',
                                controller: _hrMaxController,
                                suffix: 'BPM',
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Normal adult resting heart rate range is 60 - 100 BPM.',
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
                        ),
                        
                        const SizedBox(height: 40),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 50),
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          ),
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              final stepsVal = double.parse(_stepsController.text);
                              final sysVal = double.parse(_sysMaxController.text);
                              final diaVal = double.parse(_diaMaxController.text);
                              final hrMinVal = double.parse(_hrMinController.text);
                              final hrMaxVal = double.parse(_hrMaxController.text);

                              await settingsVM.saveThreshold('steps', 0, stepsVal);
                              await settingsVM.saveThreshold('systolic', 90, sysVal);
                              await settingsVM.saveThreshold('diastolic', 60, diaVal);
                              await settingsVM.saveThreshold('heart_rate', hrMinVal, hrMaxVal);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Vitals thresholds updated successfully!')),
                                );
                                Navigator.pop(context);
                              }
                            }
                          },
                          child: Text(
                            'SAVE THRESHOLDS',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 18,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: GoogleFonts.bebasNeue(
          fontSize: 14,
          color: PhiaColors.skyBlue,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String suffix,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            color: const Color(0xFF0D0E0F),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Must be number';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                suffix,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(
            helper,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
