import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              // Persist the session token reliably across app restarts. The
              // Android default backend can silently drop values when the
              // Keystore key is rotated or fails to decrypt after a cold start
              // — which logs the user out on reopen even though their session
              // is still valid. EncryptedSharedPreferences is durable, and
              // resetOnError clears an undecryptable legacy entry (e.g. one
              // written by the old backend) instead of throwing on read.
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: true,
              ),
            );

  static const _tokenKey = 'cupet.api_token';

  final FlutterSecureStorage _storage;

  Future<void> save(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> read() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      // A decrypt / Keystore error must never crash the cold-start auth check;
      // treat it as "no stored token" so the app falls back to sign-in cleanly.
      return null;
    }
  }

  Future<void> clear() => _storage.delete(key: _tokenKey);
}
