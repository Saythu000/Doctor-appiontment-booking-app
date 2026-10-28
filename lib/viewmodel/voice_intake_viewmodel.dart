import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/service/voice_intake_service.dart';
import '../data/service/intake_service.dart';
import '../domain/model/intake_models.dart';

enum VoiceCallState {
  offline,
  connecting,
  connected,
  ending,
  generatingReport,
  saving,
  completed,
  error,
}

class VoiceIntakeViewModel extends ChangeNotifier {
  final VoiceIntakeService _voiceService;
  final IntakeService _intakeService;

  VoiceIntakeViewModel({
    VoiceIntakeService? voiceService,
    IntakeService? intakeService,
  })  : _voiceService = voiceService ?? VoiceIntakeService(),
        _intakeService = intakeService ?? IntakeService();

  VoiceCallState _callState = VoiceCallState.offline;
  String _statusLabel = 'Offline';
  String _statusDotColor = 'grey'; // 'grey', 'amber', 'green'
  bool _isMuted = false;
  String? _errorMessage;

  // Turn-Commit Buffers (§4.1)
  final List<IntakeChatMessage> _committedMessages = [];
  String _pendingUser = '';
  String _pendingAgent = '';

  int? _savedIntakeRecordId;
  IntakeClinicalReport? _clinicalReport;
  StreamSubscription<VoiceAgentEvent>? _eventsSubscription;
  bool _isEndingCall = false;

  VoiceCallState get callState => _callState;
  String get statusLabel => _statusLabel;
  String get statusDotColor => _statusDotColor;
  bool get isMuted => _isMuted;
  String? get errorMessage => _errorMessage;
  List<IntakeChatMessage> get committedMessages => List.unmodifiable(_committedMessages);
  String get pendingUser => _pendingUser;
  String get pendingAgent => _pendingAgent;
  int? get savedIntakeRecordId => _savedIntakeRecordId;
  IntakeClinicalReport? get clinicalReport => _clinicalReport;

  bool get isCallActive =>
      _callState == VoiceCallState.connecting || _callState == VoiceCallState.connected;

  bool get isBusy =>
      _callState == VoiceCallState.ending ||
      _callState == VoiceCallState.generatingReport ||
      _callState == VoiceCallState.saving;

