import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../shared/models/match.dart';
import '../../../../shared/models/pet.dart';
import '../../data/discover_remote_data_source.dart';

abstract class DiscoverEvent extends Equatable {
  const DiscoverEvent();
  @override
  List<Object?> get props => [];
}

class DeckLoaded extends DiscoverEvent {
  const DeckLoaded(this.petId);
  final int petId;
  @override
  List<Object?> get props => [petId];
}

class CardSwiped extends DiscoverEvent {
  const CardSwiped({
    required this.fromPetId,
    required this.toPetId,
    required this.liked,
  });
  final int fromPetId;
  final int toPetId;
  final bool liked;
  @override
  List<Object?> get props => [fromPetId, toPetId, liked];
}

class MatchAcknowledged extends DiscoverEvent {
  const MatchAcknowledged();
}

enum DiscoverStatus { initial, loading, ready, swiping, error }

class DiscoverState extends Equatable {
  const DiscoverState({
    this.status = DiscoverStatus.initial,
    this.deck = const [],
    this.match,
    this.errorMessage,
  });

  final DiscoverStatus status;
  final List<Pet> deck;
  final PetMatch? match;
  final String? errorMessage;

  DiscoverState copyWith({
    DiscoverStatus? status,
    List<Pet>? deck,
    PetMatch? match,
    bool clearMatch = false,
    String? errorMessage,
    bool clearError = false,
  }) =>
      DiscoverState(
        status: status ?? this.status,
        deck: deck ?? this.deck,
        match: clearMatch ? null : (match ?? this.match),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  List<Object?> get props => [status, deck, match?.id, errorMessage];
}

class DiscoverBloc extends Bloc<DiscoverEvent, DiscoverState> {
  DiscoverBloc(this._remote) : super(const DiscoverState()) {
    on<DeckLoaded>(_onLoad);
    on<CardSwiped>(_onSwipe);
    on<MatchAcknowledged>(
      (event, emit) => emit(state.copyWith(clearMatch: true)),
    );
  }

  final DiscoverRemoteDataSource _remote;

  Future<void> _onLoad(DeckLoaded event, Emitter<DiscoverState> emit) async {
    emit(state.copyWith(status: DiscoverStatus.loading, clearError: true));
    try {
      final deck = await _remote.deck(petId: event.petId);
      emit(state.copyWith(status: DiscoverStatus.ready, deck: deck));
    } catch (e) {
      emit(state.copyWith(
        status: DiscoverStatus.error,
        errorMessage: Failure.fromDio(e).message,
      ));
    }
  }

  Future<void> _onSwipe(CardSwiped event, Emitter<DiscoverState> emit) async {
    final remaining =
        state.deck.where((p) => p.id != event.toPetId).toList(growable: false);
    emit(state.copyWith(status: DiscoverStatus.swiping, deck: remaining));
    try {
      final outcome = await _remote.swipe(
        fromPetId: event.fromPetId,
        toPetId: event.toPetId,
        liked: event.liked,
      );
      emit(state.copyWith(
        status: DiscoverStatus.ready,
        match: outcome.match,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DiscoverStatus.error,
        errorMessage: Failure.fromDio(e).message,
      ));
    }
  }
}
