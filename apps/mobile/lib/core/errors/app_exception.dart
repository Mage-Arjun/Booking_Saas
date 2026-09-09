import 'package:dio/dio.dart';

/// Represents an application-level error safe for presentation to users.
///
/// Network and backend-specific exceptions should be translated into this
/// type at the repository boundary. UI code can then display a useful message
/// without depending directly on Dio's exception hierarchy.
class AppException implements Exception {
  /// Creates an application exception.
  const AppException(this.message, {this.code});

  /// Human-readable description suitable for a UI error state.
  final String message;

  /// Optional backend/application error code.
  final String? code;

  @override
  String toString() => message;
}

/// Converts a Dio failure into the application's stable error abstraction.
AppException mapDioException(Object error) {
  if (error is AppException) return error;

  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      final code = data['code'];
      if (detail is String && detail.isNotEmpty) {
        return AppException(
          detail,
          code: code is String ? code : null,
        );
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppException(
          'The request timed out. Please try again.',
          code: 'TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return const AppException(
          'Unable to reach the server. Check your connection and try again.',
          code: 'CONNECTION_ERROR',
        );
      default:
        return const AppException(
          'Something went wrong while communicating with the server.',
          code: 'NETWORK_ERROR',
        );
    }
  }

  return const AppException('An unexpected error occurred.');
}
