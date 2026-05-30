import 'dart:async';

import 'package:flutter/foundation.dart';

import 'socket_client.dart';

/// Events surfaced from the app-wide `user.{id}` socket-hub channel.
sealed class RealtimeUserEvent {
  const RealtimeUserEvent();
}

/// A new match was created for this user (backend `match.created`).
class MatchCreatedEvent extends RealtimeUserEvent {
  const MatchCreatedEvent();
}

/// A new message arrived for this user. Raised either from the backend's
/// `message.received` event on the user channel (live, even when not inside the
/// chat) or from the FCM foreground handler via
/// [RealtimeUserService.notifyMessageReceived] as a backup.
class MessageReceivedEvent extends RealtimeUserEvent {
  const MessageReceivedEvent(this.conversationId);
  final int conversationId;
}

/// This user read a conversation (backend `conversation.read`), so the inbox
/// unread badge should clear — fires across all of the user's devices.
class ConversationReadEvent extends RealtimeUserEvent {
  const ConversationReadEvent(this.conversationId);
  final int conversationId;
}

/// App-level subscription to the user's private Reverb channel. Started when
/// the user authenticates and stopped on logout, so the Matches list can stay
/// live regardless of which tab is currently showing.
class RealtimeUserService {
  RealtimeUserService(this._socket);

  final SocketHubClient _socket;
  final StreamController<RealtimeUserEvent> _controller =
      StreamController<RealtimeUserEvent>.broadcast();

  StreamSubscription<Map<String, dynamic>>? _subscription;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _readSubscription;
  String? _channelName;
  int? _userId;

  Stream<RealtimeUserEvent> get events => _controller.stream;

  Future<void> start(int userId) async {
    // Idempotent: AuthBloc emits `authenticated` repeatedly (e.g. profile
    // refreshes), so re-starting for the same user is a no-op.
    if (_userId == userId && _subscription != null) return;
    if (_userId != null) await stop();

    _userId = userId;
    try {
      await _socket.ensureStarted();
      final channel = 'user.$userId';
      _channelName = channel;
      await _socket.subscribe(channel);
      // `match.created` only reaches this user's own channel, so no filtering.
      _subscription = _socket.on('match.created').listen((_) {
        // A new conversation now exists; refresh the token so the chat screen
        // can subscribe to it, then surface the event.
        unawaited(_socket.refreshToken());
        _controller.add(const MatchCreatedEvent());
      });
      // `message.received` also reaches only this user's channel, fired by the
      // backend for every inbound message so the inbox stays live even when the
      // user isn't inside that conversation (whose channel they aren't on).
      _messageSubscription = _socket.on('message.received').listen((data) {
        final conversationId = data['conversation_id'];
        if (conversationId is int) {
          _controller.add(MessageReceivedEvent(conversationId));
        }
      });
      // Fired when this user reads a conversation (on any of their devices) so
      // the inbox unread badge clears live without reopening the list.
      _readSubscription = _socket.on('conversation.read').listen((data) {
        final conversationId = data['conversation_id'];
        if (conversationId is int) {
          _controller.add(ConversationReadEvent(conversationId));
        }
      });
    } catch (e) {
      debugPrint('RealtimeUserService start failed: $e');
    }
  }

  /// Re-establish realtime after the app returns to the foreground. No-op when
  /// logged out; otherwise reconnects only if the socket was dropped.
  Future<void> onAppResumed() async {
    if (_userId == null) return;
    await _socket.reconnect();
  }

  /// Called by the FCM foreground handler so a visible Matches list re-orders
  /// when a new message arrives.
  void notifyMessageReceived(int conversationId) {
    _controller.add(MessageReceivedEvent(conversationId));
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    await _readSubscription?.cancel();
    _readSubscription = null;
    if (_channelName != null) {
      await _socket.unsubscribe(_channelName!);
      _channelName = null;
    }
    _userId = null;
  }
}
