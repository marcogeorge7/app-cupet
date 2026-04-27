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
  });

  final String verificationId;
  final int? resendToken;
}

class AuthRepository {
  AuthRepository({
    required AuthRemoteDataSource remote,
    required SecureTokenStorage storage,
    fb.FirebaseAuth? firebaseAuth,
  })  : _remote = remote,
        _storage = storage,
        _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance;

  final AuthRemoteDataSource _remote;
  final SecureTokenStorage _storage;
  final fb.FirebaseAuth _firebaseAuth;

  AppUser? _cachedUser;
  AppUser? get cachedUser => _cachedUser;

  Future<bool> hasToken() async {
    final token = await _storage.read();
    return token != null && token.isNotEmpty;
  }

  /// Sends an OTP to [phoneNumber]. Calls [onCodeSent] with a verification id
  /// when the SMS has been dispatched, or [onAutoSignIn] on Android instant
  /// verification.
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(PendingPhoneVerification) onCodeSent,
    required void Function(fb.UserCredential) onAutoSignIn,
    required void Function(Failure) onError,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (cred) async {
        try {
          final result = await _firebaseAuth.signInWithCredential(cred);
          onAutoSignIn(result);
        } catch (e) {
          onError(Failure(e.toString()));
        }
      },
      verificationFailed: (e) {
        onError(Failure(e.message ?? 'Phone verification failed'));
      },
      codeSent: (verificationId, resendToken) {
        onCodeSent(PendingPhoneVerification(
          verificationId: verificationId,
          resendToken: resendToken,
        ));
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<AppUser> verifyOtpAndSignIn({
    required PendingPhoneVerification pending,
    required String smsCode,
  }) async {
    final cred = fb.PhoneAuthProvider.credential(
      verificationId: pending.verificationId,
      smsCode: smsCode,
    );
    final result = await _firebaseAuth.signInWithCredential(cred);
    final idToken = await result.user?.getIdToken();
    if (idToken == null) {
      throw const Failure('Could not obtain Firebase ID token.');
    }
    return _exchange(idToken);
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
    try {
      await _remote.logout();
    } catch (_) {}
    await _firebaseAuth.signOut();
    await _storage.clear();
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
