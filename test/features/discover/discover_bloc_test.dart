import 'package:bloc_test/bloc_test.dart';
import 'package:cupet_app/features/discover/data/discover_remote_data_source.dart';
import 'package:cupet_app/features/discover/presentation/bloc/discover_bloc.dart';
import 'package:cupet_app/shared/models/match.dart';
import 'package:cupet_app/shared/models/pet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements DiscoverRemoteDataSource {}

Pet _pet(int id) => Pet(
      id: id,
      userId: 100 + id,
      type: PetType.dog,
      gender: PetGender.male,
      name: 'Pet$id',
    );

PetMatch _match() => PetMatch(
      id: 9,
      petA: _pet(1),
      petB: _pet(2),
      conversationId: 55,
      createdAt: DateTime(2026),
    );

void main() {
  late _MockRemote remote;
  final deck = [_pet(1), _pet(2), _pet(3)];

  setUp(() => remote = _MockRemote());

  void stubSwipe(SwipeOutcome outcome) {
    when(() => remote.swipe(
          fromPetId: any(named: 'fromPetId'),
          toPetId: any(named: 'toPetId'),
          liked: any(named: 'liked'),
        )).thenAnswer((_) async => outcome);
  }

  group('DiscoverBloc CardSwiped', () {
    // The swiper owns its own card index; the bloc must NOT remove the swiped
    // card from the deck, or the index desyncs and cardBuilder reads past the
    // end of the list (the RangeError that showed as a black screen).
    blocTest<DiscoverBloc, DiscoverState>(
      'keeps the deck stable on a normal swipe',
      setUp: () => stubSwipe(const SwipeOutcome(matched: false)),
      build: () => DiscoverBloc(remote),
      seed: () => DiscoverState(status: DiscoverStatus.ready, deck: deck),
      act: (bloc) =>
          bloc.add(const CardSwiped(fromPetId: 100, toPetId: 1, liked: true)),
      verify: (bloc) => expect(bloc.state.deck, deck),
    );

    blocTest<DiscoverBloc, DiscoverState>(
      'surfaces a match without shrinking the deck',
      setUp: () => stubSwipe(SwipeOutcome(matched: true, match: _match())),
      build: () => DiscoverBloc(remote),
      seed: () => DiscoverState(status: DiscoverStatus.ready, deck: deck),
      act: (bloc) =>
          bloc.add(const CardSwiped(fromPetId: 100, toPetId: 2, liked: true)),
      verify: (bloc) {
        expect(bloc.state.deck, deck);
        expect(bloc.state.match?.id, 9);
      },
    );

    blocTest<DiscoverBloc, DiscoverState>(
      'a failed swipe keeps the deck (no full-screen error wipe)',
      setUp: () => when(() => remote.swipe(
            fromPetId: any(named: 'fromPetId'),
            toPetId: any(named: 'toPetId'),
            liked: any(named: 'liked'),
          )).thenThrow(Exception('network')),
      build: () => DiscoverBloc(remote),
      seed: () => DiscoverState(status: DiscoverStatus.ready, deck: deck),
      act: (bloc) =>
          bloc.add(const CardSwiped(fromPetId: 100, toPetId: 3, liked: false)),
      verify: (bloc) {
        expect(bloc.state.deck, deck);
        expect(bloc.state.status, DiscoverStatus.ready);
      },
    );
  });
}
