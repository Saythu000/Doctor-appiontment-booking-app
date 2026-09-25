import 'package:dio/dio.dart';
import '../../domain/model/patient_profile.dart';
import '../service/fhir_api_client.dart';

class ProfileRepository {
  final FhirApiClient _apiClient = FhirApiClient();

  /// Retrieve the Patient profile of the authenticated user via GET /api/v1/patients/me
  Future<PlainPatient?> getMyProfile({
    String? userId,
    String? orgId,
  }) async {
    try {
      // 1. First try /api/v1/patients/me (token-resolved profile)
      final response = await _apiClient.client.get('/api/v1/patients/me');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['id'] != null) {
          return PlainPatient.fromJson(data);
        }
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Fallback: try filtering by user_id if supplied
        if (userId != null && userId.isNotEmpty) {
          try {
            final fallbackResp = await _apiClient.client.get(
              '/api/v1/patients/',
              queryParameters: {
                'user_id': userId,
                if (orgId != null && orgId.isNotEmpty) 'org_id': orgId,
              },
            );
            if (fallbackResp.statusCode == 200 && fallbackResp.data != null) {
              final list = fallbackResp.data['data'] as List?;
              if (list != null && list.isNotEmpty) {
                return PlainPatient.fromJson(list.first as Map<String, dynamic>);
              }
            }
          } catch (_) {}
        }
        return null; // Profile does not exist yet
      }
      return null;
    } catch (e) {
      return null;
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
    try {
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
    } catch (e) {
      // Fallback to basic /api/v1/patients/ if /patients/full has schema restrictions
      final fallbackResp = await _apiClient.client.post(
        '/api/v1/patients/',
        data: {
          'active': true,
          'user_id': userId,
          'org_id': orgId,
        },
      );
      return PlainPatient.fromJson(fallbackResp.data as Map<String, dynamic>);
    }
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
  }) async {
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
      'telecom': [
        if (phone != null && phone.isNotEmpty)
          {'system': 'phone', 'value': phone, 'rank': 1},
        if (email != null && email.isNotEmpty)
          {'system': 'email', 'value': email, 'rank': 1},
      ],
    };

    final response = await _apiClient.client.patch(
      '/api/v1/patients/$patientId/full',
      data: payload,
    );
    return PlainPatient.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update core demographics (Gender, DOB)
  Future<PlainPatient> patchDemographics({
    required int patientId,
    required String gender,
    required String birthDate,
  }) async {
    final response = await _apiClient.client.patch(
      '/api/v1/patients/$patientId',
      data: {
        'gender': gender.toLowerCase(),
        'birth_date': birthDate,
      },
    );
    return PlainPatient.fromJson(response.data as Map<String, dynamic>);
  }

  /// Append/Update the patient's name list sub-resource
  Future<PlainPatient> addName({
    required int patientId,
    required String givenName,
    required String familyName,
  }) async {
    final response = await _apiClient.client.post(
      '/api/v1/patients/$patientId/names',
      data: {
        'use': 'official',
        'text': '$givenName $familyName'.trim(),
        'given': [givenName],
        'family': familyName,
      },
    );
    return PlainPatient.fromJson(response.data);
  }

  /// Append/Update the patient's email/phone telecom list sub-resource
  Future<PlainPatient> addTelecom({
    required int patientId,
    required String system, // 'phone' or 'email'
    required String value,
  }) async {
    final response = await _apiClient.client.post(
      '/api/v1/patients/$patientId/telecom',
      data: {
        'system': system,
        'value': value,
        'use': 'home',
      },
    );
    return PlainPatient.fromJson(response.data);
  }

  /// Append/Update the patient's address list sub-resource
  Future<PlainPatient> addAddress({
    required int patientId,
    required String street,
    required String city,
    required String state,
    required String zip,
    required String country,
  }) async {
    final response = await _apiClient.client.post(
      '/api/v1/patients/$patientId/addresses',
      data: {
        'use': 'home',
        'line': [street],
        'city': city,
        'state': state,
        'postal_code': zip,
        'country': country,
      },
    );
    return PlainPatient.fromJson(response.data);
  }
}
