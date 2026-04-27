import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'cupet.api_token';

  final FlutterSecureStorage _storage;

  Future<void> save(String token) => _storage.write(key: _tokenKey, value: token);

  Future<String?> read() => _storage.read(key: _tokenKey);

  Future<void> clear() => _storage.delete(key: _tokenKey);
}
