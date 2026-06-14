import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dot_matrix.dart';
import '../../core/widgets/notification_center_modal.dart';
import '../../viewmodel/activity_viewmodel.dart';
import '../../viewmodel/profile_viewmodel.dart';
import '../../viewmodel/booking_viewmodel.dart';
import '../../core/utils/language_helper.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/image_helper.dart';


class DashboardScreen extends StatelessWidget {
  final Function(int)? onTabSelected;
  const DashboardScreen({super.key, this.onTabSelected});
  @override
  Widget build(BuildContext context) {
    final activityVM = context.watch<ActivityViewModel>();
    final profileVM = context.watch<ProfileViewModel>();
    final bookingVM = context.watch<BookingViewModel>();

    // Get nearest upcoming appointment
    Map<String, dynamic>? nearestUpcoming;
    final now = DateTime.now();
    for (var appt in bookingVM.appointmentsList) {
      try {
        final startStr = appt['start_time'] as String;
        final start = DateTime.parse(startStr).toLocal();
        if (start.isAfter(now)) {
          if (nearestUpcoming == null) {
            nearestUpcoming = appt;
          } else {
            final currentNearestStart = DateTime.parse(nearestUpcoming['start_time'] as String).toLocal();
            if (start.isBefore(currentNearestStart)) {
              nearestUpcoming = appt;
            }
          }
        }
      } catch (_) {}
    }

    void showCancelConfirmation(BuildContext context, String id, String doctorName) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.black,
            shape: const Border(
              top: BorderSide(color: Colors.redAccent, width: 2.0),
            ),
            title: Text(
              'CANCEL APPOINTMENT',
              style: GoogleFonts.bebasNeue(
                fontSize: 20,
                color: Colors.white,
                letterSpacing: 2.0,
              ),
            ),
            content: Text(
              'Are you sure you want to cancel your scheduled appointment with $doctorName?',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'KEEP IT',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                onPressed: () {
                  context.read<BookingViewModel>().cancelAppointment(id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Appointment with $doctorName cancelled.')),
                  );
                },
                child: Text(
                  'CANCEL',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    void showAppointmentDetails(Map<String, dynamic> appt) {
      final id = appt['id'] as String;
      final name = appt['practitioner_name'] as String;
      final role = appt['practitioner_role'] as String;
      final image = appt['practitioner_image'] as String;
      final startStr = appt['start_time'] as String;
      final isVirtual = (appt['is_virtual'] as int? ?? 1) == 1;

      String dateFormatted = '';
      String timeFormatted = '';
      try {
        final dateTime = DateTime.parse(startStr).toLocal();
        dateFormatted = DateFormat('EEEE, MMMM d, yyyy').format(dateTime).toUpperCase();
        timeFormatted = DateFormat('hh:mm a').format(dateTime);
      } catch (_) {
        dateFormatted = startStr;
      }

      final String fallbackImageUrl = 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?q=80&w=100';
      final imageUrl = image.isNotEmpty ? image : fallbackImageUrl;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.black,
            shape: const Border(
              top: BorderSide(color: PhiaColors.skyBlue, width: 2.0),
            ),
            title: Text(
              'APPOINTMENT DETAILS',
              style: GoogleFonts.bebasNeue(
                fontSize: 20,
                color: Colors.white,
                letterSpacing: 2.0,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 60,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isVirtual ? 'VIRTUAL CLINICAL CONSULTATION' : 'IN-PERSON CLINICAL VISIT',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: PhiaColors.skyBlue,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name.toUpperCase(),
                            style: GoogleFonts.bebasNeue(
                              fontSize: 18,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            role.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                Text(
                  'DATE',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white38,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormatted,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'TIME',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white38,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeFormatted,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 18,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'CLOSE',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                onPressed: () {
                  Navigator.pop(context); // Close details dialog
                  showCancelConfirmation(context, id, name);
                },
                child: Text(
                  'CANCEL',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    // Dynamic metrics calculation
    int steps = activityVM.currentSteps;
    int calories = activityVM.currentCalories;
    int activeMins = activityVM.currentActiveMins;

    double progressSteps = (steps / 10000.0).clamp(0.0, 1.0);
    double progressCalories = (calories / 500.0).clamp(0.0, 1.0);
    double progressActiveMins = (activeMins / 60.0).clamp(0.0, 1.0);

    // Steps formatting
    String stepsStr = steps.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    // BMI Calculations
    double bmi = 0.0;
    String bmiClassification = 'N/A';
    Color bmiColor = Colors.white38;
    if (activityVM.userHeight > 0 && activityVM.userWeight > 0) {
      double heightM = activityVM.userHeight / 100.0;
      bmi = activityVM.userWeight / (heightM * heightM);
      if (bmi < 18.5) {
        bmiClassification = 'UNDERWEIGHT';
        bmiColor = PhiaColors.pulseRed;
      } else if (bmi < 25.0) {
        bmiClassification = 'NORMAL';
        bmiColor = PhiaColors.stepGreen;
      } else if (bmi < 30.0) {
        bmiClassification = 'OVERWEIGHT';
        bmiColor = Colors.amber;
      } else {
        bmiClassification = 'OBESE';
        bmiColor = PhiaColors.pulseRed;
      }
    }

    String formatAppointmentDate(String? isoString) {
      if (isoString == null || isoString.isEmpty) return 'N/A';
      try {
        final dt = DateTime.parse(isoString).toLocal();
        final List<String> months = [
          'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
          'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
        ];
        final monthStr = months[dt.month - 1];
        final dayStr = dt.day.toString().padLeft(2, '0');
        final yearStr = dt.year.toString();
        final hourStr = dt.hour.toString().padLeft(2, '0');
        final minStr = dt.minute.toString().padLeft(2, '0');
        final period = dt.hour >= 12 ? 'PM' : 'AM';
        final formattedHour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        return '$monthStr $dayStr, $yearStr @ ${formattedHour.toString().padLeft(2, '0')}:$minStr $period';
      } catch (_) {
        return isoString;
      }
    }

    return Scaffold(
      backgroundColor: PhiaColors.background,
      body: Stack(
        children: [
          // 1. Ambient Dot Matrix Grid Background
          const Positioned.fill(
            child: DotMatrixBackground(child: SizedBox.shrink()),
          ),

          // 2. Main Scrollable Dashboard Panel
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_hospital, color: Colors.white, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            AppLanguageHelper.translate(context, 'drgodly', defaultText: 'DRGODLY'),
                            style: GoogleFonts.bebasNeue(
                              fontSize: 24,
                              letterSpacing: 4.0,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Cyberpunk neon sensor active badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: activityVM.hasActivityPermission ? Colors.white : Colors.white.withValues(alpha: 0.05),
                              border: Border.all(
                                color: activityVM.hasActivityPermission ? Colors.white : Colors.white.withValues(alpha: 0.12),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: activityVM.hasActivityPermission ? PhiaColors.stepGreen : PhiaColors.pulseRed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  activityVM.hasActivityPermission
                                      ? (activityVM.isStepSensorFallback
                                          ? 'ACCELEROMETER ACTIVE'
                                          : 'NATIVE SENSOR ACTIVE')
                                      : 'NO SENSOR ACCESS',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: activityVM.hasActivityPermission ? Colors.black : Colors.white30,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => showNotificationCenter(context),
                        icon: const Icon(Icons.notifications_none, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Profile Welcome Greeting Block
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppLanguageHelper.translate(context, 'hi', defaultText: 'HI')}, ${(profileVM.currentProfile?.name != null && profileVM.currentProfile!.name!.isNotEmpty) ? profileVM.currentProfile!.name!.first.givenName.toUpperCase() : AppLanguageHelper.translate(context, 'patient', defaultText: 'PATIENT')}',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 28,
                          letterSpacing: 2.0,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your health portal is active and secure.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // DAILY ACTIVITY Concentric circular Progress Card
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/activity_tracking'),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: PhiaColors.surface,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'DAILY ACTIVITY',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                  color: Colors.white,
                                ),
                              ),
                              const Icon(Icons.show_chart, color: Colors.white54, size: 18),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Stacked Concentric progress rings with custom painter
                          Center(
                            child: SizedBox(
                              width: 140,
                              height: 140,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size(140, 140),
                                    painter: ConcentricActivityPainter(
                                      stepsPct: progressSteps,
                                      caloriesPct: progressCalories,
                                      activeMinsPct: progressActiveMins,
                                    ),
                                  ),
                                  Text(
                                    '${((progressSteps + progressCalories + progressActiveMins) / 3 * 100).toStringAsFixed(0)}%',
                                    style: GoogleFonts.bebasNeue(
                                      fontSize: 28,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Bullet details below
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBulletItem(AppLanguageHelper.translate(context, 'steps', defaultText: 'STEPS'), stepsStr, Colors.white),
                              const SizedBox(height: 12),
                              _buildBulletItem(AppLanguageHelper.translate(context, 'calories', defaultText: 'CALORIES'), '$calories', Colors.white70),
                              const SizedBox(height: 12),
                              _buildBulletItem(AppLanguageHelper.translate(context, 'active_time', defaultText: 'ACTIVE TIME'), '$activeMins', Colors.white30),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // UPCOMING CONSULTATIONS Card
                  GestureDetector(
                    onTap: nearestUpcoming != null
                        ? () => showAppointmentDetails(nearestUpcoming!)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: PhiaColors.surface,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'UPCOMING CONSULTATIONS',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                  color: Colors.white70,
                                ),
                              ),
                              const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (nearestUpcoming != null) ...[
                            Text(
                              nearestUpcoming['practitioner_name']?.toString().toUpperCase() ?? 'SPECIALIST',
                              style: GoogleFonts.bebasNeue(
                                fontSize: 24,
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
                                    color: Colors.white.withValues(alpha: 0.08),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Text(
                                    nearestUpcoming['type']?.toString().toUpperCase() ?? 'CONSULTATION',
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    formatAppointmentDate(nearestUpcoming['start_time']?.toString()),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              'NO UPCOMING APPOINTMENTS',
                              style: GoogleFonts.bebasNeue(
                                fontSize: 20,
                                color: Colors.white30,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Schedule a consultation with our medical specialists.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white38,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: () => onTabSelected?.call(1),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white24),
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'BOOK APPOINTMENT',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 14),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CLINICAL VITALS & BMI Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: PhiaColors.surface,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'CLINICAL VITALS & BMI',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HEIGHT',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white38,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                 Text(
                                  '${activityVM.userHeight.toStringAsFixed(0)} CM',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 22,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WEIGHT',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white38,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${activityVM.userWeight.toStringAsFixed(1)} KG',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 22,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AGE',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white38,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${activityVM.userAge} YRS',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 22,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BODY MASS INDEX (BMI)',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white38,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  bmi > 0 ? bmi.toStringAsFixed(1) : 'N/A',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 28,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            if (bmi > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: bmiColor.withValues(alpha: 0.5)),
                                  color: bmiColor.withValues(alpha: 0.08),
                                ),
                                child: Text(
                                  bmiClassification,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: bmiColor,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.bebasNeue(
                fontSize: 18,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// 1. Concentric progress painter for three biological arcs (Steps, Calories, Active minutes)
class ConcentricActivityPainter extends CustomPainter {
  final double stepsPct;
  final double caloriesPct;
  final double activeMinsPct;

  ConcentricActivityPainter({
    required this.stepsPct,
    required this.caloriesPct,
    required this.activeMinsPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeW = 6.0;
    final double spacing = 6.0;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // Ring 1 (outermost): Steps (Solid White)
    double r1 = size.width / 2 - strokeW / 2;
    _drawRing(canvas, center, r1, strokeW, stepsPct, Colors.white, Colors.white.withValues(alpha: 0.12));

    // Ring 2 (middle): Calories (Gray)
    double r2 = r1 - strokeW - spacing;
    _drawRing(canvas, center, r2, strokeW, caloriesPct, Colors.white70, Colors.white.withValues(alpha: 0.06));

    // Ring 3 (innermost): Active Mins (Dark Gray)
    double r3 = r2 - strokeW - spacing;
    _drawRing(canvas, center, r3, strokeW, activeMinsPct, Colors.white30, Colors.white.withValues(alpha: 0.03));
  }

  void _drawRing(Canvas canvas, Offset center, double radius, double strokeWidth, double pct, Color color, Color bgColor) {
    final bgPaint = Paint()
      ..color = bgColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159265 / 2, // Start at Top
      pct * 2 * 3.14159265,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ConcentricActivityPainter oldDelegate) {
    return oldDelegate.stepsPct != stepsPct || oldDelegate.caloriesPct != caloriesPct || oldDelegate.activeMinsPct != activeMinsPct;
  }
}

