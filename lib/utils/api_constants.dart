// Константы для API эндпоинтов
class ApiEndpoints {
  // Базовый URL API
  static const String baseUrl = 'https://paddle-app.ru';
  
  // Эндпоинты для клубов
  static const String clubs = '/api/clubs';
  
  // Эндпоинты для бронирований
  static const String bookings = '/api/bookings';
  static const String cancelBooking = '/api/bookings/cancel';
  
  // Эндпоинты для пользователей
  static const String profile = '/api/profile';
  static const String updateProfile = '/api/profile/update';
  
  // Эндпоинты для матчей
  static const String matches = '/api/matches';
  static const String createMatch = '/api/matches/create';
  static const String joinMatch = '/api/matches/join';
  static const String leaveMatch = '/api/matches/leave';
  
  // Эндпоинты для аутентификации
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String refreshToken = '/api/auth/refresh';
  
  // Эндпоинты для рейтинга
  static const String rating = '/api/rating';
  static const String initializeRating = '/api/rating/initialize';
  
  // Эндпоинты для поиска
  static const String searchMatches = '/api/search/matches';
  static const String searchPlayers = '/api/search/players';
}

// Коды статусов HTTP
class HttpStatusCodes {
  static const int ok = 200;
  static const int created = 201;
  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int internalServerError = 500;
}

// Сообщения об ошибках
class ErrorMessages {
  static const String networkError = 'Ошибка сети';
  static const String unauthorized = 'Необходима авторизация';
  static const String forbidden = 'Доступ запрещен';
  static const String notFound = 'Ресурс не найден';
  static const String serverError = 'Ошибка сервера';
  static const String invalidData = 'Некорректные данные';
} 