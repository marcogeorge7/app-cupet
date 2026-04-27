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
      if (deviceName != null) 'device_name': deviceName,
    });

    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
      );
    }

    final data = response.data as Map<String, dynamic>;
    return (
      token: data['token'] as String,
      user: AppUser.fromJson(
        (data['user'] as Map<String, dynamic>)['data'] as Map<String, dynamic>? ??
            data['user'] as Map<String, dynamic>,
      ),
    );
  }

  Future<AppUser> me() async {
    final response = await _dio.get('/me');
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
}
