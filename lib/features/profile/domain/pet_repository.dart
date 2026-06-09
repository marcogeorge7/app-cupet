import '../../../core/error/failures.dart';
import '../../../shared/models/pet.dart';
import '../data/pet_remote_data_source.dart';

class PetRepository {
  PetRepository(this._remote);

  final PetRemoteDataSource _remote;

  Future<List<Pet>> listMyPets() async {
    try {
      return await _remote.listMyPets();
    } catch (e) {
      throw Failure.fromDio(e);
    }
  }

  Future<Pet> create({
    required PetType type,
    required PetGender gender,
    required String name,
    String? breed,
    String? bio,
    DateTime? birthdate,
    double? lat,
    double? lng,
    String? locationName,
    String? primaryPhotoUrl,
  }) async {
    try {
      return await _remote.create({
        'type': type.name,
        'gender': gender.name,
        'name': name,
        'breed': ?breed,
        'bio': ?bio,
        if (birthdate != null)
          'birthdate': birthdate.toIso8601String().substring(0, 10),
        'location_lat': ?lat,
        'location_lng': ?lng,
        'location_name': ?locationName,
        'primary_photo_url': ?primaryPhotoUrl,
      });
    } catch (e) {
      throw Failure.fromDio(e);
    }
  }

  Future<Pet> update(int id, Map<String, dynamic> payload) async {
    try {
      return await _remote.update(id, payload);
    } catch (e) {
      throw Failure.fromDio(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _remote.delete(id);
    } catch (e) {
      throw Failure.fromDio(e);
    }
  }

  Future<void> addPhoto(int petId, String url) => _remote.addPhoto(petId, url);

  Future<Pet> uploadPrimaryPhoto({
    required int petId,
    required String filePath,
  }) async {
    try {
      final url = await _remote.uploadPhotoFile(petId, filePath);
      if (url == null) {
        throw const Failure('Photo upload returned no URL');
      }
      return await _remote.update(petId, {'primary_photo_url': url});
    } catch (e) {
      throw Failure.fromDio(e);
    }
  }

  /// Upload several photos for a pet (in order), then reload the pet so its
  /// `photos[]` + `primary_photo_url` reflect the additions. The backend sets
  /// the first uploaded photo as the primary when the pet has none yet.
  Future<Pet> uploadPhotos({
    required int petId,
    required List<String> filePaths,
  }) async {
    try {
      for (final path in filePaths) {
        await _remote.uploadPhotoFile(petId, path);
      }
      return await _remote.getPet(petId);
    } catch (e) {
      throw Failure.fromDio(e);
    }
  }

  Future<void> addVaccination(
    int petId, {
    required String name,
    DateTime? givenAt,
    String? certificateUrl,
  }) =>
      _remote.addVaccination(
        petId,
        name: name,
        givenAt: givenAt,
        certificateUrl: certificateUrl,
      );
}
