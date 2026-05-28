import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/realtime/socket_client.dart';
import '../../../../shared/models/message.dart';
import '../../data/message_remote_data_source.dart';

// ── Events ──────────────────────────────────────────────────────────────────

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

/// Re-send a previously-failed optimistic bubble.
class ChatMessageRetried extends ChatEvent {
  const ChatMessageRetried(this.localId);
  final String localId;
  @override
  List<Object?> get props => [localId];
}

/// Load an older page (pull/scroll to the top of history).
class ChatLoadMore extends ChatEvent {
  const ChatLoadMore();
}

/// The local user started/stopped typing — fans out as a Reverb whisper.
class ChatTypingChanged extends ChatEvent {
  const ChatTypingChanged(this.isTyping);
  final bool isTyping;
  @override
  List<Object?> get props => [isTyping];
}

class _ChatRemoteMessage extends ChatEvent {
  const _ChatRemoteMessage(this.message);
  final ChatMessage message;
  @override
  List<Object?> get props => [message.id];
}

class _ChatRemoteRead extends ChatEvent {
  const _ChatRemoteRead(this.readerUserId, this.readAt);
  final int readerUserId;
  final DateTime readAt;
  @override
  List<Object?> get props => [readerUserId, readAt];
}

class _ChatPeerTyping extends ChatEvent {
  const _ChatPeerTyping(this.typing);
  final bool typing;
  @override
  List<Object?> get props => [typing];
}

class _ChatConnectionChanged extends ChatEvent {
  const _ChatConnectionChanged(this.connected);
  final bool connected;
  @override
  List<Object?> get props => [connected];
}

// ── State ───────────────────────────────────────────────────────────────────

enum ChatStatus { initial, loading, ready, error }

class ChatState extends Equatable {
  const ChatState({
    this.status = ChatStatus.initial,
    this.conversationId,
    this.messages = const [],
    this.errorMessage,
    this.connected = true,
    this.peerTyping = false,
    this.loadingMore = false,
    this.hasMore = true,
  });

  final ChatStatus status;
  final int? conversationId;
  final List<ChatMessage> messages;
  final String? errorMessage;

  /// Reverb socket health — drives the "Connecting…" banner.
  final bool connected;

  /// The other participant is composing a message right now.
  final bool peerTyping;

  /// An older-history page request is in flight.
  final bool loadingMore;

  /// More history may exist further back (false once a short page returns).
  final bool hasMore;

  ChatState copyWith({
    ChatStatus? status,
    int? conversationId,
    List<ChatMessage>? messages,
    String? errorMessage,
    bool? connected,
    bool? peerTyping,
    bool? loadingMore,
    bool? hasMore,
  }) =>
      ChatState(
        status: status ?? this.status,
        conversationId: conversationId ?? this.conversationId,
        messages: messages ?? this.messages,
        errorMessage: errorMessage ?? this.errorMessage,
        connected: connected ?? this.connected,
        peerTyping: peerTyping ?? this.peerTyping,
        loadingMore: loadingMore ?? this.loadingMore,
        hasMore: hasMore ?? this.hasMore,
      );

  @override
  List<Object?> get props => [
        status,
        conversationId,
        messages,
        errorMessage,
        connected,
        peerTyping,
        loadingMore,
        hasMore,
      ];
}

