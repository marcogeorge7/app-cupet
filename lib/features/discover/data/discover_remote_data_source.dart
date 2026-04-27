import 'package:dio/dio.dart';

import '../../../shared/models/match.dart';
import '../../../shared/models/pet.dart';

class SwipeOutcome {
  const SwipeOutcome({required this.matched, this.match});
  final bool matched;
  final PetMatch? match;
}

class DiscoverRemoteDataSource {
  DiscoverRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Pet>> deck({required int petId, double? radiusKm}) async {
    final response = await _dio.get('/discover', queryParameters: {
      'pet_id': petId,
      if (radiusKm != null) 'radius_km': radiusKm,
    });
    final list = (response.data as Map<String, dynamic>)['data'] as List;
    return list.map((e) => Pet.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SwipeOutcome> swipe({
    required int fromPetId,
    required int toPetId,
    required bool liked,
  }) async {
    final response = await _dio.post('/swipes', data: {
      'from_pet_id': fromPetId,
      'to_pet_id': toPetId,
      'direction': liked ? 'like' : 'pass',
    });
    final data = response.data as Map<String, dynamic>;
    final matched = data['matched'] == true;
    if (matched && data['match'] is Map<String, dynamic>) {
      return SwipeOutcome(
        matched: true,
        match: PetMatch.fromJson(
          (data['match'] as Map<String, dynamic>)['data']
                  as Map<String, dynamic>? ??
              data['match'] as Map<String, dynamic>,
        ),
      );
    }
    return const SwipeOutcome(matched: false);
  }
}
