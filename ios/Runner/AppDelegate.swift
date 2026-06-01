import Flutter
import UIKit
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // The new UIScene + implicit-engine architecture (Flutter 3.41) doesn't
    // reliably let firebase_messaging trigger APNs registration, so kick it off
    // explicitly. iOS then calls didRegister…/didFailToRegister… below. This is
    // idempotent — safe even if the plugin also calls it.
    application.registerForRemoteNotifications()
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // APNs registration succeeded. Hand the token to Firebase explicitly so the
  // FCM token can still be minted even if automatic method-swizzling didn't
  // pick it up — a possible cause of `getAPNSToken()` staying null on iOS 26.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    NSLog("CUPET_APNS: registered OK (\(deviceToken.count) bytes)")
    Messaging.messaging().apnsToken = deviceToken
    super.application(
      application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // APNs registration failed — log Apple's exact reason.
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("CUPET_APNS: FAILED to register: \(error.localizedDescription)")
    super.application(
      application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
