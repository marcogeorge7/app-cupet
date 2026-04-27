import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/domain/auth_repository.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate — keep this minimal. The platform shows the
  // notification automatically using the `notification` payload.
  debugPrint('FCM background: ${message.messageId}');
}

class FcmService {
  FcmService(this._auth);

  final AuthRepository _auth;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final token = await _messaging.getToken();
      if (token != null) {
        await _auth.registerFcmToken(token);
      }

      _messaging.onTokenRefresh.listen(_auth.registerFcmToken);
    } catch (e) {
      debugPrint('FCM init failed: $e');
    }
  }
}
