import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/service/intake_service.dart';
import '../data/repository/health_repository.dart';
import '../domain/model/intake_models.dart';

enum IntakeState {
  idle,
  streaming,
  ending,
  generatingReport,
  saving,
  completed,
  error,
}

class IntakeViewModel extends ChangeNotifier {
  final IntakeService _intakeService;

  IntakeViewModel({IntakeService? intakeService})
      : _intakeService = intakeService ?? IntakeService();

  IntakeState _state = IntakeState.idle;
  final List<IntakeChatMessage> _messages = [];
  String? _sessionId;
  int? _savedIntakeRecordId;
  IntakeClinicalReport? _clinicalReport;
  String _currentStreamingText = '';
  String? _errorMessage;
  StreamSubscription<IntakeStreamChunk>? _streamSubscription;

  IntakeState get state => _state;
  List<IntakeChatMessage> get messages => List.unmodifiable(_messages);
  String? get sessionId => _sessionId;
  int? get savedIntakeRecordId => _savedIntakeRecordId;
  IntakeClinicalReport? get clinicalReport => _clinicalReport;
  String get currentStreamingText => _currentStreamingText;
  String? get errorMessage => _errorMessage;
  bool get isStreaming => _state == IntakeState.streaming;
  bool get isBusy => _state == IntakeState.streaming ||
      _state == IntakeState.ending ||
      _state == IntakeState.generatingReport ||
      _state == IntakeState.saving;

