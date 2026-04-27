import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../reports/presentation/report_sheet.dart';
import '../bloc/matches_bloc.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  @override
  void initState() {
    super.initState();
    context.read<MatchesBloc>().add(const MatchesLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthBloc>().state.user?.id ?? -1;
    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: BlocBuilder<MatchesBloc, MatchesState>(
        builder: (context, state) {
          if (state.status == MatchesStatus.loading && state.matches.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.matches.isEmpty) {
            return const EmptyState(
              title: 'No matches yet',
              subtitle: 'Keep swiping to find your fluffball a date.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                context.read<MatchesBloc>().add(const MatchesLoaded()),
            child: ListView.separated(
              itemCount: state.matches.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final match = state.matches[index];
                final other = match.otherPetFor(userId);
                return ListTile(
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundImage: other.primaryPhotoUrl != null
                        ? CachedNetworkImageProvider(other.primaryPhotoUrl!)
                        : null,
                    child: other.primaryPhotoUrl == null
                        ? const Text('🐾')
                        : null,
                  ),
                  title: Text(other.name),
                  subtitle: Text(
                      '${other.type.name.toUpperCase()} · ${other.gender.name}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'report') {
                        showReportSheet(context, other.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'report', child: Text('Report')),
                    ],
                  ),
                  onTap: () {
                    if (match.conversationId != null) {
                      context.push(
                        '/chat/${match.conversationId}?title=${Uri.encodeComponent(other.name)}',
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
