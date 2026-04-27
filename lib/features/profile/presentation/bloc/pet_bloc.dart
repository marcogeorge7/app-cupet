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

  @override
  List<Object?> get props =>
      [type, gender, name, bio, birthdate, lat, lng, locationName, primaryPhotoUrl];
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
      final pet = await _repository.create(
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
      emit(state.copyWith(status: PetStatus.ready, pets: [pet, ...state.pets]));
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
