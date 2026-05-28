import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../shared/models/pet.dart';
import '../../domain/pet_repository.dart';

abstract class PetEvent extends Equatable {
  const PetEvent();
  @override
  List<Object?> get props => [];
}

class PetsLoaded extends PetEvent {
  const PetsLoaded();
}

class PetCreated extends PetEvent {
  const PetCreated({
    required this.type,
    required this.gender,
    required this.name,
    this.bio,
    this.birthdate,
    this.lat,
    this.lng,
    this.locationName,
    this.primaryPhotoUrl,
    this.photoFilePath,
  });

  final PetType type;
  final PetGender gender;
  final String name;
  final String? bio;
  final DateTime? birthdate;
  final double? lat;
  final double? lng;
  final String? locationName;
  final String? primaryPhotoUrl;
  final String? photoFilePath;

  @override
  List<Object?> get props => [
        type,
        gender,
        name,
        bio,
        birthdate,
        lat,
        lng,
        locationName,
        primaryPhotoUrl,
        photoFilePath,
      ];
}

class PetUpdated extends PetEvent {
  const PetUpdated({
    required this.id,
    this.type,
    this.gender,
    this.name,
    this.bio,
    this.clearBio = false,
    this.birthdate,
    this.clearBirthdate = false,
    this.lat,
    this.lng,
    this.locationName,
    this.clearLocationName = false,
    this.primaryPhotoUrl,
    this.photoFilePath,
  });

  final int id;
  final PetType? type;
  final PetGender? gender;
  final String? name;
  final String? bio;
  final bool clearBio;
  final DateTime? birthdate;
  final bool clearBirthdate;
  final double? lat;
  final double? lng;
  final String? locationName;
  final bool clearLocationName;
  final String? primaryPhotoUrl;
  final String? photoFilePath;

  @override
  List<Object?> get props => [
        id,
        type,
        gender,
        name,
        bio,
        clearBio,
        birthdate,
        clearBirthdate,
        lat,
        lng,
        locationName,
        clearLocationName,
        primaryPhotoUrl,
        photoFilePath,
      ];
}

class PetDeleted extends PetEvent {
  const PetDeleted(this.id);
  final int id;
  @override
  List<Object?> get props => [id];
}

enum PetStatus { initial, loading, ready, error }

class PetState extends Equatable {
  const PetState({
    this.status = PetStatus.initial,
    this.pets = const [],
    this.errorMessage,
  });

  final PetStatus status;
  final List<Pet> pets;
  final String? errorMessage;

  PetState copyWith({
    PetStatus? status,
    List<Pet>? pets,
    String? errorMessage,
    bool clearError = false,
  }) =>
      PetState(
        status: status ?? this.status,
        pets: pets ?? this.pets,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  List<Object?> get props => [status, pets, errorMessage];
}

class PetBloc extends Bloc<PetEvent, PetState> {
  PetBloc(this._repository) : super(const PetState()) {
    on<PetsLoaded>(_onLoad);
    on<PetCreated>(_onCreate);
    on<PetUpdated>(_onUpdate);
    on<PetDeleted>(_onDelete);
  }

  final PetRepository _repository;

  Future<void> _onLoad(PetsLoaded event, Emitter<PetState> emit) async {
    emit(state.copyWith(status: PetStatus.loading, clearError: true));
    try {
      final pets = await _repository.listMyPets();
      emit(state.copyWith(status: PetStatus.ready, pets: pets));
    } on Failure catch (e) {
      emit(state.copyWith(status: PetStatus.error, errorMessage: e.message));
    }
  }

  Future<void> _onCreate(PetCreated event, Emitter<PetState> emit) async {
    emit(state.copyWith(status: PetStatus.loading, clearError: true));
    try {
      var pet = await _repository.create(
        type: event.type,
        gender: event.gender,
        name: event.name,
        bio: event.bio,
        birthdate: event.birthdate,
        lat: event.lat,
        lng: event.lng,
        locationName: event.locationName,
        primaryPhotoUrl: event.primaryPhotoUrl,
      );
      if (event.photoFilePath != null) {
        try {
          pet = await _repository.uploadPrimaryPhoto(
            petId: pet.id,
            filePath: event.photoFilePath!,
          );
        } catch (_) {
          // photo upload best-effort — pet still saved
        }
      }
      emit(state.copyWith(status: PetStatus.ready, pets: [pet, ...state.pets]));
    } on Failure catch (e) {
      emit(state.copyWith(status: PetStatus.error, errorMessage: e.message));
    }
  }

  Future<void> _onUpdate(PetUpdated event, Emitter<PetState> emit) async {
    emit(state.copyWith(status: PetStatus.loading, clearError: true));
    try {
      // Build a sparse PUT payload: only include fields the caller actually
      // changed, so the backend's `sometimes`/`nullable` rules behave as
      // expected and we never overwrite existing values with `null` by
      // accident. The `clear*` flags let the form explicitly null a field.
      final payload = <String, dynamic>{};
      if (event.type != null) payload['type'] = event.type!.name;
      if (event.gender != null) payload['gender'] = event.gender!.name;
      if (event.name != null) payload['name'] = event.name;
      if (event.clearBio) {
        payload['bio'] = null;
      } else if (event.bio != null) {
        payload['bio'] = event.bio;
      }
      if (event.clearBirthdate) {
        payload['birthdate'] = null;
      } else if (event.birthdate != null) {
        payload['birthdate'] =
            event.birthdate!.toIso8601String().substring(0, 10);
      }
      if (event.lat != null) payload['location_lat'] = event.lat;
      if (event.lng != null) payload['location_lng'] = event.lng;
      if (event.clearLocationName) {
        payload['location_name'] = null;
      } else if (event.locationName != null) {
        payload['location_name'] = event.locationName;
      }
      if (event.primaryPhotoUrl != null) {
        payload['primary_photo_url'] = event.primaryPhotoUrl;
      }

      var pet = payload.isEmpty
          ? state.pets.firstWhere((p) => p.id == event.id)
          : await _repository.update(event.id, payload);

      if (event.photoFilePath != null) {
        try {
          pet = await _repository.uploadPrimaryPhoto(
            petId: event.id,
            filePath: event.photoFilePath!,
          );
        } catch (_) {
          // photo upload best-effort — text fields already saved
        }
      }

      final next = state.pets
          .map((p) => p.id == pet.id ? pet : p)
          .toList(growable: false);
      emit(state.copyWith(status: PetStatus.ready, pets: next));
    } on Failure catch (e) {
      emit(state.copyWith(status: PetStatus.error, errorMessage: e.message));
    }
  }

  Future<void> _onDelete(PetDeleted event, Emitter<PetState> emit) async {
    try {
      await _repository.delete(event.id);
      emit(state.copyWith(
        pets: state.pets.where((p) => p.id != event.id).toList(),
      ));
    } on Failure catch (e) {
      emit(state.copyWith(status: PetStatus.error, errorMessage: e.message));
    }
  }
}
