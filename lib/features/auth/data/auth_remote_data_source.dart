import 'package:dio/dio.dart';

import '../../../shared/models/user.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<({String token, AppUser user})> exchangeFirebaseToken({
    required String idToken,
    String? deviceName,
  }) async {
    final response = await _dio.post('/auth/firebase', data: {
      'id_token': idToken,
      'device_name': ?deviceName,
    });

    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
      );
    }

    return _parseAuthResponse(response.data as Map<String, dynamic>);
  }

  Future<({String channel, bool testMode})> requestOtp(String phone) async {
    final response = await _dio.post('/auth/otp/request', data: {
      'phone': phone,
    });

    if (response.statusCode != 200) {
      // 422 (validation), 429 (throttled), etc. Surface the backend message
      // instead of casting a null body and crashing — and so the user stays
      // on phone entry rather than being pushed to a doomed OTP screen.
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
      );
    }

    final data = response.data as Map<String, dynamic>;
    return (
      channel: (data['channel'] as String?) ?? 'sms',
      testMode: (data['test_mode'] as bool?) ?? false,
    );
  }

  Future<({String token, AppUser user})> verifyOtp({
    required String phone,
    required String code,
    String? deviceName,
  }) async {
    final response = await _dio.post('/auth/otp/verify', data: {
      'phone': phone,
      'code': code,
      'device_name': ?deviceName,
    });

    if (response.statusCode != 200) {
      // Backend rejected the code (wrong/expired code, no active code for
      // this phone, too many attempts, banned account, …). Throw so
      // Failure.fromDio turns the {message}/{errors} body into a readable
      // error instead of crashing on `data['user'] as Map` with
      // "type 'Null' is not a subtype of type 'Map<String, dynamic>'".
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
      );
    }

    return _parseAuthResponse(response.data as Map<String, dynamic>);
  }

  ({String token, AppUser user}) _parseAuthResponse(Map<String, dynamic> data) {
    final userJson = data['user'] as Map<String, dynamic>;
    return (
      token: data['token'] as String,
      user: AppUser.fromJson(
        (userJson['data'] as Map<String, dynamic>?) ?? userJson,
      ),
    );
  }

  Future<AppUser> me() async {
    final response = await _dio.get('/me');
    final data = response.data as Map<String, dynamic>;
    return AppUser.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<AppUser> updateMe({
    String? name,
    String? email,
    String? avatarUrl,
    bool clearEmail = false,
    bool clearAvatarUrl = false,
  }) async {
    // Backend accepts `nullable` fields, so to clear a value we send an
    // explicit null; to leave it untouched we omit the key.
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (clearEmail) {
      payload['email'] = null;
    } else if (email != null) {
      payload['email'] = email;
    }
    if (clearAvatarUrl) {
      payload['avatar_url'] = null;
    } else if (avatarUrl != null) {
      payload['avatar_url'] = avatarUrl;
    }
    final response = await _dio.put('/me', data: payload);
    final data = response.data as Map<String, dynamic>;
    return AppUser.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
  }) async {
    await _dio.post('/devices', data: {
      'fcm_token': fcmToken,
      'platform': platform,
    });
  }

  Future<void> logout() async {
    await _dio.post('/logout');
  }

  /// Permanently delete the current user's account on the backend.
  Future<void> deleteAccount() async {
    await _dio.delete('/me');
  }
}
