import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/notification_center_modal.dart';
import '../../viewmodel/activity_viewmodel.dart';
import '../../viewmodel/profile_viewmodel.dart';
import '../../viewmodel/booking_viewmodel.dart';
import '../../viewmodel/auth_viewmodel.dart';
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
    final authVM = context.watch<AuthViewModel>();

    // Get nearest upcoming appointment
    Map<String, dynamic>? nearestUpcoming;
    final now = DateTime.now();
    for (var appt in bookingVM.appointmentsList) {
      try {
        final status = (appt['status'] as String? ?? '').toLowerCase();
        if (status == 'fulfilled' || status == 'noshow' || status == 'cancelled' || status == 'canceled') {
          continue;
        }
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

      final status = (appt['status']?.toString().toLowerCase()) ?? 'pending';

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

      // Status badge styling
      Color statusBg;
      Color statusTextColor;
      String statusLabel;
      switch (status) {
        case 'booked':
        case 'confirmed':
          statusBg = const Color(0xFFDCFCE7);
          statusTextColor = const Color(0xFF15803D);
          statusLabel = 'CONFIRMED';
          break;
        case 'rescheduled':
          statusBg = const Color(0xFFEDE9FE);
          statusTextColor = const Color(0xFF6D28D9);
          statusLabel = 'RESCHEDULED';
          break;
        case 'cancelled':
        case 'canceled':
          statusBg = PhiaColors.pulseRedLight;
          statusTextColor = PhiaColors.pulseRed;
          statusLabel = 'CANCELLED';
          break;
        case 'pending':
        default:
          statusBg = const Color(0xFFFEF3C7);
          statusTextColor = const Color(0xFFB45309);
          statusLabel = 'PENDING';
          break;
      }

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: PhiaColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Consultation Details',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: PhiaColors.navyAnchor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusTextColor,
                    ),
                  ),
                ),
              ],
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
                const SizedBox(height: 12),
                Text(
                  'STATUS',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: PhiaColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusTextColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status == 'booked'
                          ? 'Confirmed by Doctor'
                          : (status == 'pending'
                              ? 'Awaiting Doctor Confirmation'
                              : (status == 'rescheduled' ? 'Rescheduled' : 'Cancelled')),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PhiaColors.textPrimary,
                      ),
                    ),
                  ],
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

    String patientGivenName = 'User';
    if (profileVM.currentProfile?.name != null &&
        profileVM.currentProfile!.name!.isNotEmpty &&
        profileVM.currentProfile!.name!.first.givenName.trim().isNotEmpty) {
      patientGivenName = profileVM.currentProfile!.name!.first.givenName.trim();
    } else if (authVM.user?.name != null && authVM.user!.name.trim().isNotEmpty) {
      patientGivenName = authVM.user!.name.trim().split(' ').first;
    }

    return Scaffold(
      backgroundColor: PhiaColors.background,
      appBar: AppBar(
        backgroundColor: PhiaColors.primary,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/app_logo.jpeg',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'DrGodly',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => showNotificationCenter(context),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_rounded, color: Colors.white),
                if (bookingVM.appointmentsList.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: PhiaColors.pulseRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '${bookingVM.appointmentsList.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onTabSelected?.call(2),
            icon: const Icon(Icons.search_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: PhiaColors.primary,
          onRefresh: () async {
            await activityVM.syncOpenWearablesVitals('Android Health Connect');
            await activityVM.initDashboard();
            if (context.mounted) {
              await context.read<ProfileViewModel>().fetchOrInitProfile();
            }
            if (context.mounted) {
              await context.read<BookingViewModel>().fetchAppointments();
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                        border: Border.all(color: PhiaColors.activeGreen.withValues(alpha: 0.3)),
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
                    ? Builder(
                        builder: (context) {
                          final status = (nearestUpcoming!['status']?.toString().toLowerCase()) ?? 'pending';
                          Color badgeBg;
                          Color badgeTextColor;
                          String badgeText;

                          switch (status) {
                            case 'fulfilled':
                            case 'completed':
                              badgeBg = const Color(0xFFDCFCE7);
                              badgeTextColor = const Color(0xFF15803D);
                              badgeText = 'FULFILLED';
                              break;
                            case 'noshow':
                            case 'no-show':
                              badgeBg = const Color(0xFFF1F5F9);
                              badgeTextColor = const Color(0xFF64748B);
                              badgeText = 'MISSED';
                              break;
                            case 'booked':
                            case 'confirmed':
                              badgeBg = const Color(0xFFDCFCE7);
                              badgeTextColor = const Color(0xFF15803D);
                              badgeText = 'CONFIRMED';
                              break;
                            case 'rescheduled':
                              badgeBg = const Color(0xFFEDE9FE);
                              badgeTextColor = const Color(0xFF6D28D9);
                              badgeText = 'RESCHEDULED';
                              break;
                            case 'cancelled':
                            case 'canceled':
                              badgeBg = PhiaColors.pulseRedLight;
                              badgeTextColor = PhiaColors.pulseRed;
                              badgeText = 'CANCELLED';
                              break;
                            case 'pending':
                            default:
                              badgeBg = const Color(0xFFFEF3C7);
                              badgeTextColor = const Color(0xFFB45309);
                              badgeText = 'PENDING';
                              break;
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: badgeTextColor,
                              ),
                            ),
                          );
                        },
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
                                      'No upcoming consultations',
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
              const SizedBox(height: 14),

              // CARD 1.5: AI PRE-VISIT CLINICAL INTAKE (Text Chat)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F4C81), Color(0xFF1E6B9B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F4C81).withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).pushNamed('/intake');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.smart_toy_outlined,
                              color: Colors.white,
                              size: 26,
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
                                      'DrGodly Pre-Visit Clinical Intake',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.tealAccent.shade400,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '2 MIN',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F4C81),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Describe symptoms to DrGodly before seeing the doctor',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // CARD 2: DAILY VITALITY PROGRESS (Navy Header Banner)
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
                          : '--',
                      unit: 'bpm',
                      subtitle: (activityVM.dashboardMinHr != null && activityVM.dashboardMaxHr != null)
                          ? '${activityVM.dashboardMinHr} - ${activityVM.dashboardMaxHr} bpm'
                          : null,
                      icon: Icons.favorite_rounded,
                      iconColor: PhiaColors.pulseRed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalsTile(
                      title: 'Distance Walked',
                      value: activityVM.dashboardDistanceKm > 0
                          ? activityVM.dashboardDistanceKm.toStringAsFixed(2)
                          : '0.00',
                      unit: 'km',
                      icon: Icons.straighten_rounded,
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
                      title: 'Sleep Duration',
                      value: activityVM.currentSleep > 0
                          ? activityVM.currentSleep.toStringAsFixed(1)
                          : '--',
                      unit: 'h',
                      subtitle: (activityVM.deepSleepMinutes > 0 || activityVM.lightSleepMinutes > 0)
                          ? '${activityVM.deepSleepMinutes}m Deep • ${activityVM.lightSleepMinutes}m Light'
                          : null,
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
                onTap: () => _showEditBodyMetricsSheet(context, activityVM),
                actionWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
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
                    const SizedBox(width: 8),
                    const Icon(Icons.edit_outlined, size: 14, color: Colors.white70),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Height', activityVM.userHeight > 0 ? '${activityVM.userHeight.toStringAsFixed(0)} cm' : '--'),
                      Container(width: 1, height: 28, color: PhiaColors.borderSubtle),
                      _buildStatColumn('Weight', activityVM.userWeight > 0 ? '${activityVM.userWeight.toStringAsFixed(1)} kg' : '--'),
                      Container(width: 1, height: 28, color: PhiaColors.borderSubtle),
                      _buildStatColumn('Age', activityVM.userAge > 0 ? '${activityVM.userAge} yrs' : '--'),
                      Container(width: 1, height: 28, color: PhiaColors.borderSubtle),
                      _buildStatColumn('BMI', bmi > 0 ? bmi.toStringAsFixed(1) : '--'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _showEditBodyMetricsSheet(BuildContext context, ActivityViewModel activityVM) {
    final heightController = TextEditingController(
      text: activityVM.userHeight > 0 ? activityVM.userHeight.toStringAsFixed(0) : '',
    );
    final weightController = TextEditingController(
      text: activityVM.userWeight > 0 ? activityVM.userWeight.toStringAsFixed(1) : '',
    );
    final ageController = TextEditingController(
      text: activityVM.userAge > 0 ? activityVM.userAge.toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: PhiaColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: PhiaColors.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Body Metrics',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: PhiaColors.navyAnchor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: PhiaColors.textMuted),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HEIGHT (CM)',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: PhiaColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: PhiaColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: PhiaColors.borderSubtle),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: TextField(
                              controller: heightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
                              style: GoogleFonts.inter(fontSize: 14, color: PhiaColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'e.g. 175',
                                hintStyle: GoogleFonts.inter(fontSize: 13, color: PhiaColors.textMuted),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WEIGHT (KG)',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: PhiaColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: PhiaColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: PhiaColors.borderSubtle),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: TextField(
                              controller: weightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.inter(fontSize: 14, color: PhiaColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'e.g. 70.5',
                                hintStyle: GoogleFonts.inter(fontSize: 13, color: PhiaColors.textMuted),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AGE (YEARS)',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: PhiaColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: PhiaColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: PhiaColors.borderSubtle),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: ageController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        style: GoogleFonts.inter(fontSize: 14, color: PhiaColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. 28',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: PhiaColors.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final h = double.tryParse(heightController.text.trim()) ?? 0.0;
                    final w = double.tryParse(weightController.text.trim()) ?? 0.0;
                    final a = double.tryParse(ageController.text.trim()) ?? 0.0;
                    Navigator.pop(sheetCtx);
                    if (h > 0 || w > 0 || a > 0) {
                      await activityVM.saveBioData(
                        weight: w > 0 ? w : activityVM.userWeight,
                        height: h > 0 ? h : activityVM.userHeight,
                        age: a > 0 ? a : (activityVM.userAge > 0 ? activityVM.userAge.toDouble() : 25.0),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: PhiaColors.activeGreen,
                            content: Text(
                              'Body metrics updated!',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PhiaColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Save Body Metrics',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavyCard({
    required String title,
    required Widget child,
    Widget? actionWidget,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PhiaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PhiaColors.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
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
    _drawRing(canvas, center, r1, strokeW, stepsPct, PhiaColors.primary, PhiaColors.primary.withValues(alpha: 0.12));

    // Ring 2 (middle): Calories (Clinical Cyan)
    double r2 = r1 - strokeW - spacing;
    _drawRing(canvas, center, r2, strokeW, caloriesPct, const Color(0xFF4BAAE5), const Color(0xFF4BAAE5).withValues(alpha: 0.12));

    // Ring 3 (innermost): Active Mins (Active Green)
    double r3 = r2 - strokeW - spacing;
    _drawRing(canvas, center, r3, strokeW, activeMinsPct, PhiaColors.activeGreen, PhiaColors.activeGreen.withValues(alpha: 0.12));
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
