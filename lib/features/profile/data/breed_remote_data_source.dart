import 'package:dio/dio.dart';

/// Fetches the selectable breed names for a species from the backend catalogue
/// (`GET /breeds?type=`). Backs the "creatable" breed dropdown on the pet form;
/// a breed the user types that isn't here is auto-added server-side on save, so
/// the list grows over time.
class BreedRemoteDataSource {
  BreedRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<String>> fetchBreeds(String type) async {
    final response = await _dio.get('/breeds', queryParameters: {'type': type});
    final data = response.data as Map<String, dynamic>;
    return (data['data'] as List<dynamic>)
        .map((e) => (e as Map<String, dynamic>)['name'] as String)
        .toList();
  }
}
