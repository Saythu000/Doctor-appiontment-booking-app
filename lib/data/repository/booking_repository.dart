import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';
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
        if (list != null && list.isNotEmpty) {
          final List<PractitionerRoleBooking> roles = [];
          for (var item in list) {
            if (item is Map<String, dynamic>) {
              roles.add(PractitionerRoleBooking.fromJson(item));
            }
          }
          if (roles.isNotEmpty) {
            return roles;
          }
        }
      }

      // If org-scoped query returned empty and orgId was provided, fallback to platform query
      if (orgId != null && orgId.isNotEmpty) {
        debugPrint('[BookingRepository] Org $orgId returned 0 doctors, falling back to global query...');
        final fallbackResp = await _apiClient.client.get(
          '/api/v1/practitioner-roles/booking',
          queryParameters: {
            'active': 'true',
            'limit': 50,
          },
        );
        if (fallbackResp.statusCode == 200) {
          final data = fallbackResp.data;
          final list = data['data'] as List?;
          if (list != null && list.isNotEmpty) {
            final List<PractitionerRoleBooking> fallbackRoles = [];
            for (var item in list) {
              if (item is Map<String, dynamic>) {
                fallbackRoles.add(PractitionerRoleBooking.fromJson(item));
              }
            }
            return fallbackRoles;
          }
        }
      }

      return [];
    } catch (e) {
      debugPrint('[BookingRepository] Failed to fetch practitioner roles from /api/v1/practitioner-roles/booking: $e');
      return [];
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
        if (dateString.isNotEmpty) 'date': dateString,
        'status': 'free',
        'limit': 100,
      };
      if (orgId != null && orgId.isNotEmpty) {
        queryParams['org_id'] = orgId;
      }

      final response = await _apiClient.client.get(
        '/api/v1/slots/',
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
    String? userId,
    required String orgId,
    required String appointmentTypeDisplay,
    String? reasonCode,
    String? comment,
    required String practitionerName,
    required String patientName,
  }) async {
    try {
      final effectiveOrgId = orgId.isNotEmpty ? orgId : ApiConstants.defaultOrganizationId;
      final payload = {
        'practitioner_id': practitionerId,
        'slot_id': slotId,
        'patient_id': patientId,
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        'org_id': effectiveOrgId,
        'appointment_type_display': appointmentTypeDisplay,
        if (practitionerName.isNotEmpty) 'practitioner_display': practitionerName,
        if (patientName.isNotEmpty) 'patient_display': patientName,
        if (reasonCode != null && reasonCode.isNotEmpty) 'reason_code': reasonCode,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      };

      if (kDebugMode) {
        print('[BookingRepository] Submitting appointment booking request...');
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
        print('[BookingRepository] Appointment booking request failed');
      }
      rethrow;
    }
  }

  /// Provision consultation room via POST https://app.drgodly.com/api/consultation/create
  Future<bool> provisionConsultationRoom(int fhirAppointmentId) async {
    try {
      final resp = await _apiClient.client.post(
        'https://app.drgodly.com/api/consultation/create',
        data: {
          'fhir_appointment_id': fhirAppointmentId,
        },
      );
      if (kDebugMode) {
        print('[BookingRepository] Consultation room created successfully');
      }
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      if (kDebugMode) {
        print('[BookingRepository] consultation/create (non-critical error)');
      }
      return false;
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
      final effectiveOrgId = orgId.isNotEmpty ? orgId : ApiConstants.defaultOrganizationId;
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
              'org_id': effectiveOrgId,
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
            'org_id': effectiveOrgId,
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
}
