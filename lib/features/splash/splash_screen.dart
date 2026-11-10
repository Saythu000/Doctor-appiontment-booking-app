import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phia_flutter/app/app_routes.dart';
import 'package:phia_flutter/core/theme/app_tokens.dart';
import 'package:phia_flutter/core/theme/theme_extensions.dart';
import 'package:phia_flutter/core/widgets/app_button.dart';
import 'package:phia_flutter/core/widgets/brand.dart';
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
  /// Length of the brand intro. Navigation waits for it (and for the login
  /// check, whichever takes longer), so the intro always plays in full.
  static const _introLength = Duration(milliseconds: 4500);

  /// With "Remove animations" on there is nothing to watch: shorter hold.
  static const _reducedIntroLength = Duration(milliseconds: 1500);

  late final AnimationController _intro =
      AnimationController(vsync: this, duration: _introLength);
  Future<void> _introDone = Future<void>.value();
  bool _introStarted = false;

  Timer? _slowTimer;

  /// Shown when loading runs well past the intro, so it doesn't look frozen.
  bool _showSlowLoader = false;
  bool _hasError = false;
  bool _isRedirecting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_introStarted) return;
    _introStarted = true;
    final reduced = AppMotion.reduced(context);
    if (reduced) {
      _intro.value = 1;
      _introDone = Future<void>.delayed(_reducedIntroLength);
    } else {
      _introDone = _intro.forward().orCancel.catchError((_) {});
    }
    _startSlowTimer();
    _checkAuthAndRedirect();
  }

  void _startSlowTimer() {
    _slowTimer?.cancel();
    _slowTimer = Timer(_introLength + const Duration(seconds: 3), () {
      if (mounted && !_isRedirecting && !_hasError) {
        setState(() => _showSlowLoader = true);
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
      final isAuthenticated =
          await authVM.checkAutoLogin().timeout(const Duration(seconds: 15));

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
      // Let the intro finish before showing the offline card.
      await _introDone;
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

  Future<void> _redirect(String route) async {
    if (_isRedirecting) return;
    _isRedirecting = true;
    await _introDone;
    _slowTimer?.cancel();
    if (mounted) context.go(route);
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _intro.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _showSlowLoader = false);
    _startSlowTimer();
    _checkAuthAndRedirect();
  }

  /// Progress of the intro between [begin] and [end] (fractions of 4.5 s).
  double _phase(double begin, double end, [Curve curve = Curves.linear]) =>
      curve.transform(((_intro.value - begin) / (end - begin)).clamp(0.0, 1.0));

  /// Two heartbeat pulses ("lub-dub, lub-dub") between 0.2 s and 1.2 s.
  double get _beatScale {
    final t = _phase(0.04, 0.27);
    if (t <= 0 || t >= 1) return 1;
    // Two bumps, the second softer.
    final beat1 =
        math.max(0.0, math.sin(t * 2 * math.pi * 2)) * (t < 0.5 ? 0.08 : 0.05);
    return 1 + beat1;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Logo size and place match the Android launch screen at the start
    // (about 120dp, exact centre), so the hand-over is seamless.
    const logoSize = 96.0;
    const startScale = 1.25;
    const settledLift = 96.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBarsFor(context),
      child: Scaffold(
        backgroundColor: colors.background,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final centreY = constraints.maxHeight / 2;
            return AnimatedBuilder(
              animation: _intro,
              builder: (context, _) {
                final settle = _phase(0.24, 0.42, AppMotion.emphasized);
                final logoCentre = centreY - settledLift * settle;
                final scale =
                    (startScale + (1 - startScale) * settle) * _beatScale;
                final nameIn =
                    _phase(0.38, 0.52, AppMotion.emphasizedDecelerate);
                final taglineIn =
                    _phase(0.45, 0.60, AppMotion.emphasizedDecelerate);
                final lineIn = _phase(0.29, 0.40);

                return Stack(
                  children: [
                    // Ripples spreading from the logo with each heartbeat.
                    for (final (begin, end) in const [
                      (0.04, 0.34),
                      (0.15, 0.45)
                    ])
                      _Ripple(
                        centre: Offset(constraints.maxWidth / 2, logoCentre),
                        progress: _phase(begin, end, Curves.easeOut),
                        color: colors.primary,
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: logoCentre - logoSize / 2,
                      child: Center(
                        child: Transform.scale(
                            scale: scale,
                            child: const BrandMark(size: logoSize)),
                      ),
                    ),
                    Positioned(
                      left: AppSpacing.xl,
                      right: AppSpacing.xl,
                      top: centreY - settledLift + logoSize / 2 + AppSpacing.xl,
                      bottom: 0,
                      // Scrolls if a large text size makes the offline card
                      // taller than the space left on a small phone.
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.paddingOf(context).bottom +
                                AppSpacing.lg),
                        child: Column(
                          children: [
                            _Reveal(
                              progress: nameIn,
                              child: Text('DrGodly',
                                  style: context.text.headlineMedium),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            _Reveal(
                              progress: taglineIn,
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
                              child: _hasError
                                  ? _buildError(context)
                                  : Opacity(
                                      opacity: lineIn,
                                      child: _buildLoading(context)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Semantics(
      key: const ValueKey('loading'),
      liveRegion: true,
      label: _showSlowLoader ? 'Still connecting' : 'Loading DrGodly',
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
            Text("Can't connect right now",
                style: context.text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Check your internet connection and try again.',
              style: context.text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.secondary(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: _retry),
          ],
        ),
      ),
    );
  }
}

/// One soft ring growing out of the logo and fading away.
class _Ripple extends StatelessWidget {
  final Offset centre;
  final double progress;
  final Color color;

  const _Ripple(
      {required this.centre, required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return const SizedBox.shrink();
    final radius = 60 + 110 * progress;
    return Positioned(
      left: centre.dx - radius,
      top: centre.dy - radius,
      child: IgnorePointer(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: color.withValues(alpha: 0.35 * (1 - progress)),
                width: 2),
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts text into place as [progress] goes from 0 to 1.
class _Reveal extends StatelessWidget {
  final double progress;
  final Widget child;
  const _Reveal({required this.progress, required this.child});

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: progress,
        child: Transform.translate(
            offset: Offset(0, 10 * (1 - progress)), child: child),
      );
}
