import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/image_helper.dart';
import '../../viewmodel/booking_viewmodel.dart';
import '../../domain/model/booking_models.dart';

class SelectSpecialistScreen extends StatefulWidget {
  final bool isTab;
  const SelectSpecialistScreen({super.key, this.isTab = false});

  @override
  State<SelectSpecialistScreen> createState() => _SelectSpecialistScreenState();
}

class _SelectSpecialistScreenState extends State<SelectSpecialistScreen> {
  String _selectedSpecialty = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BookingViewModel>(context, listen: false).fetchSpecialists();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookingVM = Provider.of<BookingViewModel>(context);
    final navArgs = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final bool intakeCompleted = navArgs?['intakeCompleted'] == true;
    final int? passedIntakeId = navArgs?['intakeId'] as int?;
    final dynamic passedClinicalReport = navArgs?['clinicalReport'];

    // Dynamically derive specialties from onboarded doctors
    final Set<String> dynamicSet = {};
    for (final sp in bookingVM.specialists) {
      for (final s in sp.specialties) {
        final clean = s.replaceAll(RegExp(r'\(SPECIALTY\)', caseSensitive: false), '').trim().toUpperCase();
        if (clean.isNotEmpty) {
          dynamicSet.add(clean);
        }
      }
    }
    final sortedSpecialties = dynamicSet.toList()..sort();
    final specialties = ['ALL', ...sortedSpecialties];

    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.primary,
        elevation: 0,
        automaticallyImplyLeading: !widget.isTab,
        leading: widget.isTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        centerTitle: true,
        title: Text(
          'Find a Specialist',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (intakeCompleted)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Clinical intake completed. Select a specialist to schedule your consultation.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: PhiaColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PhiaColors.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                  style: GoogleFonts.inter(fontSize: 14, color: PhiaColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search doctor name, specialty, condition...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: PhiaColors.textMuted),
                    icon: const Icon(Icons.search, color: PhiaColors.primary, size: 20),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Specialty Filter Chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: specialties.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final s = specialties[idx];
                  final activeSpecialty = specialties.contains(_selectedSpecialty) ? _selectedSpecialty : 'ALL';
                  final isSelected = activeSpecialty == s;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedSpecialty = s;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? PhiaColors.navyAnchor : PhiaColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? PhiaColors.navyAnchor : PhiaColors.borderSubtle,
                        ),
                      ),
                      child: Text(
                        s,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : PhiaColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Doctor List Area
            Expanded(
              child: Consumer<BookingViewModel>(
                builder: (context, vm, child) {
                  if (vm.isSpecialistsLoading && vm.specialists.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: PhiaColors.primary,
                        strokeWidth: 2.5,
                      ),
                    );
                  }

                  // Filter specialists by query & category
                  final activeFilter = specialties.contains(_selectedSpecialty) ? _selectedSpecialty : 'ALL';
                  final filtered = vm.specialists.where((sp) {
                    final name = sp.practitionerDetail?.fullName ?? sp.practitionerDisplay ?? '';
                    final specialty = sp.specialties.isNotEmpty ? sp.specialties.first : '';
                    final matchesQuery = _searchQuery.isEmpty ||
                        name.toLowerCase().contains(_searchQuery) ||
                        specialty.toLowerCase().contains(_searchQuery);

                    if (!matchesQuery) return false;
                    if (activeFilter == 'ALL') return true;

                    return sp.specialties.any((s) {
                      final clean = s.replaceAll(RegExp(r'\(SPECIALTY\)', caseSensitive: false), '').trim().toUpperCase();
                      return clean == activeFilter || clean.contains(activeFilter);
                    });
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: PhiaColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            'No specialists found',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: PhiaColors.navyAnchor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try selecting a different specialty or search term.',
                            style: GoogleFonts.inter(fontSize: 13, color: PhiaColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: PhiaColors.primary,
                    onRefresh: () => vm.fetchSpecialists(),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        return _buildCleanDoctorCard(
                          context,
                          filtered[idx],
                          intakeCompleted: intakeCompleted,
                          intakeId: passedIntakeId,
                          clinicalReport: passedClinicalReport,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanDoctorCard(
    BuildContext context,
    PractitionerRoleBooking pr, {
    bool intakeCompleted = false,
    int? intakeId,
    dynamic clinicalReport,
  }) {
    final detail = pr.practitionerDetail;
    final String name = detail?.fullName ?? pr.practitionerDisplay ?? 'Clinical Specialist';
    final rawSpecialty = pr.specialties.isNotEmpty ? pr.specialties.first : 'General Practitioner';
    final String specialty = rawSpecialty.replaceAll(RegExp(r'\(SPECIALTY\)', caseSensitive: false), '').trim();
    final imageUrl = detail?.photoUrl ?? 'assets/doctors/doctor_1.png';

    // Badge styling based on specialty
    Color badgeColor = PhiaColors.navyAnchor;
    Color badgeBg = PhiaColors.primaryLight;
    if (specialty.toUpperCase().contains('CARDIO')) {
      badgeColor = PhiaColors.pulseRed;
      badgeBg = PhiaColors.pulseRedLight;
    } else if (specialty.toUpperCase().contains('NEURO')) {
      badgeColor = const Color(0xFF228BCA);
      badgeBg = PhiaColors.primaryLight;
    }

    return Container(
      decoration: BoxDecoration(
        color: PhiaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhiaColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 64,
                  height: 64,
                  color: PhiaColors.surfaceSubtle,
                  child: SafeNetworkImage(
                    imageUrl: imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.person,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        specialty.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: PhiaColors.navyAnchor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, size: 16, color: PhiaColors.primary),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFBBF24)),
                        const SizedBox(width: 3),
                        Text(
                          '4.9',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: PhiaColors.navyAnchor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(120+ clinical reviews)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: PhiaColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: PhiaColors.borderSubtle, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                    'Available Today',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  if (intakeCompleted) {
                    Navigator.pushNamed(
                      context,
                      '/booking_date_time',
                      arguments: {
                        'specialist': pr,
                        'name': name,
                        'role': specialty,
                        'accentColor': badgeColor,
                        'imageUrl': imageUrl,
                        'intakeCompleted': true,
                        'intakeId': intakeId,
                        'clinicalReport': clinicalReport,
                      },
                    );
                  } else {
                    _showBookingOptionsModal(
                      context,
                      specialist: pr,
                      name: name,
                      role: specialty,
                      accentColor: badgeColor,
                      imageUrl: imageUrl,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PhiaColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                child: Text(
                  'Book Visit',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBookingOptionsModal(
    BuildContext context, {
    required dynamic specialist,
    required String name,
    required String role,
    required Color accentColor,
    required String imageUrl,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SafeNetworkImage(
                    imageUrl: imageUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.person,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: PhiaColors.navyAnchor,
                        ),
                      ),
                      Text(
                        role,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: PhiaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Select Booking Option',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: PhiaColors.navyAnchor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose how you would like to prepare for your consultation with $name:',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: PhiaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),

            // Option 1: With AI Intake
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(
                  context,
                  '/intake',
                  arguments: {
                    'specialist': specialist,
                    'name': name,
                    'role': role,
                    'accentColor': accentColor,
                    'imageUrl': imageUrl,
                  },
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        color: Color(0xFF16A34A),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'With AI Intake',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF14532D),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'RECOMMENDED • 2 MIN',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Describe your symptoms to DrGodly so your doctor receives an organized clinical briefing before your visit.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF166534),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Color(0xFF16A34A),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Option 2: Without AI Intake
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(
                  context,
                  '/booking_date_time',
                  arguments: {
                    'specialist': specialist,
                    'name': name,
                    'role': role,
                    'accentColor': accentColor,
                    'imageUrl': imageUrl,
                  },
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: PhiaColors.navyAnchor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Without AI Intake',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: PhiaColors.navyAnchor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF64748B),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'DIRECT BOOKING',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Skip AI symptom intake and proceed directly to choose your consultation date and time slot.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: PhiaColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: PhiaColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
