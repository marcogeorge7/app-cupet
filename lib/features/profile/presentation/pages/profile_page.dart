import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/pet.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/widgets/cupet_logo.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/germeen.dart';
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
        title: const CupetWordmarkLogo(height: 28),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
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
          final petCount = state.pets.length;
          return RefreshIndicator(
            onRefresh: () async {
              context.read<PetBloc>().add(const PetsLoaded());
              context.read<AuthBloc>().add(const AuthCheckRequested());
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _ProfileHeader(user: user, petCount: petCount),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: 'Your pets',
                  trailing: petCount > 0
                      ? Text(
                          '$petCount',
                          style: Theme.of(context).textTheme.labelLarge,
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                if (state.status == PetStatus.loading && state.pets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.pets.isEmpty)
                  EmptyState(
                    title: 'No pets yet',
                    subtitle:
                        '${user?.name ?? 'Hey'}! Add your first pet so we can find them a date.',
                    action: ElevatedButton(
                      onPressed: () => context.push('/profile/new-pet'),
                      child: const Text('Add a pet'),
                    ),
                  )
                else
                  ...List.generate(state.pets.length, (index) {
                    final pet = state.pets[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == state.pets.length - 1 ? 0 : 12,
                      ),
                      child: _PetTile(pet: pet),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?trailing,
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.petCount});

  final AppUser? user;
  final int petCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final name = (user?.name == null || user!.name!.trim().isEmpty)
        ? 'Add your name'
        : user!.name!;
    final hasName = user?.name != null && user!.name!.trim().isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(url: user?.avatarUrl, name: user?.name),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: hasName ? null : cs.onSurfaceVariant,
                          fontStyle: hasName
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                      if (user?.phone.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        _IconLine(
                          icon: Icons.phone_outlined,
                          text: user!.phone,
                        ),
                      ],
                      if (user?.email != null && user!.email!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _IconLine(icon: Icons.mail_outline, text: user!.email!),
                      ],
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit profile',
                  onPressed: user == null
                      ? null
                      : () => context.push('/profile/edit'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Stat(label: 'Pets', value: '$petCount'),
                ),
                Container(width: 1, height: 32, color: cs.outlineVariant),
                Expanded(
                  child: _Stat(
                    label: 'Member since',
                    value: _formatMonthYear(user?.createdAt),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatMonthYear(DateTime? dt) {
    if (dt == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url, this.name});
  final String? url;
  final String? name;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _initialsAvatar(context, size),
          placeholder: (_, _) => _initialsAvatar(context, size),
        ),
      );
    }
    return _initialsAvatar(context, size);
  }

  Widget _initialsAvatar(BuildContext context, double size) {
    final cs = Theme.of(context).colorScheme;
    final initial = (name == null || name!.trim().isEmpty)
        ? '?'
        : name!.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PetTile extends StatelessWidget {
  const _PetTile({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/profile/pet/${pet.id}'),
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
                      : const Germeen(size: 72, mood: GermeenMood.sweet),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pet.type.name.toUpperCase()} · ${pet.gender.name}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (pet.locationName != null)
                      Text(
                        pet.locationName!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit ${pet.name}',
                onPressed: () => context.push('/profile/pet/${pet.id}/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete ${pet.name}',
                onPressed: () async {
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
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
