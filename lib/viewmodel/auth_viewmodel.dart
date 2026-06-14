import 'package:flutter/foundation.dart';
import '../data/repository/auth_repository.dart';
import '../data/repository/health_repository.dart';
import '../data/service/fhir_api_client.dart';
import '../domain/model/auth_models.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository authRepository;
  final HealthRepository healthRepository;

  bool _isLoading = false;
  String? _errorMessage;
  String? _sessionToken;
  String? _jwtToken;
  String? _userId;
  String? _orgId;
  User? _user;

  AuthViewModel({
    required this.authRepository,
    required this.healthRepository,
  });

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get sessionToken => _sessionToken;
  String? get jwtToken => _jwtToken;
  String? get userId => _userId;
  String? get orgId => _orgId;
  User? get user => _user;
  bool get isAuthenticated => _jwtToken != null && _jwtToken!.isNotEmpty;

  /// Initiate email sign-in, retrieve session info, fetch JWT token, and configure FhirApiClient.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: Sign in with email and get session token
      final token = await authRepository.signIn(email: email, password: password);
      _sessionToken = token;

      // Step 2: Retrieve full session and user details
      var sessionResponse = await authRepository.getSession(sessionCookie: token);
      _user = sessionResponse.user;
      _userId = sessionResponse.user.id;
      _orgId = sessionResponse.session.activeOrganizationId;

      // Resolve null or empty activeOrganizationId by choosing the first available organization
      if (_orgId == null || _orgId!.isEmpty) {
        final orgs = await authRepository.listOrganizations(sessionCookie: token);
        if (orgs.isNotEmpty) {
          final firstOrgId = orgs[0]['id'] as String;
          await authRepository.setActiveOrganization(sessionCookie: token, organizationId: firstOrgId);
          // Re-fetch session to get the populated active organization
          sessionResponse = await authRepository.getSession(sessionCookie: token);
          _orgId = sessionResponse.session.activeOrganizationId;
        }
      }

      // Step 3: Fetch JWT token
      final jwt = await authRepository.getJwtToken(sessionCookie: token);
      _jwtToken = jwt;

      // Save credentials locally
      await _saveCredentials();

      // Configure the FHIR API client for live server mode
      FhirApiClient().configure(
        baseUrl: 'https://fhir.drgodly.com',
        token: _jwtToken,
        isLiveMode: true,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Initiate email registration, retrieve session info, fetch JWT token, and configure FhirApiClient.
  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: Sign up and get session token
      final token = await authRepository.signUp(
        name: name,
        email: email,
        password: password,
      );
      _sessionToken = token;

      // Step 2: Retrieve full session and user details
      var sessionResponse = await authRepository.getSession(sessionCookie: token);
      _user = sessionResponse.user;
      _userId = sessionResponse.user.id;
      _orgId = sessionResponse.session.activeOrganizationId;

      // Resolve null or empty activeOrganizationId by choosing the first available organization
      if (_orgId == null || _orgId!.isEmpty) {
        final orgs = await authRepository.listOrganizations(sessionCookie: token);
        if (orgs.isNotEmpty) {
          final firstOrgId = orgs[0]['id'] as String;
          await authRepository.setActiveOrganization(sessionCookie: token, organizationId: firstOrgId);
          // Re-fetch session to get the populated active organization
          sessionResponse = await authRepository.getSession(sessionCookie: token);
          _orgId = sessionResponse.session.activeOrganizationId;
        }
      }

      // Step 3: Fetch JWT token
      final jwt = await authRepository.getJwtToken(sessionCookie: token);
      _jwtToken = jwt;

      // Save credentials locally
      await _saveCredentials();

      // Configure the FHIR API client for live server mode
      FhirApiClient().configure(
        baseUrl: 'https://fhir.drgodly.com',
        token: _jwtToken,
        isLiveMode: true,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Check for saved credentials in the settings table and attempt auto-login/token refresh.
  Future<bool> checkAutoLogin() async {
    try {
      final savedSessionToken = await healthRepository.getSetting('iam_session_token');

      if (savedSessionToken == null || savedSessionToken.isEmpty) {
        return false;
      }

      // Verify the session is still valid by requesting it again from the server
      var sessionResponse = await authRepository.getSession(sessionCookie: savedSessionToken);
      _sessionToken = savedSessionToken;
      _user = sessionResponse.user;
      _userId = sessionResponse.user.id;
      _orgId = sessionResponse.session.activeOrganizationId;

      // Resolve null or empty activeOrganizationId by choosing the first available organization
      if (_orgId == null || _orgId!.isEmpty) {
        final orgs = await authRepository.listOrganizations(sessionCookie: savedSessionToken);
        if (orgs.isNotEmpty) {
          final firstOrgId = orgs[0]['id'] as String;
          await authRepository.setActiveOrganization(sessionCookie: savedSessionToken, organizationId: firstOrgId);
          // Re-fetch session to get the populated active organization
          sessionResponse = await authRepository.getSession(sessionCookie: savedSessionToken);
          _orgId = sessionResponse.session.activeOrganizationId;
        }
      }

      // Fetch a fresh JWT token
      final jwt = await authRepository.getJwtToken(sessionCookie: savedSessionToken);
      _jwtToken = jwt;

      // Save the updated credentials (which might have changed organization or JWT expires)
      await _saveCredentials();

      // Configure the FHIR API client for live server mode
      FhirApiClient().configure(
        baseUrl: 'https://fhir.drgodly.com',
        token: _jwtToken,
        isLiveMode: true,
      );

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[AuthViewModel] Auto-login verification failed: $e');
      }
      // If validation fails (e.g. session expired or offline with no server response),
      // we clean up and fall back to local/offline default state.
      await signOut();
      return false;
    }
  }

  /// Sign out the user, clear local state, and reset FhirApiClient to mock mode.
  Future<void> signOut() async {
    _sessionToken = null;
    _jwtToken = null;
    _userId = null;
    _orgId = null;
    _user = null;
    _errorMessage = null;

    // Remove stored credentials
    await healthRepository.saveSetting('iam_session_token', '');
    await healthRepository.saveSetting('iam_jwt_token', '');
    await healthRepository.saveSetting('iam_user_id', '');
    await healthRepository.saveSetting('iam_org_id', '');
    await healthRepository.saveSetting('user_name', '');
    await healthRepository.saveSetting('user_email', '');

    // Wipe cached demographics/profile settings to prevent local leakage
    await healthRepository.saveProfileValue('given_name', '');
    await healthRepository.saveProfileValue('family_name', '');
    await healthRepository.saveProfileValue('gender', '');
    await healthRepository.saveProfileValue('birth_date', '');
    await healthRepository.saveProfileValue('profile_image_path', '');

    // Reset FhirApiClient to default mock mode (no token, isLiveMode = false)
    FhirApiClient().configure(
      baseUrl: 'http://10.0.2.2:8000',
      token: null,
      isLiveMode: false,
    );

    notifyListeners();
  }

  Future<void> _saveCredentials() async {
    if (_sessionToken != null) {
      await healthRepository.saveSetting('iam_session_token', _sessionToken!);
    }
    if (_jwtToken != null) {
      await healthRepository.saveSetting('iam_jwt_token', _jwtToken!);
    }
    if (_userId != null) {
      await healthRepository.saveSetting('iam_user_id', _userId!);
    }
    if (_orgId != null) {
      await healthRepository.saveSetting('iam_org_id', _orgId!);
    }
    if (_user != null) {
      await healthRepository.saveSetting('user_name', _user!.name);
      await healthRepository.saveSetting('user_email', _user!.email);
    }
  }
}
