import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';

class WorkoutLibraryScreen extends StatelessWidget {
  const WorkoutLibraryScreen({super.key});

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
                // Top Header (⚡ KINETIC and Notification Bell)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
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
                        onPressed: () {},
                        icon: const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),

                // Search Box
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.white.withValues(alpha: 0.4), size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'SEARCH WORKOUTS...',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4),
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(Icons.tune, color: Colors.white.withValues(alpha: 0.4), size: 18),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Category scroll area
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                    children: [
                      // RECOMMENDED Section
                      _buildSectionHeader('RECOMMENDED', actionText: 'VIEW ALL'),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 280,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildRecommendedCard(
                              context,
                              imageUrl: 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?q=80&w=1000',
                              chips: ['ELITE', '45 MIN'],
                              title: 'FULL BODY BLAST',
                              subtitle: 'HIGH INTENSITY STRENGTH',
                            ),
                            const SizedBox(width: 16),
                            _buildRecommendedCard(
                              context,
                              imageUrl: 'https://images.unsplash.com/photo-1518310383802-640c2de311b2?q=80&w=1000',
                              chips: ['ADVANCED', '30 MIN'],
                              title: 'CORE STABILITY',
                              subtitle: 'STABILITY & FOCUS',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // STRENGTH Section
                      _buildSectionHeader('STRENGTH', actionText: 'EXPLORE'),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildStrengthGridCard(
                              context,
                              imageUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=1000',
                              title: 'KETTLEBELL FLOW',
                              level: 'INTERMEDIATE',
                              duration: '20M',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStrengthGridCard(
                              context,
                              imageUrl: 'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?q=80&w=1000',
                              title: 'HYPERTROPHY LEGS',
                              level: 'ADVANCED',
                              duration: '60M',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // RECOVERY Section
                      _buildSectionHeader('RECOVERY'),
                      const SizedBox(height: 12),
                      _buildRecoveryTile(
                        context,
                        imageUrl: 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?q=80&w=1000',
                        category: 'RECOVERY',
                        title: 'DYNAMIC HIP FLOW',
                        duration: '15 MIN',
                        level: 'BEGINNER',
                      ),
                      const SizedBox(height: 12),
                      _buildRecoveryTile(
                        context,
                        imageUrl: 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?q=80&w=1000',
                        category: 'MOBILITY',
                        title: 'UPPER BODY RELEASE',
                        duration: '10 MIN',
                        level: 'ALL LEVELS',
                      ),

                      const SizedBox(height: 28),

                      // CARDIO Section
                      _buildSectionHeader('CARDIO'),
                      const SizedBox(height: 12),
                      _buildCardioBannerCard(
                        context,
                        imageUrl: 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?q=80&w=1000',
                        badge: 'HIGH INTENSITY',
                        title: 'HIIT SPRINTS',
                        duration: '25 MINS',
                        level: 'INTERMEDIATE',
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

  // Helper Section Header with custom thin divider line
  Widget _buildSectionHeader(String title, {String? actionText}) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.bebasNeue(
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        if (actionText != null) ...[
          const SizedBox(width: 12),
          Text(
            actionText,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ],
    );
  }

  // Helper desaturated network image box decoration with full gradient overlay
  Decoration _buildDesaturatedImageDecoration(String imageUrl, {BorderRadius? borderRadius}) {
    return BoxDecoration(
      borderRadius: borderRadius ?? BorderRadius.zero,
      color: PhiaColors.surface,
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
    );
  }

  // 1. Tall Recommended card
  Widget _buildRecommendedCard(
    BuildContext context, {
    required String imageUrl,
    required List<String> chips,
    required String title,
    required String subtitle,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/live_workout'),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Stack(
          children: [
            // Background desaturated photo
            Positioned.fill(
              child: Container(
                decoration: _buildDesaturatedImageDecoration(imageUrl),
              ),
            ),
            // Bottom Gradient Overlay for typography readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.9),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Content
            Positioned(
              left: 16,
              bottom: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: chips.map((chipText) {
                      bool isWhiteBackground = chipText == 'ELITE';
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isWhiteBackground ? Colors.white : Colors.transparent,
                          border: Border.all(
                            color: isWhiteBackground ? Colors.white : Colors.white.withValues(alpha: 0.4),
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Text(
                          chipText,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isWhiteBackground ? Colors.black : Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.bebasNeue(
                      fontSize: 24,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.5),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Strength grid cards
  Widget _buildStrengthGridCard(
    BuildContext context, {
    required String imageUrl,
    required String title,
    required String level,
    required String duration,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/live_workout'),
      child: Container(
        decoration: BoxDecoration(
          color: PhiaColors.surface,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail with Duration indicator in bottom-right corner
            SizedBox(
              height: 110,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: _buildDesaturatedImageDecoration(imageUrl),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        duration,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Text Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.bebasNeue(
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    level,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.4),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Recovery lists tiles
  Widget _buildRecoveryTile(
    BuildContext context, {
    required String imageUrl,
    required String category,
    required String title,
    required String duration,
    required String level,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/live_workout'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            // Left square photo
            Container(
              width: 58,
              height: 58,
              decoration: _buildDesaturatedImageDecoration(imageUrl),
            ),
            const SizedBox(width: 14),
            // Center Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.4),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: GoogleFonts.bebasNeue(
                      fontSize: 18,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        duration,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        level,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Right thin circular play button
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.0),
              ),
              child: const Center(
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4. Large Cardio wide banner
  Widget _buildCardioBannerCard(
    BuildContext context, {
    required String imageUrl,
    required String badge,
    required String title,
    required String duration,
    required String level,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/live_workout'),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: _buildDesaturatedImageDecoration(imageUrl),
              ),
            ),
            // Soft overlay gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Card details
            Positioned(
              left: 16,
              top: 16,
              bottom: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top left white pill badge with dark text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  // Title and details stacked
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.bebasNeue(
                          fontSize: 28,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              duration,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            level,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: Colors.white.withValues(alpha: 0.5),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
