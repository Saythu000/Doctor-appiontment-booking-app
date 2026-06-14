import '../../domain/model/vitals_payload.dart';
import '../service/fhir_api_client.dart';

class VitalsRepository {
  final FhirApiClient _apiClient = FhirApiClient();

  /// Log a new vitals entry on the FHIR server
  Future<void> submitVitals(
    VitalsRecord record, {
    required String userId,
    required String orgId,
  }) async {
    final Map<String, dynamic> body = record.toJson();
    body['user_id'] = userId;
    body['org_id'] = orgId;

    await _apiClient.client.post(
      '/api/v1/vitals/',
      data: body,
    );
  }

  /// Retrieve active user's historical vitals records
  Future<List<VitalsRecord>> getMyVitals({
    required String userId,
    required String orgId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.client.get(
        '/api/v1/vitals/',
        queryParameters: {
          'user_id': userId,
          'org_id': orgId,
          'limit': limit,
          'offset': offset,
        },
      );
      if (response.statusCode == 200) {
        final data = response.data;
        final list = data['data'] as List?;
        if (list == null) return [];
        return list.map((x) => VitalsRecord.fromJson(x)).toList();
      }
      return [];
    } catch (e) {
      // In case of any API error, return empty array gracefully
      return [];
    }
  }
}
