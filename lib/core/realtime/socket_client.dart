import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Client for the shared **socket-hub** server (Socket.IO), replacing the old
/// Laravel Reverb / Pusher client.
///
/// Connection auth uses a short-lived JWT minted by the cupet backend at
/// `GET /socket/token`; the JWT carries the channels this user may join. The
/// backend publishes events server-side (HTTP trigger), so here we only
/// subscribe to channels and listen for events.
///
/// Channels are plain names (`user.{id}`, `conversation.{id}`) — no `private-`
/// prefix. Events are namespace-wide in Socket.IO, so consumers listen per
/// event name and filter by id where needed (see [on]).
class SocketHubClient {
  SocketHubClient(this._dio);

  final Dio _dio;
  io.Socket? _socket;
  bool _connecting = false;

  /// Channels we want to be joined to; replayed on every (re)connect.
  final Set<String> _subscribed = {};

  /// One broadcast controller per event name we surface.
  final Map<String, StreamController<Map<String, dynamic>>> _events = {};
  final Set<String> _listenerRegistered = {};

  final StreamController<String> _connectionState =
      StreamController<String>.broadcast();
  String _state = 'DISCONNECTED';

  /// Fires when socket-hub kicks this connection because the account signed in
  /// on another device (one device per account). The socket is torn down so it
  /// can't auto-reconnect and re-kick the new device; consumers force a logout.
  final StreamController<void> _sessionRevoked =
      StreamController<void>.broadcast();

  Stream<String> get connectionStates => _connectionState.stream;
  Stream<void> get sessionRevoked => _sessionRevoked.stream;
  String get connectionState => _state;
  bool get isConnected => _state == 'CONNECTED';

  /// Fetch a fresh token and open the connection. Idempotent.
  Future<void> ensureStarted() async {
    if (_socket != null || _connecting) return;
    _connecting = true;
    try {
      final res = await _dio.get<Map<String, dynamic>>('/socket/token');
      final data = res.data;
      if (data == null) return;
      _connect(
        url: data['url'] as String,
        namespace: (data['namespace'] as String?) ?? 'cupet',
        token: data['token'] as String,
      );
    } catch (e) {
      debugPrint('SocketHubClient ensureStarted failed: $e');
    } finally {
      _connecting = false;
    }
  }

  void _connect({
    required String url,
    required String namespace,
    required String token,
  }) {
    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    _socket = io.io(
      '$base/$namespace',
      io.OptionBuilder()
          // websocket-only. Verified against socket-hub: this Dart client's
          // polling (XHR) transport hangs/times out there, while websocket
          // connects in ~1s — WebSocket passes the Hostinger CDN fine for the
          // real client. A polling-first list left the socket stuck on iOS
          // (polling hung before it could upgrade). The earlier "stuck
          // Connecting…" was actually the /socket/token URL bug, not transport.
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          // Explicit battery-safe backoff: 1s base, 30s cap, 0.5 jitter — a
          // flaky network can never spin a tight reconnect loop and overheat
          // the device. (socket_io_client already backs off; this pins it.)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(30000)
          .setRandomizationFactor(0.5)
          .setAuth({'token': token})
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _setState('CONNECTED');
        _resubscribe();
      })
      ..onDisconnect((_) => _setState('DISCONNECTED'))
      ..onConnectError((_) => _setState('DISCONNECTED'))
      ..onError((_) => _setState('DISCONNECTED'))
      // Kicked by a newer login elsewhere. Tear the socket down (so auto-
      // reconnect can't immediately re-kick the new device in a ping-pong),
      // then surface the event so the app force-logs-out.
      ..on('session.revoked', (_) {
        _setState('DISCONNECTED');
        if (!_sessionRevoked.isClosed) _sessionRevoked.add(null);
        scheduleMicrotask(_teardownSocket);
      });

    // (Re)attach listeners for any events already requested via [on].
    for (final event in _events.keys) {
      _ensureListener(event);
    }

