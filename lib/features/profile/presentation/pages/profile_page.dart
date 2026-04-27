import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/pet.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/pet_bloc.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    context.read<PetBloc>().add(const PetsLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLoggedOut()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/profile/new-pet'),
        icon: const Icon(Icons.add),
        label: const Text('Add pet'),
      ),
      body: BlocBuilder<PetBloc, PetState>(
        builder: (context, state) {
          if (state.status == PetStatus.loading && state.pets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.pets.isEmpty) {
            return EmptyState(
              title: 'No pets yet',
              subtitle:
                  '${user?.name ?? 'Hey'}! Add your first pet so we can find them a date.',
              action: ElevatedButton(
                onPressed: () => context.push('/profile/new-pet'),
                child: const Text('Add a pet'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                context.read<PetBloc>().add(const PetsLoaded()),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.pets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final pet = state.pets[index];
                return _PetTile(pet: pet);
              },
            ),
          );
        },
      ),
    );
  }
}

class _PetTile extends StatelessWidget {
  const _PetTile({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 72,
                height: 72,
                child: pet.primaryPhotoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: pet.primaryPhotoUrl!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.primary,
                        alignment: Alignment.center,
                        child: const Text('🐾',
                            style: TextStyle(fontSize: 36)),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pet.name,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${pet.type.name.toUpperCase()} · ${pet.gender.name}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (pet.locationName != null)
                    Text(pet.locationName!,
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  context.read<PetBloc>().add(PetDeleted(pet.id)),
            ),
          ],
        ),
      ),
    );
  }
}
