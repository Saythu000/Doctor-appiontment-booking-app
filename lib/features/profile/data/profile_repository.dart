import 'package:dio/dio.dart';
import 'package:phia_flutter/core/network/fhir_api_client.dart';
import 'package:phia_flutter/features/profile/domain/patient_profile.dart';

class ProfileRepository {
  final FhirApiClient _apiClient = FhirApiClient();

  /// Retrieve the Patient profile of the authenticated user via GET /api/v1/patients/me
  Future<PlainPatient?> getMyProfile({
    String? userId,
    String? orgId,
  }) async {
    // GET /patients/me, resolved from the bearer token (patient guide §3.1).
    // Returns null ONLY for "not found" (needs onboarding). Any other failure
    // (offline, 5xx, 401) is rethrown: treating it as "no profile" made the
    // app create a second patient record for the same user.
    try {
      final response = await _apiClient.client.get('/api/v1/patients/me');
      final data = response.data;
      if (data is Map<String, dynamic> && data['id'] != null) {
        return PlainPatient.fromJson(data);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Initialize / create full atomic profile via POST /api/v1/patients/full
  Future<PlainPatient> createInitialProfile({
    required String userId,
    required String orgId,
    String? givenName,
    String? familyName,
    String? gender,
    String? birthDate,
    String? phone,
    String? email,
    String? addressLine,
    String? city,
  }) async {
    // POST /patients/full, one atomic create (patient guide §3.2). No retry
    // through another endpoint: if this call actually succeeded, a retry
    // would create a duplicate patient.
    final payload = <String, dynamic>{
      'user_id': userId,
      'org_id': orgId,
      'active': true,
      if (gender != null && gender.isNotEmpty) 'gender': gender.toLowerCase(),
      if (birthDate != null && birthDate.isNotEmpty) 'birth_date': birthDate,
      if (givenName != null && givenName.isNotEmpty)
        'names': [
          {
            'given': [givenName],
            if (familyName != null && familyName.isNotEmpty) 'family': familyName,
          }
        ],
      'telecom': [
        if (phone != null && phone.isNotEmpty)
          {'system': 'phone', 'value': phone, 'rank': 1},
        if (email != null && email.isNotEmpty)
          {'system': 'email', 'value': email, 'rank': 1},
      ],
      if (addressLine != null && addressLine.isNotEmpty)
        'addresses': [
          {
            'line': [addressLine],
            if (city != null && city.isNotEmpty) 'city': city,
          }
        ],
    };

    final response = await _apiClient.client.post(
      '/api/v1/patients/full',
      data: payload,
    );
    return PlainPatient.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update profile via PATCH /api/v1/patients/{id}/full
  Future<PlainPatient> updateFullProfile({
    required int patientId,
    String? gender,
    String? birthDate,
    String? givenName,
    String? familyName,
    String? phone,
    String? email,
    String? street,
    String? city,
    String? state,
    String? zip,
    String? country,
  }) async {
    // Only send sections that carry data. Sending an empty `telecom` list or an
    // empty address object replaces (erases) what is stored on the server.
    final telecom = <Map<String, dynamic>>[
      if (phone != null && phone.isNotEmpty)
        {'system': 'phone', 'value': phone, 'rank': 1},
      if (email != null && email.isNotEmpty)
        {'system': 'email', 'value': email, 'rank': 1},
    ];
    final hasAddress = [street, city, state, zip, country]
        .any((v) => v != null && v.isNotEmpty);

    final payload = <String, dynamic>{
      if (gender != null && gender.isNotEmpty) 'gender': gender.toLowerCase(),
      if (birthDate != null && birthDate.isNotEmpty) 'birth_date': birthDate,
      if (givenName != null && givenName.isNotEmpty)
        'names': [
          {
            'given': [givenName],
            if (familyName != null && familyName.isNotEmpty) 'family': familyName,
          }
        ],
      if (telecom.isNotEmpty) 'telecom': telecom,
      if (hasAddress)
        'addresses': [
          {
            if (street != null && street.isNotEmpty) 'line': [street],
            if (city != null && city.isNotEmpty) 'city': city,
            if (state != null && state.isNotEmpty) 'state': state,
            if (zip != null && zip.isNotEmpty) 'postal_code': zip,
            if (country != null && country.isNotEmpty) 'country': country,
          }
        ],
    };

    final response = await _apiClient.client.patch(
      '/api/v1/patients/$patientId/full',
      data: payload,
    );
    return PlainPatient.fromJson(response.data as Map<String, dynamic>);
  }
}
