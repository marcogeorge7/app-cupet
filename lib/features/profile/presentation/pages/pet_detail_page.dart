import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/pet.dart';
import '../../../../shared/widgets/germeen.dart';
import '../bloc/pet_bloc.dart';

class PetDetailPage extends StatelessWidget {
  const PetDetailPage({super.key, required this.petId});

  final int petId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, state) {
        // The app-level PetBloc is the source of truth for the user's pets.
        // If we land here on a deep link / hot-restart before the list has
        // loaded, kick off a load and show a spinner.
        final pet = state.pets.where((p) => p.id == petId).firstOrNull;

        if (pet == null) {
          if (state.status == PetStatus.initial) {
            context.read<PetBloc>().add(const PetsLoaded());
          }
          return Scaffold(
            appBar: AppBar(),
            body: state.status == PetStatus.loading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pets_outlined, size: 56),
                          const SizedBox(height: 12),
                          const Text("This pet isn\u2019t in your list anymore."),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => context.go('/profile'),
                            child: const Text('Back to profile'),
                          ),
                        ],
                      ),
                    ),
                  ),
          );
        }

        return PetProfileView(pet: pet);
      },
    );
  }
}

/// Renders a pet's full profile (hero gallery, chips, bio, photos,
/// vaccinations). Reused for the owner's own pet (with edit/delete actions)
/// and, with [owner] = false, as a read-only view of a discovered pet.
class PetProfileView extends StatelessWidget {
  const PetProfileView({super.key, required this.pet, this.owner = true});

  final Pet pet;
  final bool owner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final age = _ageLabel(pet.birthdate);
    final allPhotos = _collectPhotoUrls(pet);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            actions: [
              if (owner) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit ${pet.name}',
                  onPressed: () => context.push('/profile/pet/${pet.id}/edit'),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'delete') {
                      await _confirmDelete(context, pet);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete pet'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                pet.name,
                style: const TextStyle(
                  shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                ),
              ),
              background: _HeroPhoto(urls: allPhotos),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            sliver: SliverList.list(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      icon: Icons.pets_outlined,
                      label: pet.type.name.toUpperCase(),
                    ),
                    if (pet.breed != null && pet.breed!.trim().isNotEmpty)
                      _Chip(
                        icon: Icons.badge_outlined,
                        label: pet.breed!,
                      ),
                    _Chip(
                      icon: pet.gender == PetGender.male
                          ? Icons.male
                          : Icons.female,
                      label: pet.gender.name,
                    ),
                    if (age != null)
                      _Chip(icon: Icons.cake_outlined, label: age),
                    if (pet.locationName != null &&
                        pet.locationName!.isNotEmpty)
                      _Chip(
                        icon: Icons.place_outlined,
                        label: pet.locationName!,
                      ),
                    _Chip(
                      icon: pet.isActive
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      label: pet.isActive ? 'Visible in Discover' : 'Hidden',
                      tonal: !pet.isActive,
                    ),
                  ],
                ),
                if (pet.bio != null && pet.bio!.trim().isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle(text: 'About ${pet.name}'),
                  const SizedBox(height: 8),
                  Text(
                    pet.bio!,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
                const SizedBox(height: 24),
                _SectionTitle(text: 'Profile'),
                const SizedBox(height: 8),
                _DetailTile(
                  icon: Icons.tag,
                  label: 'Pet ID',
                  value: '#${pet.id}',
                ),
                if (pet.birthdate != null)
                  _DetailTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'Birthday',
                    value: _formatDate(pet.birthdate!),
                  ),
                if (pet.locationLat != null && pet.locationLng != null)
                  _DetailTile(
                    icon: Icons.my_location,
                    label: 'Coordinates',
                    value:
                        '${pet.locationLat!.toStringAsFixed(4)}, ${pet.locationLng!.toStringAsFixed(4)}',
                  ),
                if (pet.photos.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle(text: 'Photos (${pet.photos.length})'),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pet.photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final p = pet.photos[i];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: p.url,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(
                              width: 96,
                              height: 96,
                              color: cs.surfaceContainerHighest,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _SectionTitle(
                  text: 'Vaccinations (${pet.vaccinations.length})',
                ),
                const SizedBox(height: 8),
                if (pet.vaccinations.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Germeen(size: 48, mood: GermeenMood.sleepy),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No vaccinations recorded yet.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...pet.vaccinations.map(
                    (v) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.vaccines_outlined),
                        title: Text(v.name),
                        subtitle: v.givenAt != null
                            ? Text('Given ${_formatDate(v.givenAt!)}')
                            : null,
                      ),
                    ),
                  ),
                if (owner) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () =>
                        context.push('/profile/pet/${pet.id}/edit'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit pet profile'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Pet pet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete pet?'),
        content: Text(
          'This will permanently remove ${pet.name} and any matches. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<PetBloc>().add(PetDeleted(pet.id));
      if (context.mounted) context.go('/profile');
    }
  }

  static List<String> _collectPhotoUrls(Pet pet) {
    // Prefer the dedicated photos collection (ordered) but fall back to the
    // primary URL so the hero header is never empty when we have at least
    // one image.
    final fromCollection = pet.photos.map((p) => p.url).toList();
    if (fromCollection.isNotEmpty) return fromCollection;
    if (pet.primaryPhotoUrl != null && pet.primaryPhotoUrl!.isNotEmpty) {
      return [pet.primaryPhotoUrl!];
    }
    return const [];
  }

  static String? _ageLabel(DateTime? birthdate) {
    if (birthdate == null) return null;
    final now = DateTime.now();
    var years = now.year - birthdate.year;
    var months = now.month - birthdate.month;
    if (now.day < birthdate.day) months -= 1;
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    if (years <= 0) {
      if (months <= 0) return 'New arrival';
      return '$months mo';
    }
    if (months == 0) return '$years yr';
    return '$years yr · $months mo';
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.primaryContainer,
        alignment: Alignment.center,
        child: const Germeen(size: 160, mood: GermeenMood.sweet),
      );
    }
    if (urls.length == 1) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: urls.first,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined, size: 64),
            ),
          ),
          // Gradient so the title stays readable over light photos.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
          ),
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: urls.length,
          itemBuilder: (_, i) => CachedNetworkImage(
            imageUrl: urls[i],
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined, size: 64),
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black54],
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.tonal = false});

  final IconData icon;
  final String label;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = tonal ? cs.surfaceContainerHighest : cs.secondaryContainer;
    final fg = tonal ? cs.onSurfaceVariant : cs.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
