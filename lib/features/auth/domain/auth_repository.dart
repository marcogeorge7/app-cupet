import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../core/error/failures.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../../../shared/models/user.dart';
import '../data/auth_remote_data_source.dart';

class PendingPhoneVerification {
  PendingPhoneVerification({
    required this.verificationId,
    this.resendToken,
    this.channel,
  });

  /// For the Twilio OTP flow this carries the phone number itself —
  /// the field is kept named `verificationId` so callers (Bloc, UI)
  /// don't need to change.
  final String verificationId;
  final int? resendToken;
  final String? channel;
}

class AuthRepository {
  AuthRepository({
    required AuthRemoteDataSource remote,
    required SecureTokenStorage storage,
    fb.FirebaseAuth? firebaseAuth,
  })  : _remote = remote,
        _storage = storage,
        _firebaseAuthOverride = firebaseAuth;

  final AuthRemoteDataSource _remote;
  final SecureTokenStorage _storage;
  final fb.FirebaseAuth? _firebaseAuthOverride;

  /// Lazy: do NOT touch `FirebaseAuth.instance` until something actually
  /// needs Firebase (sending OTP, signing in). On a fresh launch the only
  /// path that runs is `hasToken()` + `loadCurrentUser()`, neither of which
  /// need Firebase, so a missing GoogleService-Info.plist won't crash the
  /// app — it'll just fail when the user taps "Send code".
  fb.FirebaseAuth get _firebaseAuth =>
      _firebaseAuthOverride ?? fb.FirebaseAuth.instance;

  AppUser? _cachedUser;
  AppUser? get cachedUser => _cachedUser;

  Future<bool> hasToken() async {
    final token = await _storage.read();
    return token != null && token.isNotEmpty;
  }

  /// Sends an OTP to [phoneNumber] via the backend (Twilio WhatsApp/SMS,
  /// or the configured test-phone bypass). Calls [onCodeSent] when the
  /// backend confirms dispatch. [onAutoSignIn] is unused on this transport
  /// but kept in the signature so the Bloc contract is unchanged.
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(PendingPhoneVerification) onCodeSent,
    required void Function(fb.UserCredential) onAutoSignIn,
    required void Function(Failure) onError,
  }) async {
    try {
      final result = await _remote.requestOtp(phoneNumber);
      onCodeSent(PendingPhoneVerification(
        verificationId: phoneNumber,
        channel: result.channel,
      ));
    } catch (e) {
      onError(Failure.fromDio(e));
    }
  }

  Future<AppUser> verifyOtpAndSignIn({
    required PendingPhoneVerification pending,
    required String smsCode,
  }) async {
    try {
      final result = await _remote.verifyOtp(
        phone: pending.verificationId,
        code: smsCode,
        deviceName: _deviceName(),
      );
      await _storage.save(result.token);
      _cachedUser = result.user;
      return result.user;
    } catch (e) {
      throw Failure.fromDio(e);
    }
  }

  Future<AppUser> signInWithCredential(fb.UserCredential cred) async {
    final idToken = await cred.user?.getIdToken();
    if (idToken == null) {
      throw const Failure('Could not obtain Firebase ID token.');
    }
    return _exchange(idToken);
  }

  Future<AppUser> _exchange(String idToken) async {
    try {
      final result = await _remote.exchangeFirebaseToken(
        idToken: idToken,
        deviceName: _deviceName(),
      );
      await _storage.save(result.token);
      _cachedUser = result.user;
      return result.user;
    } catch (e) {
      throw Failure.fromDio(e);
    }
  }

  Future<AppUser> loadCurrentUser() async {
    try {
      _cachedUser = await _remote.me();
      return _cachedUser!;
    } catch (e) {
      throw Failure.fromDio(e);
    }
  }

  Future<AppUser> updateProfile({
    String? name,
    String? email,
    String? avatarUrl,
    bool clearEmail = false,
    bool clearAvatarUrl = false,
  }) async {
    try {
      _cachedUser = await _remote.updateMe(
        name: name,
        email: email,
        avatarUrl: avatarUrl,
        clearEmail: clearEmail,
        clearAvatarUrl: clearAvatarUrl,
      );
      return _cachedUser!;
    } catch (e) {
      throw Failure.fromDio(e);
    }
  }

  Future<void> registerFcmToken(String fcmToken) async {
    if (fcmToken.isEmpty) return;
    try {
      await _remote.registerDevice(
        fcmToken: fcmToken,
        platform: _platform(),
      );
    } catch (_) {
      // Best-effort: do not block sign-in.
    }
  }

  Future<void> logout() async {
    // Each step is best-effort: a failure on the backend or in Firebase
    // (which may not even be initialised — sign-in goes through Twilio OTP,
    // not Firebase Auth) must NOT prevent us from clearing the local token,
    // otherwise the UI stays stuck on an "authenticated" router state.
    try {
      await _remote.logout();
    } catch (_) {}
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}
    try {
      await _storage.clear();
    } catch (_) {}
    _cachedUser = null;
  }

  /// Permanently delete the account, then tear down the local session.
  ///
  /// The backend call is NOT best-effort: if it fails we rethrow so the UI
  /// can tell the user their account was not deleted, instead of silently
  /// logging them out as if it had been. Only after the server confirms do
  /// we clear the local token + Firebase session + cached user.
  Future<void> deleteAccount() async {
    try {
      await _remote.deleteAccount();
    } catch (e) {
      throw Failure.fromDio(e);
    }
    try {
      await _firebaseAuth.signOut();
    } catch (_) {}
    try {
      await _storage.clear();
    } catch (_) {}
    _cachedUser = null;
  }

  String _platform() {
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
    } catch (_) {}
    return 'web';
  }

  String _deviceName() {
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'mobile';
    }
  }
}
