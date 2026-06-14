import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../core/widgets/image_helper.dart';
import '../../viewmodel/booking_viewmodel.dart';
import '../../domain/model/booking_models.dart';
import '../../core/utils/language_helper.dart';

class SelectDateTimeScreen extends StatefulWidget {
  const SelectDateTimeScreen({super.key});

  @override
  State<SelectDateTimeScreen> createState() => _SelectDateTimeScreenState();
}

class _SelectDateTimeScreenState extends State<SelectDateTimeScreen> {
  late DateTime _selectedDate;
  String? _selectedTimeSlot;
  bool _isVirtualMode = true; // Default virtual mode
  PractitionerRoleBooking? _specialist;
  bool _initialized = false;

  final Map<int, String> _weekdayNames = {
    DateTime.monday: 'mon',
    DateTime.tuesday: 'tue',
    DateTime.wednesday: 'wed',
    DateTime.thursday: 'thu',
    DateTime.friday: 'fri',
    DateTime.saturday: 'sat',
    DateTime.sunday: 'sun',
  };

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _specialist = args['specialist'] as PractitionerRoleBooking?;
      
      // Auto-fetch booked slots for the initial date
      _fetchSlotsForDate(_selectedDate);
      _initialized = true;
    }
  }



  void _fetchSlotsForDate(DateTime date) {
    if (_specialist != null) {
      final pId = _specialist!.practitionerRefId ?? _specialist!.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<BookingViewModel>(context, listen: false).fetchBookedSlots(pId, date);
      });
    }
  }


  /// Generate timeslots based on doctor's schedule times
  List<String> _generateTimeSlots() {
    if (_specialist == null || _specialist!.availability.isEmpty) {
      return ['09:00', '09:30', '10:00', '10:30', '11:00', '11:30', '13:00', '13:30', '14:00', '14:30', '15:00', '15:30', '16:00', '16:30'];
    }

    final currentDayName = _weekdayNames[_selectedDate.weekday];
    final slots = <String>[];

    for (var av in _specialist!.availability) {
      for (var time in av.availableTimes) {
        if (time.daysOfWeek.map((d) => d.toLowerCase()).contains(currentDayName)) {
          final startStr = time.availableStartTime ?? '09:00:00';
          final endStr = time.availableEndTime ?? '17:00:00';

          final startParts = startStr.split(':');
          final endParts = endStr.split(':');

          int startHour = int.parse(startParts[0]);
          int startMinute = int.parse(startParts[1]);
          int endHour = int.parse(endParts[0]);
          int endMinute = int.parse(endParts[1]);

          var current = DateTime(2000, 1, 1, startHour, startMinute);
          final end = DateTime(2000, 1, 1, endHour, endMinute);

          while (current.isBefore(end)) {
            final hour = current.hour.toString().padLeft(2, '0');
            final minute = current.minute.toString().padLeft(2, '0');
            slots.add('$hour:$minute');
            current = current.add(const Duration(minutes: 30));
          }
        }
      }
    }

    if (slots.isEmpty) {
      return ['09:00', '09:30', '10:00', '10:30', '11:00', '11:30', '13:00', '13:30', '14:00', '14:30', '15:00', '15:30', '16:00', '16:30'];
    }
    return slots;
  }  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String specialistName = args['name'] as String;
    final String specialistRole = args['role'] as String;
    final Color accentColor = args['accentColor'] as Color;
    final String specialistImageUrl = args['imageUrl'] as String;
    final timeSlots = _generateTimeSlots();

    String doctorBio = 'Attending clinical specialist at the DRGODLY Clinical Wellness Center, dedicated to high-fidelity diagnostic evaluations and personalized patient care plans.';
    final nameLower = specialistName.toLowerCase();
    if (nameLower.contains('aurelius')) {
      doctorBio = 'Dr. Marcus Aurelius is a dedicated Primary Care Physician specializing in comprehensive family medicine and preventative care protocols. He focuses on longitudinal patient wellness and metabolic health tracking.';
    } else if (nameLower.contains('vance')) {
      doctorBio = 'Dr. Elena Vance is a leading Cardiovascular Specialist with over 12 years of clinical research and practice in advanced heart failure management, non-invasive imaging, and cardiac rehabilitation.';
    } else if (nameLower.contains('chen')) {
      doctorBio = 'Dr. David Chen is a Board Certified Endocrinologist dedicated to advanced diabetes management, thyroid therapeutics, and metabolic health mapping.';
    } else if (nameLower.contains('jenkins')) {
      doctorBio = 'Dr. Sarah Jenkins is an experienced Clinical Neurologist specializing in cognitive health tracking, neuro-diagnostics, and autonomic system assessments.';
    }

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          // 1. Dot Matrix Grid Background overlay
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          // 2. Main Scrollable Panel
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Custom Header Row (Menu, Centered KINETIC, desaturated Avatar)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
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

                // Main Content List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    children: [
                      const SizedBox(height: 12),

                      // Title Area (SESSION PLANNER and SELECT DATE & TIME)
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.38),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'CLINICAL SCHEDULER',
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
                        AppLanguageHelper.translate(context, 'select_date_time', defaultText: 'SELECT DATE & TIME'),
                        style: GoogleFonts.bebasNeue(
                          fontSize: 32,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Doctor Profile Card
                      Container(
                        decoration: BoxDecoration(
                          color: PhiaColors.surface,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Segment 1: Header Profile Row
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Grayscale portrait
                                  Container(
                                    width: 60,
                                    height: 75,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                      image: DecorationImage(
                                        image: getImageProvider(specialistImageUrl, fallback: 'assets/doctors/doctor_1.png'),
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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          specialistRole.toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: accentColor,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          specialistName.toUpperCase(),
                                          style: GoogleFonts.bebasNeue(
                                            fontSize: 22,
                                            color: Colors.white,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber, size: 12),
                                            const SizedBox(width: 4),
                                            Text(
                                              '4.9 (120 REVIEWS)',
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white70,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              '•',
                                              style: TextStyle(color: Colors.white38),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '12 YRS EXP',
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white70,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'DRGODLY CLINICAL WELLNESS CENTER',
                                          style: GoogleFonts.inter(
                                            fontSize: 8,
                                            color: Colors.white38,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Segment Divider Line
                            Container(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),

                            // Segment 2: Biography details
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ABOUT THE PRACTITIONER',
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white38,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    doctorBio,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white54,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Mode Selector (Virtual vs In-Person)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isVirtualMode = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _isVirtualMode ? Colors.white : Colors.transparent,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'VIRTUAL CONSULTATION',
                                      style: GoogleFonts.bebasNeue(
                                        fontSize: 12,
                                        color: _isVirtualMode ? Colors.black : Colors.white60,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isVirtualMode = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !_isVirtualMode ? Colors.white : Colors.transparent,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'IN-PERSON VISIT',
                                      style: GoogleFonts.bebasNeue(
                                        fontSize: 12,
                                        color: !_isVirtualMode ? Colors.black : Colors.white60,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 3. COMPACT HORIZONTAL DATE SELECTOR
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
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
                                    'SELECT DATE',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(alpha: 0.38),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                DateFormat('MMMM yyyy').format(_selectedDate).toUpperCase(),
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 14,
                                  color: Colors.white,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _thirtyDays.length,
                              itemBuilder: (context, index) {
                                final DateTime day = _thirtyDays[index];
                                final bool isSelected = _selectedDate.day == day.day &&
                                                      _selectedDate.month == day.month &&
                                                      _selectedDate.year == day.year;

                                final String weekday = _weekdayNames[day.weekday] ?? 'mon';
                                final String dayNumber = day.day.toString().padLeft(2, '0');
                                final String monthAbbr = DateFormat('MMM').format(day).toUpperCase();

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedDate = day;
                                      _selectedTimeSlot = null; // Reset slot
                                    });
                                    _fetchSlotsForDate(day);
                                  },
                                  child: Container(
                                    width: 60,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.transparent : PhiaColors.surface,
                                      border: Border.all(
                                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.08),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          weekday.toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : Colors.white30,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          dayNumber,
                                          style: GoogleFonts.bebasNeue(
                                            fontSize: 20,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          monthAbbr,
                                          style: GoogleFonts.inter(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w500,
                                            color: isSelected ? Colors.white60 : Colors.white30,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // 4. AVAILABLE SLOTS SECTION HEADER
                      Row(
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
                            'AVAILABLE SLOTS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.38),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Time Slot Bento Cards List
                      Consumer<BookingViewModel>(
                        builder: (context, vm, child) {
                          if (vm.isSlotsLoading) {
                            return _buildSlotsLoader();
                          }

                          return Column(
                            children: List.generate(timeSlots.length, (index) {
                              final String slotTime = timeSlots[index];
                              bool isSelected = _selectedTimeSlot == slotTime;
                              bool isBooked = vm.bookedSlots.contains(slotTime);

                              // Assign custom titles for visual variety
                              String title = 'MIDDAY CLINICAL FLOW';
                              final hour = int.parse(slotTime.split(':')[0]);
                              if (hour < 12) {
                                title = 'MORNING APPOINTMENT FLOW';
                              } else if (hour >= 16) {
                                title = 'EVENING CONSULTATION FLOW';
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: GestureDetector(
                                  onTap: isBooked
                                      ? null
                                      : () {
                                          setState(() {
                                            _selectedTimeSlot = slotTime;
                                          });
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isBooked ? Colors.white.withValues(alpha: 0.01) : Colors.transparent,
                                      border: Border.all(
                                        color: isBooked
                                            ? Colors.white.withValues(alpha: 0.05)
                                            : (isSelected ? Colors.white : Colors.white.withValues(alpha: 0.12)),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: isBooked
                                                    ? Colors.white.withValues(alpha: 0.15)
                                                    : (isSelected ? Colors.white : Colors.white.withValues(alpha: 0.35)),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              slotTime,
                                              style: GoogleFonts.bebasNeue(
                                                fontSize: 26,
                                                color: isBooked
                                                    ? Colors.white.withValues(alpha: 0.15)
                                                    : Colors.white,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              isBooked ? 'OCCUPIED' : '30 MIN',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isBooked
                                                    ? Colors.white.withValues(alpha: 0.15)
                                                    : Colors.white.withValues(alpha: 0.6),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              isBooked ? Icons.lock_outline : Icons.access_time_outlined,
                                              color: isBooked
                                                  ? Colors.white.withValues(alpha: 0.15)
                                                  : (isSelected ? Colors.white : Colors.white.withValues(alpha: 0.35)),
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),

                    ],
                  ),
                ),

                // Pinned Continue Button outside the scrollable view
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: PhiaColors.background,
                    border: Border(
                      top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: _selectedTimeSlot == null
                        ? null
                        : () {
                            final String formattedDate = DateFormat('MMMM d, yyyy').format(_selectedDate);

                            Navigator.pushNamed(
                              context,
                              '/booking_review',
                              arguments: {
                                'specialist': _specialist,
                                'name': specialistName,
                                'role': specialistRole,
                                'accentColor': accentColor,
                                'date': formattedDate,
                                'date_raw': _selectedDate,
                                'time': _selectedTimeSlot,
                                'isVirtual': _isVirtualMode,
                                'imageUrl': specialistImageUrl,
                              },
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                      disabledForegroundColor: Colors.white.withValues(alpha: 0.2),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      elevation: 0,
                    ),
                    child: Text(
                      'CONTINUE TO REVIEW',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsLoader() {
    return Container(
      height: 100,
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
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'RETRIEVING LIVE RESERVATION INDEX...',
              style: GoogleFonts.bebasNeue(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.38),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
