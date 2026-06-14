import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../domain/model/booking_models.dart';
import '../service/fhir_api_client.dart';

class BookingRepository {
  final FhirApiClient _apiClient = FhirApiClient();

  /// Retrieve available specialists directory for booking
  Future<List<PractitionerRoleBooking>> getActivePractitionerRoles() async {
    try {
      final response = await _apiClient.client.get(
        '/api/fhir/v1/practitioner-roles/',
        queryParameters: {
          'active': 'true',
          'limit': 50,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final list = data['data'] as List?;
        if (list == null || list.isEmpty) {
          if (kDebugMode) {
            print('[BookingRepository] Server active directory is empty. Hydrating fallback specialists...');
          }
          return _getFallbackMockSpecialists();
        }

        final List<PractitionerRoleBooking> roles = [];
        final List<Future<PractitionerDetail?>> futures = [];

        for (var item in list) {
          if (item is Map<String, dynamic>) {
            final role = PractitionerRoleBooking.fromJson(item);
            roles.add(role);
            if (role.practitionerRefId != null) {
              futures.add(_fetchPractitionerDetail(role.practitionerRefId!));
            } else {
              futures.add(Future.value(null));
            }
          }
        }

        final details = await Future.wait(futures);
        
        final List<PractitionerRoleBooking> enrichedRoles = [];
        for (int i = 0; i < roles.length; i++) {
          final role = roles[i];
          final detail = details[i];
          
          enrichedRoles.add(PractitionerRoleBooking(
            id: role.id,
            active: role.active,
            practitionerRefId: role.practitionerRefId,
            practitionerDisplay: role.practitionerDisplay,
            organizationDisplay: role.organizationDisplay,
            availabilityExceptions: role.availabilityExceptions,
            specialties: role.specialties,
            availability: role.availability,
            practitionerDetail: detail ?? role.practitionerDetail,
            orgId: role.orgId,
          ));
        }

        return enrichedRoles;
      }
      return _getFallbackMockSpecialists();
    } catch (e) {
      if (kDebugMode) {
        print('[BookingRepository] Failed to fetch practitioner roles: $e');
      }
      return _getFallbackMockSpecialists();
    }
  }

  Future<PractitionerDetail?> _fetchPractitionerDetail(int practitionerId) async {
    try {
      final response = await _apiClient.client.get('/api/fhir/v1/practitioners/$practitionerId');
      if (response.statusCode == 200) {
        return PractitionerDetail.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('[BookingRepository] Failed to fetch details for practitioner $practitionerId: $e');
      }
      return null;
    }
  }

  /// Retrieve user's appointments from the FHIR server
  Future<List<Map<String, dynamic>>> getUserAppointments({
    required String userId,
    required String orgId,
  }) async {
    try {
      final response = await _apiClient.client.get(
        '/api/fhir/v1/appointments/',
        queryParameters: {
          'user_id': userId,
          'org_id': orgId,
          'limit': 100,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final list = data['data'] as List?;
        if (list == null) return [];
        return List<Map<String, dynamic>>.from(list);
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('[BookingRepository] Failed to get user appointments from server: $e');
      }
      return [];
    }
  }

  /// Retrieve booked slot times for a practitioner on a specific date
  Future<List<String>> getBookedSlotsForDoctor({
    required int practitionerId,
    required String dateString, // Format: YYYY-MM-DD
  }) async {
    try {
      final startOfDay = '${dateString}T00:00:00Z';
      final endOfDay = '${dateString}T23:59:59Z';

      final response = await _apiClient.client.get(
        '/api/fhir/v1/appointments/',
        queryParameters: {
          'start_from': startOfDay,
          'start_to': endOfDay,
          'limit': 100,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final list = data['data'] as List?;
        if (list == null) return [];

        final bookedTimes = <String>[];
        final practitionerRef = 'Practitioner/$practitionerId';

        for (var appt in list) {
          if (appt is Map<String, dynamic>) {
            final status = appt['status']?.toString().toLowerCase();
            if (status == 'cancelled' || status == 'entered-in-error' || status == 'declined') {
              continue;
            }

            final participants = appt['participant'] as List?;
            bool isDoctorParticipant = false;
            if (participants != null) {
              for (var p in participants) {
                if (p is Map<String, dynamic>) {
                  final actor = p['actor']?.toString();
                  if (actor == practitionerRef) {
                    isDoctorParticipant = true;
                    break;
                  }
                }
              }
            }

            if (isDoctorParticipant) {
              final start = appt['start']?.toString();
              if (start != null && start.isNotEmpty) {
                try {
                  final dateTime = DateTime.parse(start).toLocal();
                  final hour = dateTime.hour.toString().padLeft(2, '0');
                  final minute = dateTime.minute.toString().padLeft(2, '0');
                  bookedTimes.add('$hour:$minute');
                } catch (e) {
                  // Swallowed
                }
              }
            }
          }
        }
        return bookedTimes;
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('[BookingRepository] Failed to get booked slots from server: $e');
      }
      return [];
    }
  }

  /// Create Appointment directly on live FHIR server (skipping encounters)
  Future<Map<String, dynamic>> createAppointmentWithEncounter({
    required int patientId,
    required String patientName,
    required int practitionerId,
    required String practitionerName,
    required String startTimeIso,
    required String endTimeIso,
    required bool isVirtual,
    required String userId,
    required String orgId,
    String? note,
  }) async {
    try {
      final String apptTypeCode = isVirtual ? 'VIRTUAL' : 'INPERSON';
      final String apptTypeDisplay = isVirtual ? 'Virtual Consultation' : 'In-Person Visit';

      final appointmentPayload = {
        'status': 'booked',
        'subject': 'Patient/$patientId',
        'subject_display': patientName,
        'start': startTimeIso,
        'end': endTimeIso,
        'minutes_duration': 30,
        'created': DateTime.now().toIso8601String(),
        'description': note ?? 'Consultation Appointment',
        'appointment_type_code': apptTypeCode,
        'appointment_type_display': apptTypeDisplay,
        'user_id': userId,
        'org_id': orgId,
        'participant': [
          {
            'reference': 'Patient/$patientId',
            'reference_display': patientName,
            'required': true,
            'status': 'accepted',
          },
          {
            'reference': 'Practitioner/$practitionerId',
            'reference_display': practitionerName,
            'types': [
              {
                'coding_code': 'ATND',
                'coding_display': 'attender',
              }
            ],
            'required': true,
            'status': 'accepted',
          }
        ]
      };

      if (kDebugMode) {
        print('[BookingRepository] Creating Appointment on server...');
      }
      final appointmentResponse = await _apiClient.client.post(
        '/api/fhir/v1/appointments/',
        data: appointmentPayload,
      );

      if (appointmentResponse.statusCode != 200 && appointmentResponse.statusCode != 201) {
        throw Exception('Appointment creation failed with status ${appointmentResponse.statusCode}');
      }

      final appointmentData = appointmentResponse.data;
      final int appointmentId = appointmentData['id'] is int 
          ? appointmentData['id'] 
          : int.parse(appointmentData['id'].toString());

      return {
        'encounter_id': 0, // Encounters bypassed
        'appointment_id': appointmentId,
        'start': startTimeIso,
        'end': endTimeIso,
        'practitioner_name': practitionerName,
        'patient_name': patientName,
        'type': apptTypeDisplay,
      };
    } catch (e) {
      if (kDebugMode) {
        print('[BookingRepository] Appointment creation failed: $e');
      }
      rethrow;
    }
  }

  /// Delete/Cancel Appointment on server
  Future<void> cancelAppointmentServer(String appointmentId) async {
    try {
      final response = await _apiClient.client.delete(
        '/api/fhir/v1/appointments/$appointmentId',
      );
      if (response.statusCode != 204 && response.statusCode != 200) {
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
