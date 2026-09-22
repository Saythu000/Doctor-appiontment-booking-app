import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../viewmodel/auth_viewmodel.dart';
import '../../viewmodel/profile_viewmodel.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final List<String> _loadingStatuses = [
    'Connecting securely...',
    'Syncing clinical modules...',
    'Loading patient profile...',
    'Structuring workspace...',
  ];

  String _currentStatus = 'Connecting securely...';
  Timer? _statusTimer;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    _startStatusRotation();
    _checkAuthAndRedirect();
  }

  void _startStatusRotation() {
    int statusIndex = 0;
    _statusTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (statusIndex < _loadingStatuses.length - 1) {
        statusIndex++;
        setState(() {
          _currentStatus = _loadingStatuses[statusIndex];
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _checkAuthAndRedirect() async {
    final authVM = context.read<AuthViewModel>();
    final isAuthenticated = await authVM.checkAutoLogin();

    await Future.delayed(const Duration(seconds: 4));

    if (mounted && !_isRedirecting) {
      _isRedirecting = true;
      if (isAuthenticated) {
        final profileVM = context.read<ProfileViewModel>();
        await profileVM.fetchOrInitProfile();
        if (mounted) {
          final profile = profileVM.currentProfile;
          final bool hasProfile = profile != null &&
              profile.name != null &&
              profile.name!.isNotEmpty &&
              profile.name!.first.givenName.isNotEmpty;

          if (hasProfile) {
            Navigator.pushReplacementNamed(context, '/dashboard');
          } else {
            Navigator.pushReplacementNamed(context, '/profile_setup');
          }
        }
      } else {
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Centered Clinical Card & Brand Identity
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: PhiaColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: PhiaColors.borderSubtle, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: PhiaColors.navyAnchor.withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: PhiaColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.medical_services_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'DRGODLY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        color: PhiaColors.navyAnchor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CLINICAL TELEHEALTH & VITALS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: PhiaColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: PhiaColors.activeGreenBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PhiaColors.activeGreen.withOpacity(0.3)),
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
                          const SizedBox(width: 6),
                          Text(
                            'HIPAA Compliant · FHIR Ready',
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
              ),

              const Spacer(),

              // Bottom Loader & Status
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(PhiaColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentStatus.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: PhiaColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
