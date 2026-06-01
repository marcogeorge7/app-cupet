import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

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

  /// Returns true if the stored bearer is still valid on the backend. Used to
  /// tell a real "signed in elsewhere" kick (bearer revoked → false) from a
  /// spurious socket self-kick (bearer still valid → true). A network error
  /// means we can't tell, so we assume still-valid to avoid logging out a user
  /// who is merely offline.
  Future<bool> verifySession() async {
    try {
      return await _remote.verifySession();
    } catch (_) {
      return true;
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
    // No session yet (startup before login, or an onTokenRefresh while logged
    // out) — there's nothing to attach the device to, and POSTing would just
    // 401. app.dart calls syncToken() again right after login, when this runs
    // for real.
    if (!await hasToken()) {
      return;
    }
    try {
      await _remote.registerDevice(
        fcmToken: fcmToken,
        platform: _platform(),
      );
    } catch (e) {
      // Best-effort: never block sign-in — but surface WHY it failed, since a
      // silent failure here is exactly why `device_tokens` can stay empty.
      debugPrint('FCM: registerDevice failed (POST /devices): $e');
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

  /// Tear down ONLY the local session — no backend call. Used when the server
  /// has already invalidated our token (a newer login on another device, one
  /// device per account), so calling `/logout` would just 401 again. Mirrors
  /// the local half of [logout]: Firebase sign-out + clear storage + drop the
  /// cached user, each best-effort so nothing can strand the user mid-logout.
  Future<void> clearLocalSession() async {
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
