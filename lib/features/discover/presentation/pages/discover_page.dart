import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/pet.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/cupet_logo.dart';
import '../../../blocks/presentation/block_sheet.dart';
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
  void initState() {
    super.initState();
    // The deck is derived from the app-level PetBloc, which is otherwise only
    // loaded when the Profile tab is opened. After login the router lands here
    // directly, so kick off the pet load if nothing has loaded it yet.
    final petBloc = context.read<PetBloc>();
    if (petBloc.state.status == PetStatus.initial) {
      petBloc.add(const PetsLoaded());
    }
  }

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
        if (!mounted) return;
        context.read<DiscoverBloc>().add(DeckLoaded(next.id));
      });
    }
  }

  Future<void> _refresh() async {
    context.read<PetBloc>().add(const PetsLoaded());
    if (_activePet != null) {
      context.read<DiscoverBloc>().add(DeckLoaded(_activePet!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, petState) {
        if (petState.pets.isEmpty) {
          final stillLoading = petState.status == PetStatus.initial ||
              petState.status == PetStatus.loading;
          if (stillLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Ready/error with no pets → the user genuinely has no pet profile.
          return Scaffold(
            appBar: AppBar(title: const Text('Discover')),
            body: RefreshIndicator(
              onRefresh: () async =>
                  context.read<PetBloc>().add(const PetsLoaded()),
              child: const _ScrollableCenter(
                child: EmptyState(
                  title: 'Add a pet to start swiping',
                  subtitle:
                      'You need a pet profile before we can find a match.',
                ),
              ),
            ),
          );
        }
        _ensureLoaded(petState.pets);
        return BlocConsumer<DiscoverBloc, DiscoverState>(
          listenWhen: (a, b) => a.match?.id != b.match?.id && b.match != null,
          listener: (context, state) {
            final m = state.match!;
            final other = m.otherPetFor(_activePet?.userId ?? -1);
            final discoverBloc = context.read<DiscoverBloc>();
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
                discoverBloc.add(const MatchAcknowledged());
              }
            });
          },
          builder: (context, state) {
            return Scaffold(
              appBar: AppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupetWordmarkLogo(height: 26),
                    if (_activePet != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· ${_activePet!.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: () {
                      if (_activePet != null) {
                        context
                            .read<DiscoverBloc>()
                            .add(DeckLoaded(_activePet!.id));
                      }
                    },
                  ),
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
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'Report or block',
                      onSelected: (value) {
                        // The deck is stable now, so the visible card is the
                        // swiper's current index — not deck.first.
                        final i = _swiper.cardIndex ?? 0;
                        if (i < 0 || i >= state.deck.length) return;
                        final pet = state.deck[i];
                        if (value == 'report') {
                          showReportSheet(context, pet.id);
                        } else if (value == 'block') {
                          showBlockSheet(
                            context,
                            userId: pet.userId,
                            name: pet.name,
                            onBlocked: () {
                              if (_activePet != null) {
                                context
                                    .read<DiscoverBloc>()
                                    .add(DeckLoaded(_activePet!.id));
                              }
                            },
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'report', child: Text('Report')),
                        PopupMenuItem(value: 'block', child: Text('Block')),
                      ],
                    ),
                ],
              ),
              body: state.status == DiscoverStatus.loading
                  ? const Center(child: CircularProgressIndicator())
                  : state.status == DiscoverStatus.error
                      ? RefreshIndicator(
                          onRefresh: _refresh,
                          child: _ScrollableCenter(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cloud_off, size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    state.errorMessage ??
                                        'Could not load nearby pets.',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: () {
                                      if (_activePet != null) {
                                        context.read<DiscoverBloc>().add(
                                              DeckLoaded(_activePet!.id),
                                            );
                                      }
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Try again'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : state.deck.isEmpty
                          ? RefreshIndicator(
                              onRefresh: _refresh,
                              child: const _ScrollableCenter(
                                child: EmptyState(
                                  illustration:
                                      CupetLogo(size: 140, showWordmark: false),
                                  title: 'No more pets nearby',
                                  subtitle:
                                      'Check back soon for new fluffballs.',
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: AppinioSwiper(
                                      // Key by deck identity: in-deck swipes
                                      // preserve the swiper (and its index),
                                      // while a freshly loaded deck recreates it
                                      // at index 0.
                                      key: ValueKey(
                                        'deck-${state.deck.map((p) => p.id).join(',')}',
                                      ),
                                      controller: _swiper,
                                      cardCount: state.deck.length,
                                      // Last card swiped → fetch a fresh deck
                                      // (backend excludes already-swiped pets).
                                      // An empty reload shows the EmptyState.
                                      onEnd: () {
                                        if (_activePet != null) {
                                          context
                                              .read<DiscoverBloc>()
                                              .add(DeckLoaded(_activePet!.id));
                                        }
                                      },
                                      cardBuilder: (_, i) =>
                                          PetCard(pet: state.deck[i]),
                                      onSwipeEnd: (prev, target, activity) {
                                        final pet = state.deck.length > prev
                                            ? state.deck[prev]
                                            : null;
                                        if (pet == null ||
                                            _activePet == null) {
                                          return;
                                        }
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
                                        onPressed: () => _swiper.swipeLeft(),
                                      ),
                                      _ActionButton(
                                        icon: Icons.favorite,
                                        background: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        onPressed: () => _swiper.swipeRight(),
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

/// Wraps non-scrolling content so it can host a [RefreshIndicator] pull
/// gesture while staying vertically centred.
class _ScrollableCenter extends StatelessWidget {
  const _ScrollableCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
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
