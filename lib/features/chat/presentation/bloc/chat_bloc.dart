import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/realtime/reverb_client.dart';
import '../../../../shared/models/message.dart';
import '../../data/message_remote_data_source.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

class ChatOpened extends ChatEvent {
  const ChatOpened(this.conversationId);
  final int conversationId;
  @override
  List<Object?> get props => [conversationId];
}

class ChatClosed extends ChatEvent {
  const ChatClosed();
}

class ChatMessageSent extends ChatEvent {
  const ChatMessageSent(this.body);
  final String body;
  @override
  List<Object?> get props => [body];
}

class _ChatRemoteMessage extends ChatEvent {
  const _ChatRemoteMessage(this.message);
  final ChatMessage message;
  @override
  List<Object?> get props => [message.id];
}

enum ChatStatus { initial, loading, ready, error }

class ChatState extends Equatable {
  const ChatState({
    this.status = ChatStatus.initial,
    this.conversationId,
    this.messages = const [],
    this.errorMessage,
  });

  final ChatStatus status;
  final int? conversationId;
  final List<ChatMessage> messages;
  final String? errorMessage;

  ChatState copyWith({
    ChatStatus? status,
    int? conversationId,
    List<ChatMessage>? messages,
    String? errorMessage,
  }) =>
      ChatState(
        status: status ?? this.status,
        conversationId: conversationId ?? this.conversationId,
        messages: messages ?? this.messages,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  @override
  List<Object?> get props => [status, conversationId, messages, errorMessage];
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required MessageRemoteDataSource remote,
    required ReverbClient reverb,
  })  : _remote = remote,
        _reverb = reverb,
        super(const ChatState()) {
    on<ChatOpened>(_onOpen);
    on<ChatClosed>(_onClose);
    on<ChatMessageSent>(_onSend);
    on<_ChatRemoteMessage>(_onRemoteMessage);
  }

  final MessageRemoteDataSource _remote;
  final ReverbClient _reverb;
  StreamSubscription<Map<dynamic, dynamic>>? _subscription;
  String? _channelName;

  Future<void> _onOpen(ChatOpened event, Emitter<ChatState> emit) async {
    emit(state.copyWith(
      status: ChatStatus.loading,
      conversationId: event.conversationId,
      messages: const [],
    ));
    try {
      final messages = await _remote.list(event.conversationId);
      emit(state.copyWith(status: ChatStatus.ready, messages: messages));
      await _remote.markRead(event.conversationId);
      await _subscribeToChannel(event.conversationId);
    } catch (e) {
      emit(state.copyWith(
        status: ChatStatus.error,
        errorMessage: Failure.fromDio(e).message,
      ));
    }
  }

  Future<void> _subscribeToChannel(int conversationId) async {
    await _reverb.ensureStarted();
    final channel = 'private-conversation.$conversationId';
    _channelName = channel;
    final stream = _reverb.subscribe(channel);
    _subscription = stream.listen((payload) {
      if (payload['event'] != 'message.sent') return;
      final raw = payload['data'];
      Map<String, dynamic>? body;
      if (raw is String) {
        body = jsonDecode(raw) as Map<String, dynamic>;
      } else if (raw is Map) {
        body = Map<String, dynamic>.from(raw);
      }
      final messageJson = body?['message'] as Map<String, dynamic>?;
      if (messageJson != null) {
        add(_ChatRemoteMessage(ChatMessage.fromJson(messageJson)));
      }
    });
  }

  Future<void> _onClose(ChatClosed event, Emitter<ChatState> emit) async {
    await _subscription?.cancel();
    _subscription = null;
    if (_channelName != null) {
      await _reverb.unsubscribe(_channelName!);
      _channelName = null;
    }
    emit(const ChatState());
  }

  Future<void> _onSend(ChatMessageSent event, Emitter<ChatState> emit) async {
    final id = state.conversationId;
    if (id == null) return;
    try {
      final message = await _remote.send(id, event.body);
      _appendMessage(message, emit);
    } catch (e) {
      emit(state.copyWith(errorMessage: Failure.fromDio(e).message));
    }
  }

  void _onRemoteMessage(_ChatRemoteMessage event, Emitter<ChatState> emit) {
    _appendMessage(event.message, emit);
  }

  void _appendMessage(ChatMessage message, Emitter<ChatState> emit) {
    if (state.messages.any((m) => m.id == message.id)) return;
    emit(state.copyWith(messages: [...state.messages, message]));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    if (_channelName != null) {
      await _reverb.unsubscribe(_channelName!);
    }
    return super.close();
  }
}
