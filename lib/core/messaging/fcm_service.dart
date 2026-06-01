import 'dart:convert';
import 'dart:io' show Platform;

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
}

// Bumped from 'cupet_messages' when the custom sound was added: an Android
// channel's sound is immutable once created, so existing installs need a NEW id
// to pick it up. Must match the FCM default-channel meta-data in
// AndroidManifest.xml and the backend's android `channel_id`.
const _channelId = 'cupet_messages_v2';
const _channelName = 'Messages';
const _channelDescription = 'New chat messages and matches';

// `message_chat` => android/app/src/main/res/raw/message_chat.wav.
const _androidChannel = AndroidNotificationChannel(
  _channelId,
  _channelName,
  description: _channelDescription,
  importance: Importance.high,
  sound: RawResourceAndroidNotificationSound('message_chat'),
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
      // authorized / provisional => APNs can register. denied => no APNS token
      // will ever be issued, so getToken() will keep failing.
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

      await syncToken();
      _messaging.onTokenRefresh.listen(_auth.registerFcmToken);
    } catch (e) {
      debugPrint('FCM init failed: $e');
    }
  }

  /// Fetch the current FCM token and register it with the backend. Safe to
  /// call repeatedly — registration is an idempotent upsert keyed on the
  /// token. init() runs this once at startup, but on a fresh install that
  /// races ahead of OTP login and the `POST /devices` 401s, so app.dart also
  /// calls this when auth resolves so a newly-signed-in device is reachable
  /// without an app restart.
  Future<void> syncToken() async {
    try {
      // iOS: getToken() returns null until the APNS token is registered, which
      // lags slightly behind permission on a fresh launch. Calling getToken()
      // too early returned null and we gave up — so /devices was never hit.
      // Wait for the APNS token first so getToken() can succeed.
      if (!kIsWeb && Platform.isIOS) {
        await _ensureApnsToken();
      }

      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('FCM: getToken() returned null — push unavailable.');
        return;
      }
      await _auth.registerFcmToken(token);
    } catch (e) {
      debugPrint('FCM syncToken failed: $e');
    }
  }

  /// iOS only: poll for the APNS device token (up to ~5s) so the subsequent
  /// [FirebaseMessaging.getToken] doesn't return null because APNS isn't ready.
  /// A non-null APNS token here but a null FCM token next points specifically
  /// at a missing APNs Auth Key in the Firebase console.
  Future<void> _ensureApnsToken() async {
    // First-launch APNs registration round-trips Apple's servers and can take
    // well over 5s, so wait up to ~15s before giving up.
    for (var i = 0; i < 30; i++) {
      final apns = await _messaging.getAPNSToken();
      if (apns != null) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    debugPrint('FCM: APNS token unavailable after ~15s — push may not work.');
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
    // Drop the pre-sound channel so users don't keep a stale silent "Messages".
    await android32?.deleteNotificationChannel('cupet_messages');
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
      // The instant in-app banner (app.dart) already surfaced this message via
      // the socket; skip the duplicate. If the socket was down it wasn't
      // surfaced, so this banner still fires.
      final messageId = int.tryParse('${data['message_id']}');
      if (_realtime.messageSurfacedRecently(messageId)) return;
    } else if (type == 'match') {
      // A foregrounded match is normally surfaced instantly by the in-app
      // realtime banner (app.dart) or the Discover dialog, so this queue-delayed
      // push must not draw a duplicate. But if the socket was down we never got
      // that realtime event — so suppress ONLY when this exact match really was
      // surfaced in-app moments ago; otherwise fall through and draw the banner.
      final matchId = int.tryParse('${data['match_id']}');
      if (_realtime.matchSurfacedRecently(matchId)) return;
    } else {
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
          sound: RawResourceAndroidNotificationSound('message_chat'),
        ),
        iOS: DarwinNotificationDetails(sound: 'message_chat.wav'),
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
