import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../core/widgets/image_helper.dart';
import '../../viewmodel/booking_viewmodel.dart';
import '../../domain/model/booking_models.dart';
import '../../core/utils/language_helper.dart';

class SelectSpecialistScreen extends StatefulWidget {
  final bool isTab;
  const SelectSpecialistScreen({super.key, this.isTab = false});

  @override
  State<SelectSpecialistScreen> createState() => _SelectSpecialistScreenState();
}

class _SelectSpecialistScreenState extends State<SelectSpecialistScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch specialists from local FHIR server on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BookingViewModel>(context, listen: false).fetchSpecialists();
    });
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
                        'DRGODLY',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 26,
                          letterSpacing: 4.0,
                          color: Colors.white,
                        ),
                      ),
                      const UserHeaderAvatar(),
                    ],
                  ),
                ),

                // Main Area
                Expanded(
                  child: Consumer<BookingViewModel>(
                    builder: (context, vm, child) {
                      return RefreshIndicator(
                        backgroundColor: PhiaColors.surface,
                        color: Colors.white,
                        onRefresh: () => vm.fetchSpecialists(),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          physics: const AlwaysScrollableScrollPhysics(),
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
                                  'MEDICAL CLINIC NETWORK',
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
                              AppLanguageHelper.translate(context, 'specialists_directory', defaultText: 'SPECIALISTS DIRECTORY'),
                              style: GoogleFonts.bebasNeue(
                                fontSize: 32,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Select from our certified physicians and clinical specialists to schedule a consultation.',
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
                                Container(
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
                              ],
                            ),

                            const SizedBox(height: 28),

                            // Dynamic loading state
                            if (vm.isSpecialistsLoading) ...[
                              _buildCyberneticLoader(),
                            ] else if (vm.specialists.isEmpty) ...[
                              _buildEmptyState(),
                            ] else ...[
                              // Map dynamic specialist items from FHIR server
                              ...vm.specialists.map((specialist) {
                                return Column(
                                  children: [
                                    _buildDynamicSpecialistCard(context, specialist),
                                    const SizedBox(height: 24),
                                  ],
                                );
                              }),
                            ],

                            const SizedBox(height: 12),

                            // Bottom Recommended Panel (DRGODLY Medical Experts)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: PhiaColors.surface,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Icon(
                                      Icons.local_hospital,
                                      color: Colors.white.withValues(alpha: 0.03),
                                      size: 84,
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'RECOMMENDED CLINICIAN',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white.withValues(alpha: 0.4),
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'DRGODLY MEDICAL EXPERTS',
                                        style: GoogleFonts.bebasNeue(
                                          fontSize: 22,
                                          color: Colors.white,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Consult with our highly qualified medical experts. Specialized in advanced diagnostics, heart care, and patient wellness.',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.white.withValues(alpha: 0.38),
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton(
                                        onPressed: () {},
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                        ),
                                        child: Text(
                                          'EXPLORE CLINICAL DIRECTORY',
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a high-fidelity cyberpunk visual loading state
  Widget _buildCyberneticLoader() {
    return Container(
      height: 150,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'INITIALIZING CLINIC DIRECTORY MATCH...',
              style: GoogleFonts.bebasNeue(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.38),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a cyberpunk empty state if no specialists are returned
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.wifi_off, color: Colors.white30, size: 32),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'NO ACTIVE PRACTITIONERS FOUND',
              style: GoogleFonts.bebasNeue(
                fontSize: 16,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Verify connection and ensure clinical directories are initialized.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.38),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a dynamic specialist card mapping FHIR data into visual layouts
  Widget _buildDynamicSpecialistCard(BuildContext context, PractitionerRoleBooking pr) {
    final detail = pr.practitionerDetail;
    final String name = detail?.fullName ?? pr.practitionerDisplay ?? 'Elite Specialist';
    final String specialty = pr.specialties.isNotEmpty ? pr.specialties.first : 'Unknown Specialty';

    // Assign categories and custom cyberpunk colors based on specialties
    String category = specialty.toUpperCase();
    Color accentColor = PhiaColors.stepGreen;
    String defaultImageUrl = 'assets/doctors/doctor_1.png'; // fall back
 
    if (category.contains('FAMILY') || category.contains('PRIMARY') || category.contains('MEDICINE') || category.contains('PRACTITIONER') || category.contains('GENERAL')) {
      category = 'PRIMARY CARE';
      accentColor = PhiaColors.stepGreen;
      defaultImageUrl = 'assets/doctors/doctor_1.png';
    } else if (category.contains('CARDIOLOGY') || category.contains('CARDIOVASCULAR') || category.contains('HEART')) {
      category = 'CARDIOLOGY';
      accentColor = PhiaColors.pulseRed;
      defaultImageUrl = 'assets/doctors/doctor_2.png';
    } else if (category.contains('ENDOCRINOLOGY') || category.contains('DIABETES') || category.contains('METABOLIC')) {
      category = 'ENDOCRINOLOGY';
      accentColor = PhiaColors.warningOrange;
      defaultImageUrl = 'assets/doctors/doctor_3.png';
    } else if (category.contains('NEUROLOGY') || category.contains('NEURO') || category.contains('BRAIN') || category.contains('COGNITIVE')) {
      category = 'NEUROLOGY';
      accentColor = PhiaColors.skyBlue;
      defaultImageUrl = 'assets/doctors/doctor_4.png';
    } else {
      category = 'CLINICAL MEDICINE';
      accentColor = Colors.white60;
      defaultImageUrl = 'assets/doctors/doctor_5.png';
    }
 
    final imageUrl = detail?.photoUrl ?? defaultImageUrl;
 
    // Availability text helper
    String nextAvailable = 'ACTIVE SHIFT CALIBRATED';
    if (pr.availability.isNotEmpty && pr.availability.first.availableTimes.isNotEmpty) {
      final times = pr.availability.first.availableTimes.first;
      final days = times.daysOfWeek.map((d) => d.toUpperCase()).join(', ');
      nextAvailable = 'AVAILABLE:\n$days\n${times.availableStartTime ?? ''} - ${times.availableEndTime ?? ''}';
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
                    image: getImageProvider(imageUrl, fallback: 'assets/doctors/doctor_1.png'),
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
                      name.toUpperCase(),
                      style: GoogleFonts.bebasNeue(
                        fontSize: 22,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialty.toUpperCase(),
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
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                    // Large SELECT CTA Button
                    GestureDetector(
                      onTap: () {
                        // Pass practitioner role details dynamically
                        Navigator.pushNamed(
                          context,
                          '/booking_date_time',
                          arguments: {
                            'specialist': pr,
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
                          color: Colors.transparent,
                          border: Border.all(color: Colors.white),
                        ),
                        child: Center(
                          child: Text(
                            'SELECT',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 13,
                              color: Colors.white,
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
