import 'package:dio/dio.dart';

import '../../../shared/models/match.dart';

class MatchRemoteDataSource {
  MatchRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<PetMatch>> list({int? petId}) async {
    final response = await _dio.get('/matches', queryParameters: {
      'pet_id': ?petId,
    });
    final list = (response.data as Map<String, dynamic>)['data'] as List;
    return list
        .map((e) => PetMatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
