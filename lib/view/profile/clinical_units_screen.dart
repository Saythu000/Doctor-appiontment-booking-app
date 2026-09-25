import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
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
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: const BoxDecoration(
            color: PhiaColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PhiaColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: PhiaColors.navyAnchor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: PhiaColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...options.map((opt) {
                final isSelected = opt == currentVal;
                return InkWell(
                  onTap: () {
                    context.read<SettingsViewModel>().saveSetting(settingKey, opt);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          opt,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: isSelected ? PhiaColors.primary : PhiaColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: PhiaColors.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsVM = context.watch<SettingsViewModel>();

    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Clinical Unit Registrations',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
              child: Text(
                'Clinical Measurement Standards',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PhiaColors.navyAnchor,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: PhiaColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PhiaColors.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                  const Divider(color: PhiaColors.borderSubtle, height: 1),
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
                  const Divider(color: PhiaColors.borderSubtle, height: 1),
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
                  const Divider(color: PhiaColors.borderSubtle, height: 1),
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
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: PhiaColors.textPrimary,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: PhiaColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: PhiaColors.textMuted,
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
