import 'package:flutter/foundation.dart';
import 'dart:math';
import '../../domain/model/booking_models.dart';
import '../../domain/model/patient_profile.dart';
import '../../data/repository/booking_repository.dart';
import '../../data/repository/health_repository.dart';
import '../../data/repository/profile_repository.dart';
import '../data/service/notification_service.dart';

class BookingViewModel extends ChangeNotifier {
  final BookingRepository bookingRepository;
  final HealthRepository healthRepository;
  final ProfileRepository profileRepository;

  List<PractitionerRoleBooking> specialists = [];
  bool isSpecialistsLoading = false;

  Set<String> bookedSlots = {};
  bool isSlotsLoading = false;

  List<Map<String, dynamic>> appointmentsList = [];
  bool isBookingExecuting = false;
  Map<String, dynamic>? lastBookingConfirmed;

  BookingViewModel({
    required this.bookingRepository,
    required this.healthRepository,
    required this.profileRepository,
  }) {
    fetchAppointments();
    _loadLastBookingFromLocal();
  }

  Future<void> _loadLastBookingFromLocal() async {
    final lastBookedDoctor = await healthRepository.getProfileValue('last_booking_practitioner');
    if (lastBookedDoctor != null) {
      final lastBookedStart = await healthRepository.getProfileValue('last_booking_start');
      final lastBookedType = await healthRepository.getProfileValue('last_booking_type');
      final lastBookedId = await healthRepository.getProfileValue('last_booking_id');
      lastBookingConfirmed = {
        'practitioner_name': lastBookedDoctor,
        'start': lastBookedStart,
        'type': lastBookedType,
        'appointment_id': lastBookedId,
      };
      notifyListeners();
    }
  }

  /// Fetch available specialists from FHIR server
  Future<void> fetchSpecialists() async {
    isSpecialistsLoading = true;
    notifyListeners();

    try {
      specialists = await bookingRepository.getActivePractitionerRoles();
    } catch (e) {
      if (kDebugMode) {
        print('[BookingViewModel] Failed to load specialists: $e');
      }
    } finally {
      isSpecialistsLoading = false;
      notifyListeners();
    }
  }