  void reset() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _voiceService.disconnect();
    _callState = VoiceCallState.offline;
    _statusLabel = 'Offline';
    _statusDotColor = 'grey';
    _isMuted = false;
    _errorMessage = null;
    _committedMessages.clear();
    _pendingUser = '';
    _pendingAgent = '';
    _savedIntakeRecordId = null;
    _clinicalReport = null;
    _isEndingCall = false;
    notifyListeners();
  }

  /// Start voice intake call (§2)
  Future<void> startCall({
    required String authToken,
    String? patientName,
    String? birthDate,
    String? email,
    String? phone,
    String? wsUrlOverride,
  }) async {
    reset();
    _callState = VoiceCallState.connecting;
    _statusLabel = 'Connecting...';
    _statusDotColor = 'amber';
    notifyListeners();

    // Build patient context (§2.1 & text guide §2.0)
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

    final patientContextString = contextFields.isNotEmpty
        ? '[Patient context: ${contextFields.join(', ')}]'
        : null;

    try {
      await _voiceService.connect(
        authToken: authToken,
        patientContext: patientContextString,
        wsUrlOverride: wsUrlOverride,
      );

      _callState = VoiceCallState.connected;
      _statusLabel = 'Online';
      _statusDotColor = 'green';
      notifyListeners();

      // Listen to voice events
      _eventsSubscription = _voiceService.events.listen(
        (event) => _handleVoiceEvent(event, authToken),
        onError: (e) {
          _statusLabel = 'Error';
          _statusDotColor = 'grey';
          _errorMessage = e.toString();
          notifyListeners();
        },
      );
    } catch (e) {
      _callState = VoiceCallState.error;
      _statusLabel = 'Offline';
      _statusDotColor = 'grey';
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  /// Process incoming events according to turn-commit rules (§4.1, §4.2)
  void _handleVoiceEvent(VoiceAgentEvent event, String authToken) {
    switch (event.type) {
      case 'status':
        _updateStatusFromAgent(event.status);
        if (event.status == 'end') {
          // Automatic end (§5.1)
          endCall(authToken: authToken);
        }
        break;

      case 'status_end':
        // Automatic end (§5.1)
        endCall(authToken: authToken);
        break;

      case 'transcript':
        // Patient speech recognised so far (§4.1)
        // 1. If pendingAgent is non-empty, commit it as agent message and clear
        if (_pendingAgent.trim().isNotEmpty) {
          _committedMessages.add(
            IntakeChatMessage(role: 'assistant', content: _pendingAgent.trim()),
          );
          _pendingAgent = '';
        }
        // 2. Set pendingUser = text (replace). Show it live.
        _pendingUser = event.text ?? '';
        notifyListeners();
        break;

      case 'text':
      case 'text_delta':
        // Incremental agent reply (§4.1)
        // 1. If pendingUser is non-empty, commit it as patient message and clear
        if (_pendingUser.trim().isNotEmpty) {
          _committedMessages.add(
            IntakeChatMessage(role: 'user', content: _pendingUser.trim()),
          );
          _pendingUser = '';
        }
        // 2. pendingAgent += text. Show it live.
        _pendingAgent += event.text ?? '';
        _statusLabel = 'Speaking...';
        _statusDotColor = 'amber';
        notifyListeners();
        break;

      case 'assistant_text':
        // One complete, final agent turn (§4.1)
        // 1. If pendingUser is non-empty, commit it and clear
        if (_pendingUser.trim().isNotEmpty) {
          _committedMessages.add(
            IntakeChatMessage(role: 'user', content: _pendingUser.trim()),
          );
          _pendingUser = '';
        }
        // 2. Discard pendingAgent and commit final text
        _pendingAgent = '';
        if (event.text != null && event.text!.trim().isNotEmpty) {
          _committedMessages.add(
            IntakeChatMessage(role: 'assistant', content: event.text!.trim()),
          );
        }
        _statusLabel = 'Ready — you can speak';
        _statusDotColor = 'green';
        notifyListeners();
        break;

      case 'error':
        _errorMessage = event.message ?? 'Unknown error from agent';
        notifyListeners();
        break;

      default:
        break;
    }
  }

  void _updateStatusFromAgent(String? status) {
    if (status == null) return;
    switch (status) {
      case 'greeting':
        _statusLabel = 'Speaking greeting...';
        _statusDotColor = 'amber';
        break;
      case 'thinking':
        _statusLabel = 'Thinking...';
        _statusDotColor = 'amber';
        break;
      case 'ready':
        _statusLabel = 'Ready — you can speak';
        _statusDotColor = 'green';
        break;
      case 'end':
        _statusLabel = 'Call ended';
        _statusDotColor = 'grey';
        break;
      default:
        break;
    }
    notifyListeners();
  }

  /// Toggle Mute / Unmute (§5.3)
  void toggleMute() {
    _isMuted = !_isMuted;
    _voiceService.setMuted(_isMuted);
    notifyListeners();
  }

  /// Restart Call (§5.3)
  Future<void> restartCall({
    required String authToken,
    String? patientName,
    String? birthDate,
    String? email,
    String? phone,
    String? wsUrlOverride,
  }) async {
    if (isBusy) return;
    await _voiceService.disconnect();
    _committedMessages.clear();
    _pendingUser = '';
    _pendingAgent = '';
    await startCall(
      authToken: authToken,
      patientName: patientName,
      birthDate: birthDate,
      email: email,
      phone: phone,
      wsUrlOverride: wsUrlOverride,
    );
  }

  /// End Call (§5.1, §5.2, §6)
  Future<void> endCall({
    required String authToken,
    int? patientFhirId,
    String? orgId,
  }) async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    _callState = VoiceCallState.ending;
    _statusLabel = 'Call ended';
    _statusDotColor = 'grey';
    notifyListeners();

    // 1. Flush pending buffers (§4.1)
    if (_pendingUser.trim().isNotEmpty) {
      _committedMessages.add(IntakeChatMessage(role: 'user', content: _pendingUser.trim()));
      _pendingUser = '';
    }
    if (_pendingAgent.trim().isNotEmpty) {
      _committedMessages.add(IntakeChatMessage(role: 'assistant', content: _pendingAgent.trim()));
      _pendingAgent = '';
    }

    // 2. Tear down audio and WebSocket
    await _voiceService.disconnect();

    // 3. Zero messages check (§5.2)
    if (_committedMessages.isEmpty) {
      _callState = VoiceCallState.offline;
      _statusLabel = 'Offline';
      _isEndingCall = false;
      notifyListeners();
      return;
    }

    // 4. Generate Clinical Report with Assessment Agent (§6.1)
    _callState = VoiceCallState.generatingReport;
    notifyListeners();

    Map<String, dynamic>? rawReport;
    try {
      rawReport = await _intakeService.generateClinicalReport(
        conversation: _committedMessages,
        authToken: authToken,
      );
      if (rawReport != null) {
        _clinicalReport = IntakeClinicalReport.fromJson(rawReport);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[VoiceIntakeViewModel] Report generation non-fatal error: $e');
      }
    }

    // 5. Create & Save Intake Record with mode: "VOICE" (§6.2, §6.3)
    _callState = VoiceCallState.saving;
    notifyListeners();

    try {
      final record = await _intakeService.createIntakeRecord(
        patientFhirId: patientFhirId ?? 10001,
        mode: 'VOICE',
        authToken: authToken,
        orgId: orgId,
      );
      if (record != null) {
        _savedIntakeRecordId = record.id;

        await _intakeService.updateIntakeRecord(
          id: record.id,
          conversation: _committedMessages,
          report: rawReport,
          authToken: authToken,
          orgId: orgId,
        );
      }

      _callState = VoiceCallState.completed;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('[VoiceIntakeViewModel] Error saving voice intake record: $e');
      }
      _errorMessage = 'Failed to save intake: ${e.toString().replaceFirst("Exception: ", "")}';
      _callState = VoiceCallState.error;
      notifyListeners();
    } finally {
      _isEndingCall = false;
    }
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _voiceService.dispose();
    super.dispose();
  }
}
