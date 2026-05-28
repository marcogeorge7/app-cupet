import 'package:dio/dio.dart';

import '../../../shared/models/country.dart';

class CountryRemoteDataSource {
  CountryRemoteDataSource(this._dio);

  final Dio _dio;

  /// Fetches the backend-configured country dial-code list. Returns the
  /// preselected ISO (e.g. 'EG') alongside the list so the dropdown can
  /// default to whatever the backend recommends.
  Future<({List<Country> countries, String? defaultIso})> fetchCountries() async {
    final response = await _dio.get('/countries');
    final data = response.data as Map<String, dynamic>;
    final list = (data['data'] as List<dynamic>)
        .map((e) => Country.fromJson(e as Map<String, dynamic>))
        .toList();
    return (countries: list, defaultIso: data['default'] as String?);
  }
}
