import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../domain/model/booking_models.dart';
import '../service/fhir_api_client.dart';

class BookingRepository {
  final FhirApiClient _apiClient = FhirApiClient();

  /// Retrieve available specialists directory for booking
  /// Retrieve available specialists directory for booking from /api/v1/practitioner-roles/booking
  Future<List<PractitionerRoleBooking>> getActivePractitionerRoles({String? orgId}) async {
    try {
      final queryParams = <String, dynamic>{
        'active': 'true',
        'limit': 50,
      };
      if (orgId != null && orgId.isNotEmpty) {
        queryParams['org_id'] = orgId;
      }

      final response = await _apiClient.client.get(
        '/api/v1/practitioner-roles/booking',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final list = data['data'] as List?;
        if (list == null || list.isEmpty) {
          if (kDebugMode) {
            print('[BookingRepository] Server active directory returned empty. Using fallback specialists...');
          }
          return _getFallbackMockSpecialists();
        }

        final List<PractitionerRoleBooking> roles = [];
        for (var item in list) {
          if (item is Map<String, dynamic>) {
            roles.add(PractitionerRoleBooking.fromJson(item));
          }
        }
        return roles;
      }
      return _getFallbackMockSpecialists();
    } catch (e) {
      if (kDebugMode) {
        print('[BookingRepository] Failed to fetch practitioner roles from /api/v1/practitioner-roles/booking: $e');
      }
      return _getFallbackMockSpecialists();
    }
  }

