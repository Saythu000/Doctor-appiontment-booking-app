import 'package:flutter/foundation.dart';
import '../../domain/model/booking_models.dart';
import '../../domain/model/patient_profile.dart';
import '../../data/repository/booking_repository.dart';
import '../../data/repository/health_repository.dart';
import '../../data/repository/profile_repository.dart';
import '../data/service/fhir_api_client.dart';
import '../data/service/notification_service.dart';

class BookingViewModel extends ChangeNotifier {
  final BookingRepository bookingRepository;
  final HealthRepository healthRepository;
  final ProfileRepository profileRepository;

  List<PractitionerRoleBooking> specialists = [];
  bool isSpecialistsLoading = false;

  List<BookingSlot> availableSlots = [];
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
      final orgId = await healthRepository.getSetting('iam_org_id');
      specialists = await bookingRepository.getActivePractitionerRoles(orgId: orgId);
    } catch (e) {
      if (kDebugMode) {
        print('[BookingViewModel] Failed to load specialists: $e');
      }
    } finally {
      isSpecialistsLoading = false;
      notifyListeners();
    }
  }

  /// Retrieve available slots for a specialist on a selected date
  Future<void> fetchBookedSlots(int practitionerRoleId, DateTime date) async {
    isSlotsLoading = true;
    notifyListeners();

    try {
      final orgId = await healthRepository.getSetting('iam_org_id');
      final dateStr = date.toIso8601String().split('T')[0];
      availableSlots = await bookingRepository.getAvailableSlots(
        practitionerRoleId: practitionerRoleId,
        dateString: dateStr,
        orgId: orgId,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[BookingViewModel] Failed to load slots: $e');
      }
      availableSlots = [];
    } finally {
      isSlotsLoading = false;
      notifyListeners();
    }
  }

  /// Execute slot booking checkout
  Future<Map<String, dynamic>> executeBooking({
    required int practitionerId,
    required String practitionerName,
    required String practitionerRole,
    required String practitionerImage,
    required DateTime date,
    required String timeString, // e.g. "14:30"
    required bool isVirtual,
    int? slotId,
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

      final String pName = profile.primaryName;
      final int pId = profile.id;
      final String apptTypeDisplay = isVirtual ? 'Virtual Consultation' : 'In-Person Visit';

      // Resolve valid real free slot from server if not supplied
      int effectiveSlotId = slotId ?? 0;
      if (effectiveSlotId <= 0) {
        try {
          final freeSlots = await bookingRepository.getAvailableSlots(
            practitionerRoleId: practitionerId,
            dateString: '',
            orgId: orgId,
          );
          if (freeSlots.isNotEmpty) {
            effectiveSlotId = freeSlots.first.id;
          } else {
            final resp = await FhirApiClient().client.get(
              '/api/v1/slots/',
              queryParameters: {
                'status': 'free',
                'limit': 5,
              },
            );
            final dataList = resp.data['data'] as List?;
            if (dataList != null && dataList.isNotEmpty) {
              effectiveSlotId = dataList.first['id'] as int;
            }
          }
        } catch (slotErr) {
          if (kDebugMode) {
            print('[BookingViewModel] Dynamic slot resolution error: $slotErr');
          }
        }
      }

      final result = await bookingRepository.bookSlotAtomic(
        practitionerId: practitionerId,
        slotId: effectiveSlotId,
        patientId: pId,
        orgId: orgId,
        appointmentTypeDisplay: apptTypeDisplay,
        comment: note,
        practitionerName: practitionerName,
        patientName: pName,
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
        'start_time': result['start'] ?? date.toIso8601String(),
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

  /// Reschedule an appointment to a new slot
  Future<bool> rescheduleAppointment(String appointmentId, int newSlotId) async {
    try {
      await bookingRepository.rescheduleAppointmentServer(
        appointmentId: appointmentId,
        newSlotId: newSlotId,
      );
      await fetchAppointments();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[BookingViewModel] Reschedule failed: $e');
      }
      return false;
    }
  }

  Future<void> fetchAppointments() async {
    try {
      final userId = await healthRepository.getSetting('iam_user_id') ?? '';
      final orgId = await healthRepository.getSetting('iam_org_id') ?? '';
      int? patientId;
      try {
        final profile = await profileRepository.getMyProfile(userId: userId, orgId: orgId);
        patientId = profile?.id;
      } catch (_) {}

      if (userId.isNotEmpty && orgId.isNotEmpty) {
        final serverAppts = await bookingRepository.getUserAppointments(
          userId: userId, 
          orgId: orgId,
          patientId: patientId,
        );
        
        // Clear local cache to purge any cancelled/mock records
        await healthRepository.clearLocalAppointments();
        
        for (var appt in serverAppts) {
          final id = appt['id']?.toString() ?? '';
          if (id.isEmpty) continue;

          final status = appt['status']?.toString().toLowerCase() ?? '';
          if (status == 'cancelled' || status == 'canceled' || status == 'entered-in-error' || status == 'noshow') {
            continue;
          }

          String practitionerName = 'Attending Specialist';
          final participants = appt['participant'] as List?;
          if (participants != null) {
            for (var p in participants) {
              if (p is Map<String, dynamic>) {
                final refType = p['reference_type']?.toString() ?? '';
                final actor = p['actor']?.toString() ?? '';
                if (refType == 'Practitioner' || actor.startsWith('Practitioner/')) {
                  practitionerName = p['reference_display']?.toString() ?? p['actor_display']?.toString() ?? practitionerName;
                  break;
                }
              }
            }
          }

          final start = appt['start']?.toString() ?? '';
          final type = appt['appointment_type_display']?.toString() ?? 'Consultation';
          final isVirtual = appt['appointment_type_code']?.toString().toUpperCase() == 'VIRTUAL' ? 1 : 0;

          String role = 'Specialist Care';
          String image = 'assets/doctors/doctor_1.png';
          if (practitionerName.toLowerCase().contains('kalyan')) {
            role = 'Endocrinology';
          } else if (practitionerName.toLowerCase().contains('dhakad')) {
            role = 'Endocrinology';
            image = 'assets/doctors/doctor_2.png';
          } else if (practitionerName.toLowerCase().contains('yeole')) {
            role = 'Dermatology';
            image = 'assets/doctors/doctor_3.png';
          }

          await healthRepository.saveAppointment({
            'id': id,
            'practitioner_name': practitionerName,
            'practitioner_role': role,
            'practitioner_image': image,
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

    // Clear cached last booking from profile if it matches this cancelled appointment
    final lastBookedId = await healthRepository.getProfileValue('last_booking_id');
    if (lastBookedId == id || lastBookingConfirmed?['appointment_id'] == id) {
      await healthRepository.saveProfileValue('last_booking_practitioner', '');
      await healthRepository.saveProfileValue('last_booking_start', '');
      await healthRepository.saveProfileValue('last_booking_type', '');
      await healthRepository.saveProfileValue('last_booking_id', '');
      lastBookingConfirmed = null;
    }

    final int notificationId = id.hashCode.abs() % 100000;
    await NotificationService.instance.cancelNotification(notificationId);
    await fetchAppointments();
    notifyListeners();
  }

  /// Helper to find matching PractitionerRoleBooking for an appointment record
  PractitionerRoleBooking? findSpecialistForAppointment(Map<String, dynamic> appt) {
    final docName = (appt['practitioner_name'] ?? '').toString().toLowerCase();
    for (final s in specialists) {
      final specDisplay = (s.practitionerDisplay ?? '').toLowerCase();
      if (specDisplay.isEmpty) continue;
      if (docName.isNotEmpty && (docName.contains(specDisplay) || specDisplay.contains(docName))) {
        return s;
      }
      final parts = docName.split(' ');
      if (parts.length > 1 && specDisplay.contains(parts.last.toLowerCase())) {
        return s;
      }
    }
    if (specialists.isNotEmpty) return specialists.first;
    return null;
  }
}
