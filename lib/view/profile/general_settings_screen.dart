import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../viewmodel/settings_viewmodel.dart';
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
      backgroundColor: Colors.black,
      shape: const Border(
        top: BorderSide(color: PhiaColors.skyBlue, width: 2.0),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLanguageHelper.translate(context, 'select_language', defaultText: 'SELECT LANGUAGE'),
                style: GoogleFonts.bebasNeue(
                  fontSize: 22,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    final isSelected = lang == currentLang;
                    return InkWell(
                      onTap: () {
                        context.read<SettingsViewModel>().saveSetting('appLanguage', lang);
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
                              lang,
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
      backgroundColor: Colors.black,
      shape: const Border(
        top: BorderSide(color: PhiaColors.skyBlue, width: 2.0),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLanguageHelper.translate(context, 'start_week_title', defaultText: 'START WEEK ON'),
                style: GoogleFonts.bebasNeue(
                  fontSize: 22,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 16),
              ...days.map((day) {
                final isSelected = day == currentDay;
                return InkWell(
                  onTap: () {
                    context.read<SettingsViewModel>().saveSetting('startWeekDay', day);
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
                          day,
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
                        AppLanguageHelper.translate(context, 'general_app_config', defaultText: 'GENERAL APP CONFIG'),
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
                        'CONFIGURE APP LOCALIZATION LANGUAGE AND CALENDAR HISTORY DEFAULTS.',
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
                              title: AppLanguageHelper.translate(context, 'app_language', defaultText: 'App Language'),
                              value: settingsVM.appLanguage,
                              onTap: () => _showLanguageSelector(context, settingsVM.appLanguage),
                            ),
                            _buildDivider(),
                            _buildSettingsTile(
                              title: AppLanguageHelper.translate(context, 'start_week_on', defaultText: 'Start week on'),
                              value: settingsVM.startWeekDay,
                              onTap: () => _showStartWeekSelector(context, settingsVM.startWeekDay),
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
