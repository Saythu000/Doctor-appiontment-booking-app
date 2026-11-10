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
  String? _lastUserMessage;
  bool _canRetry = false;
  StreamSubscription<IntakeStreamChunk>? _streamSubscription;

  IntakeState get state => _state;
  List<IntakeChatMessage> get messages => List.unmodifiable(_messages);
  String? get sessionId => _sessionId;
  int? get savedIntakeRecordId => _savedIntakeRecordId;
  IntakeClinicalReport? get clinicalReport => _clinicalReport;
  String get currentStreamingText => _currentStreamingText;
  String? get errorMessage => _errorMessage;
  bool get canRetry => _canRetry && _lastUserMessage != null && _lastUserMessage!.isNotEmpty;
  String? get lastUserMessage => _lastUserMessage;
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
    _lastUserMessage = null;
    _canRetry = false;
    notifyListeners();
  }

  /// Patient sends a message turn (Section 2)
  /// Prepend patient context line on the very first message of a new session only (session_id: null).
  Future<void> sendMessage({
    required String text,
    required String authToken,
    int? patientFhirId,
    String? orgId,
    String? patientName,
    String? birthDate,
    String? email,
    String? phone,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isBusy) return;

    _lastUserMessage = trimmed;
    _canRetry = false;

    // 1. Append patient message to visible chat list (only the typed text!)
    final userMessage = IntakeChatMessage(role: 'user', content: trimmed);
    _messages.add(userMessage);
    _state = IntakeState.streaming;
    _currentStreamingText = '';
    _errorMessage = null;
    notifyListeners();

    // 2. Prepend patient context on first message of a new session only
    String outboundMessage = trimmed;
    final bool isFirstTurn = _sessionId == null || _sessionId!.isEmpty;
    if (isFirstTurn) {
      final List<String> contextFields = [];

      // name: Better Auth display name or fallback 'Patient'
      final resolvedName = (patientName != null && patientName.trim().isNotEmpty)
          ? patientName.trim()
          : 'Patient';
      contextFields.add('name=$resolvedName');

      // age: Whole years computed from Patient.birth_date (e.g. YYYY-MM-DD)
      if (birthDate != null && birthDate.trim().isNotEmpty) {
        try {
          final dob = DateTime.parse(birthDate.trim());
          final now = DateTime.now();
          int age = now.year - dob.year;
          if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
            age--;
          }
          if (age >= 0 && age <= 130) {
            contextFields.add('age=$age');
          }
        } catch (_) {}
      }

      // Patient context format from the intake guides:
      // [Patient context: name=..., age=..., email=..., phone=...]
      if (email != null && email.trim().isNotEmpty) {
        contextFields.add('email=${email.trim()}');
      }
      if (phone != null && phone.trim().isNotEmpty) {
        contextFields.add('phone=${phone.trim()}');
      }

      if (contextFields.isNotEmpty) {
        final contextPrefix = '[Patient context: ${contextFields.join(', ')}]';
        outboundMessage = '$contextPrefix\n\n$trimmed';
      }
    }

    // Ensure valid non-empty auth token
    String effectiveToken = authToken;
    if (effectiveToken.isEmpty) {
      final storedJwt = await HealthRepository().getSetting('iam_jwt_token');
      if (storedJwt != null && storedJwt.isNotEmpty) {
        effectiveToken = storedJwt;
      }
    }

    await _startStreamingTurn(
      outboundMessage: outboundMessage,
      effectiveToken: effectiveToken,
      authToken: authToken,
      patientFhirId: patientFhirId,
      orgId: orgId,
    );
  }

  /// Retries the last failed message turn without duplicating user chat bubbles.
  Future<void> retryLastMessage({
    required String authToken,
    int? patientFhirId,
    String? orgId,
    String? patientName,
    String? birthDate,
    String? email,
    String? phone,
  }) async {
    if (_lastUserMessage == null || _lastUserMessage!.isEmpty || isBusy) return;

    // If an incomplete assistant response was partially committed upon error, remove it
    if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
      _messages.removeLast();
    }

    _canRetry = false;
    _errorMessage = null;
    _state = IntakeState.streaming;
    _currentStreamingText = '';
    notifyListeners();

    // Prepare outbound message
    String outboundMessage = _lastUserMessage!;
    final bool isFirstTurn = _sessionId == null || _sessionId!.isEmpty;
    if (isFirstTurn) {
      final List<String> contextFields = [];
      final resolvedName = (patientName != null && patientName.trim().isNotEmpty)
          ? patientName.trim()
          : 'Patient';
      contextFields.add('name=$resolvedName');

      if (birthDate != null && birthDate.trim().isNotEmpty) {
        try {
          final dob = DateTime.parse(birthDate.trim());
          final now = DateTime.now();
          int age = now.year - dob.year;
          if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
            age--;
          }
          if (age >= 0 && age <= 130) {
            contextFields.add('age=$age');
          }
        } catch (_) {}
      }

      if (email != null && email.trim().isNotEmpty) {
        contextFields.add('email=${email.trim()}');
      }

      if (phone != null && phone.trim().isNotEmpty) {
        contextFields.add('phone=${phone.trim()}');
      }

      if (contextFields.isNotEmpty) {
        outboundMessage = '[Patient context: ${contextFields.join(', ')}]\n\n$_lastUserMessage';
      }
    }

    String effectiveToken = authToken;
    if (effectiveToken.isEmpty) {
      final storedJwt = await HealthRepository().getSetting('iam_jwt_token');
      if (storedJwt != null && storedJwt.isNotEmpty) {
        effectiveToken = storedJwt;
      }
    }

    await _startStreamingTurn(
      outboundMessage: outboundMessage,
      effectiveToken: effectiveToken,
      authToken: authToken,
      patientFhirId: patientFhirId,
      orgId: orgId,
    );
  }

  Future<void> _startStreamingTurn({
    required String outboundMessage,
    required String effectiveToken,
    required String authToken,
    int? patientFhirId,
    String? orgId,
  }) async {
    try {
      final stream = _intakeService.streamChatTurn(
        message: outboundMessage,
        sessionId: _sessionId,
        authToken: effectiveToken,
      );

      _streamSubscription = stream.listen(
        (chunk) {
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
              _canRetry = false;
              _commitAssistantMessage();
              break;

            case 'status_end':
              _canRetry = false;
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
          debugPrint('[IntakeViewModel] Stream error: $err');
          _commitAssistantMessage();
          _canRetry = true;
          _errorMessage = 'Connection interrupted. Tap to retry.';
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
      debugPrint('[IntakeViewModel] Failed to send message: $e');
      _canRetry = true;
      _errorMessage = 'Connection failed. Tap to retry.';
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

    // Ensure valid non-empty auth token
    String effectiveToken = authToken;
    if (effectiveToken.isEmpty) {
      final storedJwt = await HealthRepository().getSetting('iam_jwt_token');
      if (storedJwt != null && storedJwt.isNotEmpty) {
        effectiveToken = storedJwt;
      }
    }

    // Step 1: Section 4 - Generate clinical report (Non-blocking)
    _state = IntakeState.generatingReport;
    notifyListeners();

    Map<String, dynamic>? rawReport;
    try {
      rawReport = await _intakeService.generateClinicalReport(
        conversation: _messages,
        authToken: effectiveToken,
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
    _errorMessage = null;
    notifyListeners();

    // Intake does not require a profile: without a patient id the field is
    // omitted (text guide §5.1).
    final int? resolvedPatientId =
        (patientFhirId != null && patientFhirId > 0) ? patientFhirId : null;

    try {
      // On a retry after a failed update, reuse the record already created
      // instead of creating a second one.
      int? recordId = _savedIntakeRecordId;
      if (recordId == null) {
        final record = await _intakeService.createIntakeRecord(
          patientFhirId: resolvedPatientId,
          authToken: effectiveToken,
          orgId: orgId,
        );
        if (record == null) {
          _failSave('Could not save your intake to your health record. Check your connection and tap End again.');
          return;
        }
        recordId = record.id;
        _savedIntakeRecordId = recordId;
        try {
          await HealthRepository().saveSetting('last_intake_record_id', recordId.toString());
        } catch (_) {}
      }

      // Step 3: Section 5.2 - Save transcript + report, mark complete
      final success = await _intakeService.updateIntakeRecord(
        id: recordId,
        conversation: _messages,
        report: rawReport,
        authToken: effectiveToken,
        orgId: orgId,
      );
      if (!success) {
        _failSave('Your conversation could not be saved. Check your connection and tap End again.');
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[IntakeViewModel] Saving intake failed: $e');
      }
      _failSave('Could not save your intake. Check your connection and tap End again.');
      return;
    }

    _state = IntakeState.completed;
    notifyListeners();
  }

  /// Save failed: keep the conversation so the user can retry; never report
  /// "completed" for an intake the doctor will not see.
  void _failSave(String message) {
    _state = IntakeState.error;
    _errorMessage = message;
    _canRetry = false;
    notifyListeners();
  }

  /// Section 6.1: Link completed intake to newly booked appointment
  Future<bool> linkToAppointment({
    int? intakeRecordId,
    required int fhirAppointmentId,
    required String authToken,
    String? orgId,
  }) async {
    // Only link the intake explicitly carried through this booking flow.
    // Falling back to a remembered/persisted id could attach a stale (or
    // another user's) intake to this appointment.
    final int? intakeId = intakeRecordId;
    if (intakeId == null || intakeId <= 0) return false;

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
