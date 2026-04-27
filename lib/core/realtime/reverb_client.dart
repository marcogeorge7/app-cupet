import 'dart:async';

import 'package:dio/dio.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../config/app_config.dart';
import '../storage/secure_token_storage.dart';

/// Thin wrapper around `pusher_channels_flutter` configured for Laravel Reverb.
///
/// Authorization for private channels is delegated to a Dio call against the
/// Laravel `broadcasting/auth` endpoint, reusing the Sanctum token via the
/// shared interceptor.
class ReverbClient {
  ReverbClient(this._storage, this._dio);

  final SecureTokenStorage _storage;
  final Dio _dio;
  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  bool _started = false;

  final Map<String, StreamController<Map<dynamic, dynamic>>> _controllers = {};

  Future<void> ensureStarted() async {
    if (_started) return;

    await _pusher.init(
      apiKey: AppConfig.reverbAppKey,
      cluster: 'mt1',
      onAuthorizer: _authorize,
      onEvent: _dispatch,
      useTLS: AppConfig.reverbScheme == 'https',
    );

    await _pusher.connect();
    _started = true;
  }

  Future<dynamic> _authorize(
    String channelName,
    String socketId,
    dynamic options,
  ) async {
    final token = await _storage.read();
    final response = await _dio.post<Map<String, dynamic>>(
      AppConfig.broadcastingAuthEndpoint,
      data: {
        'channel_name': channelName,
        'socket_id': socketId,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    return response.data ?? {};
  }

  Stream<Map<dynamic, dynamic>> subscribe(String channel) {
    final controller = _controllers.putIfAbsent(
      channel,
      () => StreamController<Map<dynamic, dynamic>>.broadcast(),
    );
    _pusher.subscribe(channelName: channel);
    return controller.stream;
  }

  Future<void> unsubscribe(String channel) async {
    await _pusher.unsubscribe(channelName: channel);
    await _controllers.remove(channel)?.close();
  }

  void _dispatch(PusherEvent event) {
    final controller = _controllers[event.channelName];
    if (controller == null) return;
    if (event.data is String) {
      controller.add({'event': event.eventName, 'data': event.data});
    } else if (event.data is Map) {
      controller.add({'event': event.eventName, ...(event.data as Map)});
    }
  }

  Future<void> dispose() async {
    for (final c in _controllers.values) {
      await c.close();
    }
    _controllers.clear();
    if (_started) {
      await _pusher.disconnect();
      _started = false;
    }
  }
}