// ── Bloc ────────────────────────────────────────────────────────────────────

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required MessageRemoteDataSource remote,
    required SocketHubClient socket,
    required int? myUserId,
  })  : _remote = remote,
        _socket = socket,
        _myUserId = myUserId,
        super(const ChatState()) {
    on<ChatOpened>(_onOpen);
    on<ChatClosed>(_onClose);
    on<ChatMessageSent>(_onSend);
    on<ChatMessageRetried>(_onRetry);
    on<ChatLoadMore>(_onLoadMore);
    on<ChatTypingChanged>(_onTypingChanged);
    on<_ChatRemoteMessage>(_onRemoteMessage);
    on<_ChatRemoteRead>(_onRemoteRead);
    on<_ChatPeerTyping>(_onPeerTyping);
    on<_ChatConnectionChanged>(_onConnectionChanged);
  }

  final MessageRemoteDataSource _remote;
  final SocketHubClient _socket;
  final int? _myUserId;

  static const _pageSize = 50;
  static const _typingThrottle = Duration(seconds: 2);
  static const _typingSelfTimeout = Duration(seconds: 3);
  static const _typingPeerTimeout = Duration(seconds: 5);

  final List<StreamSubscription<Map<String, dynamic>>> _eventSubs = [];
  StreamSubscription<String>? _connSub;
  String? _channelName;

  DateTime? _lastTypingWhisper;
  Timer? _selfTypingTimer;
  Timer? _peerTypingTimer;

  // ── Open / close ──────────────────────────────────────────────────────────

  Future<void> _onOpen(ChatOpened event, Emitter<ChatState> emit) async {
    emit(state.copyWith(
      status: ChatStatus.loading,
      conversationId: event.conversationId,
      messages: const [],
      hasMore: true,
    ));
    try {
      final messages = await _remote.list(event.conversationId);
      emit(state.copyWith(
        status: ChatStatus.ready,
        messages: _sorted(messages),
        hasMore: messages.length >= _pageSize,
        connected: _socket.isConnected,
      ));
      await _markRead(event.conversationId);
      await _subscribeToChannel(event.conversationId);
      _listenConnection();
    } catch (e) {
      emit(state.copyWith(
        status: ChatStatus.error,
        errorMessage: Failure.fromDio(e).message,
      ));
    }
  }

  Future<void> _subscribeToChannel(int conversationId) async {
    await _socket.ensureStarted();
    final channel = 'conversation.$conversationId';
    _channelName = channel;
    await _socket.subscribe(channel);

    // Socket.IO events are namespace-wide, so filter by conversation id.
    _eventSubs.add(_socket.on('message.sent').listen((data) {
      final json = data['message'];
      if (json is! Map) return;
      if ((json['conversation_id'] as num?)?.toInt() != conversationId) return;
      // Our own messages are rendered optimistically (no toOthers() anymore),
      // so ignore the server echo to avoid duplicates.
      if ((json['sender_user_id'] as num?)?.toInt() == _myUserId) return;
      add(_ChatRemoteMessage(ChatMessage.fromJson(Map<String, dynamic>.from(json))));
    }));

    _eventSubs.add(_socket.on('messages.read').listen((data) {
      if ((data['conversation_id'] as num?)?.toInt() != conversationId) return;
      final reader = (data['reader_user_id'] as num?)?.toInt();
      final at = data['read_at'];
      if (reader != null && at is String) {
        final parsed = DateTime.tryParse(at);
        if (parsed != null) add(_ChatRemoteRead(reader, parsed));
      }
    }));

    // Typing whisper — the server relays only to other members, so any frame
    // we receive is the peer's.
    _eventSubs.add(_socket.on('client-typing').listen((data) {
      if ((data['conversation_id'] as num?)?.toInt() != conversationId) return;
      add(_ChatPeerTyping(data['typing'] == true));
    }));
  }

  void _listenConnection() {
    _connSub ??= _socket.connectionStates.listen((s) {
      add(_ChatConnectionChanged(s == 'CONNECTED'));
    });
  }

  Future<void> _cancelEventSubs() async {
    for (final sub in _eventSubs) {
      await sub.cancel();
    }
    _eventSubs.clear();
  }

  Future<void> _onClose(ChatClosed event, Emitter<ChatState> emit) async {
    _selfTypingTimer?.cancel();
    _peerTypingTimer?.cancel();
    await _cancelEventSubs();
    await _connSub?.cancel();
    _connSub = null;
    if (_channelName != null) {
      await _socket.unsubscribe(_channelName!);
      _channelName = null;
    }
    emit(const ChatState());
  }

  // ── Sending ───────────────────────────────────────────────────────────────

  Future<void> _onSend(ChatMessageSent event, Emitter<ChatState> emit) async {
    final id = state.conversationId;
    if (id == null) return;

    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = ChatMessage.optimistic(
      localId: localId,
      conversationId: id,
      senderUserId: _myUserId ?? -1,
      body: event.body,
    );
    emit(state.copyWith(messages: _sorted([...state.messages, optimistic])));

    // Sending implies we stopped typing.
    _stopTyping();

    await _deliver(localId, id, event.body, emit);
  }

  Future<void> _onRetry(
    ChatMessageRetried event,
    Emitter<ChatState> emit,
  ) async {
    final id = state.conversationId;
    final msg = state.messages
        .where((m) => m.localId == event.localId)
        .cast<ChatMessage?>()
        .firstWhere((m) => m != null, orElse: () => null);
    if (id == null || msg == null) return;

    emit(state.copyWith(
      messages: _replaceByLocalId(
        event.localId,
        msg.copyWith(status: MessageStatus.sending),
      ),
    ));
    await _deliver(event.localId, id, msg.body, emit);
  }

  Future<void> _deliver(
    String localId,
    int conversationId,
    String body,
    Emitter<ChatState> emit,
  ) async {
    try {
      final saved = await _remote.send(conversationId, body);
      emit(state.copyWith(messages: _sorted(_replaceByLocalId(localId, saved))));
    } catch (e) {
      final failed = state.messages
          .where((m) => m.localId == localId)
          .cast<ChatMessage?>()
          .firstWhere((m) => m != null, orElse: () => null);
      if (failed != null) {
        emit(state.copyWith(
          messages: _replaceByLocalId(
            localId,
            failed.copyWith(status: MessageStatus.failed),
          ),
          errorMessage: Failure.fromDio(e).message,
        ));
      }
    }
  }

  // ── Pagination ────────────────────────────────────────────────────────────

  Future<void> _onLoadMore(
    ChatLoadMore event,
    Emitter<ChatState> emit,
  ) async {
    final id = state.conversationId;
    if (id == null || state.loadingMore || !state.hasMore) return;

    final oldest = state.messages
        .where((m) => m.id > 0)
        .fold<int?>(null, (min, m) => min == null || m.id < min ? m.id : min);
    if (oldest == null) return;

    emit(state.copyWith(loadingMore: true));
    try {
      final older = await _remote.list(id, beforeId: oldest);
      emit(state.copyWith(
        loadingMore: false,
        hasMore: older.length >= _pageSize,
        messages: _sorted([...older, ...state.messages]),
      ));
    } catch (_) {
      emit(state.copyWith(loadingMore: false));
    }
  }

  // ── Realtime inbound ──────────────────────────────────────────────────────

  Future<void> _onRemoteMessage(
    _ChatRemoteMessage event,
    Emitter<ChatState> emit,
  ) async {
    if (state.messages.any((m) => m.id == event.message.id)) return;
    emit(state.copyWith(
      messages: _sorted([...state.messages, event.message]),
      peerTyping: false,
    ));
    _peerTypingTimer?.cancel();

    // The chat is on-screen, so anything from the peer is read immediately —
    // tell the backend so their bubble flips to "read" live.
    final id = state.conversationId;
    if (id != null && event.message.senderUserId != _myUserId) {
      await _markRead(id);
    }
  }

  void _onRemoteRead(_ChatRemoteRead event, Emitter<ChatState> emit) {
    if (event.readerUserId == _myUserId) return; // our own read receipt
    final updated = [
      for (final m in state.messages)
        (m.senderUserId == _myUserId && m.readAt == null && m.id > 0)
            ? m.copyWith(readAt: event.readAt)
            : m,
    ];
    emit(state.copyWith(messages: updated));
  }

  void _onPeerTyping(_ChatPeerTyping event, Emitter<ChatState> emit) {
    _peerTypingTimer?.cancel();
    if (event.typing) {
      _peerTypingTimer = Timer(
        _typingPeerTimeout,
        () => add(const _ChatPeerTyping(false)),
      );
    }
    emit(state.copyWith(peerTyping: event.typing));
  }

  Future<void> _onConnectionChanged(
    _ChatConnectionChanged event,
    Emitter<ChatState> emit,
  ) async {
    final reconnected = event.connected && !state.connected;
    emit(state.copyWith(connected: event.connected));

    // Recover anything missed while the socket was down: re-pull the latest
    // page and merge, then re-flag read.
    final id = state.conversationId;
    if (reconnected && id != null && state.status == ChatStatus.ready) {
      try {
        final latest = await _remote.list(id);
        final byId = {for (final m in state.messages) m.id: m};
        for (final m in latest) {
          byId[m.id] = m;
        }
        emit(state.copyWith(messages: _sorted(byId.values.toList())));
        await _markRead(id);
      } catch (_) {
        // Best-effort catch-up; live stream resumes regardless.
      }
    }
  }

  // ── Typing (outbound whisper) ─────────────────────────────────────────────

  Future<void> _onTypingChanged(
    ChatTypingChanged event,
    Emitter<ChatState> emit,
  ) async {
    final channel = _channelName;
    if (channel == null) return;

    if (event.isTyping) {
      // Auto-stop if the user goes idle without sending.
      _selfTypingTimer?.cancel();
      _selfTypingTimer = Timer(_typingSelfTimeout, _stopTyping);

      // Throttle: at most one "typing" frame every couple of seconds.
      final now = DateTime.now();
      if (_lastTypingWhisper != null &&
          now.difference(_lastTypingWhisper!) < _typingThrottle) {
        return;
      }
      _lastTypingWhisper = now;
      _socket.whisper(channel, 'client-typing', {
        'typing': true,
        'user_id': _myUserId,
        'conversation_id': state.conversationId,
      });
    } else {
      _stopTyping();
    }
  }

  void _stopTyping() {
    _selfTypingTimer?.cancel();
    _selfTypingTimer = null;
    _lastTypingWhisper = null;
    final channel = _channelName;
    if (channel != null) {
      _socket.whisper(channel, 'client-typing', {
        'typing': false,
        'user_id': _myUserId,
        'conversation_id': state.conversationId,
      });
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _markRead(int conversationId) async {
    try {
      await _remote.markRead(conversationId);
    } catch (_) {
      // Non-critical; the next open or inbound message retries it.
    }
  }

  List<ChatMessage> _replaceByLocalId(String localId, ChatMessage replacement) {
    var replaced = false;
    final next = [
      for (final m in state.messages)
        if (m.localId == localId) ...[replacement] else m,
    ];
    replaced = next.any((m) => identical(m, replacement));
    return replaced ? next : [...state.messages, replacement];
  }

  /// Chronological order with optimistic bubbles (negative ids) last.
  List<ChatMessage> _sorted(List<ChatMessage> list) {
    final copy = [...list]..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return copy;
  }

  @override
  Future<void> close() async {
    _selfTypingTimer?.cancel();
    _peerTypingTimer?.cancel();
    await _cancelEventSubs();
    await _connSub?.cancel();
    if (_channelName != null) {
      await _socket.unsubscribe(_channelName!);
    }
    return super.close();
  }
}
