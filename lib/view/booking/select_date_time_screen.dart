import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/image_helper.dart';
import '../../viewmodel/booking_viewmodel.dart';
import '../../domain/model/booking_models.dart';

class SelectDateTimeScreen extends StatefulWidget {
  const SelectDateTimeScreen({super.key});

  @override
  State<SelectDateTimeScreen> createState() => _SelectDateTimeScreenState();
}

class _SelectDateTimeScreenState extends State<SelectDateTimeScreen> {
  late DateTime _selectedDate;
  String? _selectedTimeSlot;
  int? _selectedSlotId;
  bool _isVirtualMode = true;
  PractitionerRoleBooking? _specialist;
  bool _initialized = false;

  late List<DateTime> _thirtyDays;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _generateThirtyDays();
  }

  void _generateThirtyDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _thirtyDays = List.generate(30, (index) => today.add(Duration(days: index)));
  }

  bool _isDoctorAvailableOn(DateTime d) {
    if (_specialist == null) return true;
    final avails = _specialist!.availability;
    if (avails.isEmpty) return true;

    const daysMap = {
      DateTime.monday: 'mon',
      DateTime.tuesday: 'tue',
      DateTime.wednesday: 'wed',
      DateTime.thursday: 'thu',
      DateTime.friday: 'fri',
      DateTime.saturday: 'sat',
      DateTime.sunday: 'sun',
    };
    final dayCode = daysMap[d.weekday] ?? '';

    final allowedDays = <String>{};
    for (final a in avails) {
      for (final t in a.availableTimes) {
        for (final day in t.daysOfWeek) {
          allowedDays.add(day.toLowerCase().trim());
        }
      }
    }

    if (allowedDays.isEmpty) return true;
    return allowedDays.contains(dayCode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _specialist = args['specialist'] as PractitionerRoleBooking?;

      // Auto-select first available day if today is not an active day for this specialist
      if (!_isDoctorAvailableOn(_selectedDate)) {
        for (final d in _thirtyDays) {
          if (_isDoctorAvailableOn(d)) {
            _selectedDate = d;
            break;
          }
        }
      }

      _fetchSlotsForDate(_selectedDate);
      _initialized = true;
    }
  }

  void _fetchSlotsForDate(DateTime date) {
    if (_specialist != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<BookingViewModel>().fetchBookedSlots(_specialist!.id, date);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final specialistName = args['name'] as String? ?? 'Clinical Specialist';
    final specialistRole = args['role'] as String? ?? 'General Practice';
    final specialistImageUrl = args['imageUrl'] as String? ?? 'assets/doctors/doctor_1.png';

    final isRescheduling = args['reschedule_appointment_id'] != null;

    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isRescheduling ? 'Reschedule Consultation' : 'Select Date & Time',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Doctor Mini Card (Navy Header Banner)
                  Container(
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
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 56,
                            height: 56,
                            color: PhiaColors.surfaceSubtle,
                            child: SafeNetworkImage(
                              imageUrl: specialistImageUrl,
                              width: 56,
                              height: 56,
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
                              Text(
                                specialistName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: PhiaColors.navyAnchor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                specialistRole,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: PhiaColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
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
                                  const SizedBox(width: 5),
                                  Text(
                                    'Verified Practitioner',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF15803D),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Consultation Format Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: PhiaColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PhiaColors.borderSubtle),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isVirtualMode = true),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isVirtualMode ? PhiaColors.surface : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _isVirtualMode
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.videocam_rounded,
                                    size: 16,
                                    color: _isVirtualMode ? PhiaColors.primary : PhiaColors.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Video Consultation',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: _isVirtualMode ? FontWeight.w700 : FontWeight.w500,
                                      color: _isVirtualMode ? PhiaColors.navyAnchor : PhiaColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isVirtualMode = false),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isVirtualMode ? PhiaColors.surface : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !_isVirtualMode
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.local_hospital_rounded,
                                    size: 16,
                                    color: !_isVirtualMode ? PhiaColors.primary : PhiaColors.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'In-Clinic Visit',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: !_isVirtualMode ? FontWeight.w700 : FontWeight.w500,
                                      color: !_isVirtualMode ? PhiaColors.navyAnchor : PhiaColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Calendar Date Selector
                  Text(
                    'SELECT DATE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: PhiaColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _thirtyDays.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, idx) {
                        final d = _thirtyDays[idx];
                        final isAvailable = _isDoctorAvailableOn(d);
                        final isSelected = isAvailable &&
                            d.year == _selectedDate.year &&
                            d.month == _selectedDate.month &&
                            d.day == _selectedDate.day;

                        return Opacity(
                          opacity: isAvailable ? 1.0 : 0.38,
                          child: InkWell(
                            onTap: isAvailable
                                ? () {
                                    setState(() {
                                      _selectedDate = d;
                                      _selectedTimeSlot = null;
                                      _selectedSlotId = null;
                                    });
                                    _fetchSlotsForDate(d);
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 60,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? PhiaColors.navyAnchor
                                    : (isAvailable ? PhiaColors.surface : PhiaColors.surfaceSubtle),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? PhiaColors.navyAnchor
                                      : PhiaColors.borderSubtle,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: PhiaColors.navyAnchor.withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    DateFormat('E').format(d).toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : (isAvailable ? PhiaColors.textMuted : PhiaColors.textMuted.withValues(alpha: 0.6)),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    d.day.toString(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? Colors.white
                                          : (isAvailable ? PhiaColors.navyAnchor : PhiaColors.textMuted),
                                    ),
                                  ),
                                  if (!isAvailable) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'OFF',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: PhiaColors.textMuted,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Time Slots Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AVAILABLE TIME SLOTS',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: PhiaColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (context.watch<BookingViewModel>().isSlotsLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: PhiaColors.primary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Builder(
                    builder: (context) {
                      final bookingVM = context.watch<BookingViewModel>();
                      final serverSlots = bookingVM.availableSlots;

                      if (bookingVM.isSlotsLoading) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 36.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(color: PhiaColors.primary),
                                const SizedBox(height: 14),
                                Text(
                                  'Checking schedule for $specialistName...',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: PhiaColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (serverSlots.isEmpty) {
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                          decoration: BoxDecoration(
                            color: PhiaColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: PhiaColors.borderSubtle),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: PhiaColors.surfaceSubtle,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.event_busy_rounded,
                                  color: PhiaColors.textMuted,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No Slots Available',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: PhiaColors.navyAnchor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'No consultation slots available for $specialistName on ${DateFormat('EEE, MMM d').format(_selectedDate)}.\nPlease select another date from the calendar above.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: PhiaColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final morning = serverSlots.where((s) {
                        final hour = s.startDateTime?.hour ?? 9;
                        return hour < 12;
                      }).toList();

                      final afternoon = serverSlots.where((s) {
                        final hour = s.startDateTime?.hour ?? 13;
                        return hour >= 12 && hour < 17;
                      }).toList();

                      final evening = serverSlots.where((s) {
                        final hour = s.startDateTime?.hour ?? 18;
                        return hour >= 17;
                      }).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (morning.isNotEmpty) ...[
                            Text(
                              'MORNING',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: PhiaColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: morning.map((s) => _buildSlotChip(s.displayTime, slotId: s.id)).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (afternoon.isNotEmpty) ...[
                            Text(
                              'AFTERNOON',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: PhiaColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: afternoon.map((s) => _buildSlotChip(s.displayTime, slotId: s.id)).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (evening.isNotEmpty) ...[
                            Text(
                              'EVENING',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: PhiaColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: evening.map((s) => _buildSlotChip(s.displayTime, slotId: s.id)).toList(),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Bottom Continue Bar
            Container(
              decoration: BoxDecoration(
                color: PhiaColors.surface,
                border: const Border(top: BorderSide(color: PhiaColors.borderSubtle)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedTimeSlot != null
                              ? '${DateFormat('MMM d').format(_selectedDate)} at $_selectedTimeSlot'
                              : 'Select a time slot',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: PhiaColors.navyAnchor,
                          ),
                        ),
                        Text(
                          _isVirtualMode ? 'Standard Video Consultation' : 'In-Person Consultation',
                          style: GoogleFonts.inter(fontSize: 12, color: PhiaColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _selectedTimeSlot == null
                        ? null
                        : () async {
                            if (isRescheduling) {
                              final rescheduleId = args['reschedule_appointment_id'].toString();
                              final slotId = _selectedSlotId ?? 0;
                              final scaffold = ScaffoldMessenger.of(context);
                              final nav = Navigator.of(context);
                              
                              final success = await context.read<BookingViewModel>().rescheduleAppointment(
                                rescheduleId,
                                slotId,
                              );
                              
                              if (success) {
                                scaffold.showSnackBar(
                                  const SnackBar(
                                    content: Text('Consultation rescheduled successfully!'),
                                    backgroundColor: PhiaColors.navyAnchor,
                                  ),
                                );
                                nav.pop();
                              } else {
                                scaffold.showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to reschedule consultation. Please try another slot.'),
                                    backgroundColor: PhiaColors.pulseRed,
                                  ),
                                );
                              }
                              return;
                            }

                            Navigator.pushNamed(
                              context,
                              '/booking_review',
                              arguments: {
                                'specialist': _specialist,
                                'name': specialistName,
                                'role': specialistRole,
                                'accentColor': PhiaColors.primary,
                                'date': DateFormat('MMMM d, yyyy').format(_selectedDate),
                                'date_raw': _selectedDate,
                                'time': _selectedTimeSlot!,
                                'slot_id': _selectedSlotId,
                                'imageUrl': specialistImageUrl,
                                'isVirtual': _isVirtualMode,
                              },
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PhiaColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: PhiaColors.borderSubtle,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    ),
                    child: Text(
                      isRescheduling ? 'Confirm Reschedule' : 'Review Booking',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
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

  Widget _buildSlotChip(String slot, {int? slotId}) {
    final isSelected = _selectedTimeSlot == slot;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTimeSlot = slot;
          _selectedSlotId = slotId;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? PhiaColors.primary : PhiaColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? PhiaColors.primary : PhiaColors.borderSubtle,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: PhiaColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          slot,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : PhiaColors.navyAnchor,
          ),
        ),
      ),
    );
  }
}
