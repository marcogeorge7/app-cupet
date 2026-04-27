import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

class Failure extends Equatable implements Exception {
  const Failure(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];

  factory Failure.fromDio(Object error) {
    if (error is DioException) {
      final response = error.response;
      final data = response?.data;
      String message = error.message ?? 'Request failed';

      if (data is Map && data['message'] is String) {
        message = data['message'] as String;
      } else if (data is Map && data['errors'] is Map) {
        final errors = data['errors'] as Map;
        if (errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) {
            message = first.first.toString();
          }
        }
      }

      return Failure(message, statusCode: response?.statusCode);
    }
    return Failure(error.toString());
  }
}
