import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/messaging/active_chat_tracker.dart';
import '../../../../shared/models/message.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/chat_bloc.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.conversationId, this.title});

  final int conversationId;
  final String? title;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  /// Inbound messages that landed while the user was scrolled up reading
  /// history — surfaced as a badge on the jump-to-latest button.
  int _pendingBelow = 0;
  bool _showJump = false;

  @override
  void initState() {
    super.initState();
    // Tell the FCM handler to suppress banners for this conversation.
    getIt<ActiveChatTracker>().enter(widget.conversationId);
    context.read<ChatBloc>().add(ChatOpened(widget.conversationId));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    getIt<ActiveChatTracker>().leave(widget.conversationId);
    context.read<ChatBloc>().add(const ChatClosed());
    _scrollController.removeListener(_onScroll);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // The list is reversed, so offset 0 == newest (bottom) and
  // maxScrollExtent == oldest (top).
  bool get _atBottom =>
      !_scrollController.hasClients || _scrollController.offset < 80;

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    final showJump = pos.pixels > 240;
    if (showJump != _showJump) {
      setState(() {
        _showJump = showJump;
        if (!showJump) _pendingBelow = 0;
      });
    }

    // Near the top (oldest) of a reversed list → page in older history.
    if (pos.pixels > pos.maxScrollExtent - 300) {
      context.read<ChatBloc>().add(const ChatLoadMore());
    }
  }

  void _jumpToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
    setState(() => _pendingBelow = 0);
  }

  void _send() {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    context.read<ChatBloc>().add(ChatMessageSent(body));
    _controller.clear();
    // Our own send should always snap us to the bottom.
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
  }

  void _onTextChanged(String value) {
    context
        .read<ChatBloc>()
        .add(ChatTypingChanged(value.trim().isNotEmpty));
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthBloc>().state.user?.id;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: BlocSelector<ChatBloc, ChatState, bool>(
          selector: (s) => s.peerTyping,
          builder: (context, typing) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title ?? 'Chat',
                  style: const TextStyle(fontSize: 18)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: typing
                    ? const Text(
                        'typing…',
                        key: ValueKey('typing'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: CupetColors.primaryDark,
                        ),
                      )
                    : const SizedBox(height: 0, key: ValueKey('idle')),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _ConnectionBanner(),
            Expanded(
              child: BlocConsumer<ChatBloc, ChatState>(
                listenWhen: (a, b) =>
                    a.messages.length != b.messages.length ||
                    a.peerTyping != b.peerTyping,
                listener: (context, state) {
                  final last =
                      state.messages.isNotEmpty ? state.messages.last : null;
                  final mine = last != null && last.senderUserId == myId;
                  if (_atBottom || mine) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                  } else if (last != null && !mine) {
                    setState(() => _pendingBelow += 1);
                  }
                },
                builder: (context, state) {
                  if (state.status == ChatStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.status == ChatStatus.error) {
                    return _ErrorView(
                      message: state.errorMessage ?? 'Something went wrong.',
                      onRetry: () => context
                          .read<ChatBloc>()
                          .add(ChatOpened(widget.conversationId)),
                    );
                  }
                  if (state.messages.isEmpty && !state.peerTyping) {
                    return _EmptyView(name: widget.title);
                  }
                  return _MessageList(
                    state: state,
                    myId: myId,
                    scrollController: _scrollController,
                    onRetry: (localId) => context
                        .read<ChatBloc>()
                        .add(ChatMessageRetried(localId)),
                  );
                },
              ),
            ),
            _Composer(
              controller: _controller,
              onChanged: _onTextChanged,
              onSend: _send,
            ),
          ],
        ),
      ),
      floatingActionButton: _showJump
          ? _JumpButton(count: _pendingBelow, onTap: _jumpToLatest)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ── Message list (reversed, grouped, date-separated) ────────────────────────

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.state,
    required this.myId,
    required this.scrollController,
    required this.onRetry,
  });

  final ChatState state;
  final int? myId;
  final ScrollController scrollController;
  final void Function(String localId) onRetry;

  @override
  Widget build(BuildContext context) {
    // state.messages is chronological (oldest→newest). Build flat render
    // rows with day separators + grouping, then show reversed so the
    // newest sits at the bottom.
    final rows = <_Row>[];
    final msgs = state.messages;
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      final prev = i > 0 ? msgs[i - 1] : null;
      final next = i + 1 < msgs.length ? msgs[i + 1] : null;

      final newDay = prev == null ||
          !DateUtils.isSameDay(prev.createdAt, m.createdAt);
      if (newDay) rows.add(_DateRow(m.createdAt));

      final firstOfGroup = newDay || prev.senderUserId != m.senderUserId;
      final lastOfGroup = next == null ||
          next.senderUserId != m.senderUserId ||
          !DateUtils.isSameDay(next.createdAt, m.createdAt);

      rows.add(_MsgRow(m, firstOfGroup, lastOfGroup));
    }
    if (state.peerTyping) rows.add(const _TypingRow());

    final extra = state.loadingMore ? 1 : 0;

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: rows.length + extra,
      itemBuilder: (context, index) {
        // Oldest end of a reversed list — the spinner for older history.
        if (index == rows.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final row = rows[rows.length - 1 - index];
        if (row is _DateRow) return _DateChip(row.day);
        if (row is _TypingRow) return const _TypingBubble();
        final r = row as _MsgRow;
        return _Bubble(
          message: r.message,
          mine: r.message.senderUserId == myId,
          showTail: r.lastOfGroup,
          onRetry: onRetry,
        );
      },
    );
  }
}

