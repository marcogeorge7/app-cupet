import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/di/injector.dart';
import 'core/messaging/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureInjector();

  try {
    await Firebase.initializeApp();
    await getIt<FcmService>().init();
  } catch (e) {
    debugPrint('Firebase init failed (configure firebase_options.dart): $e');
  }

  runApp(const CupetApp());
}