    _socket!.connect();
  }

  void _setState(String state) {
    _state = state;
    if (!_connectionState.isClosed) _connectionState.add(state);
  }

  /// Stream of payloads for a single server event (e.g. `message.sent`).
  /// Events are namespace-wide; filter by id in the listener.
  Stream<Map<String, dynamic>> on(String event) {
    final controller = _events.putIfAbsent(
      event,
      () => StreamController<Map<String, dynamic>>.broadcast(),
    );
    _ensureListener(event);
    return controller.stream;
  }

  void _ensureListener(String event) {
    final socket = _socket;
    if (socket == null || _listenerRegistered.contains(event)) return;
    socket.on(event, (data) {
      final controller = _events[event];
      if (controller != null && !controller.isClosed) {
        controller.add(_asMap(data));
      }
    });
    _listenerRegistered.add(event);
  }

  /// Join a channel. If the current token doesn't authorize it (e.g. a
  /// conversation created after the token was minted), refresh the token and
  /// rejoin automatically.
  Future<void> subscribe(String channel) async {
    _subscribed.add(channel);
    if (_socket == null || !isConnected) return; // joined on (re)connect
    final res = await _emitAck('subscribe', channel);
    if (res is Map && res['ok'] != true) {
      await refreshToken(); // reconnect replays _subscribed with new claims
    }
  }

  Future<void> unsubscribe(String channel) async {
    _subscribed.remove(channel);
    _socket?.emit('unsubscribe', channel);
  }

  void _resubscribe() {
    for (final channel in _subscribed) {
      _socket?.emit('subscribe', channel);
    }
  }

  /// Ephemeral client-to-channel signal (e.g. typing). Relayed by socket-hub
  /// to the channel's other members; best-effort, dropped while disconnected.
  void whisper(String channel, String event, Map<String, dynamic> data) {
    if (!isConnected) return;
    _socket?.emit('whisper', {
      'channel': channel,
      'event': event,
      'data': data,
    });
  }

  /// Close the live connection when the app is backgrounded, WITHOUT disposing
  /// the singleton: event controllers, listeners, and the desired-subscription
  /// set all survive, so [reconnect] restores everything on resume. A manual
  /// disconnect also halts socket.io's auto-reconnect until we explicitly
  /// reconnect, so nothing churns while the screen isn't visible.
  void disconnectForBackground() {
    _socket?.disconnect();
    _setState('DISCONNECTED');
  }

  /// Drop the socket entirely after a forced kick. Event controllers and the
  /// desired-subscription set are kept (a later login replays them on a fresh
  /// socket); only the live connection and its per-socket listener bookkeeping
  /// go, so the next `_connect` re-registers cleanly.
  void _teardownSocket() {
    _listenerRegistered.clear();
    _socket?.dispose();
    _socket = null;
  }

  /// Ensure a live connection, re-minting the token if needed. Called when the
  /// app returns to the foreground: the OS may have torn the socket down and
  /// the JWT may have expired, so a stale `_socket` must be re-authed and
  /// reconnected. Already-connected sockets are left alone.
  Future<void> reconnect() async {
    if (_socket == null) {
      await ensureStarted(); // never started (or disposed) — start fresh
    } else if (!isConnected) {
      await refreshToken(); // re-mint token + disconnect/connect
    }
  }

  /// Re-mint the connection token (picks up newly-authorized channels) and
  /// reconnect. Listeners and subscriptions persist across the reconnect.
  Future<void> refreshToken() async {
    final socket = _socket;
    if (socket == null) return;
    try {
      final res = await _dio.get<Map<String, dynamic>>('/socket/token');
      final token = res.data?['token'] as String?;
      if (token == null) return;
      socket.auth = {'token': token};
      socket.disconnect();
      socket.connect();
    } catch (e) {
      debugPrint('SocketHubClient refreshToken failed: $e');
    }
  }

  Future<dynamic> _emitAck(String event, dynamic data) {
    final socket = _socket;
    if (socket == null) return Future.value(null);
    final completer = Completer<dynamic>();
    socket.emitWithAck(
      event,
      data,
      ack: (res) {
        if (!completer.isCompleted) completer.complete(res);
      },
    );
    return completer.future
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'data': data};
  }

  Future<void> dispose() async {
    for (final controller in _events.values) {
      await controller.close();
    }
    _events.clear();
    _listenerRegistered.clear();
    _subscribed.clear();
    await _connectionState.close();
    await _sessionRevoked.close();
    _socket?.dispose();
    _socket = null;
  }
}
