import 'package:dio/dio.dart';
import '../../domain/model/patient_profile.dart';
import '../service/fhir_api_client.dart';

class ProfileRepository {
  final FhirApiClient _apiClient = FhirApiClient();

  /// Retrieve the Patient profile of the authenticated user
  Future<PlainPatient?> getMyProfile({
    required String userId,
    required String orgId,
  }) async {
    try {
      final response = await _apiClient.client.get(
        '/api/fhir/v1/patients/',
        queryParameters: {
          'user_id': userId,
          'org_id': orgId,
        },
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['data'] is List) {
          final list = data['data'] as List;
          if (list.isNotEmpty) {
            return PlainPatient.fromJson(list.first as Map<String, dynamic>);
          }
        }
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // Profile does not exist yet
      }
      rethrow;
    }
  }

  /// Initialize an empty FHIR Patient profile on the server
  Future<PlainPatient> createInitialProfile({
    required String userId,
    required String orgId,
  }) async {
    final response = await _apiClient.client.post(
      '/api/fhir/v1/patients/',
      data: {
        'active': true,
        'user_id': userId,
        'org_id': orgId,
      },
    );
    return PlainPatient.fromJson(response.data);
  }

  /// Update core demographics (Gender, DOB)
  Future<PlainPatient> patchDemographics({
    required int patientId,
    required String gender,
    required String birthDate,
  }) async {
    final response = await _apiClient.client.patch(
      '/api/fhir/v1/patients/$patientId',
      data: {
        'gender': gender.toLowerCase(),
        'birth_date': birthDate,
      },
    );
    return PlainPatient.fromJson(response.data);
  }

  /// Append/Update the patient's name list sub-resource
  Future<PlainPatient> addName({
    required int patientId,
    required String givenName,
    required String familyName,
  }) async {
    final response = await _apiClient.client.post(
      '/api/fhir/v1/patients/$patientId/names',
      data: {
        'use': 'official',
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
      '/api/fhir/v1/patients/$patientId/telecom',
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
      '/api/fhir/v1/patients/$patientId/addresses',
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
