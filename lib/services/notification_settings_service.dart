import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class NotificationSettings {
  final bool friends;
  final bool matches;
  final bool bookings;
  final bool tournaments;
  final bool payments;
  final bool support;
  final bool externalPushOrEmail;

  const NotificationSettings({
    required this.friends,
    required this.matches,
    required this.bookings,
    required this.tournaments,
    required this.payments,
    required this.support,
    required this.externalPushOrEmail,
  });

  factory NotificationSettings.defaults() => const NotificationSettings(
        friends: true,
        matches: true,
        bookings: true,
        tournaments: true,
        payments: true,
        support: true,
        externalPushOrEmail: true,
      );

  NotificationSettings copyWith({
    bool? friends,
    bool? matches,
    bool? bookings,
    bool? tournaments,
    bool? payments,
    bool? support,
    bool? externalPushOrEmail,
  }) {
    return NotificationSettings(
      friends: friends ?? this.friends,
      matches: matches ?? this.matches,
      bookings: bookings ?? this.bookings,
      tournaments: tournaments ?? this.tournaments,
      payments: payments ?? this.payments,
      support: support ?? this.support,
      externalPushOrEmail: externalPushOrEmail ?? this.externalPushOrEmail,
    );
  }

  // Локальный JSON (для кэша)
  Map<String, dynamic> toJson() => {
        'friends': friends,
        'matches': matches,
        'bookings': bookings,
        'tournaments': tournaments,
        'payments': payments,
        'support': support,
        // в локальном кэше продолжаем хранить старый ключ для обратной совместимости
        'externalPushOrEmail': externalPushOrEmail,
      };

  // JSON для API с маппингом enable_push
  Map<String, dynamic> toApiJson() => {
        'friends': friends,
        'matches': matches,
        'bookings': bookings,
        'tournaments': tournaments,
        'payments': payments,
        'support': support,
        'enable_push': externalPushOrEmail,
      };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      friends: json['friends'] ?? true,
      matches: json['matches'] ?? true,
      bookings: json['bookings'] ?? true,
      tournaments: json['tournaments'] ?? true,
      payments: json['payments'] ?? true,
      support: json['support'] ?? true,
      // поддерживаем оба ключа: новый (API) и старый (локальный кэш)
      externalPushOrEmail: (json.containsKey('enable_push')
              ? json['enable_push']
              : json['externalPushOrEmail'])
          ?? true,
    );
  }
}

class NotificationSettingsService {
  static const _prefsKey = 'notification_settings_v2';
  static const _endpoint = '/api/notifications/settings';

  static Future<NotificationSettings> load() async {
    // Сначала пробуем получить с сервера
    try {
      final response = await ApiService.authenticatedGet(_endpoint);
      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final settings = NotificationSettings.fromJson(map);
        // Сохраняем кэш
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode(settings.toJson()));
        return settings;
      }
    } catch (_) {
      // игнорируем, попробуем взять из кэша
    }

    // Фоллбек к локальному кэшу или дефолтам
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return NotificationSettings.fromJson(map);
      } catch (_) {}
    }
    return NotificationSettings.defaults();
  }

  static Future<void> save(NotificationSettings settings) async {
    // Сразу оптимистично кладем в кэш (для мгновенного UI)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(settings.toJson()));

    // Отправляем на сервер
    final response = await ApiService.authenticatedPut(_endpoint, settings.toApiJson());
    if (response.statusCode != 200) {
      throw ApiException('Не удалось сохранить настройки уведомлений', response.statusCode);
    }
  }
}



