import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/notification_center_modal.dart';
import '../../viewmodel/activity_viewmodel.dart';
import '../../viewmodel/profile_viewmodel.dart';
import '../../viewmodel/booking_viewmodel.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/image_helper.dart';
import '../devices/device_manager_sheet.dart';
import '../../data/service/ble_heart_rate_service.dart';

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
            backgroundColor: PhiaColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Cancel Appointment',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: PhiaColors.navyAnchor,
              ),
            ),
            content: Text(
              'Are you sure you want to cancel your consultation with $doctorName?',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: PhiaColors.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Keep Appointment',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: PhiaColors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PhiaColors.pulseRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  context.read<BookingViewModel>().cancelAppointment(id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Appointment with $doctorName cancelled.')),
                  );
                },
                child: const Text('Cancel Visit'),
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
        dateFormatted = DateFormat('EEEE, MMMM d, yyyy').format(dateTime);
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
            backgroundColor: PhiaColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Consultation Details',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: PhiaColors.navyAnchor,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 52,
                        height: 52,
                        color: PhiaColors.surfaceSubtle,
                        child: SafeNetworkImage(
                          imageUrl: imageUrl,
                          width: 52,
                          height: 52,
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
                              color: PhiaColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isVirtual ? 'VIDEO CONSULTATION' : 'IN-CLINIC VISIT',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: PhiaColors.navyAnchor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: PhiaColors.textPrimary,
                            ),
                          ),
                          Text(
                            role,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: PhiaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: PhiaColors.borderSubtle),
                const SizedBox(height: 12),
                Text(
                  'DATE & TIME',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: PhiaColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$dateFormatted · $timeFormatted',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PhiaColors.textPrimary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: PhiaColors.textSecondary,
                  ),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: PhiaColors.primary),
                  foregroundColor: PhiaColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  final specialist = bookingVM.findSpecialistForAppointment(appt);
                  Navigator.pushNamed(
                    context,
                    '/booking_date_time',
                    arguments: {
                      'specialist': specialist,
                      'name': name,
                      'role': role,
                      'imageUrl': image,
                      'reschedule_appointment_id': id,
                    },
                  );
                },
                child: const Text('Reschedule'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PhiaColors.pulseRedLight,
                  foregroundColor: PhiaColors.pulseRed,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  showCancelConfirmation(context, id, name);
                },
                child: const Text('Cancel Visit'),
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

    String stepsStr = steps.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    // BMI Calculations
    double bmi = 0.0;
    String bmiClassification = 'Normal';
    Color bmiColor = PhiaColors.activeGreen;
    Color bmiBg = PhiaColors.activeGreenBg;
    if (activityVM.userHeight > 0 && activityVM.userWeight > 0) {
      double heightM = activityVM.userHeight / 100.0;
      bmi = activityVM.userWeight / (heightM * heightM);
      if (bmi < 18.5) {
        bmiClassification = 'Underweight';
        bmiColor = PhiaColors.primary;
        bmiBg = PhiaColors.primaryLight;
      } else if (bmi < 25.0) {
        bmiClassification = 'Optimal';
        bmiColor = PhiaColors.activeGreen;
        bmiBg = PhiaColors.activeGreenBg;
      } else if (bmi < 30.0) {
        bmiClassification = 'Overweight';
        bmiColor = PhiaColors.amberWarning;
        bmiBg = const Color(0xFFFEF3C7);
      } else {
        bmiClassification = 'Obese';
        bmiColor = PhiaColors.pulseRed;
        bmiBg = PhiaColors.pulseRedLight;
      }
    }

    String formatAppointmentDate(String? isoString) {
      if (isoString == null || isoString.isEmpty) return 'N/A';
      try {
        final dt = DateTime.parse(isoString).toLocal();
        return DateFormat('EEE, MMM d · hh:mm a').format(dt);
      } catch (_) {
        return isoString;
      }
    }

    final patientGivenName = (profileVM.currentProfile?.name != null && profileVM.currentProfile!.name!.isNotEmpty)
        ? profileVM.currentProfile!.name!.first.givenName
        : 'Sarah';

    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.primary,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'DRGODLY',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Connect Wearable',
            onPressed: () => DeviceManagerSheet.show(context),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.watch_rounded, color: Colors.white),
                if (activityVM.bleService.currentState == BleDeviceState.connected)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: PhiaColors.activeGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => showNotificationCenter(context),
            icon: const Icon(Icons.notifications_rounded, color: Colors.white),
          ),
          IconButton(
            onPressed: () => onTabSelected?.call(2),
            icon: const Icon(Icons.search_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Patient Greeting Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, $patientGivenName',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: PhiaColors.navyAnchor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your clinical telemetry is synchronized.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: PhiaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: PhiaColors.activeGreenBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: PhiaColors.activeGreen.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                            'Active',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CARD 1: UPCOMING CONSULTATIONS (Navy Header Banner)
              _buildNavyCard(
                title: 'Upcoming Consultations',
                actionWidget: nearestUpcoming != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: PhiaColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'TELEHEALTH',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: nearestUpcoming != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    color: PhiaColors.surfaceSubtle,
                                    child: SafeNetworkImage(
                                      imageUrl: nearestUpcoming['practitioner_image']?.toString() ?? '',
                                      width: 50,
                                      height: 50,
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
                                        nearestUpcoming['practitioner_name']?.toString() ?? 'Specialist',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: PhiaColors.navyAnchor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        nearestUpcoming['practitioner_role']?.toString() ?? 'General Practice',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: PhiaColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatAppointmentDate(nearestUpcoming['start_time']?.toString()),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: PhiaColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => showAppointmentDetails(nearestUpcoming!),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: PhiaColors.borderSubtle),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: Text(
                                      'View Details',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: PhiaColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => showAppointmentDetails(nearestUpcoming!),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: PhiaColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: Text(
                                      'Enter Room',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: PhiaColors.primaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.calendar_today_rounded, size: 18, color: PhiaColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No visits today',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: PhiaColors.navyAnchor,
                                      ),
                                    ),
                                    Text(
                                      'Consult top verified specialists',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: PhiaColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => onTabSelected?.call(2),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  backgroundColor: PhiaColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  'Book Doctor',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // CARD 2: ENERGY METER / BODY BATTERY (boAt Parity)
              _buildNavyCard(
                title: 'Energy Meter & Body Battery',
                actionWidget: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: activityVM.energyMeterScore >= 60 ? PhiaColors.activeGreen : PhiaColors.amberWarning,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    activityVM.energyMeterScore >= 75 ? 'HIGH' : (activityVM.energyMeterScore >= 40 ? 'OPTIMAL' : 'DRAINED'),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Color(0xFF16A34A), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${activityVM.energyMeterScore}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: PhiaColors.navyAnchor,
                                  ),
                                ),
                                Text(
                                  ' / 100',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: PhiaColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: activityVM.energyMeterScore / 100.0,
                                minHeight: 6,
                                backgroundColor: PhiaColors.borderSubtle,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  activityVM.energyMeterScore >= 60 ? PhiaColors.activeGreen : PhiaColors.amberWarning,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Energy readiness computed from sleep restorative depth and physical exertion.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: PhiaColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // CARD 3: DAILY VITALITY PROGRESS (Navy Header Banner)
              _buildNavyCard(
                title: 'Daily Vitality Progress',
                actionWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => DeviceManagerSheet.show(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: activityVM.bleService.currentState == BleDeviceState.connected
                              ? PhiaColors.activeGreen
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              activityVM.bleService.currentState == BleDeviceState.connected
                                  ? Icons.bluetooth_connected_rounded
                                  : Icons.watch_outlined,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              activityVM.bleService.currentState == BleDeviceState.connected
                                  ? (activityVM.connectedBleDeviceName ?? 'Watch')
                                  : 'Pair Watch',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => onTabSelected?.call(1),
                      child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () => onTabSelected?.call(1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                      // Concentric Progress Painter
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(110, 110),
                              painter: ConcentricActivityPainter(
                                stepsPct: progressSteps,
                                caloriesPct: progressCalories,
                                activeMinsPct: progressActiveMins,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${((progressSteps + progressCalories + progressActiveMins) / 3 * 100).toStringAsFixed(0)}%',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: PhiaColors.navyAnchor,
                                  ),
                                ),
                                Text(
                                  'Score',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: PhiaColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          children: [
                            _buildMetricRow('Steps', stepsStr, '10,000 Goal', PhiaColors.primary),
                            const Divider(color: PhiaColors.borderSubtle, height: 16),
                            _buildMetricRow('Calories', '$calories kcal', '500 kcal Goal', const Color(0xFF4BAAE5)),
                            const Divider(color: PhiaColors.borderSubtle, height: 16),
                            _buildMetricRow('Active Time', '$activeMins min', '60 min Goal', PhiaColors.activeGreen),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ),
              const SizedBox(height: 16),

              // CARD 4: 2x2 CLINICAL BIOMETRICS (with Min/Max Heart Rate Curve)
              Row(
                children: [
                  Expanded(
                    child: _buildVitalsTile(
                      title: 'Resting HR',
                      value: activityVM.dashboardHr > 0
                          ? activityVM.dashboardHr.toInt().toString()
                          : (activityVM.bleService.currentState == BleDeviceState.connected ? '--' : '64'),
                      unit: 'bpm',
                      subtitle: (activityVM.dashboardMinHr != null && activityVM.dashboardMaxHr != null)
                          ? '${activityVM.dashboardMinHr} - ${activityVM.dashboardMaxHr} bpm'
                          : null,
                      status: activityVM.bleService.currentState == BleDeviceState.connected && activityVM.dashboardHr > 0
                          ? 'Live BLE'
                          : (activityVM.bleService.currentState == BleDeviceState.connected && activityVM.dashboardHr == 0
                              ? 'Measuring...'
                              : (activityVM.isOpenWearablesSynced ? 'Health Connect' : 'Normal')),
                      statusColor: (activityVM.bleService.currentState == BleDeviceState.connected && activityVM.dashboardHr == 0)
                          ? PhiaColors.amberWarning
                          : const Color(0xFF15803D),
                      statusBg: (activityVM.bleService.currentState == BleDeviceState.connected && activityVM.dashboardHr == 0)
                          ? const Color(0xFFFEF3C7)
                          : PhiaColors.activeGreenBg,
                      icon: Icons.favorite_rounded,
                      iconColor: PhiaColors.pulseRed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalsTile(
                      title: 'Heart Rate Var.',
                      value: activityVM.dashboardHrv > 0
                          ? activityVM.dashboardHrv.toStringAsFixed(0)
                          : (activityVM.bleService.currentState == BleDeviceState.connected ? '--' : '58'),
                      unit: 'ms',
                      status: activityVM.dashboardHrv > 0
                          ? (activityVM.isOpenWearablesSynced ? 'Health Connect' : 'Optimal')
                          : (activityVM.bleService.currentState == BleDeviceState.connected ? 'Analyzing' : 'Optimal'),
                      statusColor: const Color(0xFF15803D),
                      statusBg: PhiaColors.activeGreenBg,
                      icon: Icons.graphic_eq_rounded,
                      iconColor: PhiaColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildVitalsTile(
                      title: 'Sleep Architecture',
                      value: activityVM.currentSleep > 0
                          ? '${activityVM.currentSleep.toStringAsFixed(1)}h'
                          : '--',
                      unit: activityVM.currentSleep > 0 ? 'Watch Synced' : 'Pending Sync',
                      status: activityVM.currentSleep > 0 ? 'Recorded' : 'Pending',
                      statusColor: activityVM.currentSleep > 0 ? PhiaColors.navyAnchor : const Color(0xFF64748B),
                      statusBg: activityVM.currentSleep > 0 ? PhiaColors.primaryLight : const Color(0xFFF1F5F9),
                      icon: Icons.bedtime_rounded,
                      iconColor: const Color(0xFF4BAAE5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalsTile(
                      title: 'Blood Oxygen',
                      value: activityVM.dashboardSpo2 != null && activityVM.dashboardSpo2! > 0
                          ? '${activityVM.dashboardSpo2!.toInt()}'
                          : '--',
                      unit: '% SpO2',
                      status: activityVM.dashboardSpo2 != null && activityVM.dashboardSpo2! > 0
                          ? (activityVM.dashboardSpo2! >= 95 ? 'Healthy' : 'Low')
                          : 'Pending',
                      statusColor: activityVM.dashboardSpo2 != null && activityVM.dashboardSpo2! >= 95
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB45309),
                      statusBg: activityVM.dashboardSpo2 != null && activityVM.dashboardSpo2! >= 95
                          ? PhiaColors.activeGreenBg
                          : const Color(0xFFFEF3C7),
                      icon: Icons.air_rounded,
                      iconColor: PhiaColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // CARD 4: CLINICAL BASELINE & BMI
              _buildNavyCard(
                title: 'Clinical Baseline & Body Metrics',
                actionWidget: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: bmiBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    bmiClassification,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: bmiColor,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Height', '${activityVM.userHeight.toStringAsFixed(0)} cm'),
                      Container(width: 1, height: 28, color: PhiaColors.borderSubtle),
                      _buildStatColumn('Weight', '${activityVM.userWeight.toStringAsFixed(1)} kg'),
                      Container(width: 1, height: 28, color: PhiaColors.borderSubtle),
                      _buildStatColumn('Age', '${activityVM.userAge} yrs'),
                      Container(width: 1, height: 28, color: PhiaColors.borderSubtle),
                      _buildStatColumn('BMI', bmi > 0 ? bmi.toStringAsFixed(1) : 'N/A'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavyCard({
    required String title,
    required Widget child,
    Widget? actionWidget,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PhiaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhiaColors.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: PhiaColors.navyAnchor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                if (actionWidget != null) actionWidget,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, String goal, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: PhiaColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PhiaColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Text(
          goal,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: PhiaColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildVitalsTile({
    required String title,
    required String value,
    required String unit,
    String? subtitle,
    required String status,
    required Color statusColor,
    required Color statusBg,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PhiaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhiaColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: PhiaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: PhiaColors.navyAnchor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: PhiaColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: PhiaColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: PhiaColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: PhiaColors.navyAnchor,
          ),
        ),
      ],
    );
  }
}

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
    final double spacing = 4.0;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // Ring 1 (outermost): Steps (Primary Sky Blue)
    double r1 = size.width / 2 - strokeW / 2;
    _drawRing(canvas, center, r1, strokeW, stepsPct, PhiaColors.primary, PhiaColors.primary.withOpacity(0.12));

    // Ring 2 (middle): Calories (Clinical Cyan)
    double r2 = r1 - strokeW - spacing;
    _drawRing(canvas, center, r2, strokeW, caloriesPct, const Color(0xFF4BAAE5), const Color(0xFF4BAAE5).withOpacity(0.12));

    // Ring 3 (innermost): Active Mins (Active Green)
    double r3 = r2 - strokeW - spacing;
    _drawRing(canvas, center, r3, strokeW, activeMinsPct, PhiaColors.activeGreen, PhiaColors.activeGreen.withOpacity(0.12));
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
      -3.14159265 / 2,
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
