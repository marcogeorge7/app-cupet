import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../shared/models/match.dart';
import '../../data/match_remote_data_source.dart';

abstract class MatchesEvent extends Equatable {
  const MatchesEvent();
  @override
  List<Object?> get props => [];
}

class MatchesLoaded extends MatchesEvent {
  const MatchesLoaded({this.petId});
  final int? petId;
  @override
  List<Object?> get props => [petId];
}

class MatchUnmatched extends MatchesEvent {
  const MatchUnmatched(this.matchId);
  final int matchId;
  @override
  List<Object?> get props => [matchId];
}

enum MatchesStatus { initial, loading, ready, error }

class MatchesState extends Equatable {
  const MatchesState({
    this.status = MatchesStatus.initial,
    this.matches = const [],
    this.errorMessage,
  });

  final MatchesStatus status;
  final List<PetMatch> matches;
  final String? errorMessage;

  MatchesState copyWith({
    MatchesStatus? status,
    List<PetMatch>? matches,
    String? errorMessage,
  }) =>
      MatchesState(
        status: status ?? this.status,
        matches: matches ?? this.matches,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [status, matches, errorMessage];
}

class MatchesBloc extends Bloc<MatchesEvent, MatchesState> {
  MatchesBloc(this._remote) : super(const MatchesState()) {
    on<MatchesLoaded>(_onLoad);
    on<MatchUnmatched>(_onUnmatch);
  }

  final MatchRemoteDataSource _remote;

  Future<void> _onUnmatch(
    MatchUnmatched event,
    Emitter<MatchesState> emit,
  ) async {
    // Optimistic: drop the row immediately, restore it if the call fails.
    final previous = state.matches;
    emit(state.copyWith(
      matches: previous.where((m) => m.id != event.matchId).toList(),
    ));
    try {
      await _remote.unmatch(event.matchId);
    } catch (e) {
      emit(state.copyWith(
        status: MatchesStatus.error,
        matches: previous,
        errorMessage: Failure.fromDio(e).message,
      ));
    }
  }

  Future<void> _onLoad(MatchesLoaded event, Emitter<MatchesState> emit) async {
    emit(state.copyWith(status: MatchesStatus.loading));
    try {
      final list = await _remote.list(petId: event.petId);
      emit(state.copyWith(status: MatchesStatus.ready, matches: list));
    } catch (e) {
      emit(state.copyWith(
        status: MatchesStatus.error,
        errorMessage: Failure.fromDio(e).message,
      ));
    }
  }
}
