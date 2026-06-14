import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
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
    // Start verification in parallel with splash animation
    final authVM = context.read<AuthViewModel>();
    final isAuthenticated = await authVM.checkAutoLogin();

    // Maintain splash screen visibility for at least 5 seconds for visual branding
    await Future.delayed(const Duration(seconds: 5));

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
      body: Stack(
        children: [
          // Dot Matrix Background Grid overlay
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Centered logo container & Brand identity
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Image.asset(
                          'assets/app_logo.jpeg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[900],
                            child: const Icon(Icons.broken_image, color: Colors.white24, size: 48),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'DRGODLY',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 36,
                          letterSpacing: 6.0,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PERSONAL HEALTH ENCLAVE',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Bottom Loader Segment
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _currentStatus.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white38,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
