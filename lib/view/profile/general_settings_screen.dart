import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../viewmodel/settings_viewmodel.dart';
import '../../viewmodel/activity_viewmodel.dart';
import '../../core/utils/language_helper.dart';

class GeneralSettingsScreen extends StatelessWidget {
  const GeneralSettingsScreen({super.key});

  void _showLanguageSelector(BuildContext context, String currentLang) {
    final languages = [
      'English', 'Français', 'Italiano', 'Deutsch', 'Español', 
      'Русский', 'Português', 'Nederlands', 'Polski', '日本語', 
      '한국어', 'Türkçe', 'العربية', 'Indonesia', '简体中文', 
      '繁體中文', 'فارسی', 'Tiếng Việt', 'ไทย'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: PhiaColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
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
                    AppLanguageHelper.translate(context, 'select_language', defaultText: 'Select Language'),
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
              Expanded(
                child: ListView.separated(
                  itemCount: languages.length,
                  separatorBuilder: (_, __) => const Divider(color: PhiaColors.borderSubtle, height: 1),
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    final isSelected = lang == currentLang;
                    return InkWell(
                      onTap: () {
                        context.read<SettingsViewModel>().saveSetting('appLanguage', lang);
                        Navigator.pop(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              lang,
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
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStartWeekSelector(BuildContext context, String currentDay) {
    final days = ['Sunday', 'Monday'];

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
                    AppLanguageHelper.translate(context, 'start_week_title', defaultText: 'Start Week On'),
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
              ...days.map((day) {
                final isSelected = day == currentDay;
                return InkWell(
                  onTap: () {
                    context.read<SettingsViewModel>().saveSetting('startWeekDay', day);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          day,
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

  void _showEditBodyMetricsSheet(BuildContext context, ActivityViewModel activityVM) {
    final heightController = TextEditingController(
      text: activityVM.userHeight > 0 ? activityVM.userHeight.toStringAsFixed(0) : '',
    );
    final weightController = TextEditingController(
      text: activityVM.userWeight > 0 ? activityVM.userWeight.toStringAsFixed(1) : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
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
                    'Edit Body Metrics',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: PhiaColors.navyAnchor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: PhiaColors.textMuted),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HEIGHT (CM)',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: PhiaColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: PhiaColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: PhiaColors.borderSubtle),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: TextField(
                            controller: heightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: false),
                            style: GoogleFonts.inter(fontSize: 14, color: PhiaColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'e.g. 175',
                              hintStyle: GoogleFonts.inter(fontSize: 13, color: PhiaColors.textMuted),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WEIGHT (KG)',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: PhiaColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: PhiaColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: PhiaColors.borderSubtle),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: TextField(
                            controller: weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.inter(fontSize: 14, color: PhiaColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'e.g. 70.5',
                              hintStyle: GoogleFonts.inter(fontSize: 13, color: PhiaColors.textMuted),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final h = double.tryParse(heightController.text.trim()) ?? 0.0;
                  final w = double.tryParse(weightController.text.trim()) ?? 0.0;
                  Navigator.pop(sheetCtx);
                  if (h > 0 || w > 0) {
                    await activityVM.saveBioData(
                      weight: w > 0 ? w : activityVM.userWeight,
                      height: h > 0 ? h : activityVM.userHeight,
                      age: activityVM.userAge > 0 ? activityVM.userAge.toDouble() : 25.0,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: PhiaColors.activeGreen,
                          content: Text(
                            'Body metrics saved successfully!',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PhiaColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  'Save Body Metrics',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsVM = context.watch<SettingsViewModel>();
    final activityVM = context.watch<ActivityViewModel>();

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
          'Preferred Language & Settings',
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
                'Localization & Calendar Preferences',
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
                    title: AppLanguageHelper.translate(context, 'app_language', defaultText: 'App Language'),
                    value: settingsVM.appLanguage,
                    onTap: () => _showLanguageSelector(context, settingsVM.appLanguage),
                  ),
                  const Divider(color: PhiaColors.borderSubtle, height: 1),
                  _buildSettingsTile(
                    title: AppLanguageHelper.translate(context, 'start_week_on', defaultText: 'Start week on'),
                    value: settingsVM.startWeekDay,
                    onTap: () => _showStartWeekSelector(context, settingsVM.startWeekDay),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
              child: Text(
                'Body & Physical Metrics',
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
                    title: 'Height & Weight',
                    value: (activityVM.userHeight > 0 || activityVM.userWeight > 0)
                        ? '${activityVM.userHeight > 0 ? "${activityVM.userHeight.toStringAsFixed(0)} cm" : "--"}, ${activityVM.userWeight > 0 ? "${activityVM.userWeight.toStringAsFixed(1)} kg" : "--"}'
                        : 'Not Set',
                    onTap: () => _showEditBodyMetricsSheet(context, activityVM),
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
