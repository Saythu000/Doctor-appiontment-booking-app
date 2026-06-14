import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../viewmodel/settings_viewmodel.dart';

class ClinicalUnitsScreen extends StatelessWidget {
  const ClinicalUnitsScreen({super.key});

  void _showUnitSelector({
    required BuildContext context,
    required String title,
    required String currentVal,
    required List<String> options,
    required String settingKey,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const Border(
        top: BorderSide(color: PhiaColors.skyBlue, width: 2.0),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: GoogleFonts.bebasNeue(
                      fontSize: 22,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...options.map((opt) {
                    final isSelected = opt == currentVal;
                    return InkWell(
                      onTap: () {
                        context.read<SettingsViewModel>().saveSetting(settingKey, opt);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              opt,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: isSelected ? Colors.white : Colors.white60,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: PhiaColors.skyBlue,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                      minimumSize: const Size(double.infinity, 48),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'CANCEL',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
                        'CLINICAL MEASUREMENT PREFERENCES',
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
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    children: [
                      Text(
                        'SET MEASUREMENT PREFERENCES TO ENSURE LOGGED OBS & VITALS DISPLAY CORRECTLY ACROSS THE DRGODLY PORTAL.',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: PhiaColors.surface,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          children: [
                            _buildSettingsTile(
                              title: 'Weight Unit',
                              value: settingsVM.weightUnit,
                              onTap: () => _showUnitSelector(
                                context: context,
                                title: 'Select Weight Unit',
                                currentVal: settingsVM.weightUnit,
                                options: ['kg', 'lbs'],
                                settingKey: 'weightUnit',
                              ),
                            ),
                            _buildDivider(),
                            _buildSettingsTile(
                              title: 'Height Unit',
                              value: settingsVM.heightUnit,
                              onTap: () => _showUnitSelector(
                                context: context,
                                title: 'Select Height Unit',
                                currentVal: settingsVM.heightUnit,
                                options: ['cm', 'in.'],
                                settingKey: 'heightUnit',
                              ),
                            ),
                            _buildDivider(),
                            _buildSettingsTile(
                              title: 'Temperature Unit',
                              value: settingsVM.tempUnit,
                              onTap: () => _showUnitSelector(
                                context: context,
                                title: 'Select Temperature Unit',
                                currentVal: settingsVM.tempUnit,
                                options: ['°C', '°F'],
                                settingKey: 'tempUnit',
                              ),
                            ),
                            _buildDivider(),
                            _buildSettingsTile(
                              title: 'Blood Glucose Unit',
                              value: settingsVM.glucoseUnit,
                              onTap: () => _showUnitSelector(
                                context: context,
                                title: 'Select Blood Glucose Unit',
                                currentVal: settingsVM.glucoseUnit,
                                options: ['mg/dL', 'mmol/L'],
                                settingKey: 'glucoseUnit',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: PhiaColors.skyBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.24),
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}
