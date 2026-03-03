import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_storage.dart';

/// Информация о навигации после авторизации
class NavigationInfo {
  final NavigationType type;
  final String id;
  final bool? isOwnProfile; // Только для профилей

  NavigationInfo._({
    required this.type,
    required this.id,
    this.isOwnProfile,
  });

  /// Создает информацию о переходе к матчу
  factory NavigationInfo.match(String matchId) {
    return NavigationInfo._(
      type: NavigationType.match,
      id: matchId,
    );
  }

  /// Создает информацию о переходе к профилю
  factory NavigationInfo.profile(String profileId, bool isOwnProfile) {
    return NavigationInfo._(
      type: NavigationType.profile,
      id: profileId,
      isOwnProfile: isOwnProfile,
    );
  }

  /// Создает информацию о переходе к клубу
  factory NavigationInfo.club(String clubId) {
    return NavigationInfo._(
      type: NavigationType.club,
      id: clubId,
    );
  }

  /// Создает информацию о переходе к соревнованию
  factory NavigationInfo.competition(String competitionId) {
    return NavigationInfo._(
      type: NavigationType.competition,
      id: competitionId,
    );
  }

  /// Создает информацию о переходе к тренировке
  factory NavigationInfo.training(String trainingId) {
    return NavigationInfo._(
      type: NavigationType.training,
      id: trainingId,
    );
  }

  /// Создает информацию о переходе к успешному бронированию
  factory NavigationInfo.bookingSuccess(String bookingId) {
    return NavigationInfo._(
      type: NavigationType.bookingSuccess,
      id: bookingId,
    );
  }
}