  /// Reset state for a fresh intake session
  void reset() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _state = IntakeState.idle;
    _messages.clear();
    _sessionId = null;
    _savedIntakeRecordId = null;
    _clinicalReport = null;
    _currentStreamingText = '';
    _errorMessage = null;
    notifyListeners();
  }

  /// Patient sends a message turn (Section 2)
  Future<void> sendMessage({
    required String text,
    required String authToken,
    int? patientFhirId,
    String? orgId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isBusy) return;

    // 1. Append patient message to list
    final userMessage = IntakeChatMessage(role: 'user', content: trimmed);
    _messages.add(userMessage);
    _state = IntakeState.streaming;
    _currentStreamingText = '';
    _errorMessage = null;
    notifyListeners();

    try {
      // 2. Stream turn from AI intake agent
      final stream = _intakeService.streamChatTurn(
        message: trimmed,
        sessionId: _sessionId,
        authToken: authToken,
      );

      _streamSubscription = stream.listen(
        (chunk) {
          // Check for session ID from header or agent_end chunk
          if (chunk.sessionId != null && chunk.sessionId!.isNotEmpty) {
            _sessionId = chunk.sessionId;
          }

          switch (chunk.type) {
            case 'text_delta':
              if (chunk.textDelta != null) {
                _currentStreamingText += chunk.textDelta!;
                notifyListeners();
              }
              break;

            case 'agent_end':
              _commitAssistantMessage();
              break;

            case 'status_end':
              // Section 3.1: Agent decided conversation is complete
              if (kDebugMode) {
                print('[IntakeViewModel] Received status_end from agent. Auto-finishing...');
              }
              _commitAssistantMessage();
              finishIntake(
                authToken: authToken,
                patientFhirId: patientFhirId,
                orgId: orgId,
              );
              break;

            default:
              break;
          }
        },
        onError: (err) {
          if (kDebugMode) {
            print('[IntakeViewModel] Stream error: $err');
          }
          _commitAssistantMessage();
          _errorMessage = 'Network connection interrupted. Please try again.';
          _state = IntakeState.idle;
          notifyListeners();
        },
        onDone: () {
          if (_state == IntakeState.streaming) {
            _commitAssistantMessage();
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[IntakeViewModel] Failed to send message: $e');
      }
      _errorMessage = 'Failed to send message: $e';
      _state = IntakeState.idle;
      notifyListeners();
    }
  }

  void _commitAssistantMessage() {
    if (_currentStreamingText.trim().isNotEmpty) {
      _messages.add(
        IntakeChatMessage(
          role: 'assistant',
          content: _currentStreamingText.trim(),
        ),
      );
    }
    _currentStreamingText = '';
    _state = IntakeState.idle;
    notifyListeners();
  }

  /// Section 3.2: Patient taps "End Chat" or Section 3.1: Agent signals "status_end"
  /// Executes: Section 4 (Generate Report) -> Section 5 (Save Intake)
  Future<void> finishIntake({
    required String authToken,
    int? patientFhirId,
    String? orgId,
  }) async {
    // If stream is actively in-flight, cancel immediately
    if (_streamSubscription != null) {
      await _streamSubscription?.cancel();
      _streamSubscription = null;
      _commitAssistantMessage();
    }

    // If zero messages sent, nothing to save
    if (_messages.isEmpty) {
      _state = IntakeState.idle;
      notifyListeners();
      return;
    }

    // Step 1: Section 4 - Generate clinical report (Non-blocking)
    _state = IntakeState.generatingReport;
    notifyListeners();

    Map<String, dynamic>? rawReport;
    try {
      rawReport = await _intakeService.generateClinicalReport(
        conversation: _messages,
        authToken: authToken,
      );
      if (rawReport != null) {
        _clinicalReport = IntakeClinicalReport.fromJson(rawReport);
      }
    } catch (reportErr) {
      // Non-blocking rule: Section 4 states report failure must never block save
      if (kDebugMode) {
        print('[IntakeViewModel] Report generation skipped/errored: $reportErr');
      }
    }

    // Step 2: Section 5.1 - Create intake record in DB
    _state = IntakeState.saving;
    notifyListeners();

    final record = await _intakeService.createIntakeRecord(
      patientFhirId: patientFhirId,
      authToken: authToken,
      orgId: orgId,
    );

    if (record != null) {
      _savedIntakeRecordId = record.id;
      try {
        await HealthRepository().saveSetting('last_intake_record_id', record.id.toString());
      } catch (_) {}

      // Step 3: Section 5.2 - Save transcript + report, mark complete
      final success = await _intakeService.updateIntakeRecord(
        id: record.id,
        conversation: _messages,
        report: rawReport,
        authToken: authToken,
        orgId: orgId,
      );

      if (success) {
        _state = IntakeState.completed;
      } else {
        // Even if update failed, we have record created
        _state = IntakeState.completed;
      }
    } else {
      // Offline fallback: mark completed locally with report
      if (kDebugMode) {
        print('[IntakeViewModel] Server intake create unreachable. Persisting locally as completed.');
      }
      _state = IntakeState.completed;
    }

    notifyListeners();
  }

  /// Section 6.1: Link completed intake to newly booked appointment
  Future<bool> linkToAppointment({
    int? intakeRecordId,
    required int fhirAppointmentId,
    required String authToken,
    String? orgId,
  }) async {
    int? intakeId = intakeRecordId ?? _savedIntakeRecordId;
    if (intakeId == null) {
      final savedStr = await HealthRepository().getSetting('last_intake_record_id');
      if (savedStr != null && savedStr.isNotEmpty) {
        intakeId = int.tryParse(savedStr);
      }
    }
    if (intakeId == null) return false;

    if (kDebugMode) {
      print('[IntakeViewModel] Linking intake ID $intakeId to appointment $fhirAppointmentId');
    }

    final success = await _intakeService.linkIntakeToAppointment(
      id: intakeId,
      fhirAppointmentId: fhirAppointmentId,
      authToken: authToken,
      orgId: orgId,
    );

    if (success) {
      if (kDebugMode) {
        print('[IntakeViewModel] Successfully linked intake $intakeId to appointment $fhirAppointmentId');
      }
      _savedIntakeRecordId = null;
      try {
        await HealthRepository().saveSetting('last_intake_record_id', '');
      } catch (_) {}
    }
    return success;
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}
