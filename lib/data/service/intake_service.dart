import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';
import '../../domain/model/intake_models.dart';

/// Result packet emitted during live streaming conversation turn
class IntakeStreamChunk {
  final String type; // 'text_delta' | 'agent_end' | 'status_end' | 'text_complete' | 'other'
  final String? textDelta;
  final String? sessionId;

  IntakeStreamChunk({
    required this.type,
    this.textDelta,
    this.sessionId,
  });
}

// ponytail: consolidated network stack onto single production Dio client; removed redundant package:http
class IntakeService {
  final Dio _dio;
  String _intakeAgentUrl = ApiConstants.defaultIntakeAgentUrl;
  String _assessmentPlanAgentUrl = ApiConstants.defaultAssessmentPlanAgentUrl;
  String _appBaseUrl = ApiConstants.appBaseUrl;

  IntakeService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ));

  /// Configure service URLs dynamically if environment requires
  void configure({
    String? intakeAgentUrl,
    String? assessmentPlanAgentUrl,
    String? appBaseUrl,
  }) {
    if (intakeAgentUrl != null && intakeAgentUrl.isNotEmpty) {
      _intakeAgentUrl = intakeAgentUrl.trim();
    }
    if (assessmentPlanAgentUrl != null && assessmentPlanAgentUrl.isNotEmpty) {
      _assessmentPlanAgentUrl = assessmentPlanAgentUrl.trim();
    }
    if (appBaseUrl != null && appBaseUrl.isNotEmpty) {
      _appBaseUrl = appBaseUrl.trim();
    }
  }

  // =========================================================================
  // 1. STREAMING CHAT WITH AI INTAKE AGENT (Section 2)
  // =========================================================================

  /// Stream a conversation turn to the Python AI agent using Dio streaming.
  /// Yields [IntakeStreamChunk] items as tokens arrive.
  Stream<IntakeStreamChunk> streamChatTurn({
    required String message,
    required String? sessionId,
    required String authToken,
  }) async* {
    final payload = {
      'message': message,
      'session_id': sessionId,
    };

    if (kDebugMode) {
      print('[IntakeService] POST $_intakeAgentUrl (Dio stream) | session_id: $sessionId');
    }

    Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        _intakeAgentUrl,
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json, text/event-stream',
          },
          responseType: ResponseType.stream,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('[IntakeService] Network error initiating stream: $e');
      }
      rethrow;
    }

    // Read session_id from response header if present
    final headerSessionId = response.headers.value('x-session-id');
    if (headerSessionId != null && headerSessionId.isNotEmpty) {
      yield IntakeStreamChunk(
        type: 'session_header',
        sessionId: headerSessionId.trim(),
      );
    }

    final responseBody = response.data;
    if (responseBody == null) return;

    // Read line-by-line newline-delimited stream
    final lineStream = responseBody.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('data:')) {
        trimmed = trimmed.substring(5).trim();
      }
      if (trimmed == '[DONE]') {
        break;
      }

      try {
        final Map<String, dynamic> json = jsonDecode(trimmed);
        final type = json['type']?.toString() ?? 'other';
        final data = json['data'] as Map<String, dynamic>?;

        switch (type) {
          case 'text_delta':
            final content = data?['content']?.toString() ?? '';
            yield IntakeStreamChunk(
              type: 'text_delta',
              textDelta: content,
            );
            break;

          case 'agent_end':
            final chunkSessionId = data?['session_id']?.toString();
            yield IntakeStreamChunk(
              type: 'agent_end',
              sessionId: chunkSessionId,
            );
            break;

          case 'status_end':
            yield IntakeStreamChunk(type: 'status_end');
            break;

          case 'text_complete':
          default:
            break;
        }
      } catch (parseErr) {
        if (kDebugMode) {
          print('[IntakeService] Skipped unrecognized chunk: $trimmed');
        }
      }
    }
  }

  // =========================================================================
  // 2. GENERATE CLINICAL REPORT (Section 4)
  // =========================================================================

  Future<Map<String, dynamic>?> generateClinicalReport({
    required List<IntakeChatMessage> conversation,
    required String authToken,
  }) async {
    try {
      final formattedConversation = conversation.map((msg) => msg.toAgentReportString()).toList();

      if (kDebugMode) {
        print('[IntakeService] Generating assessment report: POST $_assessmentPlanAgentUrl');
      }

      final response = await _dio.post(
        _assessmentPlanAgentUrl,
        data: {'conversation': formattedConversation},
        options: Options(
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data;
        } else if (data is String) {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) return decoded;
        }
      } else {
        if (kDebugMode) {
          print('[IntakeService] Assessment agent returned status ${response.statusCode}: ${response.data}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[IntakeService] Report generation non-fatal failure: $e');
      }
    }
    return null;
  }

  // =========================================================================
  // 3. DRGODLY REST ENDPOINTS: CREATE, UPDATE, LINK, ABANDON (Section 5 & 6)
  // =========================================================================

  Future<IntakeRecord?> createIntakeRecord({
    int? patientFhirId,
    required String authToken,
    String? orgId,
  }) async {
    try {
      final url = '$_appBaseUrl${ApiConstants.intakeCreatePath}';
      final headers = <String, dynamic>{
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      };
      if (orgId != null && orgId.isNotEmpty) {
        headers['x-org-id'] = orgId;
      }

      final payload = <String, dynamic>{'mode': 'TEXT'};
      if (patientFhirId != null) {
        payload['patient_fhir_id'] = patientFhirId;
      }

      if (kDebugMode) {
        print('[IntakeService] Creating intake record: POST $url');
      }

      final response = await _dio.post(
        url,
        data: payload,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : jsonDecode(response.data.toString()) as Map<String, dynamic>;
        return IntakeRecord.fromJson(data);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[IntakeService] Error creating intake record: $e');
      }
    }
    return null;
  }

  Future<bool> updateIntakeRecord({
    required int id,
    required List<IntakeChatMessage> conversation,
    Map<String, dynamic>? report,
    required String authToken,
    String? orgId,
  }) async {
    try {
      final url = '$_appBaseUrl${ApiConstants.intakeUpdatePath}';
      final headers = <String, dynamic>{
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      };
      if (orgId != null && orgId.isNotEmpty) {
        headers['x-org-id'] = orgId;
      }

      final payload = <String, dynamic>{
        'id': id,
        'conversation': conversation.map((c) => c.toJson()).toList(),
      };
      if (report != null && report.isNotEmpty) {
        payload['report'] = report;
      }

      if (kDebugMode) {
        print('[IntakeService] Updating intake record $id to COMPLETED: POST $url');
      }

      final response = await _dio.post(
        url,
        data: payload,
        options: Options(headers: headers),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('[IntakeService] Error updating intake record $id: $e');
      }
    }
    return false;
  }

  Future<bool> abandonIntakeRecord({
    required int id,
    required String authToken,
    String? orgId,
  }) async {
    try {
      final url = '$_appBaseUrl${ApiConstants.intakeAbandonPath}';
      final headers = <String, dynamic>{
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      };
      if (orgId != null && orgId.isNotEmpty) {
        headers['x-org-id'] = orgId;
      }

      final response = await _dio.post(
        url,
        data: {'id': id},
        options: Options(headers: headers),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('[IntakeService] Error abandoning intake record $id: $e');
      }
      return false;
    }
  }

  Future<bool> linkIntakeToAppointment({
    required int id,
    required int fhirAppointmentId,
    required String authToken,
    String? orgId,
  }) async {
    try {
      final url = '$_appBaseUrl${ApiConstants.intakeLinkPath}';
      final headers = <String, dynamic>{
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      };
      if (orgId != null && orgId.isNotEmpty) {
        headers['x-org-id'] = orgId;
      }

      if (kDebugMode) {
        print('[IntakeService] Linking intake $id to appointment $fhirAppointmentId: POST $url');
      }

      final response = await _dio.post(
        url,
        data: {
          'id': id,
          'fhir_appointment_id': fhirAppointmentId,
        },
        options: Options(headers: headers),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('[IntakeService] Error linking intake $id to appointment $fhirAppointmentId: $e');
      }
      return false;
    }
  }
}
