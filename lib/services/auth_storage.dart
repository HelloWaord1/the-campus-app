import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';

class AuthStorage {
  static const String _tokenKey = 'access_token';
  static const String _userKey = 'user_data';
  static const String _onboardingKey = 'onboarding_completed';
  
  // Глобальный колбэк, вызываемый при истечении/недействительности сессии
  // Используется для централизованного показа уведомления и навигации
  static Future<void> Function()? onSessionExpired;
  static bool _sessionExpiredNotified = false;
  
  static Future<void> saveAuthData(AuthResponse authResponse) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, authResponse.accessToken);
    await prefs.setString(_userKey, jsonEncode(authResponse.user.toJson()));
    // Сбрасываем флаг, чтобы последующие истечения могли быть обработаны
    _sessionExpiredNotified = false;
  }
  
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
  
  static Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }
    return null;
  }
  
  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  // Сообщить приложению, что сессия истекла. Защищено от повторных срабатываний.
  static Future<void> notifySessionExpired() async {
    if (_sessionExpiredNotified) return;
    _sessionExpiredNotified = true;
    try {
      final handler = onSessionExpired;
      if (handler != null) {
        await handler();
      }
    } catch (_) {
      // ignore
    }
  }
  
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // Методы для онбординга
  static Future<void> setOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }
  
  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  // Метод для обновления рейтинга пользователя
  static Future<void> updateUserRating(String rating) async {
    final user = await getUser();
    if (user != null) {
      final updatedUser = User(
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        passwordHash: user.passwordHash,
        city: user.city,
        avatarUrl: user.avatarUrl,
        currentRating: rating,
        status: user.status,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(updatedUser.toJson()));
    }
  }
} 