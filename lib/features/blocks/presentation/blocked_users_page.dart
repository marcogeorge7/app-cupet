import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/di/injector.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/block_remote_data_source.dart';

/// Lets the user review and unblock people they've previously blocked.
class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  late Future<List<BlockedUser>> _future;
  final _busy = <int>{};

  @override
  void initState() {
    super.initState();
    _future = getIt<BlockRemoteDataSource>().fetchBlocked();
  }

  void _reload() {
    setState(() {
      _busy.clear();
      _future = getIt<BlockRemoteDataSource>().fetchBlocked();
    });
  }

  Future<void> _unblock(BlockedUser user) async {
    setState(() => _busy.add(user.userId));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await getIt<BlockRemoteDataSource>().unblockUser(user.userId);
      messenger.showSnackBar(
        SnackBar(content: Text('Unblocked ${user.name ?? 'user'}.')),
      );
      _reload();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy.remove(user.userId));
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not unblock. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: FutureBuilder<List<BlockedUser>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 40),
                  const SizedBox(height: 12),
                  const Text('Could not load blocked users.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _reload,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final users = snapshot.data ?? const <BlockedUser>[];
          if (users.isEmpty) {
            return const EmptyState(
              title: "You haven't blocked anyone",
              subtitle: 'People you block will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = users[index];
                final busy = _busy.contains(user.userId);
                return ListTile(
                  leading: user.avatarUrl != null
                      ? CircleAvatar(
                          backgroundImage:
                              CachedNetworkImageProvider(user.avatarUrl!),
                        )
                      : const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(user.name ?? 'CuPet user'),
                  trailing: busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : OutlinedButton(
                          onPressed: () => _unblock(user),
                          child: const Text('Unblock'),
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
