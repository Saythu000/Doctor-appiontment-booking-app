import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../viewmodel/profile_viewmodel.dart';
import '../../viewmodel/activity_viewmodel.dart';

class CompleteScreen extends StatelessWidget {
  const CompleteScreen({super.key});

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PhiaColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PhiaColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PhiaColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: PhiaColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: PhiaColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PhiaColors.navyAnchor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileVM = Provider.of<ProfileViewModel>(context);
    final activityVM = Provider.of<ActivityViewModel>(context);

    // Extract dynamic patient info
    final String givenName = profileVM.currentProfile?.name?.firstOrNull?.givenName ?? '';
    final String familyName = profileVM.currentProfile?.name?.firstOrNull?.familyName ?? '';
    final String displayName = (givenName.isEmpty && familyName.isEmpty)
        ? (profileVM.currentProfile?.primaryName.isNotEmpty == true
            ? profileVM.currentProfile!.primaryName
            : 'Patient')
        : '$givenName $familyName'.trim();

    final String gender = (profileVM.currentProfile?.gender != null && profileVM.currentProfile!.gender!.isNotEmpty)
        ? profileVM.currentProfile!.gender!.toUpperCase()
        : 'MALE';
    final String heightStr = activityVM.userHeight > 0
        ? '${activityVM.userHeight.toStringAsFixed(0)} cm'
        : '--';
    final String weightStr = activityVM.userWeight > 0
        ? '${activityVM.userWeight.toStringAsFixed(1)} kg'
        : '--';

    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/app_logo.jpeg',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: PhiaColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.medical_services_rounded, color: PhiaColors.primary, size: 16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'DrGodly',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: PhiaColors.navyAnchor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: PhiaColors.activeGreenBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PhiaColors.activeGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: PhiaColors.activeGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Profile Ready',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    // Success Icon and Circle
                    Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: PhiaColors.activeGreenBg,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: PhiaColors.activeGreen.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF15803D),
                            size: 52,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Success Title & Subtitle
                    Text(
                      "You're All Set!",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: PhiaColors.navyAnchor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Your clinical profile is fully configured. Your biometric telemetry, doctor appointments, and medical vitals are synchronized.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: PhiaColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Patient Summary Card
                    Container(
                      decoration: BoxDecoration(
                        color: PhiaColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PhiaColors.borderSubtle),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            color: PhiaColors.navyAnchor,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Patient Profile Summary',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const Icon(Icons.verified_rounded, color: Colors.white70, size: 18),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildSummaryItem('Name', displayName, Icons.person_rounded)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildSummaryItem('Gender', gender, Icons.wc_rounded)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _buildSummaryItem('Height', heightStr, Icons.height_rounded)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildSummaryItem('Weight', weightStr, Icons.monitor_weight_rounded)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: PhiaColors.surface,
                border: const Border(top: BorderSide(color: PhiaColors.borderSubtle)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PhiaColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 52),
                    shadowColor: PhiaColors.primary.withValues(alpha: 0.3),
                  ),
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Go to Dashboard',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
