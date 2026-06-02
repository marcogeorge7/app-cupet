import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/domain/auth_repository.dart';
import '../auth/session_event_bus.dart';
import 'socket_client.dart';

/// Events surfaced from the app-wide `user.{id}` socket-hub channel.
sealed class RealtimeUserEvent {
  const RealtimeUserEvent();
}

/// A new match was created for this user (backend `match.created`). Carries the
/// other pet's name + conversation so the UI can show an in-app banner and deep
/// link straight into the chat. Fields are nullable for resilience against an
/// older/leaner payload.
class MatchCreatedEvent extends RealtimeUserEvent {
  const MatchCreatedEvent({
    this.matchId,
    this.conversationId,
    this.otherPetName,
  });

  final int? matchId;
  final int? conversationId;
  final String? otherPetName;
}

/// A new message arrived for this user. Raised either from the backend's
/// `message.received` event on the user channel (live, even when not inside the
/// chat) or from the FCM foreground handler via
/// [RealtimeUserService.notifyMessageReceived] as a backup.
///
/// [senderName]/[body] are set only on the realtime (socket) path and drive the
/// instant in-app banner; the FCM-backup path leaves them null (its banner is
/// the OS/local notification). [fromSelf] is true for the sender's own echo.
class MessageReceivedEvent extends RealtimeUserEvent {
  const MessageReceivedEvent(
    this.conversationId, {
    this.senderName,
    this.body,
    this.fromSelf = false,
  });

  final int conversationId;
  final String? senderName;
  final String? body;
  final bool fromSelf;
}

/// This user read a conversation (backend `conversation.read`), so the inbox
/// unread badge should clear live without reopening the list. (With one device
/// per account this reaches the single signed-in device.)
class ConversationReadEvent extends RealtimeUserEvent {
  const ConversationReadEvent(this.conversationId);
  final int conversationId;
}

/// App-level subscription to the user's private Reverb channel. Started when
/// the user authenticates and stopped on logout, so the Matches list can stay
/// live regardless of which tab is currently showing.
class RealtimeUserService {
  RealtimeUserService(this._socket, this._sessionBus, this._auth);

  final SocketHubClient _socket;
  final SessionEventBus _sessionBus;
  final AuthRepository _auth;
  final StreamController<RealtimeUserEvent> _controller =
      StreamController<RealtimeUserEvent>.broadcast();

  StreamSubscription<Map<String, dynamic>>? _subscription;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _readSubscription;
  StreamSubscription<void>? _sessionRevokedSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  String? _channelName;
  int? _userId;
  DateTime? _lastKick;
  int? _lastSurfacedMatchId;
  DateTime? _lastSurfacedMatchAt;
  final Map<int, DateTime> _surfacedMessageAt = {};

  Stream<RealtimeUserEvent> get events => _controller.stream;

