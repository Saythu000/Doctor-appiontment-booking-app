import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

class IntakeService {
  final http.Client _httpClient;
  String _intakeAgentUrl = ApiConstants.defaultIntakeAgentUrl;
  String _assessmentPlanAgentUrl = ApiConstants.defaultAssessmentPlanAgentUrl;
  String _appBaseUrl = ApiConstants.appBaseUrl;

  IntakeService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

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

  /// Stream a conversation turn to the Python AI agent.
  /// Yields [IntakeStreamChunk] items as tokens arrive.
  Stream<IntakeStreamChunk> streamChatTurn({
    required String message,
    required String? sessionId,
    required String authToken,
  }) async* {
    final uri = Uri.parse(_intakeAgentUrl);
    final request = http.Request('POST', uri);

    request.headers.addAll({
      'Authorization': 'Bearer $authToken',
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/event-stream',
    });

    final payload = {
      'message': message,
      'session_id': sessionId,
    };
    request.body = jsonEncode(payload);

    if (kDebugMode) {
      print('[IntakeService] POST $_intakeAgentUrl | session_id: $sessionId');
    }

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _httpClient.send(request);
    } catch (e) {
      if (kDebugMode) {
        print('[IntakeService] Network error initiating stream: $e');
      }
      rethrow;
    }

    // 2.1 Strategy 1: Read session_id from response header if present
    final headerSessionId = streamedResponse.headers['x-session-id'];
    if (headerSessionId != null && headerSessionId.isNotEmpty) {
      yield IntakeStreamChunk(
        type: 'session_header',
        sessionId: headerSessionId.trim(),
      );
    }

    // 2.2 Read line-by-line newline-delimited stream
    final lineStream = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Handle SSE-style "data: " prefix
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
            // 2.1 Strategy 2: Extract session_id from agent_end chunk if available
            final chunkSessionId = data?['session_id']?.toString();
            yield IntakeStreamChunk(
              type: 'agent_end',
              sessionId: chunkSessionId,
            );
            break;

          case 'status_end':
            // 3.1 Automatic completion signal from AI agent
            yield IntakeStreamChunk(type: 'status_end');
            break;

          case 'text_complete':
          default:
            // Safe forward-compatible no-op
            break;
        }
      } catch (parseErr) {
        // Forward-compatible parser: skip non-JSON or unrecognizable lines
        if (kDebugMode) {
          print('[IntakeService] Skipped unrecognized chunk: $trimmed');
        }
      }
    }
  }

  // =========================================================================
  // 2. GENERATE CLINICAL REPORT (Section 4)
  // =========================================================================

  /// Generate clinical assessment report from full conversation transcript.
  /// Strictly follows Section 4 formatting: "patient: ..." and "appointment-intake-agent: ...".
  /// Non-blocking: Returns null on error so save flow is never halted.
  Future<Map<String, dynamic>?> generateClinicalReport({
    required List<IntakeChatMessage> conversation,
    required String authToken,
  }) async {
    try {
      final formattedConversation = conversation.map((msg) => msg.toAgentReportString()).toList();

      final uri = Uri.parse(_assessmentPlanAgentUrl);
      if (kDebugMode) {
        print('[IntakeService] Generating assessment report: POST $_assessmentPlanAgentUrl');
      }

      final response = await _httpClient.post(
        uri,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'conversation': formattedConversation,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } else {
        if (kDebugMode) {
          print('[IntakeService] Assessment agent returned status ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      // Non-blocking rule: Section 4 explicitly dictates report failure must not block saving
      if (kDebugMode) {
        print('[IntakeService] Report generation non-fatal failure: $e');
      }
    }
    return null;
  }

  // =========================================================================
  // 3. DRGODLY REST ENDPOINTS: CREATE, UPDATE, LINK, ABANDON (Section 5 & 6)
  // =========================================================================

  /// 5.1 Create intake record on DrGodly Next.js backend
  /// POST {APP_BASE_URL}/api/intake/create
  Future<IntakeRecord?> createIntakeRecord({
    int? patientFhirId,
    required String authToken,
    String? orgId,
  }) async {
    try {
      final uri = Uri.parse('$_appBaseUrl${ApiConstants.intakeCreatePath}');
      final headers = {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      };
      if (orgId != null && orgId.isNotEmpty) {
        headers['x-org-id'] = orgId;
      }

      final payload = <String, dynamic>{
        'mode': 'TEXT',
      };
      if (patientFhirId != null) {
        payload['patient_fhir_id'] = patientFhirId;
      }

      if (kDebugMode) {
        print('[IntakeService] Creating intake record: POST $uri');
      }

      final response = await _httpClient.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return IntakeRecord.fromJson(data);
      } else {
        if (kDebugMode) {
          print('[IntakeService] Create intake returned code ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[IntakeService] Error creating intake record: $e');
      }
    }
    return null;
  }

  /// 5.2 Save transcript + report, mark complete on DrGodly backend
  /// POST {APP_BASE_URL}/api/intake/update
  Future<bool> updateIntakeRecord({
    required int id,
    required List<IntakeChatMessage> conversation,
    Map<String, dynamic>? report,
    required String authToken,
    String? orgId,
  }) async {
    try {
      final uri = Uri.parse('$_appBaseUrl${ApiConstants.intakeUpdatePath}');
      final headers = {
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
        print('[IntakeService] Updating intake record $id to COMPLETED: POST $uri');
      }

      final response = await _httpClient.post(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      } else {
        if (kDebugMode) {
          print('[IntakeService] Update intake returned code ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[IntakeService] Error updating intake record $id: $e');
      }
    }
    return false;
  }

  /// 5.3 Abandon intake record if user dropped out during optional pre-create flow
  /// POST {APP_BASE_URL}/api/intake/abandon
  Future<bool> abandonIntakeRecord({
    required int id,
    required String authToken,
    String? orgId,
  }) async {
    try {
      final uri = Uri.parse('$_appBaseUrl${ApiConstants.intakeAbandonPath}');
      final headers = {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      };
      if (orgId != null && orgId.isNotEmpty) {
        headers['x-org-id'] = orgId;
      }

      final response = await _httpClient.post(
        uri,
        headers: headers,
        body: jsonEncode({'id': id}),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('[IntakeService] Error abandoning intake record $id: $e');
      }
      return false;
    }
  }

  /// 6.1 Link completed intake record to booked FHIR appointment
  /// POST {APP_BASE_URL}/api/intake/link
  Future<bool> linkIntakeToAppointment({
    required int id,
    required int fhirAppointmentId,
    required String authToken,
    String? orgId,
  }) async {
    try {
      final uri = Uri.parse('$_appBaseUrl${ApiConstants.intakeLinkPath}');
      final headers = {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      };
      if (orgId != null && orgId.isNotEmpty) {
        headers['x-org-id'] = orgId;
      }

      if (kDebugMode) {
        print('[IntakeService] Linking intake $id to appointment $fhirAppointmentId: POST $uri');
      }

      final response = await _httpClient.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'id': id,
          'fhir_appointment_id': fhirAppointmentId,
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('[IntakeService] Error linking intake $id to appointment $fhirAppointmentId: $e');
      }
      return false;
    }
  }
}
