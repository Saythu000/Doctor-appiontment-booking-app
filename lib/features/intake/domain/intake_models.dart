/// Message in the pre-visit intake conversation
class IntakeChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;

  IntakeChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  /// Format required by DrGodly DB /api/intake/update
  Map<String, String> toJson() {
    return {
      'role': role,
      'content': content.trim(),
    };
  }

  /// Format required by Assessment Report Agent (Section 4):
  /// `patient: <message>` or `appointment-intake-agent: <message>`
  String toAgentReportString() {
    final speaker = isUser ? 'patient' : 'appointment-intake-agent';
    return '$speaker: ${content.trim()}';
  }

  factory IntakeChatMessage.fromJson(Map<String, dynamic> json) {
    return IntakeChatMessage(
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
    );
  }
}

/// Clinical assessment report returned by ASSESSMENT_PLAN_AGENT_URL (Section 4)
class IntakeClinicalReport {
  final String? clinicalOverview;
  final String? riskLevel;
  final dynamic differentialDiagnosis;
  final dynamic diagnosticPlan;
  final dynamic treatmentPlan;
  final dynamic redFlags;
  final Map<String, dynamic> rawJson;

  IntakeClinicalReport({
    this.clinicalOverview,
    this.riskLevel,
    this.differentialDiagnosis,
    this.diagnosticPlan,
    this.treatmentPlan,
    this.redFlags,
    required this.rawJson,
  });

  factory IntakeClinicalReport.fromJson(Map<String, dynamic> json) {
    return IntakeClinicalReport(
      clinicalOverview: json['clinical_overview']?.toString(),
      riskLevel: json['risk_level']?.toString(),
      differentialDiagnosis: json['differential_diagnosis'],
      diagnosticPlan: json['diagnostic_plan'],
      treatmentPlan: json['treatment_plan'],
      redFlags: json['red_flags'],
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() => rawJson;
}

/// Intake record representation returned by DrGodly REST API (/api/intake/*)
class IntakeRecord {
  final int id;
  final String? userId;
  final String? orgId;
  final int? patientFhirId;
  final String mode; // 'TEXT'
  final String status; // 'IN_PROGRESS' | 'COMPLETED' | 'ABANDONED'
  final List<IntakeChatMessage>? conversation;
  final Map<String, dynamic>? report;
  final int? fhirAppointmentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  IntakeRecord({
    required this.id,
    this.userId,
    this.orgId,
    this.patientFhirId,
    this.mode = 'TEXT',
    required this.status,
    this.conversation,
    this.report,
    this.fhirAppointmentId,
    this.createdAt,
    this.updatedAt,
  });

  factory IntakeRecord.fromJson(Map<String, dynamic> json) {
    List<IntakeChatMessage>? conversationList;
    if (json['conversation'] is List) {
      conversationList = (json['conversation'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => IntakeChatMessage.fromJson(m))
          .toList();
    }

    return IntakeRecord(
      id: json['id'] as int? ?? 0,
      userId: json['user_id']?.toString(),
      orgId: json['org_id']?.toString(),
      patientFhirId: json['patient_fhir_id'] as int?,
      mode: json['mode']?.toString() ?? 'TEXT',
      status: json['status']?.toString() ?? 'IN_PROGRESS',
      conversation: conversationList,
      report: json['report'] as Map<String, dynamic>?,
      fhirAppointmentId: json['fhir_appointment_id'] as int?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
}
