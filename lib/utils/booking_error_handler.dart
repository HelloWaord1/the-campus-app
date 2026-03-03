import '../services/api_service.dart';

class BookingErrorHandler {
  /// Преобразует техническую ошибку в понятное сообщение для пользователя
  static String getUserFriendlyMessage(Object error) {
    if (error is ApiException) {
      return _getApiExceptionMessage(error);
    } else {
      return 'Произошла ошибка сети. Проверьте подключение к интернету.';
    }
  }

  /// Обрабатывает ApiException и возвращает понятное сообщение
  static String _getApiExceptionMessage(ApiException exception) {
    final message = exception.message.toLowerCase();
    
    // Ошибки времени бронирования
    if (message.contains('в прошлом') || message.contains('cannot be in the past')) {
      return 'Нельзя создать бронирование в прошлом. Выберите другую дату или время.';
    }
    
    if (message.contains('неверное время') || message.contains('invalid time')) {
      return 'Выбранное время недоступно. Выберите другое время.';
    }
    
    if (message.contains('неверная дата') || message.contains('invalid date')) {
      return 'Выбранная дата недоступна. Выберите другую дату.';
    }
    
    // Ошибки дублирования бронирования
    if (message.contains('уже забронирован') || 
        message.contains('already exists') ||
        message.contains('duplicate key') ||
        message.contains('idx_bookings_no_overlap')) {
      return 'Этот период времени уже забронирован. Выберите другое время.';
    }
    
    // Ошибки авторизации
    if (message.contains('авторизация') || message.contains('unauthorized')) {
      return 'Необходима авторизация. Войдите в аккаунт и попробуйте снова.';
    }
    
    if (message.contains('токен') || message.contains('token')) {
      return 'Сессия истекла. Войдите в аккаунт заново.';
    }
    
    // Ошибки валидации данных
    if (message.contains('некорректные данные') || message.contains('validation')) {
      return 'Проверьте правильность введенных данных.';
    }
    
    if (message.contains('обязательное поле') || message.contains('required field')) {
      return 'Заполните все обязательные поля.';
    }
    
    // Ошибки доступности
    if (message.contains('недоступно') || message.contains('unavailable')) {
      return 'Выбранное время недоступно. Выберите другое время.';
    }
    
    if (message.contains('занято') || message.contains('occupied')) {
      return 'Выбранное время уже занято. Выберите другое время.';
    }
    
    // Ошибки клуба
    if (message.contains('клуб не найден') || message.contains('club not found')) {
      return 'Клуб не найден. Попробуйте выбрать другой клуб.';
    }
    
    if (message.contains('клуб недоступен') || message.contains('club unavailable')) {
      return 'Клуб временно недоступен. Попробуйте позже.';
    }
    
    // Ошибки продолжительности
    if (message.contains('продолжительность') || message.contains('duration')) {
      return 'Выбранная продолжительность недоступна. Выберите другое время.';
    }
    
    // Общие ошибки сервера
    if (exception.statusCode >= 500) {
      return 'Сервер временно недоступен. Попробуйте позже.';
    }
    
    if (exception.statusCode == 404) {
      return 'Запрашиваемый ресурс не найден.';
    }
    
    if (exception.statusCode == 403) {
      return 'У вас нет прав для выполнения этого действия.';
    }
    
    // Если не удалось определить тип ошибки, возвращаем оригинальное сообщение
    return exception.message;
  }

  /// Проверяет, является ли ошибка связанной с временем бронирования
  static bool isTimeRelatedError(Object error) {
    if (error is ApiException) {
      final message = error.message.toLowerCase();
      return message.contains('в прошлом') || 
             message.contains('cannot be in the past') ||
             message.contains('неверное время') ||
             message.contains('invalid time') ||
             message.contains('недоступно') ||
             message.contains('unavailable') ||
             message.contains('занято') ||
             message.contains('occupied') ||
             message.contains('уже забронирован') ||
             message.contains('already exists') ||
             message.contains('duplicate key') ||
             message.contains('idx_bookings_no_overlap');
    }
    return false;
  }

  /// Проверяет, является ли ошибка связанной с авторизацией
  static bool isAuthError(Object error) {
    if (error is ApiException) {
      final message = error.message.toLowerCase();
      return message.contains('авторизация') || 
             message.contains('unauthorized') ||
             message.contains('токен') ||
             message.contains('token') ||
             error.statusCode == 401;
    }
    return false;
  }

  /// Проверяет, является ли ошибка связанной с валидацией данных
  static bool isValidationError(Object error) {
    if (error is ApiException) {
      final message = error.message.toLowerCase();
      return message.contains('некорректные данные') || 
             message.contains('validation') ||
             message.contains('обязательное поле') ||
             message.contains('required field') ||
             error.statusCode == 400;
    }
    return false;
  }

  /// Проверяет, является ли ошибка сетевой
  static bool isNetworkError(Object error) {
    return error.toString().toLowerCase().contains('network') ||
           error.toString().toLowerCase().contains('connection') ||
           error.toString().toLowerCase().contains('timeout') ||
           error.toString().toLowerCase().contains('socket');
  }
} 