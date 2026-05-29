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

/// A new message arrived for this user. Messages broadcast on the conversation
/// channel (not the user channel), so this is raised from the FCM foreground
/// handler via [RealtimeUserService.notifyMessageReceived].
class MessageReceivedEvent extends RealtimeUserEvent {
  const MessageReceivedEvent(this.conversationId);
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
    if (_channelName != null) {
      await _socket.unsubscribe(_channelName!);
      _channelName = null;
    }
    _userId = null;
  }
}
