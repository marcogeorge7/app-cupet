import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/messaging/badge_service.dart';
import '../../../../core/realtime/realtime_user_service.dart';
import '../../../../shared/widgets/cupet_logo.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/germeen.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../blocks/presentation/block_sheet.dart';
import '../../../reports/presentation/report_sheet.dart';
import '../bloc/matches_bloc.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  StreamSubscription<RealtimeUserEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    context.read<MatchesBloc>().add(const MatchesLoaded());
    // MatchesBloc is route-scoped, so the app-wide RealtimeUserService can't
    // reach it directly — bridge its events into a reload here (same pattern
    // ChatBloc uses for the Reverb stream).
    _realtimeSub = getIt<RealtimeUserService>().events.listen((_) {
      if (mounted) {
        context.read<MatchesBloc>().add(const MatchesLoaded());
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthBloc>().state.user?.id ?? -1;
    return Scaffold(
      appBar: AppBar(title: const CupetWordmarkLogo(height: 28)),
      body: BlocListener<MatchesBloc, MatchesState>(
        listenWhen: (p, c) => p.matches != c.matches,
        listener: (context, state) {
          // Keep the OS app-icon badge in sync with the live unread total while
          // the app is open (it's cleared on resume; this re-asserts the truth).
          final total =
              state.matches.fold<int>(0, (sum, m) => sum + m.unreadCount);
          getIt<BadgeService>().setCount(total);
        },
        child: BlocBuilder<MatchesBloc, MatchesState>(
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
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final match = state.matches[index];
                final other = match.otherPetFor(userId);
                final preview = match.lastMessage;
                final hasUnread = match.unreadCount > 0;
                final subtitleText = preview != null
                    ? (preview.senderUserId == userId
                        ? 'You: ${preview.body}'
                        : preview.body)
                    : '${other.type.name.toUpperCase()} · ${other.gender.name}';
                return ListTile(
                  leading: other.primaryPhotoUrl != null
                      ? CircleAvatar(
                          radius: 28,
                          backgroundImage: CachedNetworkImageProvider(
                              other.primaryPhotoUrl!),
                        )
                      : const Germeen(size: 56, mood: GermeenMood.sassy),
                  title: Text(
                    other.name,
                    style: hasUnread
                        ? const TextStyle(fontWeight: FontWeight.bold)
                        : null,
                  ),
                  subtitle: Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: hasUnread
                        ? const TextStyle(fontWeight: FontWeight.w600)
                        : null,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${match.unreadCount}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'report') {
                            showReportSheet(context, other.id);
                          } else if (value == 'block') {
                            showBlockSheet(
                              context,
                              userId: other.userId,
                              name: other.name,
                              onBlocked: () => context
                                  .read<MatchesBloc>()
                                  .add(const MatchesLoaded()),
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
                  onTap: () async {
                    if (match.conversationId != null) {
                      // Pass the peer's pet + user ids so the chat screen can
                      // offer Report/Block. Reload on return so a block made
                      // inside the chat drops the row immediately.
                      await context.push(
                        '/chat/${match.conversationId}'
                        '?title=${Uri.encodeComponent(other.name)}'
                        '&peerPetId=${other.id}'
                        '&peerUserId=${other.userId}',
                      );
                      if (context.mounted) {
                        context.read<MatchesBloc>().add(const MatchesLoaded());
                      }
                    }
                  },
                );
              },
            ),
          );
          },
        ),
      ),
    );
  }
}