sealed class _Row {
  const _Row();
}

class _DateRow extends _Row {
  const _DateRow(this.day);
  final DateTime day;
}

class _MsgRow extends _Row {
  const _MsgRow(this.message, this.firstOfGroup, this.lastOfGroup);
  final ChatMessage message;
  final bool firstOfGroup;
  final bool lastOfGroup;
}

class _TypingRow extends _Row {
  const _TypingRow();
}

// ── Bubble ──────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.showTail,
    required this.onRetry,
  });

  final ChatMessage message;
  final bool mine;
  final bool showTail;
  final void Function(String localId) onRetry;

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(18);
    final failed = message.status == MessageStatus.failed;

    final bubble = Container(
      margin: EdgeInsets.only(
        top: 2,
        bottom: showTail ? 6 : 2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.76,
      ),
      decoration: BoxDecoration(
        color: failed
            ? CupetColors.danger.withValues(alpha: 0.12)
            : mine
                ? CupetColors.primary
                : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: radius,
          topRight: radius,
          bottomLeft: Radius.circular(mine || !showTail ? 18 : 4),
          bottomRight: Radius.circular(!mine || !showTail ? 18 : 4),
        ),
        border: Border.all(
          color: failed ? CupetColors.danger : CupetColors.soft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.body,
            style: const TextStyle(color: CupetColors.ink, height: 1.25),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('h:mm a').format(message.createdAt.toLocal()),
                style: TextStyle(
                  color: CupetColors.ink.withValues(alpha: 0.45),
                  fontSize: 10.5,
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 4),
                _StatusTicks(message),
              ],
            ],
          ),
        ],
      ),
    );

    final aligned = Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble,
    );

    if (failed && message.localId != null) {
      return Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => onRetry(message.localId!),
            child: aligned,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 6),
            child: Text(
              'Not delivered · tap to retry',
              style: TextStyle(
                color: CupetColors.danger,
                fontSize: 11,
              ),
            ),
          ),
        ],
      );
    }
    return aligned;
  }
}

class _StatusTicks extends StatelessWidget {
  const _StatusTicks(this.message);
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final dim = CupetColors.ink.withValues(alpha: 0.45);
    switch (message.status) {
      case MessageStatus.sending:
        return Icon(Icons.schedule, size: 13, color: dim);
      case MessageStatus.failed:
        return Icon(Icons.error_outline,
            size: 14, color: CupetColors.danger);
      case MessageStatus.sent:
        return Icon(
          message.isRead ? Icons.done_all : Icons.check,
          size: 14,
          color: message.isRead ? Colors.blue.shade700 : dim,
        );
    }
  }
}

// ── Typing bubble ───────────────────────────────────────────────────────────

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 2, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CupetColors.soft),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = (_c.value + i * 0.2) % 1.0;
                final scale = 0.6 + 0.4 * (1 - (t - 0.5).abs() * 2).clamp(0, 1);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Transform.scale(
                    scale: scale.toDouble(),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: CupetColors.ink.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

// ── Date chip ───────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  const _DateChip(this.day);
  final DateTime day;

  String _label() {
    final now = DateTime.now();
    final d = DateUtils.dateOnly(day);
    if (DateUtils.isSameDay(d, now)) return 'Today';
    if (DateUtils.isSameDay(d, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    if (now.difference(d).inDays < 7) return DateFormat('EEEE').format(d);
    return DateFormat('MMM d, y').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: CupetColors.soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _label(),
          style: TextStyle(
            fontSize: 11.5,
            color: CupetColors.ink.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Connection banner ───────────────────────────────────────────────────────

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatBloc, ChatState, bool>(
      selector: (s) => s.connected || s.status != ChatStatus.ready,
      builder: (context, ok) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: ok
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  color: CupetColors.ink.withValues(alpha: 0.06),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        height: 12,
                        width: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Connecting…',
                        style: TextStyle(
                          fontSize: 12,
                          color: CupetColors.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

// ── Composer ────────────────────────────────────────────────────────────────

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: CupetColors.soft)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              onChanged: onChanged,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Say hi…',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final enabled = value.text.trim().isNotEmpty;
              return IconButton.filled(
                onPressed: enabled ? onSend : null,
                icon: const Icon(Icons.send),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Jump-to-latest FAB ──────────────────────────────────────────────────────

class _JumpButton extends StatelessWidget {
  const _JumpButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: CupetColors.accent,
        child: FloatingActionButton.small(
          heroTag: 'chat-jump',
          onPressed: onTap,
          backgroundColor: Colors.white,
          foregroundColor: CupetColors.ink,
          child: const Icon(Icons.keyboard_arrow_down),
        ),
      ),
    );
  }
}

// ── Empty / error ───────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🐾', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(
              name != null ? 'Say hi to $name' : 'Say hi',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CupetColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Break the ice — your pets already matched!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CupetColors.ink.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 40, color: CupetColors.danger),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: CupetColors.ink),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
