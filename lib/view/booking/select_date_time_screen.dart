import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';

class SelectDateTimeScreen extends StatefulWidget {
  const SelectDateTimeScreen({super.key});

  @override
  State<SelectDateTimeScreen> createState() => _SelectDateTimeScreenState();
}

class _SelectDateTimeScreenState extends State<SelectDateTimeScreen> {
  int _selectedDay = 7; // October 7th is selected in the mockup
  int _selectedSlotIndex = 0; // Morning Session (08:00) is selected

  // Grid offsets for October 2023 starting on Friday: 
  // 4 empty days representing Mon, Tue, Wed, Thu, followed by 1 to 14.
  final List<int?> _calendarDays = [
    null, null, null, null, 1, 2, 3,
    4, 5, 6, 7, 8, 9, 10,
    11, 12, 13, 14
  ];

  final List<Map<String, String>> _slots = [
    {
      'title': 'MORNING SESSION',
      'time': '08:00',
      'duration': '90 MIN',
      'type': 'bolt',
    },
    {
      'title': 'MIDDAY FLOW',
      'time': '10:30',
      'duration': '60 MIN',
      'type': 'bolt',
    },
    {
      'title': 'POWER HOUR',
      'time': '13:15',
      'duration': '45 MIN',
      'type': 'bolt',
    },
    {
      'title': 'EVENING BURN',
      'time': '18:00',
      'duration': 'BOOKED',
      'type': 'lock',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Retrieve specialist details passed from previous SelectSpecialistScreen
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String specialistName = args['name'] as String;
    final String specialistRole = args['role'] as String;
    final Color accentColor = args['accentColor'] as Color;
    final String specialistImageUrl = args['imageUrl'] as String;

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
                            'SESSION PLANNER',
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
                        'SELECT DATE & TIME',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 32,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 3. CALENDAR BENTO BOX CONTAINER
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Calendar Header (OCTOBER 2023 and arrows)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'OCTOBER 2023',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {},
                                      child: const Icon(Icons.chevron_left, color: Colors.white, size: 18),
                                    ),
                                    const SizedBox(width: 20),
                                    GestureDetector(
                                      onTap: () {},
                                      child: const Icon(Icons.chevron_right, color: Colors.white, size: 18),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),

                            // Weekday Labels Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'].map((day) {
                                return Expanded(
                                  child: Center(
                                    child: Text(
                                      day,
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white.withValues(alpha: 0.35),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 16),

                            // October Days Grid Layout
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 8,
                                childAspectRatio: 1.0,
                              ),
                              itemCount: _calendarDays.length,
                              itemBuilder: (context, index) {
                                final int? day = _calendarDays[index];
                                if (day == null) {
                                  return const SizedBox.shrink();
                                }

                                bool isSelected = _selectedDay == day;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedDay = day;
                                    });
                                  },
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      border: isSelected
                                          ? Border.all(color: Colors.white, width: 1.0)
                                          : null,
                                    ),
                                    child: Text(
                                      day.toString().padLeft(2, '0'),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.35),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
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
                      Column(
                        children: List.generate(_slots.length, (index) {
                          final slot = _slots[index];
                          bool isSelected = _selectedSlotIndex == index;
                          bool isBooked = slot['type'] == 'lock';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: GestureDetector(
                              onTap: isBooked
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedSlotIndex = index;
                                      });
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
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
                                          slot['title']!,
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
                                          slot['time']!,
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
                                          slot['duration']!,
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
                                          isBooked ? Icons.lock_outline : Icons.bolt,
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
                      ),

                      const SizedBox(height: 24),

                      // 5. CONTINUE TO PAYMENT CTA (Solid White Block Button)
                      ElevatedButton(
                        onPressed: () {
                          // Assemble booking arguments to pass to review screen
                          final String selectedDateStr = 'OCTOBER ${_selectedDay.toString().padLeft(2, '0')}, 2023';
                          final String selectedTimeStr = _slots[_selectedSlotIndex]['time']!;

                          Navigator.pushNamed(
                            context,
                            '/booking_review',
                            arguments: {
                              'name': specialistName,
                              'role': specialistRole,
                              'accentColor': accentColor,
                              'date': selectedDateStr,
                              'time': selectedTimeStr,
                              'imageUrl': specialistImageUrl,
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          elevation: 0,
                        ),
                        child: Text(
                          'CONTINUE TO PAYMENT',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
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
}
