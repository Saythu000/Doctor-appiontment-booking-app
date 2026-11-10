import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phia_flutter/core/theme/colors.dart';
import 'package:phia_flutter/features/settings/presentation/settings_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:provider/provider.dart';

class VitalsScreen extends StatelessWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activityVM = context.watch<ActivityViewModel>();
    final settingsVM = context.watch<SettingsViewModel>();

    final int steps = activityVM.currentSteps;

    final String stepsStr = steps.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    double displayWeight = activityVM.userWeight;
    String weightUnitLabel = 'KG';
    if (settingsVM.weightUnit == 'lbs') {
      displayWeight = activityVM.userWeight * 2.20462;
      weightUnitLabel = 'LBS';
    }

    // BMI Calculations
    double bmi = 0.0;
    String bmiClassification = 'Pending';
    Color bmiColor = const Color(0xFF64748B);
    Color bmiBg = const Color(0xFFF1F5F9);
    if (activityVM.userHeight > 0 && activityVM.userWeight > 0) {
      final double heightM = activityVM.userHeight / 100.0;
      bmi = activityVM.userWeight / (heightM * heightM);
      if (bmi < 18.5) {
        bmiClassification = 'Underweight';
        bmiColor = PhiaColors.primary;
        bmiBg = PhiaColors.primaryLight;
      } else if (bmi < 25.0) {
        bmiClassification = 'Optimal';
        bmiColor = PhiaColors.activeGreen;
        bmiBg = PhiaColors.activeGreenBg;
      } else if (bmi < 30.0) {
        bmiClassification = 'Overweight';
        bmiColor = PhiaColors.amberWarning;
        bmiBg = const Color(0xFFFEF3C7);
      } else {
        bmiClassification = 'Obese';
        bmiColor = PhiaColors.pulseRed;
        bmiBg = PhiaColors.pulseRedLight;
      }
    }

    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.primary,
        elevation: 0,
        title: Text(
          'Your Vitals',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          children: [
            // 2x2 Bento Stats
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _buildCleanBentoCard(
                  icon: Icons.health_and_safety_rounded,
                  iconColor: bmiColor,
                  iconBg: bmiBg,
                  label: bmi > 0 ? 'BMI ($bmiClassification)' : 'BMI',
                  value: bmi > 0 ? bmi.toStringAsFixed(1) : '--',
                ),
                _buildCleanBentoCard(
                  icon: Icons.monitor_weight_rounded,
                  iconColor: PhiaColors.primary,
                  iconBg: PhiaColors.primaryLight,
                  label: 'Body Weight',
                  value: displayWeight > 0 ? '${displayWeight.toStringAsFixed(1)} $weightUnitLabel' : '--',
                ),
                _buildCleanBentoCard(
                  icon: Icons.directions_walk_rounded,
                  iconColor: PhiaColors.navyAnchor,
                  iconBg: PhiaColors.primaryLight,
                  label: 'Daily Steps',
                  value: stepsStr,
                ),
                _buildCleanBentoCard(
                  icon: Icons.straighten_rounded,
                  iconColor: const Color(0xFF4BAAE5),
                  iconBg: PhiaColors.primaryLight,
                  label: 'Distance Walked',
                  value: '${activityVM.dashboardDistanceKm.toStringAsFixed(2)} km',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // TODAY'S HEART RATE (real values from Health Connect only)
            _buildNavyCard(
              title: "Today's Heart Rate",
              actionWidget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PhiaColors.pulseRedLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  activityVM.dashboardHr > 0 ? '${activityVM.dashboardHr.toInt()} BPM RESTING' : 'NO DATA',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: PhiaColors.pulseRed,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMiniHeartMetric('Min HR', activityVM.dashboardMinHr != null ? '${activityVM.dashboardMinHr} bpm' : '--', const Color(0xFF15803D)),
                        Container(width: 1, height: 28, color: PhiaColors.borderSubtle),
                        _buildMiniHeartMetric('Resting HR', activityVM.dashboardHr > 0 ? '${activityVM.dashboardHr.toInt()} bpm' : '--', PhiaColors.navyAnchor),
                        Container(width: 1, height: 28, color: PhiaColors.borderSubtle),
                        _buildMiniHeartMetric('Max HR', activityVM.dashboardMaxHr != null ? '${activityVM.dashboardMaxHr} bpm' : '--', PhiaColors.pulseRed),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // SLEEP STAGES (real stage minutes only)
            _buildNavyCard(
              title: 'Sleep Architecture Stages',
              actionWidget: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PhiaColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  activityVM.currentSleep > 0 ? '${activityVM.currentSleep.toStringAsFixed(1)}H SLEEP' : 'PENDING SYNC',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: PhiaColors.navyAnchor,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: activityVM.currentSleep <= 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const Icon(Icons.bedtime_outlined, size: 36, color: PhiaColors.textMuted),
                            const SizedBox(height: 8),
                            Text(
                              'No Sleep Recorded Yet Today',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: PhiaColors.navyAnchor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Wear your watch to bed and let its app sync to Health Connect to see your sleep here.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: PhiaColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildSleepStages(activityVM),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Sleep stage bar. Only real stage minutes from Health Connect are shown;
  /// when the watch reports total sleep without stages we say so instead of
  /// inventing a split.
  Widget _buildSleepStages(ActivityViewModel activityVM) {
    String formatM(int m) {
      final h = m ~/ 60;
      final min = m % 60;
      return h > 0 ? '${h}h ${min}m' : '${min}m';
    }

    final deep = activityVM.deepSleepMinutes;
    final light = activityVM.lightSleepMinutes;
    final rem = activityVM.remSleepMinutes;
    final awake = activityVM.awakeMinutes;
    final sum = deep + light + rem + awake;
    final totalMin = (activityVM.currentSleep * 60).round();
    final labelStyle = GoogleFonts.inter(
      fontSize: 11,
      color: PhiaColors.textSecondary,
      fontWeight: FontWeight.w600,
    );

    if (sum <= 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total sleep: ${formatM(totalMin)}', style: labelStyle.copyWith(fontSize: 13, color: PhiaColors.navyAnchor)),
          const SizedBox(height: 4),
          Text(
            'Your watch did not report sleep stages for this night.',
            style: GoogleFonts.inter(fontSize: 11, color: PhiaColors.textMuted),
          ),
        ],
      );
    }

    Widget segment(int minutes, Color color) => minutes <= 0
        ? const SizedBox.shrink()
        : Expanded(flex: minutes, child: Container(color: color));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _buildSleepStageLegend('Deep', const Color(0xFF1E3A8A)),
            const SizedBox(width: 12),
            _buildSleepStageLegend('Light', const Color(0xFF60A5FA)),
            const SizedBox(width: 12),
            _buildSleepStageLegend('REM', const Color(0xFF818CF8)),
            const SizedBox(width: 12),
            _buildSleepStageLegend('Awake', const Color(0xFFFCA5A5)),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                segment(deep, const Color(0xFF1E3A8A)),
                segment(light, const Color(0xFF60A5FA)),
                segment(rem, const Color(0xFF818CF8)),
                segment(awake, const Color(0xFFFCA5A5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Deep: ${formatM(deep)}', style: labelStyle),
            Text('Light: ${formatM(light)}', style: labelStyle),
            Text('REM: ${formatM(rem)}', style: labelStyle),
          ],
        ),
      ],
    );
  }

  Widget _buildNavyCard({
    required String title,
    required Widget child,
    Widget? actionWidget,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PhiaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhiaColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: PhiaColors.navyAnchor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                if (actionWidget != null) actionWidget,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildCleanBentoCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PhiaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhiaColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: PhiaColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: PhiaColors.navyAnchor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniHeartMetric(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: PhiaColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSleepStageLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: PhiaColors.textSecondary,
          ),
        ),
      ],
    );
  }

}
