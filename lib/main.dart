import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/app.dart';
import 'core/di/injector.dart';
import 'core/messaging/fcm_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Surface any uncaught error to the Xcode/Console log instead of letting
  // a release build die silently to a white screen.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('CUPET FlutterError: ${details.exceptionAsString()}');
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Never block the first frame on a Google Fonts network download; fall
    // back to the platform font if Barrio/Manrope aren't cached yet.
    GoogleFonts.config.allowRuntimeFetching = false;

    configureInjector();

    // Initialise Firebase before runApp so a notification tap that cold-starts
    // the app (getInitialMessage) resolves reliably. Guarded so a missing
    // GoogleService-Info.plist / no-network state can never strand the user on
    // a white screen — on failure we skip FCM and still run the app.
    var firebaseReady = false;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseReady = true;
      // Background handler must be a top-level function registered before
      // runApp.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('CUPET Firebase init failed: $e');
    }

    runApp(const CupetApp());

    // Heavier FCM wiring (permission, token, foreground/tap listeners, initial
    // message) runs after the first frame so it never delays the UI.
    if (firebaseReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        getIt<FcmService>().init();
      });
    }
  }, (error, stack) {
    debugPrint('CUPET zone error: $error\n$stack');
  });
}