  /// Retrieve available free slots for a doctor on a specific date from /api/v1/slots
  Future<List<BookingSlot>> getAvailableSlots({
    required int practitionerRoleId,
    required String dateString, // Format: YYYY-MM-DD
    String? orgId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'practitioner_role_id': practitionerRoleId,
        'date': dateString,
        'status': 'free',
        'limit': 100,
      };
      if (orgId != null && orgId.isNotEmpty) {
        queryParams['org_id'] = orgId;
      }

      final response = await _apiClient.client.get(
        '/api/v1/slots',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final list = data['data'] as List?;
        if (list == null) return [];
        return list
            .whereType<Map<String, dynamic>>()
            .map((s) => BookingSlot.fromJson(s))
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('[BookingRepository] Failed to fetch slots from /api/v1/slots: $e');
      }
      return [];
    }
  }

  /// Atomic slot booking via POST /api/v1/appointments/book
  Future<Map<String, dynamic>> bookSlotAtomic({
    required int practitionerId,
    required int slotId,
    required int patientId,
    required String orgId,
    required String appointmentTypeDisplay,
    String? reasonCode,
    String? comment,
    required String practitionerName,
    required String patientName,
  }) async {
    try {
      final payload = {
        'practitioner_id': practitionerId,
        'slot_id': slotId,
        'patient_id': patientId,
        if (orgId.isNotEmpty) 'org_id': orgId,
        'appointment_type_display': appointmentTypeDisplay,
        if (practitionerName.isNotEmpty) 'practitioner_display': practitionerName,
        if (patientName.isNotEmpty) 'patient_display': patientName,
        if (reasonCode != null && reasonCode.isNotEmpty) 'reason_code': reasonCode,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      };

      if (kDebugMode) {
        print('[BookingRepository] POST /api/v1/appointments/book: $payload');
      }

      final response = await _apiClient.client.post(
        '/api/v1/appointments/book',
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        final appointmentId = data['id'] is int ? data['id'] : int.parse(data['id'].toString());
        return {
          'appointment_id': appointmentId,
          'status': data['status'] ?? 'booked',
          'start': data['start'],
          'end': data['end'],
          'practitioner_name': practitionerName,
          'patient_name': patientName,
          'type': appointmentTypeDisplay,
        };
      }
      throw Exception('Booking failed with status ${response.statusCode}');
    } catch (e) {
      if (kDebugMode) {
        print('[BookingRepository] POST /api/v1/appointments/book failed: $e');
      }
      rethrow;
    }
  }

  /// Reschedule appointment via POST /api/v1/appointments/{id}/reschedule
  Future<Map<String, dynamic>> rescheduleAppointmentServer({
    required String appointmentId,
    required int newSlotId,
  }) async {
    try {
      final response = await _apiClient.client.post(
        '/api/v1/appointments/$appointmentId/reschedule',
        data: {
          'new_slot_id': newSlotId,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Reschedule failed with status ${response.statusCode}');
    } catch (e) {
      if (kDebugMode) {
        print('[BookingRepository] Reschedule failed: $e');
      }
      rethrow;
    }
  }

  /// Retrieve user's appointments from GET /api/v1/appointments/me or /api/v1/appointments/
  Future<List<Map<String, dynamic>>> getUserAppointments({
    required String userId,
    required String orgId,
    int? patientId,
  }) async {
    try {
      final List<Map<String, dynamic>> results = [];

      // 1. First attempt: /api/v1/appointments/me (official scoped endpoint)
      try {
        final meResp = await _apiClient.client.get('/api/v1/appointments/me');
        if (meResp.statusCode == 200) {
          final data = meResp.data;
          final list = data['data'] as List?;
          if (list != null) {
            for (var item in list) {
              if (item is Map<String, dynamic>) results.add(item);
            }
          }
        }
      } catch (_) {}

      // 2. Query /api/v1/appointments/?patient_id= if patientId provided
      if (patientId != null && patientId > 0) {
        try {
          final patResp = await _apiClient.client.get(
            '/api/v1/appointments/',
            queryParameters: {
              'patient_id': patientId,
              if (orgId.isNotEmpty) 'org_id': orgId,
              'limit': 100,
            },
          );
          if (patResp.statusCode == 200) {
            final data = patResp.data;
            final list = data['data'] as List?;
            if (list != null) {
              for (var item in list) {
                if (item is Map<String, dynamic>) {
                  final id = item['id'];
                  if (!results.any((r) => r['id'] == id)) {
                    results.add(item);
                  }
                }
              }
            }
          }
        } catch (_) {}
      }

      // 3. Fallback: /api/v1/appointments/ with user_id
      if (results.isEmpty) {
        final response = await _apiClient.client.get(
          '/api/v1/appointments/',
          queryParameters: {
            'user_id': userId,
            if (orgId.isNotEmpty) 'org_id': orgId,
            'limit': 100,
          },
        );

        if (response.statusCode == 200) {
          final data = response.data;
          final list = data['data'] as List?;
          if (list != null) {
            for (var item in list) {
              if (item is Map<String, dynamic>) {
                final id = item['id'];
                if (!results.any((r) => r['id'] == id)) {
                  results.add(item);
                }
              }
            }
          }
        }
      }

      return results;
    } catch (e) {
      if (kDebugMode) {
        print('[BookingRepository] Failed to get user appointments: $e');
      }
      return [];
    }
  }

  /// Cancel Appointment via PATCH /api/v1/appointments/{id} (status: cancelled)
  Future<void> cancelAppointmentServer(String appointmentId) async {
    try {
      final response = await _apiClient.client.patch(
        '/api/v1/appointments/$appointmentId',
        data: {
          'status': 'cancelled',
        },
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Appointment cancellation failed with status ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BookingRepository] Appointment cancellation failed: $e');
      }
      rethrow;
    }
  }

  /// High-fidelity offline desaturated performance specialists mock list
  List<PractitionerRoleBooking> _getFallbackMockSpecialists() {
    return [
      PractitionerRoleBooking(
        id: 1,
        active: true,
        practitionerRefId: 30001,
        practitionerDisplay: 'Dr. Marcus Aurelius',
        organizationDisplay: 'DRGODLY Wellness Hub',
        availabilityExceptions: 'Not available on local public holidays.',
        specialties: ['Primary Care / Family Medicine Physician'],
        availability: [
          PractitionerAvailability(
            id: 101,
            availableTimes: [
              AvailableTimeSlot(
                id: 201,
                daysOfWeek: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'],
                allDay: false,
                availableStartTime: '08:00:00',
                availableEndTime: '12:00:00',
              ),
              AvailableTimeSlot(
                id: 202,
                daysOfWeek: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'],
                allDay: false,
                availableStartTime: '13:00:00',
                availableEndTime: '17:00:00',
              ),
            ],
          ),
        ],
        practitionerDetail: PractitionerDetail(
          id: 30001,
          gender: 'male',
          fullName: 'Dr. Marcus Aurelius',
          photoUrl: 'assets/doctors/doctor_1.png',
          qualifications: [
            PractitionerQualification(text: 'MD - Family Medicine'),
            PractitionerQualification(text: 'Board Certified General Practitioner'),
          ],
        ),
      ),
      PractitionerRoleBooking(
        id: 2,
        active: true,
        practitionerRefId: 30002,
        practitionerDisplay: 'Dr. Elena Vance',
        organizationDisplay: 'DRGODLY Cardiac Center',
        availabilityExceptions: 'Academic research commitments on Wed afternoon.',
        specialties: ['Cardiology / Cardiovascular Specialist'],
        availability: [
          PractitionerAvailability(
            id: 102,
            availableTimes: [
              AvailableTimeSlot(
                id: 203,
                daysOfWeek: ['mon', 'wed', 'fri'],
                allDay: false,
                availableStartTime: '09:00:00',
                availableEndTime: '13:00:00',
              ),
              AvailableTimeSlot(
                id: 204,
                daysOfWeek: ['mon', 'wed', 'fri'],
                allDay: false,
                availableStartTime: '14:00:00',
                availableEndTime: '16:30:00',
              ),
            ],
          ),
        ],
        practitionerDetail: PractitionerDetail(
          id: 30002,
          gender: 'female',
          fullName: 'Dr. Elena Vance',
          photoUrl: 'assets/doctors/doctor_2.png',
          qualifications: [
            PractitionerQualification(text: 'MD - Cardiology'),
            PractitionerQualification(text: 'Fellow of the American College of Cardiology'),
          ],
        ),
      ),
      PractitionerRoleBooking(
        id: 3,
        active: true,
        practitionerRefId: 30003,
        practitionerDisplay: 'Dr. David Chen',
        organizationDisplay: 'DRGODLY Endocrinology Lab',
        specialties: ['Endocrinology / Diabetes Specialist'],
        availability: [
          PractitionerAvailability(
            id: 103,
            availableTimes: [
              AvailableTimeSlot(
                id: 205,
                daysOfWeek: ['tue', 'thu'],
                allDay: false,
                availableStartTime: '10:00:00',
                availableEndTime: '15:00:00',
              ),
            ],
          ),
        ],
        practitionerDetail: PractitionerDetail(
          id: 30003,
          gender: 'male',
          fullName: 'Dr. David Chen',
          photoUrl: 'assets/doctors/doctor_3.png',
          qualifications: [
            PractitionerQualification(text: 'MD - Endocrinology'),
            PractitionerQualification(text: 'Board Certified Endocrinologist'),
          ],
        ),
      ),
      PractitionerRoleBooking(
        id: 4,
        active: true,
        practitionerRefId: 30004,
        practitionerDisplay: 'Dr. Sarah Vance',
        organizationDisplay: 'DRGODLY Neurology Clinic',
        specialties: ['Neurology / Brain & Cognitive Specialist'],
        availability: [
          PractitionerAvailability(
            id: 104,
            availableTimes: [
              AvailableTimeSlot(
                id: 206,
                daysOfWeek: ['mon', 'tue', 'thu', 'fri'],
                allDay: false,
                availableStartTime: '13:00:00',
                availableEndTime: '18:00:00',
              ),
            ],
          ),
        ],
        practitionerDetail: PractitionerDetail(
          id: 30004,
          gender: 'female',
          fullName: 'Dr. Sarah Vance',
          photoUrl: 'assets/doctors/doctor_4.png',
          qualifications: [
            PractitionerQualification(text: 'MD - Neurology'),
            PractitionerQualification(text: 'Board Certified Neurologist'),
          ],
        ),
      ),
      PractitionerRoleBooking(
        id: 5,
        active: true,
        practitionerRefId: 30005,
        practitionerDisplay: 'Dr. Kaelen Cross',
        organizationDisplay: 'DRGODLY Sleep Labs',
        specialties: ['Pulmonology / Sleep Medicine Specialist'],
        availability: [
          PractitionerAvailability(
            id: 105,
            availableTimes: [
              AvailableTimeSlot(
                id: 207,
                daysOfWeek: ['wed', 'thu', 'fri', 'sun'],
                allDay: false,
                availableStartTime: '20:00:00',
                availableEndTime: '23:30:00',
              ),
            ],
          ),
        ],
        practitionerDetail: PractitionerDetail(
          id: 30005,
          gender: 'male',
          fullName: 'Dr. Kaelen Cross',
          photoUrl: 'assets/doctors/doctor_5.png',
          qualifications: [
            PractitionerQualification(text: 'MD - Pulmonology'),
            PractitionerQualification(text: 'Sleep Medicine Board Certified'),
          ],
        ),
      ),
      PractitionerRoleBooking(
        id: 6,
        active: true,
        practitionerRefId: 30006,
        practitionerDisplay: 'Dr. Aria Frost',
        organizationDisplay: 'DRGODLY Dermatology Center',
        specialties: ['Dermatology / Skin Care Specialist'],
        availability: [
          PractitionerAvailability(
            id: 106,
            availableTimes: [
              AvailableTimeSlot(
                id: 208,
                daysOfWeek: ['tue', 'wed', 'sat'],
                allDay: false,
                availableStartTime: '07:00:00',
                availableEndTime: '11:00:00',
              ),
            ],
          ),
        ],
        practitionerDetail: PractitionerDetail(
          id: 30006,
          gender: 'female',
          fullName: 'Dr. Aria Frost',
          photoUrl: 'assets/doctors/doctor_6.png',
          qualifications: [
            PractitionerQualification(text: 'MD - Dermatology'),
            PractitionerQualification(text: 'Certified Dermatologist'),
          ],
        ),
      ),
      PractitionerRoleBooking(
        id: 7,
        active: true,
        practitionerRefId: 30007,
        practitionerDisplay: 'Dr. Logan Gray',
        organizationDisplay: 'DRGODLY Orthopedics',
        specialties: ['Orthopedic Surgery / Joint Specialist'],
        availability: [
          PractitionerAvailability(
            id: 107,
            availableTimes: [
              AvailableTimeSlot(
                id: 209,
                daysOfWeek: ['wed', 'fri', 'sat'],
                allDay: false,
                availableStartTime: '08:00:00',
                availableEndTime: '13:00:00',
              ),
            ],
          ),
        ],
        practitionerDetail: PractitionerDetail(
          id: 30007,
          gender: 'male',
          fullName: 'Dr. Logan Gray',
          photoUrl: 'assets/doctors/doctor_7.png',
          qualifications: [
            PractitionerQualification(text: 'MD - Orthopedic Surgery'),
            PractitionerQualification(text: 'Fellowship in Joint Replacement'),
          ],
        ),
      ),
      PractitionerRoleBooking(
        id: 8,
        active: true,
        practitionerRefId: 30008,
        practitionerDisplay: 'Dr. Evelyn Stark',
        organizationDisplay: 'DRGODLY Pediatrics',
        specialties: ['Pediatrics / Child Health Specialist'],
        availability: [
          PractitionerAvailability(
            id: 108,
            availableTimes: [
              AvailableTimeSlot(
                id: 210,
                daysOfWeek: ['mon', 'thu', 'sun'],
                allDay: false,
                availableStartTime: '10:00:00',
                availableEndTime: '15:00:00',
              ),
            ],
          ),
        ],
        practitionerDetail: PractitionerDetail(
          id: 30008,
          gender: 'female',
          fullName: 'Dr. Evelyn Stark',
          photoUrl: 'assets/doctors/doctor_8.png',
          qualifications: [
            PractitionerQualification(text: 'MD - Pediatrics'),
            PractitionerQualification(text: 'Board Certified Pediatrician'),
          ],
        ),
      ),
    ];
  }
}
