import 'package:dio/dio.dart';

class ReportRemoteDataSource {
  ReportRemoteDataSource(this._dio);

  final Dio _dio;

  Future<void> reportPet({
    required int petId,
    required String reason,
    String? details,
  }) async {
    await _dio.post('/reports', data: {
      'reported_pet_id': petId,
      'reason': reason,
      if (details != null) 'details': details,
    });
  }
}
