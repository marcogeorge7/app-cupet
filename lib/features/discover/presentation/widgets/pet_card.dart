import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../shared/models/pet.dart';

class PetCard extends StatelessWidget {
  const PetCard({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (pet.primaryPhotoUrl != null)
            CachedNetworkImage(
              imageUrl: pet.primaryPhotoUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) => _placeholder(context),
            )
          else
            _placeholder(context),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pet.name,
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      pet.type.name.toUpperCase(),
                      pet.gender.name,
                      if (pet.locationName != null) pet.locationName!,
                    ].join(' · '),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (pet.bio != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      pet.bio!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.primary,
        alignment: Alignment.center,
        child: const Text('🐾', style: TextStyle(fontSize: 80)),
      );
}
