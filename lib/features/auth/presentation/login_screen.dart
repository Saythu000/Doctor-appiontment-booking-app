import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phia_flutter/core/theme/colors.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Sign-in is OAuth 2.0 + PKCE in a Chrome Custom Tab only (see AuthViewModel.loginWithPKCE).

  /// True from the tap until we navigate away (covers loading the user's data
  /// after sign-in too), so the button can't start a second sign-in.
  bool _busy = false;

  Future<void> _handlePkceLogin(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final activityVM = Provider.of<ActivityViewModel>(context, listen: false);
    final profileVM = Provider.of<ProfileViewModel>(context, listen: false);
    final bookingVM = Provider.of<BookingViewModel>(context, listen: false);
    final navigator = Navigator.of(context);

    final success = await authVM.loginWithPKCE();
    if (!mounted) return;
    if (!success) setState(() => _busy = false);

    if (success) {
      activityVM.resetState();
      profileVM.resetState();
      
      // Parallelize complete clinical and booking sync. Login has already
      // succeeded, so a failed or slow preload must not strand the user here.
      try {
        await Future.wait([
          profileVM.fetchOrInitProfile(),
          activityVM.initDashboard(),
          bookingVM.fetchAppointments(),
          bookingVM.fetchSpecialists(),
        ]).timeout(const Duration(seconds: 15));
      } catch (_) {
        // Screens reload their own data when opened.
      }
      if (!mounted) return;

      final profile = profileVM.currentProfile;
      final bool hasProfile = profile != null &&
          profile.name != null &&
          profile.name!.isNotEmpty &&
          profile.name!.first.givenName.isNotEmpty;

      if (hasProfile) {
        navigator.pushNamedAndRemoveUntil('/dashboard', (route) => false);
      } else {
        navigator.pushNamedAndRemoveUntil('/profile_setup', (route) => false);
      }
    }
    // On failure the error is shown in the card above the button (not also
    // as a snackbar, which showed the same message twice).
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Icon & Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: PhiaColors.primaryLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: PhiaColors.primary.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: const Icon(
                          Icons.medical_services_rounded,
                          color: PhiaColors.primary,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'DrGodly',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: PhiaColors.navyAnchor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Secure Clinical Patient & Wearable Portal',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: PhiaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // Card Container
                Container(
                  decoration: BoxDecoration(
                    color: PhiaColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: PhiaColors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Banner
                      Container(
                        color: PhiaColors.navyAnchor,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Patient Authentication',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const Icon(Icons.lock_rounded, color: Colors.white70, size: 16),
                          ],
                        ),
                      ),

                      // Card Body
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign in using your unified DrGodly IAM identity account to access your medical records, appointments, and vitals.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.5,
                                color: PhiaColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Error Banner
                            if (authVM.errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: PhiaColors.pulseRedLight,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: PhiaColors.pulseRed.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: PhiaColors.pulseRed, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        authVM.errorMessage!,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: PhiaColors.pulseRed,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Single Authoritative Action: DrGodly IAM OAuth PKCE
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PhiaColors.navyAnchor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: PhiaColors.primary, width: 1.5),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              ),
                              onPressed: (authVM.isLoading || _busy) ? null : () => _handlePkceLogin(context),
                              child: (authVM.isLoading || _busy)
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.shield_outlined, color: PhiaColors.primaryLight, size: 20),
                                        const SizedBox(width: 10),
                                        Flexible(
                                          child: Text(
                                            'Sign In with DrGodly IAM',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
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

                const SizedBox(height: 28),

                // Trust Badge / Footer
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_user_rounded, color: PhiaColors.activeGreen, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Secure sign-in with your DrGodly account',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: PhiaColors.textMuted,
                        ),
                      ),
                    ],
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
