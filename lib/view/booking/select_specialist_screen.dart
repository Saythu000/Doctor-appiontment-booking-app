import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';

class SelectSpecialistScreen extends StatelessWidget {
  final bool isTab;
  const SelectSpecialistScreen({super.key, this.isTab = false});

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Custom Header Row (Menu, Centered KINETIC, Circular Athlete profile)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.menu, color: Colors.white, size: 24),
                      ),
                      Text(
                        'KINETIC',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 26,
                          letterSpacing: 4.0,
                          color: Colors.white,
                        ),
                      ),
                      // Desaturated circular athlete avatar profile
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.0),
                          image: const DecorationImage(
                            image: NetworkImage('https://images.unsplash.com/photo-1506126613408-eca07ce68773?q=80&w=100'),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, -20,
                              0.2126, 0.7152, 0.0722, 0, -20,
                              0.2126, 0.7152, 0.0722, 0, -20,
                              0,      0,      0,      1, 0,
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Scrollable Area
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    children: [
                      const SizedBox(height: 12),

                      // Title Area (PERFORMANCE NETWORK and SPECIALIST SELECTION)
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.38),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'PERFORMANCE NETWORK',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.38),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'SPECIALIST SELECTION',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 32,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Connect with elite trainers and medical specialists curated for your performance profile.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.38),
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Search Box & Filters Button Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Search specialists...',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.38),
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.search, color: Colors.white.withValues(alpha: 0.38), size: 16),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                              ),
                              child: Text(
                                'FILTERS',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Specialist Bento Card 1: Strength & Conditioning (Marcus)
                      _buildSpecialistBentoCard(
                        context,
                        category: 'STRENGTH & CONDITIONING',
                        name: 'COACH MARCUS',
                        specialty: 'OLYMPIC LIFTING EXPERT',
                        imageUrl: 'https://images.unsplash.com/photo-1567013127542-490d757e51fc?q=80&w=500',
                        nextAvailable: 'NEXT AVAILABLE:\nTODAY 14:00',
                        showIndicator: true,
                        isSolidSelectButton: true,
                      ),

                      const SizedBox(height: 24),

                      // Specialist Bento Card 2: Recovery Specialist (Elena)
                      _buildSpecialistBentoCard(
                        context,
                        category: 'RECOVERY SPECIALIST',
                        name: 'DR. ELENA',
                        specialty: 'PHYSICAL THERAPY',
                        imageUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?q=80&w=500',
                        nextAvailable: 'NEXT AVAILABLE:\nTOMORROW',
                        showIndicator: false,
                        isSolidSelectButton: false,
                      ),

                      const SizedBox(height: 24),

                      // Specialist Bento Card 3: Nutritionist (David Chen)
                      _buildSpecialistBentoCard(
                        context,
                        category: 'NUTRITIONIST',
                        name: 'DAVID CHEN',
                        specialty: 'METABOLIC HEALTH',
                        imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=500',
                        nextAvailable: 'NEXT AVAILABLE:\n16:30',
                        showIndicator: true,
                        isSolidSelectButton: true,
                      ),

                      const SizedBox(height: 24),

                      // Specialist Bento Card 4: Bio-Mechanics (Sarah Vance)
                      _buildSpecialistBentoCard(
                        context,
                        category: 'BIO-MECHANICS',
                        name: 'SARAH VANCE',
                        specialty: 'GAIT ANALYSIS',
                        imageUrl: 'https://images.unsplash.com/photo-1594744803329-e58b31de215f?q=80&w=500',
                        nextAvailable: 'WAITLIST ONLY',
                        showIndicator: false,
                        isSolidSelectButton: false,
                        isFull: true,
                      ),

                      const SizedBox(height: 28),

                      // Bottom Recommended Panel (Elite Performance Team)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: PhiaColors.surface,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Stack(
                          children: [
                            // Soft lightning bolt icon aligned on the right in background
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Icon(
                                Icons.bolt,
                                color: Colors.white.withValues(alpha: 0.03),
                                size: 84,
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'RECOMMENDED SPECIALIST',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withValues(alpha: 0.4),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'ELITE PERFORMANCE TEAM',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 22,
                                    color: Colors.white,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'The top 1% of our network. Specialized in peak athlete optimization and neuro-mechanical training.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.38),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // solid white button
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                  ),
                                  child: Text(
                                    'EXPLORE ELITE NETWORK',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to build the premium bento cards with overlapping category titles
  Widget _buildSpecialistBentoCard(
    BuildContext context, {
    required String category,
    required String name,
    required String specialty,
    required String imageUrl,
    required String nextAvailable,
    required bool showIndicator,
    required bool isSolidSelectButton,
    bool isFull = false,
  }) {
    Color accentColor = PhiaColors.stepGreen;
    if (category.contains('RECOVERY')) {
      accentColor = PhiaColors.skyBlue;
    } else if (category.contains('NUTRITIONIST')) {
      accentColor = PhiaColors.warningOrange;
    } else if (category.contains('BIO-MECHANICS')) {
      accentColor = PhiaColors.pulseRed;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main bordered box container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grayscale athlete portrait photo
              Container(
                width: 90,
                height: 110,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                    colorFilter: const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, -20,
                      0.2126, 0.7152, 0.0722, 0, -20,
                      0.2126, 0.7152, 0.0722, 0, -20,
                      0,      0,      0,      1, 0,
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Right side info stack
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.bebasNeue(
                        fontSize: 22,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialty,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.38),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Next available rectangular box with indicator dot
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          if (showIndicator) ...[
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              nextAvailable,
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Large SELECT / FULL CTA Button
                    isFull
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Center(
                              child: Text(
                                'FULL',
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.24),
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/booking_date_time',
                                arguments: {
                                  'name': name,
                                  'role': specialty,
                                  'accentColor': accentColor,
                                  'imageUrl': imageUrl,
                                },
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSolidSelectButton ? Colors.white : Colors.transparent,
                                border: Border.all(color: Colors.white),
                              ),
                              child: Center(
                                child: Text(
                                  'SELECT',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 13,
                                    color: isSolidSelectButton ? Colors.black : Colors.white,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Overlapping Category label positioned exactly over the top border
        Positioned(
          left: 12,
          top: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            color: Colors.black,
            child: Text(
              category,
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
