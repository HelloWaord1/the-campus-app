import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';

/// Минималистичный сервис для интеграции Яндекс OAuth в любом проекте
class YandexAuthService {
  YandexAuthService(this.baseUrl);

  final String baseUrl; // например, https://paddle-app.ru

  Future<UserYandexCallbackResponse> callback(String oauthToken) async {
    final url = Uri.parse('$baseUrl/api/auth/yandex/callback');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'oauth_token': oauthToken}),
    );
    if (response.statusCode == 200) {
      return UserYandexCallbackResponse.fromJson(jsonDecode(response.body));
    }
    throw _mapError('Ошибка авторизации через Яндекс', response);
  }

  Future<AuthResponse> register({
    required String oauthToken,
    required String city,
    required int currentRating,
    String skillLevel = 'начинающий',
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/yandex/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'oauth_token': oauthToken,
        'city': city,
        'current_rating': currentRating,
        'skill_level': skillLevel,
      }),
    );
    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    }
    throw _mapError('Ошибка регистрации через Яндекс', response);
  }

  Future<AuthResponse> completeRegistration({
    required String oauthToken,
    required String city,
    required int currentRating,
    String? preferredHand,
    String skillLevel = 'профессионал',
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/yandex/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'oauth_token': oauthToken,
        'city': city,
        'current_rating': currentRating,
        'preferred_hand': preferredHand,
        'skill_level': skillLevel,
      }),
    );
    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    }
    throw _mapError('Ошибка регистрации через Яндекс', response);
  }

  Exception _mapError(String defaultMsg, http.Response response) {
    String message = defaultMsg;
    try {
      final json = jsonDecode(response.body);
      message = json['detail'] ?? message;
      if (response.statusCode == 503) {
        message = 'Сервис Яндекса временно недоступен. Попробуйте позже.';
      }
    } catch (_) {}
    return Exception('$message (HTTP ${response.statusCode})');
  }
}