/// Типы навигации
enum NavigationType {
  match,
  profile,
  club,
  competition,
  training,
  bookingSuccess,
}

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  
  // Callback для обработки перехода к матчу
  Function(String matchId)? onMatchLinkReceived;
  
  // Callback для обработки перехода к профилю
  Function(String profileId, bool isOwnProfile)? onProfileLinkReceived;
  
  // Callback для обработки перехода к клубу
  Function(String clubId)? onClubLinkReceived;
  
  // Callback для обработки перехода к соревнованию
  Function(String competitionId)? onCompetitionLinkReceived;
  
  // Callback для обработки перехода к тренировке
  Function(String trainingId)? onTrainingLinkReceived;
  
  // Callback для обработки перехода к успешному бронированию
  Function(String bookingId)? onBookingSuccessLinkReceived;

  /// Инициализация сервиса глубоких ссылок
  Future<void> initialize() async {
    debugPrint('[DeepLinkService] initialize()');
    // Обработка ссылок при запуске приложения
    final initialLink = await _appLinks.getInitialAppLink();
    debugPrint('[DeepLinkService] initialLink: ${initialLink?.toString()}');
    if (initialLink != null) {
      _handleLink(initialLink);
    }

    // Обработка ссылок во время работы приложения
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        debugPrint('[DeepLinkService] uriLinkStream received: $uri');
        _handleLink(uri);
      },
      onError: (err) {
        debugPrint('Ошибка обработки глубокой ссылки: $err');
      },
    );
    debugPrint('[DeepLinkService] Subscribed to uriLinkStream');
  }

  /// Обработка диплинка из push payload (FCM message.data)
  void handleDeeplinkFromPushData(Map<String, dynamic> data) {
    try {
      final Object? rawDeeplink = data['deeplink'];
      if (rawDeeplink is String && rawDeeplink.isNotEmpty) {
        debugPrint('[DeepLinkService] handleDeeplinkFromPushData deeplink=$rawDeeplink');
        handleDeeplinkUriString(rawDeeplink);
        return;
      }

      final String? type = (data['type'] ?? data['screen'])?.toString();
      if (type == null) {
        debugPrint('[DeepLinkService] No type/screen in push data, skipping');
        return;
      }

      String? uri;
      switch (type) {
        case 'match':
          final id = (data['match_id'] ?? data['id'])?.toString();
          if (id != null && id.isNotEmpty) {
            uri = 'https://paddle-app.ru/match/$id';
          }
          break;
        case 'profile':
          final id = (data['profile_id'] ?? data['id'])?.toString();
          if (id != null && id.isNotEmpty) {
            uri = 'https://paddle-app.ru/profile/$id';
          }
          break;
        case 'club':
          final id = (data['club_id'] ?? data['id'])?.toString();
          if (id != null && id.isNotEmpty) {
            uri = 'https://paddle-app.ru/club/$id';
          }
          break;
        case 'competition':
          final id = (data['competition_id'] ?? data['id'])?.toString();
          if (id != null && id.isNotEmpty) {
            uri = 'https://paddle-app.ru/competition/$id';
          }
          break;
        case 'training':
          final id = (data['training_id'] ?? data['id'])?.toString();
          if (id != null && id.isNotEmpty) {
            uri = 'https://paddle-app.ru/training/$id';
          }
          break;
        default:
          debugPrint('[DeepLinkService] Unknown type "$type" in push data');
      }

      if (uri != null) {
        debugPrint('[DeepLinkService] Built deeplink from data: $uri');
        handleDeeplinkUriString(uri);
      } else {
        debugPrint('[DeepLinkService] Could not build deeplink from push data');
      }
    } catch (e) {
      debugPrint('[DeepLinkService] handleDeeplinkFromPushData error: $e');
    }
  }

  /// Публичный метод для обработки строки-URI диплинка
  void handleDeeplinkUriString(String uriString) {
    try {
      final uri = Uri.parse(uriString);
      _handleLink(uri);
    } catch (e) {
      debugPrint('[DeepLinkService] handleDeeplinkUriString parse error: $e');
    }
  }

  /// Обработка входящей ссылки
  void _handleLink(Uri uri) {
    debugPrint('Получена глубокая ссылка: $uri');
    debugPrint('[DeepLinkService] scheme=${uri.scheme}, host=${uri.host}, path=${uri.path}, segments=${uri.pathSegments}');
    
    // Обрабатываем схему paddle:// для возврата из оплаты
    if (uri.scheme == 'paddle') {
      final host = uri.host.toLowerCase();
      final pathSegments = uri.pathSegments;

      String? trainingId;
      String? bookingId;

      // Формат для тренировок: paddle://training/<id>
      if (host == 'training' && pathSegments.isNotEmpty) {
        trainingId = pathSegments.first;
      }
      // На всякий случай поддерживаем формат paddle:///training/<id>
      else if (pathSegments.length >= 2 && pathSegments[0] == 'training') {
        trainingId = pathSegments[1];
      }

      // Формат для бронирований: paddle://booking_success/<id>
      if (host == 'booking_success' && pathSegments.isNotEmpty) {
        bookingId = pathSegments.first;
      }
      // На всякий случай поддерживаем формат paddle:///booking_success/<id>
      else if (pathSegments.length >= 2 && pathSegments[0] == 'booking_success') {
        bookingId = pathSegments[1];
      }

      if (trainingId != null && trainingId.isNotEmpty) {
        debugPrint('[DeepLinkService] Payment return (paddle://) training id=$trainingId');
        _handleTrainingLink(trainingId);
        return;
      }

      if (bookingId != null && bookingId.isNotEmpty) {
        debugPrint('[DeepLinkService] Payment return (paddle://) booking id=$bookingId');
        _handleBookingSuccessLink(bookingId);
        return;
      }

        debugPrint('[DeepLinkService] Unknown paddle:// link format: $uri');
      return;
    }
    
    // Проверяем, что это ссылка на наш домен (допускаем www)
    final host = uri.host.toLowerCase();
    if (!host.endsWith('paddle-app.ru')) {
      debugPrint('[DeepLinkService] Ignored: unexpected host ${uri.host}');
      return;
    }

    // Игнорируем ссылки на /info и её подпути - они должны открываться в браузере
    final path = uri.path;
    if (path.startsWith('/info')) {
      debugPrint('[DeepLinkService] Ignored: /info path should open in browser: $path');
      return;
    }

    // Обрабатываем ссылки вида /match/{match_id}
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty && pathSegments[0] == 'match' && pathSegments.length > 1) {
      final matchId = pathSegments[1];
      debugPrint('[DeepLinkService] Matched /match id=$matchId');
      _handleMatchLink(matchId);
    }
    
    // Обрабатываем ссылки вида /profile/{profile_id}
    if (pathSegments.isNotEmpty && pathSegments[0] == 'profile' && pathSegments.length > 1) {
      final profileId = pathSegments[1];
      debugPrint('[DeepLinkService] Matched /profile id=$profileId');
      _handleProfileLink(profileId);
    }

    // Обрабатываем ссылки вида /club/{club_id}
    if (pathSegments.isNotEmpty && pathSegments[0] == 'club' && pathSegments.length > 1) {
      final clubId = pathSegments[1];
      debugPrint('[DeepLinkService] Matched /club id=$clubId');
      _handleClubLink(clubId);
    }

    // Обрабатываем ссылки вида /competition/{competition_id}
    if (pathSegments.isNotEmpty && pathSegments[0] == 'competition' && pathSegments.length > 1) {
      final competitionId = pathSegments[1];
      debugPrint('[DeepLinkService] Matched /competition id=$competitionId');
      _handleCompetitionLink(competitionId);
    }

    // Обрабатываем ссылки вида /training/{training_id}
    if (pathSegments.isNotEmpty && pathSegments[0] == 'training' && pathSegments.length > 1) {
      final trainingId = pathSegments[1];
      debugPrint('[DeepLinkService] Matched /training id=$trainingId');
      _handleTrainingLink(trainingId);
    }

    if (pathSegments.isEmpty ||
        !(pathSegments[0] == 'match' || pathSegments[0] == 'profile' || pathSegments[0] == 'club' || pathSegments[0] == 'competition' || pathSegments[0] == 'training')) {
      debugPrint('[DeepLinkService] No matching route for ${uri.path}');
    }
  }

  /// Обработка ссылки на матч
  Future<void> _handleMatchLink(String matchId) async {
    // Проверяем, авторизован ли пользователь
    final isLoggedIn = await AuthStorage.isLoggedIn();
    debugPrint('[DeepLinkService] _handleMatchLink id=$matchId isLoggedIn=$isLoggedIn');
    
    if (isLoggedIn) {
      // Если пользователь авторизован
      if (onMatchLinkReceived != null) {
        debugPrint('[DeepLinkService] onMatchLinkReceived()');
        onMatchLinkReceived!(matchId);
      } else {
        // Хендлер ещё не назначен (например, холодный старт до runApp) — сохраняем на потом
        await _savePendingMatchLink(matchId);
        debugPrint('[DeepLinkService] Saved pending match (handler not ready): $matchId');
      }
    } else {
      // Если пользователь не авторизован, просто сохраняем ссылку
      // Пользователь сам решит, когда войти в приложение
      await _savePendingMatchLink(matchId);
      debugPrint('Сохранена ссылка на матч для неавторизованного пользователя: $matchId');
    }
  }

  /// Сохранение ссылки на матч для последующего перехода после авторизации
  Future<void> _savePendingMatchLink(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_match_link', matchId);
    debugPrint('[DeepLinkService] pending_match_link saved: $matchId');
  }

  /// Получение сохраненной ссылки на матч
  Future<String?> getPendingMatchLink() async {
    final prefs = await SharedPreferences.getInstance();
    final matchId = prefs.getString('pending_match_link');
    if (matchId != null) {
      // Очищаем сохраненную ссылку
      await prefs.remove('pending_match_link');
      debugPrint('[DeepLinkService] pending_match_link restored and cleared: $matchId');
    }
    return matchId;
  }

  /// Обработка ссылки на профиль
  Future<void> _handleProfileLink(String profileId) async {
    // Проверяем, авторизован ли пользователь
    final isLoggedIn = await AuthStorage.isLoggedIn();
    debugPrint('[DeepLinkService] _handleProfileLink id=$profileId isLoggedIn=$isLoggedIn');
    
    if (isLoggedIn) {
      // Если пользователь авторизован, проверяем, свой ли это профиль
      final currentUser = await AuthStorage.getUser();
      final isOwnProfile = currentUser?.id == profileId;
      
      // Передаем информацию о том, свой ли это профиль
      if (onProfileLinkReceived != null) {
        debugPrint('[DeepLinkService] onProfileLinkReceived() isOwn=$isOwnProfile');
        onProfileLinkReceived!(profileId, isOwnProfile);
      } else {
        // Хендлер ещё не назначен — сохраняем на потом
        await _savePendingProfileLink(profileId);
        debugPrint('[DeepLinkService] Saved pending profile (handler not ready): $profileId');
      }
    } else {
      // Если пользователь не авторизован, просто сохраняем ссылку
      // Пользователь сам решит, когда войти в приложение
      await _savePendingProfileLink(profileId);
      debugPrint('Сохранена ссылка на профиль для неавторизованного пользователя: $profileId');
    }
  }

  /// Обработка ссылки на клуб
  Future<void> _handleClubLink(String clubId) async {
    final isLoggedIn = await AuthStorage.isLoggedIn();
    debugPrint('[DeepLinkService] _handleClubLink id=$clubId isLoggedIn=$isLoggedIn');
    if (isLoggedIn) {
      if (onClubLinkReceived != null) {
        debugPrint('[DeepLinkService] onClubLinkReceived()');
        onClubLinkReceived!(clubId);
      } else {
        await _savePendingClubLink(clubId);
        debugPrint('[DeepLinkService] Saved pending club (handler not ready): $clubId');
      }
    } else {
      await _savePendingClubLink(clubId);
      debugPrint('Сохранена ссылка на клуб для неавторизованного пользователя: $clubId');
    }
  }

  /// Обработка ссылки на соревнование
  Future<void> _handleCompetitionLink(String competitionId) async {
    final isLoggedIn = await AuthStorage.isLoggedIn();
    debugPrint('[DeepLinkService] _handleCompetitionLink id=$competitionId isLoggedIn=$isLoggedIn');
    if (isLoggedIn) {
      if (onCompetitionLinkReceived != null) {
        debugPrint('[DeepLinkService] onCompetitionLinkReceived()');
        onCompetitionLinkReceived!(competitionId);
      } else {
        await _savePendingCompetitionLink(competitionId);
        debugPrint('[DeepLinkService] Saved pending competition (handler not ready): $competitionId');
      }
    } else {
      await _savePendingCompetitionLink(competitionId);
      debugPrint('Сохранена ссылка на турнир для неавторизованного пользователя: $competitionId');
    }
  }

  Future<void> _savePendingCompetitionLink(String competitionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_competition_link', competitionId);
    debugPrint('[DeepLinkService] pending_competition_link saved: $competitionId');
  }

  Future<String?> getPendingCompetitionLink() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('pending_competition_link');
    if (id != null) {
      await prefs.remove('pending_competition_link');
      debugPrint('[DeepLinkService] pending_competition_link restored and cleared: $id');
    }
    return id;
  }

  /// Обработка ссылки на тренировку
  Future<void> _handleTrainingLink(String trainingId) async {
    final isLoggedIn = await AuthStorage.isLoggedIn();
    debugPrint('[DeepLinkService] _handleTrainingLink id=$trainingId isLoggedIn=$isLoggedIn');
    if (isLoggedIn) {
      if (onTrainingLinkReceived != null) {
        debugPrint('[DeepLinkService] onTrainingLinkReceived()');
        onTrainingLinkReceived!(trainingId);
      } else {
        await _savePendingTrainingLink(trainingId);
        debugPrint('[DeepLinkService] Saved pending training (handler not ready): $trainingId');
      }
    } else {
      await _savePendingTrainingLink(trainingId);
      debugPrint('Сохранена ссылка на тренировку для неавторизованного пользователя: $trainingId');
    }
  }

  Future<void> _savePendingTrainingLink(String trainingId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_training_link', trainingId);
    debugPrint('[DeepLinkService] pending_training_link saved: $trainingId');
  }

  Future<String?> getPendingTrainingLink() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('pending_training_link');
    if (id != null) {
      await prefs.remove('pending_training_link');
      debugPrint('[DeepLinkService] pending_training_link restored and cleared: $id');
    }
    return id;
  }

  /// Обработка ссылки на успешное бронирование (после оплаты)
  Future<void> _handleBookingSuccessLink(String bookingId) async {
    final isLoggedIn = await AuthStorage.isLoggedIn();
    debugPrint('[DeepLinkService] _handleBookingSuccessLink id=$bookingId isLoggedIn=$isLoggedIn');
    if (isLoggedIn) {
      if (onBookingSuccessLinkReceived != null) {
        debugPrint('[DeepLinkService] onBookingSuccessLinkReceived()');
        onBookingSuccessLinkReceived!(bookingId);
      } else {
        await _savePendingBookingSuccessLink(bookingId);
        debugPrint('[DeepLinkService] Saved pending booking_success (handler not ready): $bookingId');
      }
    } else {
      await _savePendingBookingSuccessLink(bookingId);
      debugPrint('Сохранена ссылка на бронирование для неавторизованного пользователя: $bookingId');
    }
  }

  Future<void> _savePendingBookingSuccessLink(String bookingId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_booking_success_link', bookingId);
    debugPrint('[DeepLinkService] pending_booking_success_link saved: $bookingId');
  }

  Future<String?> getPendingBookingSuccessLink() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('pending_booking_success_link');
    if (id != null) {
      await prefs.remove('pending_booking_success_link');
      debugPrint('[DeepLinkService] pending_booking_success_link restored and cleared: $id');
    }
    return id;
  }

  /// Сохранение ссылки на профиль для последующего перехода после авторизации
  Future<void> _savePendingProfileLink(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_profile_link', profileId);
    debugPrint('[DeepLinkService] pending_profile_link saved: $profileId');
  }

  /// Получение сохраненной ссылки на профиль
  Future<String?> getPendingProfileLink() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getString('pending_profile_link');
    if (profileId != null) {
      // Очищаем сохраненную ссылку
      await prefs.remove('pending_profile_link');
      debugPrint('[DeepLinkService] pending_profile_link restored and cleared: $profileId');
    }
    return profileId;
  }

  /// Сохранение ссылки на клуб для последующего перехода после авторизации
  Future<void> _savePendingClubLink(String clubId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_club_link', clubId);
    debugPrint('[DeepLinkService] pending_club_link saved: $clubId');
  }

  /// Получение сохраненной ссылки на клуб
  Future<String?> getPendingClubLink() async {
    final prefs = await SharedPreferences.getInstance();
    final clubId = prefs.getString('pending_club_link');
    if (clubId != null) {
      await prefs.remove('pending_club_link');
      debugPrint('[DeepLinkService] pending_club_link restored and cleared: $clubId');
    }
    return clubId;
  }

  /// Обработка переходов после авторизации
  /// Возвращает информацию о том, куда нужно перейти
  Future<NavigationInfo?> handlePostAuthNavigation() async {
    // 1) Проверяем, есть ли сохраненная ссылка на матч (высокий приоритет)
    final pendingMatchId = await getPendingMatchLink();
    if (pendingMatchId != null) {
      debugPrint('[DeepLinkService] handlePostAuthNavigation → match $pendingMatchId');
      return NavigationInfo.match(pendingMatchId);
    }
    
    // 2) Проверяем, есть ли сохраненная ссылка на профиль
    final pendingProfileId = await getPendingProfileLink();
    if (pendingProfileId != null) {
      // Проверяем, свой ли это профиль
      final currentUser = await AuthStorage.getUser();
      final isOwnProfile = currentUser?.id == pendingProfileId;
      
      return NavigationInfo.profile(pendingProfileId, isOwnProfile);
    }
    
    // 3) Проверяем, есть ли сохраненная ссылка на клуб
    final pendingClubId = await getPendingClubLink();
    if (pendingClubId != null) {
      debugPrint('[DeepLinkService] handlePostAuthNavigation → club $pendingClubId');
      return NavigationInfo.club(pendingClubId);
    }

    // 4) Проверяем, есть ли сохраненная ссылка на соревнование
    final pendingCompetitionId = await getPendingCompetitionLink();
    if (pendingCompetitionId != null) {
      debugPrint('[DeepLinkService] handlePostAuthNavigation → competition $pendingCompetitionId');
      return NavigationInfo.competition(pendingCompetitionId);
    }

    // 5) Проверяем, есть ли сохраненная ссылка на тренировку
    final pendingTrainingId = await getPendingTrainingLink();
    if (pendingTrainingId != null) {
      debugPrint('[DeepLinkService] handlePostAuthNavigation → training $pendingTrainingId');
      return NavigationInfo.training(pendingTrainingId);
    }

    // 6) Проверяем, есть ли сохраненная ссылка на успешное бронирование
    final pendingBookingId = await getPendingBookingSuccessLink();
    if (pendingBookingId != null) {
      debugPrint('[DeepLinkService] handlePostAuthNavigation → booking_success $pendingBookingId');
      return NavigationInfo.bookingSuccess(pendingBookingId);
    }

    debugPrint('[DeepLinkService] handlePostAuthNavigation → nothing');
    return null; // Нет сохраненных ссылок
  }

  /// Освобождение ресурсов
  void dispose() {
    _linkSubscription?.cancel();
  }
}