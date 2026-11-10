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

  /// Signed in; now loading the user's profile and appointments.
  bool _loadingAccount = false;

  Future<void> _handlePkceLogin(BuildContext context) async {
    if (_busy) return;
    setState(() => _busy = true);
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final activityVM = Provider.of<ActivityViewModel>(context, listen: false);
    final profileVM = Provider.of<ProfileViewModel>(context, listen: false);
    final bookingVM = Provider.of<BookingViewModel>(context, listen: false);
    final router = GoRouter.of(context);

    final success = await authVM.loginWithPKCE();
    if (!mounted) return;
    if (!success) setState(() => _busy = false);

    if (success) {
      setState(() => _loadingAccount = true);
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
        router.go(AppRoutes.home);
      } else {
        router.go(AppRoutes.profileSetup);
      }
    }
    // On failure the error is shown in the card above the button (not also
    // as a snackbar, which showed the same message twice).
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final colors = context.colors;
    final busy = authVM.isLoading || _busy;
    final error = busy ? null : authVM.errorMessage;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemBarsFor(context),
      child: Scaffold(
        backgroundColor: colors.background,
        // Back to the welcome slides when opened from there.
        appBar: Navigator.of(context).canPop() ? AppBar(backgroundColor: Colors.transparent) : null,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - AppSpacing.xxl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FadeSlideIn(child: Center(child: BrandMark())),
                        const SizedBox(height: AppSpacing.xl),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 80),
                          child: Semantics(
                            header: true,
                            child: Text(
                              'Sign in to DrGodly',
                              textAlign: TextAlign.center,
                              style: context.text.headlineSmall,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 140),
                          child: Text(
                            'See your appointments, visit summaries and vitals. '
                            'New to DrGodly? You can create an account on the next page.',
                            textAlign: TextAlign.center,
                            style: context.text.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AnimatedSize(
                                duration: AppMotion.medium,
                                curve: AppMotion.emphasized,
                                child: error == null ? const SizedBox(width: double.infinity) : _ErrorBanner(message: error),
                              ),
                              AppButton(
                                label: 'Continue with DrGodly account',
                                icon: Icons.lock_rounded,
                                isLoading: busy,
                                onPressed: () => _handlePkceLogin(context),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AnimatedSwitcher(
                                duration: AppMotion.medium,
                                child: Text(
                                  _loadingAccount
                                      ? 'Signed in. Setting up your account…'
                                      : busy
                                          ? 'Finish signing in on the secure page that opened.'
                                          : '',
                                  key: ValueKey('$_loadingAccount$busy'),
                                  textAlign: TextAlign.center,
                                  style: context.text.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        const FadeSlideIn(delay: Duration(milliseconds: 260), child: _TrustNote()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final danger = context.colors.danger;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: danger.background, borderRadius: AppRadius.mdAll),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: danger.foreground, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(message, style: context.text.bodyMedium!.copyWith(color: danger.foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explains, in plain words, why this sign-in is safe.
class _TrustNote extends StatelessWidget {
  const _TrustNote();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget row(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: colors.success.foreground),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(text, style: context.text.bodySmall!.copyWith(color: colors.textSecondary))),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          row(Icons.verified_user_rounded, 'Sign-in happens on a secure DrGodly page in your browser.'),
          row(Icons.password_rounded, 'This app never sees your password.'),
          row(Icons.https_rounded, 'Your health data travels over encrypted connections.'),
        ],
      ),
    );
  }
}
