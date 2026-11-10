import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/features/auth/presentation/auth_viewmodel.dart';
import 'package:phia_flutter/features/booking/presentation/booking_viewmodel.dart';
import 'package:phia_flutter/features/profile/presentation/profile_viewmodel.dart';
import 'package:phia_flutter/features/vitals/presentation/activity_viewmodel.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _sliderController;
  Timer? _slowTimer;
  bool _showSlowLoader = false;
  bool _hasError = false;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    _sliderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _startSlowTimer();
    _checkAuthAndRedirect();
  }

  void _startSlowTimer() {
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && !_isRedirecting && !_hasError) {
        setState(() {
          _showSlowLoader = true;
        });
      }
    });
  }

  bool _isChecking = false;

  Future<void> _checkAuthAndRedirect() async {
    // "Try again" while a check is still running must not start a second one.
    if (_isChecking) return;
    _isChecking = true;
    setState(() {
      _hasError = false;
    });

    try {
      final authVM = context.read<AuthViewModel>();
      // A timeout means the server is slow or unreachable, not "signed out":
      // it throws into the catch below, which shows "Try again".
      final isAuthenticated = await authVM.checkAutoLogin().timeout(const Duration(seconds: 15));

      if (!mounted || _isRedirecting) return;

      if (!isAuthenticated && authVM.autoLoginFailedOffline) {
        throw Exception('offline');
      }

      // Only a verified session may open the app. A cached profile on its own
      // is not a session: routing on it would show a signed-out (or revoked)
      // user's health data without authentication.
      if (!isAuthenticated) {
        _redirect(AppRoutes.welcome);
        return;
      }

      final profileVM = context.read<ProfileViewModel>();
      final bookingVM = context.read<BookingViewModel>();
      final activityVM = context.read<ActivityViewModel>();
      try {
        await Future.wait([
          profileVM.fetchOrInitProfile(),
          bookingVM.fetchAppointments(),
          bookingVM.fetchSpecialists(),
          activityVM.initDashboard(),
        ]).timeout(const Duration(seconds: 12));
      } catch (_) {
        // Slow or failed preload must not lock a signed-in user out:
        // each screen loads its own data again when opened.
      }

      if (mounted) _redirect(AppRoutes.home);
    } catch (e) {
      if (mounted && !_isRedirecting) {
        setState(() {
          _hasError = true;
          _showSlowLoader = false;
        });
      }
    } finally {
      _isChecking = false;
    }
  }

  void _redirect(String route) {
    if (_isRedirecting) return;
    _isRedirecting = true;
    _slowTimer?.cancel();
    context.go(route);
  }

  @override
  void dispose() {
    _sliderController.dispose();
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F1715) : const Color(0xFFF7F9F8);
    final tileBorder = isDark ? Border.all(color: const Color(0xFF2A4A43)) : null;
    final trackColor = isDark ? const Color(0xFF2A4A43) : const Color(0xFFDDE4E2);
    final sliderColor = isDark ? const Color(0xFF5FB3A1) : const Color(0xFF1F6F5F);
    final titleColor = isDark ? const Color(0xFFF7F9F8) : const Color(0xFF1A1F1E);
    const subtitleColor = Color(0xFF5F6B68);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // State 1, 2, 3: Centered minimalist Brand Tile
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                margin: EdgeInsets.only(bottom: _hasError ? 24.0 : 0.0),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF12302B),
                  borderRadius: BorderRadius.circular(13),
                  border: tileBorder,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  'DG',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              // State 2: Sleek linear sliding indeterminate loader (appears after 1.5s)
              if (_showSlowLoader && !_hasError) ...[
                const SizedBox(height: 28),
                _buildSlidingLoader(trackColor, sliderColor),
              ],

              // State 3: Connection failure / offline recovery
              if (_hasError) ...[
                Text(
                  "Can't connect",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    'Check your internet connection and try again.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () {
                    _startSlowTimer();
                    _checkAuthAndRedirect();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: sliderColor,
                    side: BorderSide(color: sliderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: const Size(96, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: Text(
                    'Try again',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: sliderColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlidingLoader(Color trackColor, Color sliderColor) {
    return Container(
      width: 72,
      height: 2,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(1),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _sliderController,
        builder: (context, child) {
          return FractionalTranslation(
            translation: Offset(-1.0 + (_sliderController.value * 3.5), 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 72 * 0.4, // 40% width per design specification
                height: 2,
                decoration: BoxDecoration(
                  color: sliderColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
