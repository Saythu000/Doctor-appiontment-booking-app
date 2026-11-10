import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/brand.dart';
import 'package:phia_flutter/core/widgets/motion.dart';
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

class _SplashScreenState extends State<SplashScreen> {
  Timer? _slowTimer;

  /// Shown after a few seconds so a slow network doesn't look frozen.
  bool _showSlowLoader = false;
  bool _hasError = false;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    _startSlowTimer();
    _checkAuthAndRedirect();
  }

  void _startSlowTimer() {
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 4), () {
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
    _slowTimer?.cancel();
    super.dispose();
  }

  void _retry() {
    setState(() => _showSlowLoader = false);
    _startSlowTimer();
    _checkAuthAndRedirect();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBarsFor(context),
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Same logo, size and place as the Android launch screen,
                  // so the hand-over is seamless; then it gently "beats".
                  const Heartbeat(child: BrandMark(size: 96)),
                  const SizedBox(height: AppSpacing.xl),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 150),
                    child: Text('DrGodly', style: context.text.headlineMedium),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 300),
                    child: Text(
                      'Your doctor and your health, in one place',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AnimatedSwitcher(
                    duration: AppMotion.medium,
                    switchInCurve: AppMotion.emphasizedDecelerate,
                    child: _hasError ? _buildError(context) : _buildLoading(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Semantics(
      key: const ValueKey('loading'),
      liveRegion: true,
      label: _showSlowLoader ? 'Still connecting' : 'Loading',
      child: Column(
        children: [
          const PulseLine(),
          const SizedBox(height: AppSpacing.sm),
          AnimatedOpacity(
            opacity: _showSlowLoader ? 1 : 0,
            duration: AppMotion.medium,
            child: Text('Still connecting…', style: context.text.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: const ValueKey('error'),
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: colors.border),
      ),
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: colors.textSecondary, size: 32),
            const SizedBox(height: AppSpacing.md),
            Text("Can't connect right now", style: context.text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Check your internet connection and try again.',
              style: context.text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.secondary(label: 'Try again', icon: Icons.refresh_rounded, onPressed: _retry),
          ],
        ),
      ),
    );
  }
}
