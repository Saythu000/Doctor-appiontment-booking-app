import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:phia_flutter/core/config/api_constants.dart';
import 'package:phia_flutter/features/booking/domain/booking_models.dart';
import 'package:phia_flutter/core/network/fhir_api_client.dart';

/// The chosen slot was booked by someone else between loading slots and
/// confirming (HTTP 409, patient guide §4.3). Re-fetch slots and let the
/// user pick again; never retry the same slot.
class SlotTakenException implements Exception {
  @override
  String toString() => 'This time slot was just booked by someone else.';
}

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

      try {
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
      } catch (orgErr) {
        debugPrint('[BookingRepository] Practitioner search failed: $orgErr');
        rethrow;
      }

      // No retry without org_id: results must stay inside this patient's
      // organization (patient guide §2, §4.1).
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

      try {
        final response = await _apiClient.client.get(
          '/api/v1/slots/',
          queryParameters: queryParams,
        );

        if (response.statusCode == 200) {
          final data = response.data;
          final list = data['data'] as List?;
          if (list != null && list.isNotEmpty) {
            return list
                .whereType<Map<String, dynamic>>()
                .map((s) => BookingSlot.fromJson(s))
                .toList();
          }
        }
      } catch (orgSlotErr) {
        debugPrint('[BookingRepository] Slot query failed: $orgSlotErr');
        rethrow;
      }

      // No retry without org_id: slots must stay inside this patient's
      // organization (patient guide §2, §4.2).
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('[BookingRepository] Failed to fetch slots from /api/v1/slots: $e');
      }
      // A failure is not "no free slots": let the caller show a retry.
      rethrow;
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
        // Keep the id as the server sent it. It used to be int.parse()d; a
        // non-numeric id threw AFTER the booking succeeded, so the user saw
        // "booking failed", retried, and got a second appointment.
        final appointmentId = data['id'];
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
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) throw SlotTakenException();
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

  /// The signed-in patient's appointments: `GET /appointments?user_id=&org_id=`
  /// (patient guide §5.1; there is no separate "my appointments" endpoint).
  /// `user_id` is the JWT `sub`. Errors are rethrown so an offline refresh
  /// never looks like "no appointments".
  Future<List<Map<String, dynamic>>> getUserAppointments({
    required String userId,
    required String orgId,
  }) async {
    try {
      final effectiveOrgId = orgId.isNotEmpty ? orgId : ApiConstants.defaultOrganizationId;
      final response = await _apiClient.client.get(
        '/api/v1/appointments/',
        queryParameters: {
          'user_id': userId,
          'org_id': effectiveOrgId,
          'limit': 100,
        },
      );
      final list = (response.data is Map) ? response.data['data'] as List? : null;
      return [
        for (final item in list ?? const [])
          if (item is Map<String, dynamic>) item,
      ];
    } catch (e) {
      if (kDebugMode) {
        print('[BookingRepository] Failed to get user appointments: $e');
      }
      rethrow;
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
