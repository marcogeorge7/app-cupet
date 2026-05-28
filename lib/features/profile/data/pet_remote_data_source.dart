import 'package:dio/dio.dart';

import '../../../shared/models/pet.dart';

class PetRemoteDataSource {
  PetRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Pet>> listMyPets() async {
    final response = await _dio.get('/pets');
    final list = (response.data as Map<String, dynamic>)['data'] as List;
    return list.map((e) => Pet.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Pet> create(Map<String, dynamic> payload) async {
    final response = await _dio.post('/pets', data: payload);
    final data = (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return Pet.fromJson(data);
  }

  Future<Pet> update(int id, Map<String, dynamic> payload) async {
    final response = await _dio.put('/pets/$id', data: payload);
    final data = (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return Pet.fromJson(data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/pets/$id');
  }

  Future<void> addPhoto(int petId, String url, {int? order}) async {
    await _dio.post('/pets/$petId/photos', data: {
      'url': url,
      'order': ?order,
    });
  }

  Future<String?> uploadPhotoFile(int petId, String filePath) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post(
      '/pets/$petId/photos',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = response.data as Map<String, dynamic>;
    final inner =
        (data['data'] as Map<String, dynamic>?) ?? data;
    return inner['url'] as String?;
  }

  Future<void> addVaccination(
    int petId, {
    required String name,
    DateTime? givenAt,
    String? certificateUrl,
  }) async {
    await _dio.post('/pets/$petId/vaccinations', data: {
      'name': name,
      if (givenAt != null) 'given_at': givenAt.toIso8601String().substring(0, 10),
      'certificate_url': ?certificateUrl,
    });
  }
}
