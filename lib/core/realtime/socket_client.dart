import 'dart:async';

import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Realtime client backed by **Ably** (replaces the old socket-hub / Socket.IO).
///
/// Connection auth uses a short-lived Ably **token request** minted by the cupet
/// backend at `GET /socket/token`, scoped (capability) to the channels this user
/// may use. The backend publishes events server-side via the Ably REST API; here
/// we only subscribe and surface events.
///
/// Channels are plain names (`user.{id}`, `conversation.{id}`). Each Ably
/// message's `name` is the event; consumers listen per event via [on] and filter
/// by id in the payload — the public API is unchanged from the Socket.IO client.
class SocketHubClient {
  SocketHubClient(this._dio);

  final Dio _dio;
  ably.Realtime? _realtime;
  bool _starting = false;

  /// Channels we want to be subscribed to; replayed on every (re)connect.
  final Set<String> _subscribed = {};
  final Map<String, StreamSubscription<ably.Message>> _channelSubs = {};

  /// One broadcast controller per event name we surface.
  final Map<String, StreamController<Map<String, dynamic>>> _events = {};

  final StreamController<String> _connectionState =
      StreamController<String>.broadcast();
  StreamSubscription<ably.ConnectionStateChange>? _connSub;
  String _state = 'DISCONNECTED';

  /// Kept for API compatibility with the old one-device socket kick. Ably has no
  /// server-side kick, so this never emits — newest-login-wins is enforced by the
  /// backend instead (the old device's API calls 401 → forced logout).
  final StreamController<void> _sessionRevoked =
      StreamController<void>.broadcast();

  Stream<String> get connectionStates => _connectionState.stream;
  Stream<void> get sessionRevoked => _sessionRevoked.stream;
  String get connectionState => _state;
  bool get isConnected => _state == 'CONNECTED';

  /// Open the Ably connection and subscribe to the desired channels. Idempotent.
  Future<void> ensureStarted() async {
    if (_realtime != null || _starting) return;
    _starting = true;
    try {
      final realtime = ably.Realtime(
        options: ably.ClientOptions(
          autoConnect: false,
          // Our own published events (typing) must not echo back to us.
          echoMessages: false,
          authCallback: (params) => _fetchToken(),
        ),
      );
      _realtime = realtime;
      _connSub = realtime.connection.on().listen(_onConnectionState);
      await realtime.connect();
      _resubscribe();
    } catch (e) {
      debugPrint('Ably ensureStarted failed: $e');
    } finally {
      _starting = false;
    }
  }

  /// Ably auth callback: fetch a signed token request from the backend.
  Future<ably.TokenRequest> _fetchToken() async {
    final res = await _dio.get<Map<String, dynamic>>('/socket/token');
    final data = res.data;
    if (data == null || data.isEmpty) {
      throw StateError('empty /socket/token response');
    }
    return ably.TokenRequest.fromMap(data);
  }

  void _onConnectionState(ably.ConnectionStateChange change) {
    final connected = change.current == ably.ConnectionState.connected;
    _setState(connected ? 'CONNECTED' : 'DISCONNECTED');
    if (connected) _resubscribe();
  }

  void _setState(String state) {
    _state = state;
    if (!_connectionState.isClosed) _connectionState.add(state);
  }

  /// Stream of payloads for a single event name (e.g. `message.sent`). Events
  /// arrive per channel; filter by id in the listener where needed.
  Stream<Map<String, dynamic>> on(String event) {
    return _events
        .putIfAbsent(
          event,
          () => StreamController<Map<String, dynamic>>.broadcast(),
        )
        .stream;
  }

  /// Join a channel. Idempotent; replayed on reconnect.
  Future<void> subscribe(String channel) async {
    _subscribed.add(channel);
    _attach(channel);
  }

  Future<void> unsubscribe(String channel) async {
    _subscribed.remove(channel);
    await _channelSubs.remove(channel)?.cancel();
    try {
      await _realtime?.channels.get(channel).detach();
    } catch (_) {
      // best-effort
    }
  }

  void _attach(String channel) {
    final realtime = _realtime;
    if (realtime == null || _channelSubs.containsKey(channel)) return;
    _channelSubs[channel] =
        realtime.channels.get(channel).subscribe().listen((message) {
      final name = message.name;
      if (name == null) return;
      final controller = _events[name];
      if (controller != null && !controller.isClosed) {
        controller.add(_asMap(message.data));
      }
    });
  }

  void _resubscribe() {
    for (final channel in _subscribed) {
      _attach(channel);
    }
  }

  /// Ephemeral client→channel signal (e.g. typing). Best-effort; dropped while
  /// disconnected. `echoMessages: false` keeps it from echoing back to us.
  void whisper(String channel, String event, Map<String, dynamic> data) {
    if (!isConnected) return;
    final realtime = _realtime;
    if (realtime == null) return;
    unawaited(realtime.channels.get(channel).publish(name: event, data: data));
  }

  /// Close the live connection when backgrounded, keeping the desired-channel
  /// set so [reconnect] restores everything on resume.
  void disconnectForBackground() {
    final realtime = _realtime;
    if (realtime != null) unawaited(realtime.close());
    _setState('DISCONNECTED');
  }

  /// Re-establish the connection on foreground.
  Future<void> reconnect() async {
    if (_realtime == null) {
      await ensureStarted();
      return;
    }
    try {
      await _realtime!.connect();
      _resubscribe();
    } catch (e) {
      debugPrint('Ably reconnect failed: $e');
    }
  }

  /// Re-mint the token (picks up newly-authorized channels — e.g. a conversation
  /// created by a new match) by forcing Ably to re-auth via the auth callback.
  Future<void> refreshToken() async {
    try {
      await _realtime?.auth.authorize();
    } catch (e) {
      debugPrint('Ably authorize failed: $e');
    }
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'data': data};
  }

  Future<void> dispose() async {
    for (final s in _channelSubs.values) {
      await s.cancel();
    }
    _channelSubs.clear();
    await _connSub?.cancel();
    for (final controller in _events.values) {
      await controller.close();
    }
    _events.clear();
    _subscribed.clear();
    await _connectionState.close();
    await _sessionRevoked.close();
    final realtime = _realtime;
    if (realtime != null) await realtime.close();
    _realtime = null;
  }
}
