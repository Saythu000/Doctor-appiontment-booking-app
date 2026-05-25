import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          // 1. High-Contrast Monochromatic Athlete Hero Background
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                // Deep Grayscale + Dramatic Low-key reduction (brightness scale ~0.4)
                0.2126 * 0.4, 0.7152 * 0.4, 0.0722 * 0.4, 0, 0,
                0.2126 * 0.4, 0.7152 * 0.4, 0.0722 * 0.4, 0, 0,
                0.2126 * 0.4, 0.7152 * 0.4, 0.0722 * 0.4, 0, 0,
                0,            0,            0,            1, 0,
              ]),
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuA5mZURGJxSO32Ypsr7S3o8c2cojisp0sbAzQtuhY2iF3XvdGQcuPwr2dnMwaTB7faiB4DjnjJg2jsgTOJOb4BXGykCADAwp__4EhMKyDp3eIXHMT2uu81y-cKMCrRhJNYexGwU89LQogAD6d-jp3C6GaHu-YxWc9qDep83A4F-BzNWLRwTJc0v4rt6I_JV5guTWe1cvROxx8NvTIcuSQrX36UiTvK1JhlOgcovpIIBHgzHH0ldWNDmXXy-gN__L7yclh39nRTs_pvo',
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(color: Colors.black);
                },
                errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
              ),
            ),
          ),

          // 2. Linear Ambient Shader to ensure maximum contrast for bottom text overlays
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.98),
                  ],
                ),
              ),
            ),
          ),

          // 3. Signature Nothing OS Dot Matrix grid overlay
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          // 4. Main Scrolling Content Container (prevents any overflows on small devices)
          SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Fixed Brand App Bar Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bolt, color: Colors.white, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'KINETIC',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 24,
                                    letterSpacing: 4.0,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.notifications_none, color: Colors.white70),
                              onPressed: () {},
                            )
                          ],
                        ),
                      ),

                      // Bottom Content Panel wrapped inside clean entrance fade animations
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Technical Capsule Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                  borderRadius: BorderRadius.circular(30),
                                  color: Colors.black.withValues(alpha: 0.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'MISSION V.1.0',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2.0,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Hero Title Text in massive condensed typography
                              Text(
                                'PRECISION',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 64,
                                  height: 0.9,
                                  letterSpacing: -1.0,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'ENGINEERING',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 64,
                                  height: 0.9,
                                  letterSpacing: -1.0,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'FOR ATHLETES. START YOUR MISSION.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.5,
                                  color: Colors.white38,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // 1px Technical Divider
                              Container(
                                width: double.infinity,
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              const SizedBox(height: 24),

                              // Asymmetrical Actions: solid white rectangle button left-aligned
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  minimumSize: const Size(180, 56),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero, // Flat corners
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.pushNamed(context, '/profile_setup');
                                },
                                child: Text(
                                  'GET STARTED',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Description Paragraph below the button
                              Text(
                                'Join the elite circle of data-driven performance. Kinetic transforms biological feedback into athletic superiority.',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white54,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
