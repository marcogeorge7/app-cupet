import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../storage/secure_token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final SecureTokenStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json';
    handler.next(options);
  }
}

Dio buildDioClient(SecureTokenStorage storage) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json'},
    validateStatus: (status) => status != null && status < 500,
  ));

  dio.interceptors.add(AuthInterceptor(storage));
  dio.interceptors.add(PrettyDioLogger(
    requestHeader: false,
    requestBody: true,
    responseBody: false,
    error: true,
    compact: true,
  ));

  return dio;
}
