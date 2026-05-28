import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/auth/domain/auth_repository.dart';
import '../navigation/navigation_service.dart';
import '../realtime/realtime_user_service.dart';
import 'active_chat_tracker.dart';
import 'notification_router.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate — no access to app singletons/UI. The OS draws the
  // notification from the `notification` block; taps are routed in the main
  // isolate via onMessageOpenedApp / getInitialMessage.
  debugPrint('FCM background: ${message.messageId}');
}

const _channelId = 'cupet_messages';
const _channelName = 'Messages';
const _channelDescription = 'New chat messages and matches';

const _androidChannel = AndroidNotificationChannel(
  _channelId,
  _channelName,
  description: _channelDescription,
  importance: Importance.high,
);

class FcmService {
  FcmService(this._auth, this._activeChat, this._navigation, this._realtime);

  final AuthRepository _auth;
  final ActiveChatTracker _activeChat;
  final NavigationService _navigation;
  final RealtimeUserService _realtime;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      await _initLocalNotifications();

      // Foreground: the OS doesn't surface FCM `notification` payloads while
      // the app is open, so we draw a local banner ourselves.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Tap while the app is backgrounded.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

      // Tap that cold-started the app from a terminated state. Stash it so
      // app.dart can replay it once auth resolves — navigating now would be
      // swallowed by the router's auth redirect.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        final route = routeForData(initial.data);
        if (route != null) {
          _navigation.pendingDeepLink = route;
        }
      }

      final token = await _messaging.getToken();
      if (token != null) {
        await _auth.registerFcmToken(token);
      }
      _messaging.onTokenRefresh.listen(_auth.registerFcmToken);
    } catch (e) {
      debugPrint('FCM init failed: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // FCM already owns the iOS permission prompt — don't prompt again here.
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          _route(Map<String, dynamic>.from(jsonDecode(payload) as Map));
        } catch (_) {
          // Malformed payload — ignore.
        }
      },
    );

    final android32 = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android32?.createNotificationChannel(_androidChannel);
    await android32?.requestNotificationsPermission();
  }

  void _onForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    if (type == 'message') {
      final conversationId = int.tryParse('${data['conversation_id']}');
      // Keep a visible Matches list re-ordered (messages broadcast on the
      // conversation channel, not the user channel).
      if (conversationId != null) {
        _realtime.notifyMessageReceived(conversationId);
      }
      // Suppress the banner if the user is already in this conversation.
      if (conversationId != null &&
          _activeChat.activeConversationId == conversationId) {
        return;
      }
    } else if (type != 'match') {
      return;
    }

    final n = message.notification;
    final title = n?.title ??
        (type == 'match' ? "It's a match!" : 'New message');
    final body = n?.body ?? '';
    _local.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        // Must match _androidChannel above.
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(data),
    );
  }

  void _handleTap(RemoteMessage message) => _route(message.data);

  void _route(Map<String, dynamic> data) {
    final route = routeForData(data);
    if (route != null) {
      _navigation.push(route);
    }
  }
}
