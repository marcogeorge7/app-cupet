import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(ChatOpened(widget.conversationId));
  }

  @override
  void dispose() {
    context.read<ChatBloc>().add(const ChatClosed());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    context.read<ChatBloc>().add(ChatMessageSent(body));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthBloc>().state.user?.id;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Chat')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BlocConsumer<ChatBloc, ChatState>(
                listenWhen: (a, b) => a.messages.length != b.messages.length,
                listener: (context, state) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController
                          .jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });
                },
                builder: (context, state) {
                  if (state.status == ChatStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      final mine = message.senderUserId == myId;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: mine
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF5EAD0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message.body),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('h:mm a').format(message.createdAt),
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Say hi…',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