  /// Retrieve booked slots for a specialist on a selected date
  Future<void> fetchBookedSlots(int practitionerId, DateTime date) async {
    isSlotsLoading = true;
    notifyListeners();

    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final times = await bookingRepository.getBookedSlotsForDoctor(
        practitionerId: practitionerId,
        dateString: dateStr,
      );
      bookedSlots = Set<String>.from(times);
    } catch (e) {
      if (kDebugMode) {
        print('[BookingViewModel] Failed to load booked slots: $e');
      }
      bookedSlots = {};
    } finally {
      isSlotsLoading = false;
      notifyListeners();
    }
  }

  /// Execute double FHIR resource transaction checkout
  Future<Map<String, dynamic>> executeBooking({
    required int practitionerId,
    required String practitionerName,
    required String practitionerRole,
    required String practitionerImage,
    required DateTime date,
    required String timeString, // e.g. "14:30"
    required bool isVirtual,
    String? note,
  }) async {
    isBookingExecuting = true;
    notifyListeners();

    try {
      // Fetch profile to get patient details
      final userId = await healthRepository.getSetting('iam_user_id') ?? '';
      final orgId = await healthRepository.getSetting('iam_org_id') ?? '';
      PlainPatient? profile = await profileRepository.getMyProfile(userId: userId, orgId: orgId);
      profile ??= await profileRepository.createInitialProfile(userId: userId, orgId: orgId);

      // Calculate start and end ISO datetimes
      final localDate = DateTime(date.year, date.month, date.day);
      final timeParts = timeString.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      final startDateTime = DateTime(localDate.year, localDate.month, localDate.day, hour, minute);
      final endDateTime = startDateTime.add(const Duration(minutes: 30));

      final startIso = '${startDateTime.toUtc().toIso8601String().replaceAll('Z', '')}Z';
      final endIso = '${endDateTime.toUtc().toIso8601String().replaceAll('Z', '')}Z';

      final String pName = profile.primaryName;
      final int pId = profile.id;

      final result = await bookingRepository.createAppointmentWithEncounter(
        patientId: pId,
        patientName: pName,
        practitionerId: practitionerId,
        practitionerName: practitionerName,
        startTimeIso: startIso,
        endTimeIso: endIso,
        isVirtual: isVirtual,
        userId: userId,
        orgId: orgId,
        note: note,
      );

      lastBookingConfirmed = result;
      
      await healthRepository.saveProfileValue('last_booking_practitioner', practitionerName);
      if (result['start'] != null) {
        await healthRepository.saveProfileValue('last_booking_start', result['start'].toString());
      }
      if (result['type'] != null) {
        await healthRepository.saveProfileValue('last_booking_type', result['type'].toString());
      }
      if (result['appointment_id'] != null) {
        await healthRepository.saveProfileValue('last_booking_id', result['appointment_id'].toString());
      }

      final appointmentId = result['appointment_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      final apptData = {
        'id': appointmentId,
        'practitioner_name': practitionerName,
        'practitioner_role': practitionerRole,
        'practitioner_image': practitionerImage,
        'start_time': startIso,
        'type': isVirtual ? 'Virtual Consultation' : 'In-Person Visit',
        'is_virtual': isVirtual ? 1 : 0,
      };
      await healthRepository.saveAppointment(apptData);

      await fetchAppointments();
      
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('[BookingViewModel] Booking checkout failed: $e');
      }
      rethrow;
    } finally {
      isBookingExecuting = false;
      notifyListeners();
    }
  }

  Future<void> fetchAppointments() async {
    try {
      final userId = await healthRepository.getSetting('iam_user_id') ?? '';
      final orgId = await healthRepository.getSetting('iam_org_id') ?? '';

      if (userId.isNotEmpty && orgId.isNotEmpty) {
        final serverAppts = await bookingRepository.getUserAppointments(userId: userId, orgId: orgId);
        
        // Clear local cache to purge any cancelled/mock records
        await healthRepository.clearLocalAppointments();
        
        for (var appt in serverAppts) {
          final id = appt['id']?.toString() ?? '';
          if (id.isEmpty) continue;

          String practitionerName = 'Attending Specialist';
          final participants = appt['participant'] as List?;
          if (participants != null) {
            for (var p in participants) {
              if (p is Map<String, dynamic>) {
                final actor = p['actor']?.toString() ?? '';
                if (actor.startsWith('Practitioner/')) {
                  practitionerName = p['actor_display']?.toString() ?? practitionerName;
                  break;
                }
              }
            }
          }

          final start = appt['start']?.toString() ?? '';
          final type = appt['appointment_type_display']?.toString() ?? 'Consultation';
          final isVirtual = appt['appointment_type_code']?.toString().toUpperCase() == 'VIRTUAL' ? 1 : 0;

          await healthRepository.saveAppointment({
            'id': id,
            'practitioner_name': practitionerName,
            'practitioner_role': 'Specialist Care',
            'practitioner_image': isVirtual == 1
                ? 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?q=80&w=500'
                : 'https://images.unsplash.com/photo-1567013127542-490d757e51fc?q=80&w=500',
            'start_time': start,
            'type': type,
            'is_virtual': isVirtual,
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BookingViewModel] Error syncing appointments from server: $e');
      }
    }

    final list = await healthRepository.getAppointments();
    appointmentsList = list;

    final now = DateTime.now();
    for (var appt in appointmentsList) {
      try {
        final startTimeStr = appt['start_time'] as String;
        final startTime = DateTime.parse(startTimeStr).toLocal();
        
        if (startTime.isAfter(now)) {
          final notifyTime = startTime.subtract(const Duration(minutes: 30));
          final int notificationId = appt['id'].hashCode.abs() % 100000;
          final docName = appt['practitioner_name'] as String;
          final type = appt['type'] as String;

          await NotificationService.instance.scheduleOneOffNotification(
            id: notificationId,
            title: 'Upcoming Appointment',
            body: 'Your $type with $docName is in 30 minutes.',
            scheduledDateTime: notifyTime,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('[BookingViewModel] Failed to schedule notification: $e');
        }
      }
    }

    notifyListeners();
  }

  Future<void> cancelAppointment(String id) async {
    try {
      if (!id.startsWith('mock_')) {
        await bookingRepository.cancelAppointmentServer(id);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BookingViewModel] Cancel on server failed, but proceeding with local removal: $e');
      }
    }
    await healthRepository.deleteAppointment(id);
    final int notificationId = id.hashCode.abs() % 100000;
    await NotificationService.instance.cancelNotification(notificationId);
    await fetchAppointments();
  }
}
