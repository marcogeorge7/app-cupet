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

  /// Firebase's opaque verification-session id from `verifyPhoneNumber`'s
  /// `codeSent` callback. It is combined with the user-entered SMS code via
  /// `PhoneAuthProvider.credential` to sign in.
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

  /// Starts Firebase phone verification for [phoneNumber] (E.164). Firebase
  /// sends the SMS itself and drives the flow through callbacks:
  ///   - [onCodeSent] once the SMS is dispatched — carries the verificationId
  ///     that the user's typed code is later combined with;
  ///   - [onAutoSignIn] on Android instant-validation / SMS auto-retrieval,
  ///     where the code never has to be typed;
  ///   - [onError] for an invalid number, quota/throttling, or a device-check
  ///     failure (reCAPTCHA / Play Integrity / APNs).
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(PendingPhoneVerification) onCodeSent,
    required void Function(fb.UserCredential) onAutoSignIn,
    required void Function(Failure) onError,
  }) async {
    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (fb.PhoneAuthCredential credential) async {
          try {
            final cred = await _firebaseAuth.signInWithCredential(credential);
            onAutoSignIn(cred);
          } catch (e) {
            onError(_firebaseFailure(e));
          }
        },
        verificationFailed: (fb.FirebaseAuthException e) =>
            onError(_firebaseFailure(e)),
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(PendingPhoneVerification(
            verificationId: verificationId,
            resendToken: resendToken,
            // Firebase always delivers via SMS; surface that on the OTP screen.
            channel: 'sms',
          ));
        },
        // Auto-retrieval window closed: the codeSent verificationId stays valid
        // for manual entry, so there's nothing to do here.
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(_firebaseFailure(e));
    }
  }

  Future<AppUser> verifyOtpAndSignIn({
    required PendingPhoneVerification pending,
    required String smsCode,
  }) async {
    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: pending.verificationId,
        smsCode: smsCode,
      );
      final cred = await _firebaseAuth.signInWithCredential(credential);
      // Firebase is satisfied; hand the ID token to the backend, which mints
      // our Sanctum session (and on failure throws its own Dio-mapped Failure
      // that propagates past the FirebaseAuthException handler below).
      return await signInWithCredential(cred);
    } on fb.FirebaseAuthException catch (e) {
      throw _firebaseFailure(e);
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
    // Each step is best-effort: a failure on the backend or in Firebase must
    // NOT prevent us from clearing the local token, otherwise the UI stays
    // stuck on an "authenticated" router state.
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

  /// Map a Firebase phone-auth error to a user-facing [Failure]; anything
  /// unrecognised falls back to Firebase's own message.
  Failure _firebaseFailure(Object error) {
    if (error is fb.FirebaseAuthException) {
      final message = switch (error.code) {
        'invalid-phone-number' =>
          'That phone number looks invalid. Check it and try again.',
        'invalid-verification-code' =>
          'That code is incorrect. Please try again.',
        'invalid-verification-id' || 'session-expired' =>
          'This code has expired. Request a new one.',
        'too-many-requests' =>
          'Too many attempts. Please wait a while and try again.',
        'quota-exceeded' => 'SMS limit reached. Please try again later.',
        'network-request-failed' =>
          'Network error. Check your connection and try again.',
        'missing-client-identifier' || 'app-not-authorized' =>
          'Could not verify this device for phone sign-in.',
        _ => error.message ?? 'Phone verification failed. Please try again.',
      };
      return Failure(message);
    }
    return Failure(error.toString());
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
