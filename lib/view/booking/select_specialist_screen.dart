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
    final specialties = ['ALL', 'PRIMARY CARE', 'CARDIOLOGY', 'NEUROLOGY', 'ENDOCRINOLOGY', 'SPORTS'];

    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.primary,
        elevation: 0,
        leading: widget.isTab
            ? const Icon(Icons.menu_rounded, color: Colors.white)
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
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),

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
                      color: Colors.black.withOpacity(0.02),
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
                  final isSelected = _selectedSpecialty == s;
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
                  if (vm.isSpecialistsLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: PhiaColors.primary,
                        strokeWidth: 2.5,
                      ),
                    );
                  }

                  // Filter specialists by query & category
                  final filtered = vm.specialists.where((sp) {
                    final name = sp.practitionerDetail?.fullName ?? sp.practitionerDisplay ?? '';
                    final specialty = sp.specialties.isNotEmpty ? sp.specialties.first : '';
                    final matchesQuery = _searchQuery.isEmpty ||
                        name.toLowerCase().contains(_searchQuery) ||
                        specialty.toLowerCase().contains(_searchQuery);

                    if (!matchesQuery) return false;
                    if (_selectedSpecialty == 'ALL') return true;

                    final catUpper = specialty.toUpperCase();
                    if (_selectedSpecialty == 'PRIMARY CARE') {
                      return catUpper.contains('PRIMARY') || catUpper.contains('FAMILY') || catUpper.contains('GENERAL');
                    } else if (_selectedSpecialty == 'CARDIOLOGY') {
                      return catUpper.contains('CARDIO') || catUpper.contains('HEART');
                    } else if (_selectedSpecialty == 'NEUROLOGY') {
                      return catUpper.contains('NEURO') || catUpper.contains('BRAIN');
                    } else if (_selectedSpecialty == 'ENDOCRINOLOGY') {
                      return catUpper.contains('ENDO') || catUpper.contains('METABOLIC');
                    } else if (_selectedSpecialty == 'SPORTS') {
                      return catUpper.contains('SPORT') || catUpper.contains('ORTHO');
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: PhiaColors.textMuted.withOpacity(0.5)),
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
                        return _buildCleanDoctorCard(context, filtered[idx]);
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

  Widget _buildCleanDoctorCard(BuildContext context, PractitionerRoleBooking pr) {
    final detail = pr.practitionerDetail;
    final String name = detail?.fullName ?? pr.practitionerDisplay ?? 'Clinical Specialist';
    final String specialty = pr.specialties.isNotEmpty ? pr.specialties.first : 'General Practitioner';
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
            color: Colors.black.withOpacity(0.02),
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
                  Navigator.pushNamed(
                    context,
                    '/booking_date_time',
                    arguments: {
                      'specialist': pr,
                      'name': name,
                      'role': specialty,
                      'accentColor': badgeColor,
                      'imageUrl': imageUrl,
                    },
                  );
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
}
