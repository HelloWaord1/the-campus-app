import 'dart:developer' as developer;
import '../services/api_service.dart';

class Logger {
  static const String _tag = 'PadelApp';

  // Логирование ошибок
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    String errorMessage = message;
    if (error != null) {
      errorMessage += '\nТип ошибки: ${error.runtimeType}';
      if (error is ApiException) {
        errorMessage += '\nСтатус код: ${error.statusCode}';
        errorMessage += '\nСообщение API: ${error.message}';
      } else {
        errorMessage += '\nОшибка: ${error.toString()}';
      }
    }

    // Выводим в консоль через print для гарантированного отображения
    print('❌ ERROR: $errorMessage');
    
    developer.log(
      '❌ ERROR: $errorMessage',
      name: _tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  // Логирование предупреждений
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    print('⚠️ WARNING: $message');
    
    developer.log(
      '⚠️ WARNING: $message',
      name: _tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  // Логирование информационных сообщений
  static void info(String message) {
    print('ℹ️ INFO: $message');
    
    developer.log(
      'ℹ️ INFO: $message',
      name: _tag,
    );
  }

  // Логирование успешных операций
  static void success(String message) {
    print('✅ SUCCESS: $message');
    
    developer.log(
      '✅ SUCCESS: $message',
      name: _tag,
    );
  }

  // Логирование API запросов
  static void apiRequest(String endpoint, Map<String, dynamic>? data) {
    // print() нужен, потому что developer.log не всегда виден в выводе `flutter run`
    print('🌐 API REQUEST: $endpoint');
    developer.log(
      '🌐 API REQUEST: $endpoint',
      name: _tag,
    );
    if (data != null) {
      print('📤 Request data: $data');
      developer.log(
        '📤 Request data: $data',
        name: _tag,
      );
    }
  }

  // Логирование API ответов
  static void apiResponse(String endpoint, int statusCode, String? responseBody) {
    // print() нужен, потому что developer.log не всегда виден в выводе `flutter run`
    print('📥 API RESPONSE: $endpoint - Status: $statusCode');
    developer.log(
      '📥 API RESPONSE: $endpoint - Status: $statusCode',
      name: _tag,
    );
    if (responseBody != null) {
      print('📥 Response body: $responseBody');
      developer.log(
        '📥 Response body: $responseBody',
        name: _tag,
      );
    }
  }

  // Логирование ошибок API
  static void apiError(String endpoint, int statusCode, String error, [Object? originalError, StackTrace? stackTrace]) {
    developer.log(
      '❌ API ERROR: $endpoint - Status: $statusCode - $error',
      name: _tag,
      error: originalError,
      stackTrace: stackTrace,
    );
  }

  // Логирование ошибок бронирования
  static void bookingError(String operation, Object error, [StackTrace? stackTrace]) {
    developer.log(
      '🏸 BOOKING ERROR: $operation',
      name: _tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  // Логирование успешного бронирования
  static void bookingSuccess(String operation, String bookingId) {
    developer.log(
      '🏸 BOOKING SUCCESS: $operation - ID: $bookingId',
      name: _tag,
    );
  }
} 