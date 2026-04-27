import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/pet.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../profile/presentation/bloc/pet_bloc.dart';
import '../../../reports/presentation/report_sheet.dart';
import '../bloc/discover_bloc.dart';
import '../widgets/pet_card.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _swiper = AppinioSwiperController();
  Pet? _activePet;

  @override
  void dispose() {
    _swiper.dispose();
    super.dispose();
  }

  void _ensureLoaded(List<Pet> pets) {
    if (pets.isEmpty) return;
    final next = _activePet != null
        ? pets.firstWhere((p) => p.id == _activePet!.id, orElse: () => pets.first)
        : pets.first;
    if (next.id != _activePet?.id) {
      _activePet = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<DiscoverBloc>().add(DeckLoaded(next.id));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, petState) {
        if (petState.status == PetStatus.loading && petState.pets.isEmpty) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (petState.pets.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Discover')),
            body: const EmptyState(
              title: 'Add a pet to start swiping',
              subtitle: 'You need a pet profile before we can find a match.',
            ),
          );
        }
        _ensureLoaded(petState.pets);
        return BlocConsumer<DiscoverBloc, DiscoverState>(
          listenWhen: (a, b) => a.match?.id != b.match?.id && b.match != null,
          listener: (context, state) {
            final m = state.match!;
            final other = m.otherPetFor(_activePet?.userId ?? -1);
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("It's a match!"),
                content: Text('You matched with ${other.name}.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Keep swiping'),
                  ),
                ],
              ),
            ).then((_) {
              if (mounted) {
                context.read<DiscoverBloc>().add(const MatchAcknowledged());
              }
            });
          },
          builder: (context, state) {
            return Scaffold(
              appBar: AppBar(
                title: Text('Discover · ${_activePet?.name ?? ''}'),
                actions: [
                  if (petState.pets.length > 1)
                    PopupMenuButton<int>(
                      icon: const Icon(Icons.swap_horiz),
                      itemBuilder: (_) => petState.pets
                          .map((p) =>
                              PopupMenuItem(value: p.id, child: Text(p.name)))
                          .toList(),
                      onSelected: (id) {
                        final next = petState.pets.firstWhere((p) => p.id == id);
                        setState(() => _activePet = next);
                        context.read<DiscoverBloc>().add(DeckLoaded(id));
                      },
                    ),
                  if (state.deck.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.flag_outlined),
                      tooltip: 'Report top card',
                      onPressed: () =>
                          showReportSheet(context, state.deck.first.id),
                    ),
                ],
              ),
              body: state.status == DiscoverStatus.loading
                  ? const Center(child: CircularProgressIndicator())
                  : state.deck.isEmpty
                      ? const EmptyState(
                          title: 'No more pets nearby',
                          subtitle: 'Check back soon for new fluffballs.',
                        )
                      : Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Expanded(
                                child: AppinioSwiper(
                                  controller: _swiper,
                                  cardCount: state.deck.length,
                                  cardBuilder: (_, i) =>
                                      PetCard(pet: state.deck[i]),
                                  onSwipeEnd: (prev, target, activity) {
                                    final pet = state.deck.length > prev
                                        ? state.deck[prev]
                                        : null;
                                    if (pet == null || _activePet == null) return;
                                    final liked = target > prev; // right
                                    context.read<DiscoverBloc>().add(
                                          CardSwiped(
                                            fromPetId: _activePet!.id,
                                            toPetId: pet.id,
                                            liked: liked,
                                          ),
                                        );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _ActionButton(
                                    icon: Icons.close,
                                    background: Colors.white,
                                    onPressed: () =>
                                        _swiper.swipeLeft(),
                                  ),
                                  _ActionButton(
                                    icon: Icons.favorite,
                                    background: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    onPressed: () =>
                                        _swiper.swipeRight(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
            );
          },
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.background,
    required this.onPressed,
  });

  final IconData icon;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onPressed,
      child: Container(
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 32),
      ),
    );
  }
}