  Future<void> start(int userId) async {
    // Idempotent: AuthBloc emits `authenticated` repeatedly (e.g. profile
    // refreshes), so re-starting for the same user is a no-op.
    if (_userId == userId && _subscription != null) return;
    if (_userId != null) await stop();

    _userId = userId;
    // Session-scoped listeners (idempotent across re-starts): forward a socket
    // kick to the forced-logout bus, and reconnect when connectivity returns.
    _sessionRevokedSub ??=
        _socket.sessionRevoked.listen((_) => unawaited(_onSocketKicked()));
    _connectivitySub ??=
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    try {
      await _socket.ensureStarted();
      final channel = 'user.$userId';
      _channelName = channel;
      await _socket.subscribe(channel);
      // Announce presence so the backend can tell the app is open and skip a
      // redundant FCM push (the realtime events below cover an open app). The
      // connection drops on background, so presence auto-leaves when closed.
      await _socket.enterPresence(channel);
      // `match.created` only reaches this user's own channel, so no filtering.
      _subscription = _socket.on('match.created').listen((data) {
        // A new conversation now exists; refresh the token so the chat screen
        // can subscribe to it, then surface the event with its match details.
        unawaited(_socket.refreshToken());
        final match = data['match'];
        final matchId =
            match is Map && match['id'] is int ? match['id'] as int : null;
        // Record that this match was surfaced in-app, so the queue-delayed FCM
        // push for the SAME match can skip its duplicate foreground banner (see
        // FcmService._onForegroundMessage). If the socket is down this never
        // runs, so the push correctly falls back to drawing the banner.
        _lastSurfacedMatchId = matchId;
        _lastSurfacedMatchAt = DateTime.now();
        if (match is Map) {
          _controller.add(MatchCreatedEvent(
            matchId: matchId,
            conversationId: match['conversation_id'] is int
                ? match['conversation_id'] as int
                : null,
            otherPetName: match['other_pet_name'] as String?,
          ));
        } else {
          _controller.add(const MatchCreatedEvent());
        }
      });
      // `message.received` also reaches only this user's channel, fired by the
      // backend for every inbound message so the inbox stays live even when the
      // user isn't inside that conversation (whose channel they aren't on).
      _messageSubscription = _socket.on('message.received').listen((data) {
        final conversationId = data['conversation_id'];
        if (conversationId is! int) return;
        final msg = data['message'];
        final senderId =
            msg is Map ? (msg['sender_user_id'] as num?)?.toInt() : null;
        final messageId = msg is Map ? (msg['id'] as num?)?.toInt() : null;
        final fromSelf = senderId != null && senderId == _userId;
        // Record it so the queue-delayed FCM push for the SAME message skips its
        // duplicate foreground banner (see FcmService._onForegroundMessage).
        if (messageId != null && !fromSelf) {
          _recordSurfacedMessage(messageId);
        }
        _controller.add(MessageReceivedEvent(
          conversationId,
          senderName: data['sender_name'] as String?,
          body: msg is Map ? msg['body'] as String? : null,
          fromSelf: fromSelf,
        ));
      });
      // Fired when this user reads a conversation so the inbox unread badge
      // clears live without reopening the list.
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
  /// logged out or while offline (don't hammer a dead network); otherwise
  /// reconnects only if the socket was dropped.
  Future<void> onAppResumed() async {
    if (_userId == null) return;
    if (!await _isOnline()) return;
    await _socket.reconnect();
  }

  /// Close the socket when the app is backgrounded. Background delivery is via
  /// push (FCM), not the socket; [onAppResumed] reopens it on return.
  Future<void> onAppPaused() async {
    if (_userId == null) return;
    _socket.disconnectForBackground();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    // Reconnect only when connectivity actually returns and we're still signed
    // in — gating reconnection on the network keeps the battery healthy.
    if (online && _userId != null) {
      unawaited(_socket.reconnect());
    }
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Called by the FCM foreground handler so a visible Matches list re-orders
  /// when a new message arrives.
  void notifyMessageReceived(int conversationId) {
    _controller.add(MessageReceivedEvent(conversationId));
  }

  /// Whether [matchId] was just surfaced in-app via the realtime banner /
  /// Discover dialog, so the queue-delayed FCM push for the SAME match should
  /// skip its duplicate foreground banner. The window comfortably exceeds the
  /// backend queue dispatch lag (~1 min). Returns false when the socket was
  /// down (no realtime event recorded), so the push still draws the banner.
  bool matchSurfacedRecently(int? matchId) {
    if (matchId == null || _lastSurfacedMatchId != matchId) return false;
    final at = _lastSurfacedMatchAt;
    return at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 2);
  }

  /// Whether [messageId] was just surfaced via the instant socket banner, so the
  /// queue-delayed FCM push for the SAME message skips its duplicate foreground
  /// banner. False when the socket was down (nothing recorded) → FCM still fires.
  bool messageSurfacedRecently(int? messageId) {
    if (messageId == null) return false;
    final at = _surfacedMessageAt[messageId];
    return at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 2);
  }

  void _recordSurfacedMessage(int messageId) {
    final now = DateTime.now();
    _surfacedMessageAt[messageId] = now;
    // Prune stale entries so the map can't grow unbounded.
    _surfacedMessageAt.removeWhere(
      (_, at) => now.difference(at) >= const Duration(minutes: 2),
    );
  }

  /// A socket `session.revoked` isn't proof the session ended — our own
  /// reconnect can trip the one-device presence sweep. The backend deletes the
  /// old bearer on a genuine new login, so verify it: if the bearer is still
  /// valid this was a false alarm, so just reconnect; only force a logout when
  /// the bearer is actually dead. Two kicks within seconds means a reconnect is
  /// being kicked straight back, so we stop fighting it and treat it as real.
  Future<void> _onSocketKicked() async {
    final now = DateTime.now();
    final rapid = _lastKick != null &&
        now.difference(_lastKick!) < const Duration(seconds: 15);
    _lastKick = now;
    if (rapid || !await _auth.verifySession()) {
      _sessionBus.notifyForcedLogout();
      return;
    }
    await _socket.reconnect();
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    await _readSubscription?.cancel();
    _readSubscription = null;
    await _sessionRevokedSub?.cancel();
    _sessionRevokedSub = null;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    if (_channelName != null) {
      await _socket.unsubscribe(_channelName!);
      _channelName = null;
    }
    _userId = null;
  }
}
