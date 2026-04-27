import 'package:equatable/equatable.dart';

enum PetType { cat, dog, other }

enum PetGender { male, female }

PetType _petTypeFrom(String s) =>
    PetType.values.firstWhere((t) => t.name == s, orElse: () => PetType.other);

PetGender _petGenderFrom(String s) =>
    PetGender.values.firstWhere((g) => g.name == s, orElse: () => PetGender.male);

class PetPhoto extends Equatable {
  const PetPhoto({required this.id, required this.url, required this.order});

  final int id;
  final String url;
  final int order;

  factory PetPhoto.fromJson(Map<String, dynamic> json) => PetPhoto(
        id: json['id'] as int,
        url: json['url'] as String,
        order: json['order'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [id, url, order];
}

class Vaccination extends Equatable {
  const Vaccination({
    required this.id,
    required this.name,
    this.givenAt,
    this.certificateUrl,
  });

  final int id;
  final String name;
  final DateTime? givenAt;
  final String? certificateUrl;

  factory Vaccination.fromJson(Map<String, dynamic> json) => Vaccination(
        id: json['id'] as int,
        name: json['name'] as String,
        givenAt: json['given_at'] != null
            ? DateTime.tryParse(json['given_at'] as String)
            : null,
        certificateUrl: json['certificate_url'] as String?,
      );

  @override
  List<Object?> get props => [id, name, givenAt, certificateUrl];
}

class Pet extends Equatable {
  const Pet({
    required this.id,
    required this.userId,
    required this.type,
    required this.gender,
    required this.name,
    this.bio,
    this.birthdate,
    this.locationLat,
    this.locationLng,
    this.locationName,
    this.primaryPhotoUrl,
    this.photos = const [],
    this.vaccinations = const [],
    this.isActive = true,
  });

  final int id;
  final int userId;
  final PetType type;
  final PetGender gender;
  final String name;
  final String? bio;
  final DateTime? birthdate;
  final double? locationLat;
  final double? locationLng;
  final String? locationName;
  final String? primaryPhotoUrl;
  final List<PetPhoto> photos;
  final List<Vaccination> vaccinations;
  final bool isActive;

  factory Pet.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    return Pet(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      type: _petTypeFrom(json['type'] as String),
      gender: _petGenderFrom(json['gender'] as String),
      name: json['name'] as String,
      bio: json['bio'] as String?,
      birthdate: json['birthdate'] != null
          ? DateTime.tryParse(json['birthdate'] as String)
          : null,
      locationLat: (location?['lat'] as num?)?.toDouble(),
      locationLng: (location?['lng'] as num?)?.toDouble(),
      locationName: location?['name'] as String?,
      primaryPhotoUrl: json['primary_photo_url'] as String?,
      photos: (json['photos'] as List? ?? [])
          .map((e) => PetPhoto.fromJson(e as Map<String, dynamic>))
          .toList(),
      vaccinations: (json['vaccinations'] as List? ?? [])
          .map((e) => Vaccination.fromJson(e as Map<String, dynamic>))
          .toList(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        gender,
        name,
        bio,
        birthdate,
        locationLat,
        locationLng,
        locationName,
        primaryPhotoUrl,
        photos,
        vaccinations,
        isActive,
      ];
}
