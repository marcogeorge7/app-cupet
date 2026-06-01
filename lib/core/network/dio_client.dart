import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../auth/session_event_bus.dart';
import '../config/app_config.dart';
import '../storage/secure_token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, this._session);

  final SecureTokenStorage _storage;
  final SessionEventBus _session;

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

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    // A revoked bearer (the account signed in on another device — one device
    // per account) comes back as a plain 401, NOT a DioException, because
    // `validateStatus` accepts everything below 500. So the forced-logout
    // signal must be raised here in onResponse, not onError. Sign-in endpoints
    // are skipped: a 401 there is a credential problem, not a kicked session.
    final status = response.statusCode;
    final path = response.requestOptions.path;
    // `skipForcedLogout` lets a caller probe the bearer (e.g. verifying it
    // before honouring a socket kick) without this interceptor signing the user
    // out on the 401 — the caller interprets the result itself.
    final skip = response.requestOptions.extra['skipForcedLogout'] == true;
    if (status == 401 && !_isAuthPath(path) && !skip) {
      _session.notifyForcedLogout();
    }
    handler.next(response);
  }

  bool _isAuthPath(String path) =>
      path.contains('/auth') || path.endsWith('/logout');
}

Dio buildDioClient(SecureTokenStorage storage, SessionEventBus session) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json'},
    validateStatus: (status) => status != null && status < 500,
  ));

  dio.interceptors.add(AuthInterceptor(storage, session));
  dio.interceptors.add(PrettyDioLogger(
    requestHeader: false,
    requestBody: true,
    responseBody: false,
    error: true,
    compact: true,
  ));

  return dio;
}
