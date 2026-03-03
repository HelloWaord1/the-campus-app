import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../models/match.dart';
import '../models/club.dart';
import '../models/user.dart';
import '../models/booking.dart';
// import 'package:path/path.dart' as path;
import 'auth_storage.dart';
import '../utils/logger.dart';
import '../models/notification.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/competition.dart';
import '../models/training.dart';
import '../models/court.dart';

class ApiService {
  // Для продакшена: 'https://the-campus.app'
  // Для локальной разработки на iOS симуляторе: 'http://localhost:8000'
  // Для локальной разработки на Android эмуляторе: 'http://10.0.2.2:8000'
  static const String baseUrl = 'https://the-campus.app';
  //static const String baseUrl = 'http://localhost:8000';

  static Future<void> _handleUnauthorized() async {
    await AuthStorage.clearAuthData();
    await AuthStorage.notifySessionExpired();
  }

  // Метод для получения заголовков с авторизацией
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthStorage.getToken();
    final headers = {'Content-Type': 'application/json'};

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Универсальный парсер серверной ошибки: берём detail из JSON, иначе raw body, иначе дефолт
  static String _extractServerDetail(http.Response response, String defaultMessage) {
    try {
      if ((response.body).isNotEmpty) {
        final dynamic data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final dynamic detail = data['detail'];
          if (detail is String && detail.trim().isNotEmpty) return detail;
          if (detail is Map) {
            // Попробуем собрать сообщение из вложенного объекта
            final msg = detail['message'] ?? detail['error'] ?? detail['reason'];
            if (msg is String && msg.trim().isNotEmpty) return msg;
          }
        }
        // Если не JSON, но есть тело — вернём его как есть
        return response.body;
      }
    } catch (_) {
      // ignore JSON parse errors
    }
    return defaultMessage;
  }

  // Политика минимально поддерживаемых версий приложения (обязательное обновление)
  static Future<Map<String, dynamic>> getAppVersionPolicy() async {
    final String path = '/api/app/version';
    try {
      Logger.apiRequest(path, {});
      final response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: const {'Content-Type': 'application/json'},
      );
      Logger.apiResponse(path, response.statusCode, response.body);
      if (response.statusCode != 200) {
        final detail = _extractServerDetail(response, 'Ошибка получения политики версии приложения');
        throw ApiException(detail, response.statusCode);
      }
      final dynamic data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      throw ApiException('Некорректный формат ответа политики версии приложения', 500);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Регистрация FCM токена на бэкенде
  static Future<void> registerPushToken({String? overrideToken, String? platform, String? deviceInfo}) async {
    try {
      Logger.info('🔔 Регистрация пуш-токена начата (override=${overrideToken != null}, platform=${platform ?? (Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'web')})');
      final String? token = overrideToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        Logger.error('🔔 FCM токен отсутствует. Регистрация невозможна. Проверьте разрешения/entitlements/APNs связку.');
        throw ApiException('Не удалось получить FCM токен', 400);
      }
      final Map<String, dynamic> body = {
        'token': token,
        'platform': platform ?? (Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'web'),
      };
      if (deviceInfo != null) {
        body['device_info'] = deviceInfo;
      }
      // Маскируем токен в логах
      final String maskedToken = token.length <= 10 ? '***' : '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
      Logger.apiRequest('/api/push/register', {
        'token': maskedToken,
        'platform': body['platform'],
        'device_info_present': deviceInfo != null,
      });

      final response = await authenticatedPost('/api/push/register', body);
      Logger.apiResponse('/api/push/register', response.statusCode, response.body);
      if (response.statusCode != 200) {
        Logger.apiError('/api/push/register', response.statusCode, 'Ошибка регистрации push токена');
        throw ApiException('Ошибка регистрации push токена', response.statusCode);
      }
      Logger.success('🔔 Пуш-токен зарегистрирован на бэкенде');
    } catch (e) {
      if (e is ApiException) {
        Logger.error('🔔 Ошибка регистрации пуш-токена (API-исключение)', e);
        rethrow;
      }
      Logger.error('🔔 Неожиданная ошибка регистрации пуш-токена', e as Object?);
      throw ApiException('Ошибка регистрации push токена: $e', 500);
    }
  }

  // ==================== МЕТОДЫ ДЛЯ СОРЕВНОВАНИЙ ====================
  static Future<CompetitionListResponse> getCompetitions({
    List<DateTime>? dates,
    double? userLatitude,
    double? userLongitude,
    double? maxDistanceKm,
    String? participantsGender, // all|male|female
    String? search,
  }) async {
    try {
      final Map<String, String> query = {};
      if (dates != null && dates.isNotEmpty) {
        final csv = dates.map((d) => d.toIso8601String().substring(0, 10)).join(',');
        query['dates'] = csv;
      }
      if (userLatitude != null) query['user_latitude'] = userLatitude.toString();
      if (userLongitude != null) query['user_longitude'] = userLongitude.toString();
      if (maxDistanceKm != null) query['max_distance_km'] = maxDistanceKm.toString();
      if (participantsGender != null) query['participants_gender'] = participantsGender;
      if (search != null && search.isNotEmpty) query['search'] = search;

      final uri = Uri.parse('$baseUrl/api/competitions').replace(queryParameters: query.isEmpty ? null : query);
      final response = await http.get(uri, headers: await _getAuthHeaders());

      if (response.statusCode == 200) {
        final jsonBody = jsonDecode(response.body);
        return CompetitionListResponse.fromJson(jsonBody);
      } else if (response.statusCode == 401) {
        await AuthStorage.clearAuthData();
        throw ApiException('Токен недействителен', 401);
      } else {
        throw ApiException('Ошибка получения турниров', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение соревнования по ID
  static Future<Competition> getCompetitionById(String competitionId) async {
    try {
      final response = await authenticatedGet('/api/competition/$competitionId');
      print('--- ApiService.getCompetitionById ---');
      print('Response: ${response.body}');
      if (response.statusCode == 200) {
        final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
        print('--- ApiService.getCompetitionById jsonBody ---');
        print('JsonBody status: ${jsonBody['status']}');
        print('JsonBody final_standings: ${jsonBody['final_standings']}');
        print('JsonBody teams: ${jsonBody['teams']}');
        return Competition.fromJson(jsonBody);
      } else if (response.statusCode == 404) {
        throw ApiException('Турнир не найден', 404);
      } else {
        throw ApiException('Ошибка получения турнира', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Матчи пользователя в рамках соревнования
  static Future<Map<String, dynamic>> getUserCompetitionMatchesWithFormat(String competitionId) async {
    print('>>> getUserCompetitionMatchesWithFormat START for competition: $competitionId');
    try {
      print('>>> Making request to: /api/competitions/$competitionId/matches');
      final response = await authenticatedGet('/api/competitions/$competitionId/matches');
      print('--- ApiService.getUserCompetitionMatchesWithFormat ---');
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        print('--- ApiService.getUserCompetitionMatchesWithFormat body ---');
        print('Body type: ${body.runtimeType}');
        print('Body total: ${body is Map ? body["total"] : "not a map"}');
        print('Body format: ${body is Map ? body["format"] : "not a map"}');
        final List<dynamic> list = (body is Map<String, dynamic>) ? (body['matches'] as List? ?? []) : (body as List? ?? []);
        print('Matches count: ${list.length}');
        final String format = (body is Map<String, dynamic>) ? (body['format'] as String? ?? 'single') : 'single';
        print('Format: $format');
        
        final List<CompetitionMatchItem> matches = [];
        for (int i = 0; i < list.length; i++) {
          try {
            final item = CompetitionMatchItem.fromJson(Map<String, dynamic>.from(list[i]));
            matches.add(item);
          } catch (e) {
            print('Error parsing match item $i: $e');
            print('Match item data: ${list[i]}');
            rethrow;
          }
        }
        
        return {
          'matches': matches,
          'format': format,
        };
      } else if (response.statusCode == 404) {
        throw ApiException('Турнир не найден', 404);
      } else {
        throw ApiException('Ошибка получения матчей турнира (код ${response.statusCode})', response.statusCode);
      }
    } catch (e, stackTrace) {
      print('getUserCompetitionMatchesWithFormat error: $e');
      print('Error stack trace: $stackTrace');
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  static Future<List<CompetitionMatchItem>> getUserCompetitionMatchesRaw(String competitionId) async {
    final result = await getUserCompetitionMatchesWithFormat(competitionId);
    return result['matches'] as List<CompetitionMatchItem>;
  }

  // Преобразуем CompetitionMatchItem в Match для карточек, если match вложен
  static Future<List<Match>> getUserCompetitionMatches(String competitionId) async {
    final raw = await getUserCompetitionMatchesRaw(competitionId);
    final List<Match> result = [];

    for (final item in raw) {
      // Участники по командам A/B
      final participants = <MatchParticipant>[];
      void addMembers(CompetitionTeamBrief? t, String teamId) {
        if (t == null) return;
        for (final m in t.members) {
          final name = (m.name ?? ((m.firstName ?? '') + ' ' + (m.lastName ?? ''))).trim();
          participants.add(MatchParticipant(
            id: null,
            userId: m.userId ?? '',
            name: name.isEmpty ? 'Игрок' : name,
            avatarUrl: m.avatarUrl,
            userRating: m.userRating,
            role: null,
            status: null,
            teamId: teamId,
            approvedByOrganizer: null,
            joinedAt: null,
            createdAt: null,
          ));
        }
      }
      addMembers(item.teamA, 'A');
      addMembers(item.teamB, 'B');

      // Разбор счёта из строки вида "6-3, 4-6, 10-8"
      List<int>? aSets;
      List<int>? bSets;
      final dynamic scoreJson = item.score;
      if (scoreJson is String && scoreJson.trim().isNotEmpty) {
        final parts = scoreJson.split(',');
        final List<int> aa = [];
        final List<int> bb = [];
        for (final p in parts) {
          final ab = p.trim().split(RegExp(r'[:\-]'));
          if (ab.length >= 2) {
            final a = int.tryParse(ab[0].trim()) ?? 0;
            final b = int.tryParse(ab[1].trim()) ?? 0;
            aa.add(a);
            bb.add(b);
          }
        }
        if (aa.isNotEmpty && bb.isNotEmpty) {
          aSets = aa;
          bSets = bb;
        }
      }

      String? winnerTeam;
      if (item.winnerTeamId != null) {
        if (item.winnerTeamId == item.teamAId) winnerTeam = 'A';
        if (item.winnerTeamId == item.teamBId) winnerTeam = 'B';
      }

      final bool finished = (aSets != null && aSets.isNotEmpty) || (bSets != null && bSets.isNotEmpty) || winnerTeam != null;
      // Определяем формат по размеру команд: если по одному игроку в каждой, считаем single
      final int teamASize = item.teamA?.members.length ?? 0;
      final int teamBSize = item.teamB?.members.length ?? 0;
      final bool isSingle = (teamASize <= 1) && (teamBSize <= 1);
      final String inferredFormat = isSingle ? 'single' : 'double';
      final dt = item.scheduledTime ?? DateTime.now();
      // Собираем Match. Некоторые поля ставим по умолчанию.
      result.add(Match(
        id: item.matchId ?? item.competitionMatchId,
        dateTime: dt,
        duration: 60,
        clubId: null,
        clubName: item.clubName,
        clubPhoto: null,
        clubCity: item.city,
        courtId: null,
        isBooked: false,
        format: inferredFormat,
        requiredLevel: 'любитель',
        isPrivate: false,
        description: null,
        maxParticipants: isSingle ? 2 : 4,
        currentParticipants: participants.length,
        organizerId: participants.isNotEmpty ? participants.first.userId : '',
        organizerName: participants.isNotEmpty ? participants.first.name : 'Организатор',
        organizerAvatarUrl: participants.isNotEmpty ? participants.first.avatarUrl : null,
        status: finished ? 'completed' : 'active',
        participants: participants,
        bookingId: null,
        createdAt: dt,
        updatedAt: null,
        courtName: null,
        price: null,
        courtNumber: null,
        bookedByName: null,
        winnerTeam: winnerTeam,
        winnerUserId: null,
        teamASets: aSets,
        teamBSets: bSets,
      ));
    }

    return result;
  }

  // Получить команды соревнования
  static Future<CompetitionTeamsApiResponse> getCompetitionTeams(String competitionId) async {
    try {
      final response = await authenticatedGet('/api/competitions/$competitionId/teams');
      if (response.statusCode == 200) {
        final jsonBody = jsonDecode(response.body);
        final List<dynamic> items = jsonBody is List ? jsonBody : (jsonBody['teams'] ?? jsonBody['items'] ?? []);
        final teams = items.map((e) => CompetitionTeam.fromJson(Map<String, dynamic>.from(e))).toList();
        final String? myStatus = (jsonBody is Map<String, dynamic>) ? (jsonBody['my_status'] as String?) : null;
        return CompetitionTeamsApiResponse(teams: teams, myStatus: myStatus);
      } else if (response.statusCode == 404) {
        throw ApiException('Турнир не найден', 404);
      } else {
        throw ApiException('Ошибка получения команд турнира', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Переключиться в другую команду
  static Future<void> switchCompetitionTeam(String competitionId, String targetTeamId) async {
    try {
      final response = await authenticatedPost(
        '/api/competitions/$competitionId/switch-team?target_team_id=$targetTeamId',
        {},
      );
      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 404) {
        throw ApiException('Турнир или команда не найдены', 404);
      } else if (response.statusCode == 400) {
        final jsonBody = jsonDecode(response.body);
        throw ApiException(jsonBody['detail'] ?? 'Невозможно сменить команду', 400);
      } else {
        throw ApiException('Ошибка смены команды', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение моих соревнований с фильтрами
  static Future<CompetitionListResponse> getMyCompetitions({
    List<DateTime>? dates,
    double? userLatitude,
    double? userLongitude,
    double? maxDistanceKm,
    String? participantsGender, // all|male|female
    String? search,
  }) async {
    try {
      final Map<String, String> query = {};
      if (dates != null && dates.isNotEmpty) {
        final csv = dates.map((d) => d.toIso8601String().substring(0, 10)).join(',');
        query['dates'] = csv;
      }
      if (userLatitude != null) query['user_latitude'] = userLatitude.toString();
      if (userLongitude != null) query['user_longitude'] = userLongitude.toString();
      if (maxDistanceKm != null) query['max_distance_km'] = maxDistanceKm.toString();
      if (participantsGender != null) query['participants_gender'] = participantsGender;
      if (search != null && search.isNotEmpty) query['search'] = search;

      final uri = Uri.parse('$baseUrl/api/competitions/my').replace(queryParameters: query.isEmpty ? null : query);
      final response = await http.get(uri, headers: await _getAuthHeaders());

      if (response.statusCode == 200) {
        final jsonBody = jsonDecode(response.body);
        return CompetitionListResponse.fromJson(jsonBody);
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw ApiException('Сессия истекла. Войдите заново.', 401);
      } else {
        throw ApiException('Ошибка получения моих турниров', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Присоединиться к соревнованию
  static Future<CompetitionJoinResponse> joinCompetition(
    String competitionId,
    CompetitionJoinRequest request,
  ) async {
    try {
      final response = await authenticatedPost('/api/competitions/$competitionId/join', request.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
        return CompetitionJoinResponse.fromJson(jsonBody);
      } else if (response.statusCode == 400) {
        throw ApiException(_extractServerDetail(response, 'Нельзя присоединиться к турниру'), 400);
      } else if (response.statusCode == 404) {
        throw ApiException(_extractServerDetail(response, 'Турнир не найден'), 404);
      } else {
        throw ApiException('Ошибка присоединения к турниру', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Покинуть соревнование
  static Future<CompetitionJoinResponse> leaveCompetition(String competitionId) async {
    try {
      final response = await authenticatedPost('/api/competitions/$competitionId/leave', {});
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.body.isEmpty) {
          return CompetitionJoinResponse(success: true);
        }
        final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
        return CompetitionJoinResponse.fromJson(jsonBody);
      } else if (response.statusCode == 404) {
        throw ApiException(_extractServerDetail(response, 'Турнир не найден'), 404);
      } else {
        throw ApiException('Ошибка выхода из турнира', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Отмена заявки на участие в соревновании (новый эндпоинт)
  static Future<CompetitionJoinResponse> cancelCompetitionRequest(String competitionId) async {
    try {
      final response = await authenticatedPost('/api/competitions/$competitionId/cancel-request', {});
      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          return CompetitionJoinResponse(success: true, message: 'Заявка отменена');
        }
        final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
        return CompetitionJoinResponse.fromJson(jsonBody);
      } else if (response.statusCode == 404) {
        throw ApiException(_extractServerDetail(response, 'Турнир не найден'), 404);
      } else if (response.statusCode == 400) {
        throw ApiException(_extractServerDetail(response, 'Нет активной заявки для отмены'), 400);
      } else {
        throw ApiException('Ошибка отмены заявки', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Парная заявка на участие в соревновании
  static Future<CompetitionJoinResponse> joinCompetitionPair(
    String competitionId,
    String companionId,
  ) async {
    try {
      final response = await authenticatedPost('/api/competitions/$competitionId/join-pair', {
        'companion_id': companionId,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
        return CompetitionJoinResponse.fromJson(jsonBody);
      } else if (response.statusCode == 400) {
        throw ApiException(_extractServerDetail(response, 'Нельзя подать парную заявку'), 400);
      } else if (response.statusCode == 404) {
        throw ApiException(_extractServerDetail(response, 'Турнир не найден'), 404);
      } else {
        throw ApiException('Ошибка парной заявки', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Удаление профиля текущего пользователя
  static Future<void> deleteProfile() async {
    Logger.info('🗑️ API: Запрос на удаление профиля');
    final url = Uri.parse('$baseUrl/api/profile');
    final response = await authenticatedDelete(url.path);

    if (response.statusCode == 200 || response.statusCode == 204) {
      Logger.success('🗑️ API: Профиль успешно удален');
      // Завершаем сессию пользователя после успешного удаления
      await AuthStorage.clearAuthData();
      return;
    } else {
      Logger.error('🗑️ API: Ошибка удаления профиля. Статус: ${response.statusCode}, Ответ: ${response.body}');
      throw ApiException('Не удалось удалить профиль: ${response.body}', response.statusCode);
    }
  }

  // Метод для логирования HTTP-ответов
  static void _logResponse(http.Response response) {
    print('--- API Response ---');
    print('Status Code: ${response.statusCode}');
    print('Headers: ${response.headers}');
    print('Body: ${response.body}');
    print('--- End Response ---');
  }

  // Метод для авторизованных GET запросов
  static Future<http.Response> authenticatedGet(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getAuthHeaders();
    
    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw ApiException('Сессия истекла. Войдите заново.', 401);
      }

      return response;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Метод для авторизованных POST запросов
  static Future<http.Response> authenticatedPost(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getAuthHeaders();

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw ApiException('Сессия истекла. Войдите заново.', 401);
      }
      
      return response;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Метод для авторизованных POST запросов с произвольным телом (список, объект и т.д.)
  static Future<http.Response> authenticatedPostRaw(
    String endpoint,
    dynamic body,
  ) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getAuthHeaders();

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw ApiException('Сессия истекла. Войдите заново.', 401);
      }
      
      return response;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }
  
  // Метод для авторизованных PUT запросов
  static Future<http.Response> authenticatedPut(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getAuthHeaders();
    
    try {
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw ApiException('Сессия истекла. Войдите заново.', 401);
      }
      
      return response;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }
  
  static Future<AuthResponse> register(RegisterRequest request) async {
      final response = await http.post(
      Uri.parse('$baseUrl/api/register/email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );
    _logResponse(response);
      if (response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        return AuthResponse.fromJson(jsonData);
      } else if (response.statusCode == 409) {
      // final errorData = jsonDecode(response.body);
        throw ApiException('Пользователь с таким email уже существует', 409);
      } else if (response.statusCode == 400) {
      // final errorData = jsonDecode(response.body);
      // Добавляем тело ответа для детального логирования
      throw ApiException('Ошибка валидации данных: ${response.body}', 400);
      } else {
        throw ApiException(
        'Произошла ошибка при регистрации. Код: ${response.statusCode}',
          response.statusCode,
        );
    }
  }

  static Future<AuthResponse> login(LoginRequest request) async {
    final url = Uri.parse('$baseUrl/api/login');
    print('--- ApiService.login ---');
    print('URL: $url');
    print('Request Body: ${jsonEncode(request.toJson())}');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return AuthResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw ApiException('Неверный email или пароль', 401);
      } else {
        throw ApiException('Произошла ошибка при входе', response.statusCode);
      }
    } catch (e) {
      print('--- ApiService.login Exception ---');
      print('Exception: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Проверка существования email через попытку регистрации
  // Если email уже существует, сервер вернет 409 Conflict
  static Future<bool> forgotPassword(ForgotPasswordRequest request) async {
    final url = Uri.parse('$baseUrl/api/register/email');

    try {
      // Создаем временный запрос регистрации с минимальными данными
      final tempRegisterRequest = RegisterRequest(
        firstName: 'temp',
        lastName: 'user',
        email: request.email,
        password: 'temp123456',
        city: 'temp',
        skillLevel: 'любитель',
        currentRating: 0,
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(tempRegisterRequest.toJson()),
      );

      if (response.statusCode == 409) {
        // Email уже существует - это то что нам нужно
        return true;
      } else if (response.statusCode == 201) {
        // Пользователь был создан (email не существовал)
        // В реальном приложении здесь нужно будет удалить созданного пользователя
        // или использовать специальный эндпоинт для проверки email
        return false;
      } else {
        // Другие ошибки (400 - валидация и т.д.)
        return false;
      }
    } catch (e) {
      // Ошибка сети
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Проверка доступности email для регистрации
  static Future<EmailAvailabilityResult> checkEmailAvailability(String email) async {
    final url = Uri.parse('$baseUrl/api/email/exists').replace(
      queryParameters: {'email': email},
    );

    // Логируем финальный URL перед отправкой
    print('--- Checking Email URL ---');
    print(url.toString());

    try {
      // Используем GET-запрос без тела
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // Email доступен для регистрации
        return EmailAvailabilityResult(isAvailable: true);
      } else if (response.statusCode == 409) {
        // Email уже зарегистрирован, парсим ответ для получения имени.
        final jsonData = jsonDecode(response.body);
        final detailData = jsonData['detail'];
        final existingUserName = detailData is Map ? detailData['existing_user_name'] : null;

        return EmailAvailabilityResult(
          isAvailable: false,
          existingUserName: existingUserName ?? 'Пользователь',
        );
      } else {
        // Другие ошибки (например, 400 - невалидный email)
        throw ApiException('Ошибка проверки email. Код: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  static Future<EmailAvailabilityResult> checkPhoneAvailability(String phone) async {
    final url = Uri.parse('$baseUrl/api/phone/exists').replace(
      queryParameters: {'phone': phone},
    );

    print('--- Checking Phone URL ---');
    print(url.toString());

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      _logResponse(response);

      if (response.statusCode == 200) {
        // Phone is available
        return EmailAvailabilityResult(isAvailable: true);
      } else if (response.statusCode == 409) {
        // Phone is taken
        final jsonData = jsonDecode(response.body);
        final detailData = jsonData['detail'];
        final existingUserName = detailData is Map ? detailData['existing_user_name'] : null;
        return EmailAvailabilityResult(
          isAvailable: false,
          existingUserName: existingUserName,
        );
      } else {
        throw ApiException('Ошибка проверки номера телефона. Код: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  /// Отправка SMS-кода верификации через MTS Exolve (Telegram Verify)
  static Future<void> sendSmsVerificationCode(String phone) async {
    final url = Uri.parse('$baseUrl/api/sms/send-code');
    Logger.info('📱 API: Отправка SMS-кода верификации на $phone');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      Logger.info(
        '📱 API: /api/sms/send-code status=${response.statusCode} body=${response.body}',
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        final bool success =
            data is Map<String, dynamic> ? (data['success'] == true) : false;
        if (!success) {
          final String message = data is Map<String, dynamic>
              ? (data['message']?.toString() ??
                  'Не удалось отправить SMS, попробуйте позже')
              : 'Не удалось отправить SMS, попробуйте позже';
          throw ApiException(message, 500);
        }
        return;
      } else {
        final message =
            _extractServerDetail(response, 'Ошибка отправки SMS-кода');
        throw ApiException(message, response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети при отправке SMS: $e', 500);
    }
  }

  /// Проверка SMS-кода верификации через MTS Exolve (Telegram Verify)
  static Future<void> verifySmsCode({
    required String phone,
    required String code,
  }) async {
    final url = Uri.parse('$baseUrl/api/sms/verify-code');
    Logger.info('📱 API: Проверка SMS-кода для $phone');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'code': code}),
      );

      Logger.info(
        '📱 API: /api/sms/verify-code status=${response.statusCode} body=${response.body}',
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        final bool success =
            data is Map<String, dynamic> ? (data['success'] == true) : false;
        if (!success) {
          final String message = data is Map<String, dynamic>
              ? (data['message']?.toString() ?? 'Неверный или истекший код')
              : 'Неверный или истекший код';
          throw ApiException(message, 422);
        }
        return;
      } else if (response.statusCode == 400 || response.statusCode == 422) {
        final message =
            _extractServerDetail(response, 'Неверный или истекший код');
        throw ApiException(message, response.statusCode);
      } else {
        final message =
            _extractServerDetail(response, 'Ошибка проверки SMS-кода');
        throw ApiException(message, response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети при проверке SMS-кода: $e', 500);
    }
  }

  // ========== НОВЫЕ МЕТОДЫ ДЛЯ РАБОТЫ С ТЕЛЕФОНОМ ==========

  // Инициализация регистрации по телефону (отправка SMS)
  static Future<PhoneInitResponse> initPhoneRegistration(
    PhoneInitRequest request,
  ) async {
    // МОКАЕМ ПОКА ЧТО - ЗАКОММЕНТИРОВАТЬ ПРИ РАЗМОКИВАНИИ
    await Future.delayed(
      const Duration(seconds: 1),
    ); // Имитация сетевого запроса
    return PhoneInitResponse(
      success: true,
      message: "SMS код отправлен на указанный номер",
      phone: request.phone,
      expiresIn: 600,
    );

    // РАЗМОКАТЬ КОГДА СЕРВЕР БУДЕТ ГОТОВ:
    /*
    final url = Uri.parse('$baseUrl/api/register/phone/init');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return PhoneInitResponse.fromJson(jsonData);
      } else if (response.statusCode == 400) {
        throw ApiException('Невалидный номер телефона', 400);
      } else if (response.statusCode == 409) {
        throw ApiException('Номер телефона уже зарегистрирован', 409);
      } else {
        throw ApiException('Произошла ошибка при отправке SMS', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети. Проверьте подключение к интернету', 0);
    }
    */
  }

  // Завершение регистрации по телефону (подтверждение SMS кода)
  static Future<AuthResponse> completePhoneRegistration(
    PhoneCompleteRequest request,
  ) async {
    // МОКАЕМ ПОКА ЧТО - ЗАКОММЕНТИРОВАТЬ ПРИ РАЗМОКИВАНИИ
    await Future.delayed(
      const Duration(seconds: 2),
    ); // Имитация сетевого запроса

    // Проверяем демо-код
    if (request.code != '123456') {
      throw ApiException('Неверный SMS код', 422);
    }

    // Возвращаем мокированный ответ
    final mockUser = User(
      id: 'mock-user-id-${DateTime.now().millisecondsSinceEpoch}',
      name: request.name,
      email: '',
      // Пустой email для телефонной регистрации
      phone: request.phone,
      passwordHash: '',
      // Пустой хеш пароля для телефонной регистрации
      city: request.city,
      avatarUrl:
          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(request.name)}&background=random',
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return AuthResponse(
      accessToken:
          'mock-phone-jwt-token-${DateTime.now().millisecondsSinceEpoch}',
      tokenType: 'Bearer',
      expiresIn: 86400,
      user: mockUser,
    );

    // РАЗМОКАТЬ КОГДА СЕРВЕР БУДЕТ ГОТОВ:
    /*
    final url = Uri.parse('$baseUrl/api/register/phone/complete');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        return AuthResponse.fromJson(jsonData);
      } else if (response.statusCode == 400) {
        throw ApiException('Невалидные данные', 400);
      } else if (response.statusCode == 409) {
        throw ApiException('Пользователь с таким номером уже существует', 409);
      } else if (response.statusCode == 422) {
        throw ApiException('Невалидный SMS код', 422);
      } else {
        throw ApiException('Произошла ошибка при регистрации', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети. Проверьте подключение к интернету', 0);
    }
    */
  }

  // Вход по номеру телефона с SMS кодом (новый эндпоинт верификации)
  static Future<AuthResponse> loginWithPhone(PhoneLoginRequest request) async {
    final url = Uri.parse('$baseUrl/api/auth/login/phone/verify');
    Logger.info('📱 API: Верификация входа по телефону: ${request.phone}');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );
      Logger.info('📱 API: verify status=${response.statusCode} body=${response.body}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return AuthResponse.fromJson(jsonData);
      } else if (response.statusCode == 400) {
        final jsonData = jsonDecode(response.body);
        throw ApiException(jsonData['detail'] ?? 'Невалидные данные', 400);
      } else if (response.statusCode == 401) {
        final jsonData = jsonDecode(response.body);
        final detail = jsonData['detail'] ?? 'Пользователь заблокирован';
        throw ApiException(detail, 401);
      } else if (response.statusCode == 403) {
        throw ApiException('Неверный код', 403);
      } else if (response.statusCode == 404) {
        throw ApiException('Пользователь не найден', 404);
      } else {
        throw ApiException('Ошибка авторизации: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Новый метод для инициализации входа по телефону (отправка SMS)
  static Future<PhoneInitResponse> initPhoneLogin(
    PhoneInitRequest request,
  ) async {
    final url = Uri.parse('$baseUrl/api/auth/login/phone/init');
    Logger.info('📱 API: Инициализация входа по телефону для ${request.phone}');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );
      Logger.info('📱 API: init status=${response.statusCode} body=${response.body}');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final initResp = EmailLoginInitResponse.fromJson(jsonData);
        return PhoneInitResponse(
          success: initResp.success,
          message: initResp.message ?? 'Код отправлен',
          phone: request.phone,
          expiresIn: initResp.expiresIn ?? 600,
        );
      } else if (response.statusCode == 400) {
        final jsonData = jsonDecode(response.body);
        throw ApiException(jsonData['detail'] ?? 'Невалидные данные', 400);
      } else if (response.statusCode == 401) {
        final jsonData = jsonDecode(response.body);
        throw ApiException(jsonData['detail'] ?? 'Пользователь заблокирован', 401);
      } else if (response.statusCode == 404) {
        throw ApiException('Пользователь не найден', 404);
      } else {
        throw ApiException('Ошибка отправки SMS: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // ========== КОНЕЦ НОВЫХ МЕТОДОВ ==========

  // ==================== EMAIL REGISTRATION CONFIRMATION ====================

  // Инициализация подтверждения email при регистрации (отправка кода)
  static Future<EmailLoginInitResponse> emailRegisterInit(String email) async {
    final url = Uri.parse('$baseUrl/api/auth/register/email/init');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      _logResponse(response);
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return EmailLoginInitResponse.fromJson(jsonData);
      } else if (response.statusCode == 400 || response.statusCode == 409) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Ошибка инициализации подтверждения email', response.statusCode);
      } else {
        throw ApiException('Произошла ошибка', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Подтверждение email кода при регистрации
  static Future<void> emailRegisterVerify(String email, String code) async {
    final url = Uri.parse('$baseUrl/api/auth/register/email/verify');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );
      _logResponse(response);
      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 400 || response.statusCode == 422) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Ошибка верификации кода', response.statusCode);
      } else {
        throw ApiException('Произошла ошибка', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение профиля пользователя (новый эндпоинт)
  // Теперь UserProfile содержит поля upcomingMatches, pastMatches, totalUpcomingMatches, totalPastMatches
  // для отображения ближайших и прошедших матчей на главном экране
  static Future<UserProfile> getProfile() async {
    const endpoint = '/api/profile';
    Logger.apiRequest(endpoint, null);
    final response = await authenticatedGet(endpoint);
    Logger.apiResponse(endpoint, response.statusCode, response.body);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return UserProfile.fromJson(jsonData);
    } else {
      throw ApiException('Ошибка получения профиля', response.statusCode);
    }
  }

  // Получение профиля пользователя по ID
  static Future<UserProfile> getUserProfileById(String userId) async {
    final endpoint = '/api/users/$userId/profile';
    Logger.apiRequest(endpoint, null);

    final response = await authenticatedGet(endpoint);

    Logger.apiResponse(endpoint, response.statusCode, response.body);
    
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      Logger.success('Успешно загружен профиль для userID: $userId');
      return UserProfile.fromJson(jsonData);
    } else if (response.statusCode == 404) {
      Logger.error('Профиль не найден для userID: $userId', null, StackTrace.current);
      throw ApiException('Пользователь не найден', 404);
    } else {
      Logger.error('Ошибка получения профиля для userID: $userId', null, StackTrace.current);
      throw ApiException('Ошибка получения профиля пользователя', response.statusCode);
    }
  }
  
  // Получение профиля текущего пользователя (старый метод)
  static Future<User> getUserProfile() async {
    final response = await authenticatedGet('/api/user/profile');

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return User.fromJson(jsonData);
    } else {
      throw ApiException('Ошибка получения профиля', response.statusCode);
    }
  }

  // Обновление профиля пользователя
  static Future<void> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await authenticatedPut('/api/profile', profileData);

      if (response.statusCode == 200) {
        // Профиль успешно обновлен
      } else {
        throw ApiException('Ошибка обновления профиля', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение списка друзей
  static Future<FriendsApiResponse> getFriends() async {
    final response = await authenticatedGet('/api/friends');

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return FriendsApiResponse.fromJson(jsonData);
    } else {
      throw ApiException('Ошибка получения списка друзей', response.statusCode);
    }
  }

  // Отправка заявки в друзья
  static Future<FriendActionResponse> sendFriendRequest(String userId) async {
    final response = await authenticatedPost('/api/friends/$userId/request', {});
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonData = jsonDecode(response.body);
      return FriendActionResponse.fromJson(jsonData);
    } else if (response.statusCode == 400) {
      throw ApiException('Нельзя отправить заявку самому себе', 400);
    } else if (response.statusCode == 404) {
      throw ApiException('Пользователь не найден', 404);
    } else if (response.statusCode == 409) {
      throw ApiException('Заявка уже отправлена', 409);
    } else {
      throw ApiException('Ошибка отправки заявки в друзья', response.statusCode);
    }
  }

  // Получение входящих заявок в друзья
  static Future<FriendRequestsResponse> getFriendRequests() async {
    final response = await authenticatedGet('/api/friends/requests');
    
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return FriendRequestsResponse.fromJson(jsonData);
    } else {
      throw ApiException('Ошибка получения заявок в друзья', response.statusCode);
    }
  }

  // Принятие заявки в друзья
  static Future<FriendActionResponse> acceptFriendRequest(String userId) async {
    final response = await authenticatedPost('/api/friends/$userId/accept', {});
    
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return FriendActionResponse.fromJson(jsonData);
    } else if (response.statusCode == 404) {
      throw ApiException('Заявка не найдена', 404);
    } else {
      throw ApiException('Ошибка принятия заявки', response.statusCode);
    }
  }

  // Отклонение заявки в друзья
  static Future<FriendActionResponse> rejectFriendRequest(String userId) async {
    final response = await authenticatedPost('/api/friends/$userId/reject', {});
    
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return FriendActionResponse.fromJson(jsonData);
    } else if (response.statusCode == 404) {
      throw ApiException('Заявка не найдена', 404);
    } else {
      throw ApiException('Ошибка отклонения заявки', response.statusCode);
    }
  }

  // Удаление друга
  static Future<FriendActionResponse> removeFriend(String userId) async {
    final url = Uri.parse('$baseUrl/api/friends/$userId');
    final headers = await _getAuthHeaders();
    
    try {
      final response = await http.delete(url, headers: headers);
      
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw ApiException('Сессия истекла. Войдите заново.', 401);
      }
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return FriendActionResponse.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        throw ApiException('Друг не найден', 404);
      } else {
        throw ApiException('Ошибка удаления друга', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение уведомлений
  static Future<NotificationsResponse> getNotifications() async {
    final response = await authenticatedGet('/api/notifications');
    
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return NotificationsResponse.fromJson(jsonData);
    } else {
      throw ApiException('Ошибка получения уведомлений', response.statusCode);
    }
  }

  // ===== V2 уведомлений =====
  // Новый формат уведомлений NotificationResponseV2
  static Future<NotificationsResponseV2> getNotificationsV2() async {
    final response = await authenticatedGet('/api/notifications');
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return NotificationsResponseV2.fromJson(jsonData);
    } else {
      throw ApiException('Ошибка получения уведомлений', response.statusCode);
    }
  }

  // Пометить одно уведомление прочитанным (V2)
  static Future<void> markNotificationReadV2(String notificationId) async {
    final response = await authenticatedPost('/api/notification/$notificationId/read', {});
    if (response.statusCode == 200) {
      return;
    } else {
      throw ApiException('Ошибка пометки уведомления как прочитанного', response.statusCode);
    }
  }

  // Пометить все уведомления прочитанными (опц. до даты before)
  static Future<void> markAllNotificationsReadV2({DateTime? before}) async {
    final body = <String, dynamic>{};
    if (before != null) {
      body['before'] = before.toIso8601String();
    }
    final response = await authenticatedPost('/api/notification/read_all', body);
    if (response.statusCode == 200) {
      return;
    } else {
      throw ApiException('Ошибка массовой пометки уведомлений', response.statusCode);
    }
  }

  // Поиск пользователей
  static Future<SearchUsersResponse> searchUsers(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final response = await authenticatedGet('/api/users/search?q=$encodedQuery');
    
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return SearchUsersResponse.fromJson(jsonData);
    } else {
      throw ApiException('Ошибка поиска пользователей', response.statusCode);
    }
  }

  // Загрузить список пользователей без фильтра (например, для пустого запроса)
  static Future<SearchUsersResponse> listUsers({int limit = 100, int offset = 0}) async {
    final response = await authenticatedGet('/api/users/search?limit=$limit&offset=$offset');
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return SearchUsersResponse.fromJson(jsonData);
    } else {
      throw ApiException('Ошибка загрузки списка пользователей', response.statusCode);
    }
  }

  // Метод для загрузки аватара
  static Future<void> uploadAvatar(File imageFile) async {
    final url = Uri.parse('$baseUrl/api/user/update-avatar');
    final token = await AuthStorage.getToken();

    if (token == null) {
      throw ApiException('Требуется авторизация', 401);
    }

    try {
      // Создаем multipart request
      final request = http.MultipartRequest('PUT', url);
      request.headers['Authorization'] = 'Bearer $token';

      // Определяем MIME тип файла
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      final mimeTypeData = mimeType.split('/');

      // Добавляем файл к запросу
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
        ),
      );

      // Отправляем запрос
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print(response.statusCode);
      print(response.body);
      print(response.headers);

      if (response.statusCode == 401) {
        await AuthStorage.clearAuthData();
        throw ApiException('Токен недействителен', 401);
      }

      if (response.statusCode != 200) {
        throw ApiException('Ошибка загрузки аватара', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  /// Генерирует дефолтный аватар для текущего пользователя, если он отсутствует.
  /// Возвращает URL аватара (существующий или вновь сгенерированный).
  static Future<String?> generateAvatarIfMissing() async {
    final response = await authenticatedPost('/api/profile/generate-avatar', {});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['avatar_url'] as String?;
    } else if (response.statusCode == 401) {
      // При невалидном токене очищаем локальные данные
      await AuthStorage.clearAuthData();
      throw ApiException('Необходимо войти в систему', 401);
    } else if (response.statusCode == 404) {
      throw ApiException('Пользователь не найден', 404);
    } else {
      throw ApiException('Не удалось сгенерировать аватар', response.statusCode);
    }
  }

  // Методы для сброса пароля
  static Future<void> changePassword(String oldPassword, String newPassword) async {
    final response = await authenticatedPost('/api/password/change', {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
    
    if (response.statusCode == 200) {
      // Пароль успешно изменен
      return;
    } else if (response.statusCode == 400) {
      final errorData = jsonDecode(response.body);
      throw ApiException(errorData['detail'] ?? 'Неверный старый пароль', 400);
    } else if (response.statusCode == 401) {
      final errorData = jsonDecode(response.body);
      final detail = errorData['detail'] ?? 'Ошибка авторизации';
      if (detail == 'User is blocked') {
        throw ApiException('Пользователь заблокирован', 401);
      } else {
        throw ApiException('Недействительный токен авторизации', 401);
      }
    } else if (response.statusCode == 404) {
      throw ApiException('Пользователь не найден', 404);
    } else {
      throw ApiException('Ошибка смены пароля', response.statusCode);
    }
  }

  static Future<void> initResetPassword(String email) async {
    final url = Uri.parse('$baseUrl/api/password/reset/init');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      
      if (response.statusCode == 200) {
        // Успешно отправлен код для сброса пароля
        return;
      } else if (response.statusCode == 404) {
        throw ApiException('Пользователь с таким email не найден', 404);
      } else {
        throw ApiException('Ошибка отправки кода для сброса пароля', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  static Future<bool> checkResetPasswordCode(String email, String code) async {
    final url = Uri.parse('$baseUrl/api/password/reset/check');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );
      
      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 400) {
        throw ApiException('Неверный код подтверждения', 400);
      } else {
        throw ApiException('Ошибка проверки кода', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  static Future<void> confirmResetPassword(String email, String code, String newPassword) async {
    final url = Uri.parse('$baseUrl/api/password/reset/confirm');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
          'new_password': newPassword,
        }),
      );
      
      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 400) {
        throw ApiException('Неверный код подтверждения или пароль', 400);
      } else {
        throw ApiException('Ошибка сброса пароля', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение статуса дружбы с пользователем
  static Future<FriendshipStatusResponse> getFriendshipStatus(String userId) async {
    try {
      final response = await authenticatedGet('/api/friends/$userId/status');
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return FriendshipStatusResponse.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        throw ApiException('Пользователь не найден', 404);
      } else {
        throw ApiException('Ошибка получения статуса дружбы', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // ==================== МЕТОДЫ ДЛЯ РАБОТЫ С МАТЧАМИ ====================

  // Получение списка матчей с фильтрами
  static Future<MatchListResponse> getMatches({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? city,
    String? clubId,
    String? format,
    String? level,
    bool? isPrivate,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final Map<String, String> queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (dateFrom != null) {
      queryParams['date_from'] = dateFrom.toIso8601String();
    }
    if (dateTo != null) {
      queryParams['date_to'] = dateTo.toIso8601String();
    }
    if (city != null) {
      queryParams['city'] = city;
    }
    if (clubId != null) {
      queryParams['club_id'] = clubId;
    }
    if (format != null) {
      queryParams['format'] = format;
    }
    if (level != null) {
      queryParams['level'] = level;
    }
    if (isPrivate != null) {
      queryParams['is_private'] = isPrivate.toString();
    }
    if (status != null) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse('$baseUrl/api/matches').replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(uri, headers: await _getAuthHeaders());
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return MatchListResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw ApiException('Сессия истекла. Войдите заново.', 401);
      } else {
        throw ApiException('Ошибка получения списка матчей', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение моих матчей
  static Future<MyMatchesResponse> getMyMatches() async {
    try {
      final response = await authenticatedGet('/api/matches/my');
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return MyMatchesResponse.fromJson(jsonData);
      } else {
        throw ApiException('Ошибка получения моих матчей', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение приглашений на матчи
  static Future<List<MatchInvitation>> getMatchInvitations() async {
    try {
      final response = await authenticatedGet('/api/matches/invitations');
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return (jsonData as List)
            .map((invitation) => MatchInvitation.fromJson(invitation))
            .toList();
      } else {
        throw ApiException('Ошибка получения приглашений на матчи', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение деталей матча
  static Future<Match> getMatchDetails(String matchId) async {
    try {
      final response = await authenticatedGet('/api/matches/$matchId');
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return Match.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка получения деталей матча', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Создание матча
  static Future<Match> createMatch(MatchCreate matchCreate) async {
    try {
      final response = await authenticatedPost('/api/matches', matchCreate.toJson());
      
      if (response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        final matchId = jsonData['id'] as String;
        
        // Запрашиваем полную информацию о созданном матче
        final match = await getMatchDetails(matchId);
        
        return match;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Ошибка валидации данных', 400);
      } else {
        throw ApiException('Ошибка создания матча', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Обновление матча
  static Future<Match> updateMatch(String matchId, MatchUpdate matchUpdate) async {
    try {
      final response = await authenticatedPut('/api/matches/$matchId', matchUpdate.toJson());
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return Match.fromJson(jsonData);
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Ошибка валидации данных', 400);
      } else if (response.statusCode == 403) {
        throw ApiException('Нет прав для редактирования этого матча', 403);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка обновления матча', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Начало матча
  static Future<Match> startMatch(String matchId) async {
    try {
      final response = await authenticatedPost('/api/matches/$matchId/start', {});

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        // Ответ содержит {"message": "...", "match": {...}}
        if (jsonData['match'] != null) {
          return Match.fromJson(jsonData['match']);
        }
        // Если match не в ответе, запросим детали
        return await getMatchDetails(matchId);
      } else {
        // Для всех ошибок используем detail из ответа backend
        final errorData = jsonDecode(response.body);
        throw ApiException(
          errorData['detail'] ?? 'Ошибка при начале матча',
          response.statusCode
        );
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Завершение матча
  static Future<Match> finishMatch(
    String matchId, {
    required String score,
    String? winnerTeamId, // 'A' | 'B' для парных матчей
    String? winnerUserId, // uuid победителя для одиночных матчей
    required int matchDuration,
    bool isDraw = false,
    String? notes,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'score': score,
        'winner_team_id': winnerTeamId,
        'winner_user_id': winnerUserId,
        'is_draw': isDraw,
        'match_duration': matchDuration,
        'notes': notes,
      };

      final response = await authenticatedPost('/api/matches/$matchId/finish', body);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return Match.fromJson(jsonData);
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Ошибка валидации данных при завершении матча', 400);
      } else if (response.statusCode == 403) {
        throw ApiException('Нет прав для завершения этого матча', 403);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка завершения матча', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Сохранение черновика счёта (draft-score)
  static Future<void> saveDraftScore(
    String matchId, {
    required String draftScore,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'draft_score': draftScore,
      };

      final response = await authenticatedPut('/api/matches/$matchId/draft-score', body);

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Ошибка валидации данных черновика счёта', 400);
      } else if (response.statusCode == 403) {
        throw ApiException('Нет прав для сохранения черновика счёта', 403);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка сохранения черновика счёта', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение черновика счёта текущего пользователя
  static Future<String?> getMyDraftScore(String matchId) async {
    try {
      final response = await authenticatedGet('/api/matches/$matchId/my-draft-score');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final draft = jsonData['draft_score'];
        if (draft == null) return null;
        if (draft is String && draft.trim().isEmpty) return null;
        return draft as String?;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Ошибка получения черновика счёта', 400);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка получения черновика счёта', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение черновика счёта от host
  static Future<String?> getHostDraftScore(String matchId) async {
    try {
      final response = await authenticatedGet('/api/matches/$matchId/host-draft-score');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final draft = jsonData['draft_score'];
        if (draft == null) return null;
        if (draft is String && draft.trim().isEmpty) return null;
        return draft as String?;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Ошибка получения черновика host', 400);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка получения черновика host', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Завершение матча как host (организатор)
  static Future<Map<String, dynamic>> finishMatchAsHost(
    String matchId, {
    required String score,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'draft_score': score,
      };

      final response = await authenticatedPost('/api/matches/$matchId/finish-as-host', body);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        // Ответ содержит информацию о статусе подтверждения
        return jsonData;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Ошибка валидации данных при завершении матча', 400);
      } else if (response.statusCode == 403) {
        throw ApiException('Нет прав для завершения этого матча как host', 403);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка завершения матча', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Проверка прав организатора на редактирование результата
  static Future<Map<String, dynamic>> organizerCanEdit(String matchId) async {
    try {
      final response = await authenticatedGet('/api/matches/$matchId/organizer-can-edit');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return jsonData;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Ошибка проверки прав редактирования', 400);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка проверки прав редактирования', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Редактирование результата организатором (обновляет draft_score организатора)
  static Future<void> organizerEditResult(
    String matchId, {
    required String score,
  }) async {
    try {
      final body = { 'score': score };
      final response = await authenticatedPut('/api/matches/$matchId/edit-result', body);
      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Ошибка редактирования результата', 400);
      } else if (response.statusCode == 403) {
        throw ApiException('Нет прав для редактирования результата', 403);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка редактирования результата', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Подтверждение счёта от host
  static Future<void> confirmHostScore(String matchId) async {
    try {
      Logger.info('🔵 Отправка подтверждения счёта для матча: $matchId');
      final response = await authenticatedPost('/api/matches/$matchId/confirm-score', {
        'action': 'accept',
      });

      Logger.info('🔵 Ответ сервера: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        Logger.success('✅ Счёт успешно подтверждён');
        return;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        Logger.error('❌ Ошибка 400: ${errorData['detail']}');
        throw ApiException(errorData['detail'] ?? 'Ошибка подтверждения счёта', 400);
      } else if (response.statusCode == 403) {
        Logger.error('❌ Ошибка 403: Нет прав');
        throw ApiException('Нет прав для подтверждения счёта', 403);
      } else if (response.statusCode == 404) {
        Logger.error('❌ Ошибка 404: Матч не найден');
        throw ApiException('Матч не найден', 404);
      } else {
        Logger.error('❌ Ошибка ${response.statusCode}: ${response.body}');
        throw ApiException('Ошибка подтверждения счёта', response.statusCode);
      }
    } catch (e) {
      Logger.error('❌ Исключение при подтверждении счёта', e);
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Оспаривание счёта от host
  static Future<void> disputeHostScore(
    String matchId, {
    required String score,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'action': 'dispute',
        'dispute_score': score,
      };

      final response = await authenticatedPost('/api/matches/$matchId/confirm-score', body);

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Ошибка оспаривания счёта', 400);
      } else if (response.statusCode == 403) {
        throw ApiException('Нет прав для оспаривания счёта', 403);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка оспаривания счёта', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Отмена матча
  static Future<void> deleteMatch(String matchId) async {
    final url = Uri.parse('$baseUrl/api/matches/$matchId');
    final headers = await _getAuthHeaders();

    try {
      final response = await http.delete(url, headers: headers);
      
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw ApiException('Сессия истекла. Войдите заново.', 401);
      }
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else if (response.statusCode == 403) {
        throw ApiException('Нет прав для отмены этого матча', 403);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка отмены матча', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Оценка игроков после матча
  static Future<void> reviewPlayers(String matchId, List<Map<String, dynamic>> reviews) async {
    final url = Uri.parse('$baseUrl/api/matches/$matchId/review');
    final headers = await _getAuthHeaders();

    try {
      final response = await http.post(
        url, 
        headers: headers,
        body: jsonEncode({'reviews': reviews}),
      );
      
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw ApiException('Сессия истекла. Войдите заново.', 401);
      }
      
      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        final detail = data['detail'] ?? 'Неверные данные';
        throw ApiException(detail, 400);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка при отправке оценок', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Присоединение к матчу
  static Future<void> joinMatch(String matchId, {String? message, String? teamId}) async {
    try {
      final request = MatchJoinRequest(message: message, teamId: teamId);
      
      final response = await authenticatedPost('/api/matches/$matchId/join', request.toJson());
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Нельзя присоединиться к этому матчу', 400);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка присоединения к матчу', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Выход из матча
  static Future<void> leaveMatch(String matchId) async {
    try {
      final response = await authenticatedPost('/api/matches/$matchId/leave', {});
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Нельзя покинуть этот матч', 400);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка выхода из матча', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Принятие приглашения в приватный матч
  static Future<void> acceptMatchInvitation(String matchId) async {
    try {
      final response = await authenticatedPost('/api/matches/$matchId/accept', {});
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Нельзя принять это приглашение', 400);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка принятия приглашения', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Отклонение приглашения в приватный матч
  static Future<void> rejectMatchInvitation(String matchId) async {
    try {
      final response = await authenticatedPost('/api/matches/$matchId/reject', {});
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Нельзя отклонить это приглашение', 400);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч не найден', 404);
      } else {
        throw ApiException('Ошибка отклонения приглашения', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Приглашение пользователя в матч (только организатором)
  static Future<void> inviteUserToMatch(String matchId, String userId, {String? message}) async {
    try {
      final request = MatchInviteRequest(userId: userId, message: message);
      final response = await authenticatedPost('/api/matches/$matchId/invite', request.toJson());
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Нельзя пригласить этого пользователя', 400);
      } else if (response.statusCode == 403) {
        throw ApiException('Только организатор может приглашать пользователей', 403);
      } else if (response.statusCode == 404) {
        throw ApiException('Матч или пользователь не найден', 404);
      } else {
        throw ApiException('Ошибка приглашения пользователя', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение заявок на матч
  static Future<List<MatchRequest>> getMatchRequests(String matchId) async {
    try {
      final response = await authenticatedGet('/api/match-requests/match/$matchId');
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> requestsJson = jsonData['requests'];
        return requestsJson.map((json) => MatchRequest.fromJson(json)).toList();
      } else {
        throw ApiException('Ошибка получения заявок на матч', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Ответ на заявку на матч (принять/отклонить)
  static Future<void> respondToMatchRequest(String requestId, String status) async {
    // status может быть 'approved' или 'declined'
    try {
      final response = await authenticatedPost(
        '/api/match-requests/$requestId/respond',
        {
          'request_id': requestId,
          'status': status,
        },
      );
      
      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Невозможно ответить на эту заявку', 400);
      } else if (response.statusCode == 404) {
        throw ApiException('Заявка не найдена', 404);
      } else {
        throw ApiException('Ошибка при ответе на заявку', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Создание заявки на участие в матче
  static Future<void> createMatchRequest(String matchId, {String? message, String? preferredTeamId}) async {
    try {
      final requestBody = {
        'match_id': matchId,
        'message': message ?? 'Привет! Хочу присоединиться к вашему матчу.',
      };
      
      if (preferredTeamId != null) {
        requestBody['preferred_team_id'] = preferredTeamId;
      }
      
      final response = await authenticatedPost('/api/match-requests', requestBody);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw ApiException(errorData['detail'] ?? 'Нельзя отправить заявку на этот матч', 400);
      } else if (response.statusCode == 409) {
        throw ApiException('Заявка уже отправлена', 409);
      } else {
        throw ApiException('Ошибка создания заявки', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // ==================== НОВЫЕ МЕТОДЫ ДЛЯ КЛУБОВ ====================

  // Получение списка клубов
  static Future<ClubsResponse> getClubs() async {
    try {
      final response = await authenticatedGet('/api/clubs');
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return ClubsResponse.fromJson(jsonData);
      } else {
        throw ApiException('Ошибка получения списка клубов', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение списка городов
  static Future<CitiesResponse> getCities() async {
    try {
      final response = await authenticatedGet('/cities/');
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return CitiesResponse.fromJson(jsonData);
      } else {
        throw ApiException('Ошибка получения списка городов', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение клубов по городу
  static Future<ClubsByCityResponse> getClubsByCity(String city) async {
    try {
      final encodedCity = Uri.encodeComponent(city);
      final response = await authenticatedGet('/api/clubs?city=$encodedCity');

      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(response.body);
          final result = ClubsByCityResponse.fromJson(jsonData);
          return result;
        } catch (parseError) {
          throw ApiException('Failed to parse response: $parseError', 500);
        }
      } else {
        throw ApiException('HTTP ${response.statusCode}: ${response.body}', response.statusCode);
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Error getting clubs: $e', 500);
    }
  }

  // Новый метод поиска матчей с расширенными фильтрами
  static Future<MatchSearchResponse> searchMatches(MatchSearchRequest request) async {
    try {
      final response = await authenticatedPost('/api/matches/search', request.toJson());

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final matches = (jsonResponse['matches'] as List)
            .map((match) => Map<String, dynamic>.from(match))
            .toList();

        final List<Match> matchObjects = matches.map((match) {
          final participants = (match['participants'] as List?)
              ?.cast<Map<String, dynamic>>() ?? [];

          return Match.fromJson({
            ...match,
            'participants': participants,
          });
        }).toList();

        return MatchSearchResponse(
          matches: matchObjects,
          totalCount: jsonResponse['total_count'] ?? 0,
          filtersApplied: jsonResponse['filters_applied'] ?? {},
        );
      } else {
        throw ApiException('Failed to search matches: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      throw ApiException('Error searching matches: $e', 500);
    }
  }

  // Получение текущего рейтинга пользователя
  static Future<UserRatingResponse?> getCurrentUserRating() async {
    final response = await authenticatedGet('/api/ratings/current');
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return UserRatingResponse.fromJson(jsonData);
    } else if (response.statusCode == 404) {
      // Рейтинг не найден
      return null;
    } else {
      throw ApiException('Ошибка получения рейтинга', response.statusCode);
    }
  }

  static Future<InitializeRatingResponse> initializeUserRating(String ntrpLevel) async {
    final url = Uri.parse('$baseUrl/api/ratings/initialize');
    final token = await AuthStorage.getToken();
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'ntrp_level': ntrpLevel,
      }),
    );
    if (response.statusCode == 201) {
      return InitializeRatingResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Ошибка инициализации рейтинга: ${response.body}');
    }
  }

  // Повторная инициализация рейтинга
  static Future<InitializeRatingResponse> reinitializeUserRating(String ntrpLevel) async {
    final url = Uri.parse('$baseUrl/api/ratings/reinitialize');
    final token = await AuthStorage.getToken();
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'ntrp_level': ntrpLevel,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return InitializeRatingResponse.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      await AuthStorage.clearAuthData();
      throw ApiException('Токен недействителен', 401);
    } else {
      throw Exception('Ошибка повторной инициализации рейтинга: ${response.body}');
    }
  }

  // ====== ЯНДЕКС OAUTH ======
  static Future<UserYandexCallbackResponse> yandexCallback(String oauthToken) async {
    final url = Uri.parse('$baseUrl/api/auth/yandex/callback');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'oauth_token': oauthToken}),
    );
    print('Ответ сервера (status \\${response.statusCode}): \\${response.body}');
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return UserYandexCallbackResponse.fromJson(jsonData);
    } else {
      String errorMsg = 'Ошибка авторизации через Яндекс';
      try {
        final json = jsonDecode(response.body);
        if (response.statusCode == 400) {
          errorMsg = json['detail'] ?? 'Некорректные данные';
        } else if (response.statusCode == 401) {
          errorMsg = json['detail'] ?? 'Пользователь заблокирован или неверный токен';
        } else if (response.statusCode == 403) {
          errorMsg = json['detail'] ?? 'Недействительный OAuth токен';
        } else if (response.statusCode == 503) {
          errorMsg = 'Сервис Яндекса временно недоступен. Попробуйте позже.';
        }
      } catch (_) {
        // Если не удалось распарсить json, оставляем стандартное сообщение
      }
      throw ApiException(errorMsg, response.statusCode);
    }
  }

  static Future<AuthResponse> yandexRegister(String oauthToken, String city, int rating) async {
    final url = Uri.parse('$baseUrl/api/auth/yandex/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'oauth_token': oauthToken,
        'city': city,
        'current_rating': rating,
        'skill_level': 'начинающий',
      }),
    );
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return AuthResponse.fromJson(jsonData);
    } else {
      String errorMsg = 'Ошибка регистрации через Яндекс';
      try {
        final json = jsonDecode(response.body);
        if (response.statusCode == 400) {
          errorMsg = json['detail'] ?? 'Некорректные данные';
        } else if (response.statusCode == 401) {
          errorMsg = json['detail'] ?? 'Пользователь заблокирован или неверный токен';
        } else if (response.statusCode == 403) {
          errorMsg = json['detail'] ?? 'Недействительный OAuth токен';
        } else if (response.statusCode == 503) {
          errorMsg = 'Сервис Яндекса временно недоступен. Попробуйте позже.';
        }
      } catch (_) {
        // Если не удалось распарсить json, оставляем стандартное сообщение
      }
      throw ApiException(errorMsg, response.statusCode);
    }
  }

  static Future<AuthResponse> completeYandexRegistration({
    required String oauthToken,
    required String city,
    required int currentRating,
    String? preferredHand,
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
        'skill_level': 'профессионал', // Устанавливаем по результатам теста
      }),
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return AuthResponse.fromJson(jsonData);
    } else {
      String errorMsg = 'Ошибка регистрации через Яндекс';
      try {
        final json = jsonDecode(response.body);
        if (response.statusCode == 400) {
          errorMsg = json['detail'] ?? 'Некорректные данные';
        } else if (response.statusCode == 401) {
          errorMsg = json['detail'] ?? 'Пользователь заблокирован или неверный токен';
        } else if (response.statusCode == 403) {
          errorMsg = json['detail'] ?? 'Недействительный OAuth токен';
        } else if (response.statusCode == 503) {
          errorMsg = 'Сервис Яндекса временно недоступен. Попробуйте позже.';
        }
      } catch (_) {
        // Если не удалось распарсить json, оставляем стандартное сообщение
      }
      throw ApiException(errorMsg, response.statusCode);
    }
  }

  // ====== VK OAUTH ======
  static Future<UserVkCallbackResponse> vkCallback(String accessToken) async {
    final url = Uri.parse('$baseUrl/api/auth/vk/callback');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'access_token': accessToken}),
    );
    print('VK callback (status ${response.statusCode}): ${response.body}');
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return UserVkCallbackResponse.fromJson(jsonData);
    } else {
      String errorMsg = 'Ошибка авторизации через VK';
      try {
        final json = jsonDecode(response.body);
        errorMsg = json['detail'] ?? errorMsg;
      } catch (_) {}
      throw ApiException(errorMsg, response.statusCode);
    }
  }

  // Новый метод: проверка пользователя по email/phone
  static Future<UserVkCallbackResponse> vkCallbackByContacts({
    String? email,
    String? phone,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/vk/callback');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'phone': phone}),
    );
    print('VK callback (contacts) status ${response.statusCode}: ${response.body}');
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return UserVkCallbackResponse.fromJson(jsonData);
    } else {
      String errorMsg = 'Ошибка авторизации через VK (contacts)';
      try {
        final json = jsonDecode(response.body);
        errorMsg = json['detail'] ?? errorMsg;
      } catch (_) {}
      throw ApiException(errorMsg, response.statusCode);
    }
  }

  static Future<AuthResponse> vkRegister(String accessToken, String city, int rating, {String? preferredHand}) async {
    final url = Uri.parse('$baseUrl/api/auth/vk/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'access_token': accessToken,
        'city': city,
        'current_rating': rating,
        'preferred_hand': preferredHand,
        'skill_level': 'профессионал',
      }),
    );
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return AuthResponse.fromJson(jsonData);
    } else {
      String errorMsg = 'Ошибка регистрации через VK';
      try {
        final json = jsonDecode(response.body);
        errorMsg = json['detail'] ?? errorMsg;
      } catch (_) {}
      throw ApiException(errorMsg, response.statusCode);
    }
  }

  static Future<AuthResponse> completeVkRegistrationWithCode({
    required String code,
    required String redirectUri,
    required String city,
    required int currentRating,
    String? preferredHand,
    required String codeVerifier,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/vk/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': codeVerifier,
        'city': city,
        'current_rating': currentRating,
        'preferred_hand': preferredHand,
        'skill_level': 'профессионал',
      }),
    );
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return AuthResponse.fromJson(jsonData);
    } else {
      String errorMsg = 'Ошибка регистрации через VK (code)';
      try {
        final json = jsonDecode(response.body);
        errorMsg = json['detail'] ?? errorMsg;
      } catch (_) {}
      throw ApiException(errorMsg, response.statusCode);
    }
  }

  static Future<AuthResponse> completeVkRegistration({
    required String accessToken,
    required String city,
    required int currentRating,
    String? preferredHand,
  }) async {
    return vkRegister(accessToken, city, currentRating, preferredHand: preferredHand);
  }

  // Новый метод для серверного обмена c PKCE
  static Future<UserVkCallbackResponse> vkCallbackWithCodePkce({
    required String code,
    required String redirectUri,
    required String codeVerifier,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/vk/callback-code');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': codeVerifier,
      }),
    );
    print('VK callback (code+pkce) status ${response.statusCode}: ${response.body}');
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return UserVkCallbackResponse.fromJson(jsonData);
    } else {
      String errorMsg = 'Ошибка авторизации через VK (code+pkce)';
      try {
        final json = jsonDecode(response.body);
        errorMsg = json['detail'] ?? errorMsg;
      } catch (_) {}
      throw ApiException(errorMsg, response.statusCode);
    }
  }

  // ==================== МЕТОДЫ ДЛЯ РАБОТЫ С БРОНИРОВАНИЯМИ ====================

  // Создание нового бронирования
  static Future<Booking> createBooking(BookingCreate bookingData) async {
    try {
      Logger.apiRequest('/api/bookings', bookingData.toJson());
      
      final response = await authenticatedPost('/api/bookings', bookingData.toJson());
      
      Logger.apiResponse('/api/bookings', response.statusCode, response.body);
      
      if (response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        final booking = Booking.fromJson(jsonData);
        Logger.bookingSuccess('Создание бронирования', booking.id);
        return booking;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? 'Некорректные данные бронирования';
        Logger.apiError('/api/bookings', response.statusCode, errorMessage);
        throw ApiException(errorMessage, 400);
      } else if (response.statusCode == 401) {
        Logger.apiError('/api/bookings', response.statusCode, 'Необходима авторизация');
        throw ApiException('Необходима авторизация', 401);
      } else if (response.statusCode == 500) {
        final errorData = jsonDecode(response.body);
        final detail = errorData['detail'] ?? '';
        
        // Специальная обработка ошибки "cannot be in the past"
        if (detail.contains('cannot be in the past') || detail.contains('в прошлом')) {
          Logger.apiError('/api/bookings', response.statusCode, 'Попытка создания бронирования в прошлом');
          throw ApiException('Нельзя создать бронирование в прошлом', 500);
        }
        
        // Специальная обработка ошибки дублирования бронирования
        if (detail.contains('duplicate key value violates unique constraint') || 
            detail.contains('idx_bookings_no_overlap') ||
            detail.contains('already exists')) {
          Logger.apiError('/api/bookings', response.statusCode, 'Попытка создания дублирующего бронирования');
          throw ApiException('Этот период времени уже забронирован', 500);
        }
        
        Logger.apiError('/api/bookings', response.statusCode, detail);
        throw ApiException(detail, 500);
      } else {
        Logger.apiError('/api/bookings', response.statusCode, 'Ошибка при создании бронирования');
        throw ApiException('Ошибка при создании бронирования', response.statusCode);
      }
    } catch (e, stackTrace) {
      if (e is ApiException) {
        Logger.bookingError('Создание бронирования', e, stackTrace);
        rethrow;
      }
      Logger.bookingError('Создание бронирования', e, stackTrace);
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Создание нескольких бронирований с одной оплатой (или без оплаты при onlinePayment=false)
  static Future<Map<String, dynamic>> createBookingsBatch(
    List<BookingCreate> bookingsData, {
    bool onlinePayment = true,
  }) async {
    try {
      final List<Map<String, dynamic>> bookingsJson = bookingsData.map((b) => b.toJson()).toList();
      final endpoint = '/api/bookings/batch?online_payment=${onlinePayment ? 'true' : 'false'}';
      Logger.apiRequest(endpoint, {'bookings': bookingsJson});
      
      final response = await authenticatedPostRaw(endpoint, bookingsJson);
      
      Logger.apiResponse(endpoint, response.statusCode, response.body);
      
      if (response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        final List<Booking> bookings = (jsonData['bookings'] as List)
            .map((bookingJson) => Booking.fromJson(bookingJson))
            .toList();
        
        Logger.bookingSuccess('Создание бронирований (batch)', bookings.length.toString());
        
        return {
          'bookings': bookings,
          'payment_url': jsonData['payment_url'],
          'payment_id': jsonData['payment_id'],
          'amount': jsonData['amount']?.toDouble() ?? 0.0,
        };
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? 'Некорректные данные бронирований';
        Logger.apiError(endpoint, response.statusCode, errorMessage);
        throw ApiException(errorMessage, 400);
      } else if (response.statusCode == 401) {
        Logger.apiError(endpoint, response.statusCode, 'Необходима авторизация');
        throw ApiException('Необходима авторизация', 401);
      } else if (response.statusCode == 500) {
        final errorData = jsonDecode(response.body);
        final detail = errorData['detail'] ?? '';
        
        // Специальная обработка ошибки "cannot be in the past"
        if (detail.contains('cannot be in the past') || detail.contains('в прошлом')) {
          Logger.apiError(endpoint, response.statusCode, 'Попытка создания бронирования в прошлом');
          throw ApiException('Нельзя создать бронирование в прошлом', 500);
        }
        
        // Специальная обработка ошибки дублирования бронирования
        if (detail.contains('duplicate key value violates unique constraint') || 
            detail.contains('idx_bookings_no_overlap') ||
            detail.contains('already exists')) {
          Logger.apiError(endpoint, response.statusCode, 'Попытка создания дублирующего бронирования');
          throw ApiException('Этот период времени уже забронирован', 500);
        }
        
        Logger.apiError(endpoint, response.statusCode, detail);
        throw ApiException(detail, 500);
      } else {
        Logger.apiError(endpoint, response.statusCode, 'Ошибка при создании бронирований');
        throw ApiException('Ошибка при создании бронирований', response.statusCode);
      }
    } catch (e, stackTrace) {
      if (e is ApiException) {
        Logger.bookingError('Создание бронирований (batch)', e, stackTrace);
        rethrow;
      }
      Logger.bookingError('Создание бронирований (batch)', e, stackTrace);
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение бронирования по ID
  static Future<Booking> getBookingById(String bookingId) async {
    try {
      Logger.apiRequest('/api/bookings/$bookingId', {});
      
      final response = await authenticatedGet('/api/bookings/$bookingId');
      
      Logger.apiResponse('/api/bookings/$bookingId', response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final booking = Booking.fromJson(jsonData);
        Logger.info('Получено бронирование: ${booking.id}');
        return booking;
      } else if (response.statusCode == 404) {
        Logger.apiError('/api/bookings/$bookingId', response.statusCode, 'Бронирование не найдено');
        throw ApiException('Бронирование не найдено', 404);
      } else {
        Logger.apiError('/api/bookings/$bookingId', response.statusCode, 'Ошибка при получении бронирования');
        throw ApiException('Ошибка при получении бронирования', response.statusCode);
      }
    } catch (e, stackTrace) {
      if (e is ApiException) {
        Logger.error('Ошибка получения бронирования: $e', stackTrace);
        rethrow;
      }
      Logger.error('Ошибка сети при получении бронирования: $e', stackTrace);
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Отмена бронирования
  static Future<Booking> cancelBooking(BookingCancel bookingData) async {
    try {
      Logger.apiRequest('/api/bookings/cancel', bookingData.toJson());
      
      final response = await authenticatedPost('/api/bookings/cancel', bookingData.toJson());
      
      Logger.apiResponse('/api/bookings/cancel', response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final booking = Booking.fromJson(jsonData);
        Logger.bookingSuccess('Отмена бронирования', booking.id);
        return booking;
      } else if (response.statusCode == 403) {
        Logger.apiError('/api/bookings/cancel', response.statusCode, 'Нет прав для отмены этого бронирования');
        throw ApiException('Нет прав для отмены этого бронирования', 403);
      } else if (response.statusCode == 404) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? 'Бронирование не найдено';
        Logger.apiError('/api/bookings/cancel', response.statusCode, errorMessage);
        throw ApiException(errorMessage, 404);
      } else {
        Logger.apiError('/api/bookings/cancel', response.statusCode, 'Ошибка при отмене бронирования');
        throw ApiException('Ошибка при отмене бронирования', response.statusCode);
      }
    } catch (e, stackTrace) {
      if (e is ApiException) {
        Logger.bookingError('Отмена бронирования', e, stackTrace);
        rethrow;
      }
      Logger.bookingError('Отмена бронирования', e, stackTrace);
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение списка бронирований пользователя
  static Future<List<Booking>> getMyBookings({
    String? clubId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (clubId != null) queryParams['club_id'] = clubId;
      if (status != null) queryParams['status'] = status;
      if (startDate != null) queryParams['start_date'] = startDate.toIso8601String().split('T')[0];
      if (endDate != null) queryParams['end_date'] = endDate.toIso8601String().split('T')[0];
      
      final queryString = queryParams.isNotEmpty 
          ? '?${Uri(queryParameters: queryParams).query}' 
          : '';
      
      Logger.apiRequest('/api/bookings$queryString', queryParams);
      
      final response = await authenticatedGet('/api/bookings$queryString');
      
      Logger.apiResponse('/api/bookings', response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final bookingsList = BookingListResponse.fromJson(jsonData);
        Logger.info('Получено ${bookingsList.bookings.length} бронирований');
        return bookingsList.bookings;
      } else {
        Logger.apiError('/api/bookings', response.statusCode, 'Ошибка при получении бронирований');
        throw ApiException('Ошибка при получении бронирований', response.statusCode);
      }
    } catch (e, stackTrace) {
      if (e is ApiException) {
        Logger.error('Ошибка получения бронирований: $e', stackTrace);
        rethrow;
      }
      Logger.error('Ошибка сети при получении бронирований: $e', stackTrace);
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение списка клубов с фильтрами
  static Future<ClubsResponse> getClubsList({
    String? cityFilter,
    String? nameFilter,
    String? addressFilter,
    String? courtType, // indoor, outdoor, shaded
    String? courtSize, // two-seater, four-seater
    bool includeInactive = false,
    double? userLatitude,
    double? userLongitude,
    double? maxDistanceKm,
    bool sortByDistance = false,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (cityFilter != null) queryParams['city'] = cityFilter;
      if (nameFilter != null) queryParams['name'] = nameFilter;
      if (addressFilter != null) queryParams['address'] = addressFilter;
      if (includeInactive) queryParams['include_inactive'] = 'true';
      if (courtType != null) queryParams['court_type'] = courtType;
      if (courtSize != null) queryParams['court_size'] = courtSize;
      if (userLatitude != null) queryParams['user_latitude'] = userLatitude.toString();
      if (userLongitude != null) queryParams['user_longitude'] = userLongitude.toString();
      if (maxDistanceKm != null) queryParams['max_distance_km'] = maxDistanceKm.toString();
      if (sortByDistance) queryParams['sort_by_distance'] = 'true';

      final queryString = queryParams.isNotEmpty 
          ? '?${Uri(queryParameters: queryParams).query}' 
          : '';
      
      final response = await authenticatedGet('/api/clubs$queryString');
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return ClubsResponse.fromJson(jsonData);
      } else {
        throw ApiException('Ошибка получения списка клубов', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение клуба по ID
  static Future<Club> getClubById(String clubId) async {
    try {
      final response = await authenticatedGet('/api/clubs/$clubId');
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return Club.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        throw ApiException('Клуб не найден', 404);
      } else {
        throw ApiException('Ошибка получения клуба', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // ==================== МЕТОДЫ ДЛЯ РАБОТЫ С КОРТАМИ ====================

  // Получение списка кортов клуба
  static Future<CourtsResponse> getCourts(String clubId) async {
    try {
      Logger.apiRequest('/api/clubs/$clubId/courts', {});
      
      final response = await authenticatedGet('/api/clubs/$clubId/courts');
      
      Logger.apiResponse('/api/clubs/$clubId/courts', response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return CourtsResponse.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        Logger.apiError('/api/clubs/$clubId/courts', response.statusCode, 'Клуб не найден');
        throw ApiException('Клуб не найден', 404);
      } else {
        Logger.apiError('/api/clubs/$clubId/courts', response.statusCode, 'Ошибка получения кортов');
        throw ApiException('Ошибка получения кортов', response.statusCode);
      }
    } catch (e, stackTrace) {
      if (e is ApiException) {
        Logger.apiError('/api/clubs/$clubId/courts', 500, e.toString());
        rethrow;
      }
      Logger.apiError('/api/clubs/$clubId/courts', 500, e.toString());
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Проверка доступности кортов для бронирования
  static Future<Map<String, dynamic>> checkBookingAvailability({
    required String clubId,
    required String bookingDate,
    required String startTime,
    required int durationMin,
  }) async {
    try {
      final queryParams = {
        'booking_date': bookingDate,
        'start_time': startTime,
        'duration_min': durationMin.toString(),
      };
      
      final queryString = Uri(queryParameters: queryParams).query;
      final endpoint = '/api/clubs/$clubId/bookings/availability?$queryString';
      
      Logger.apiRequest(endpoint, queryParams);
      
      final response = await authenticatedGet(endpoint);
      
      Logger.apiResponse(endpoint, response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData;
      } else if (response.statusCode == 404) {
        Logger.apiError(endpoint, response.statusCode, 'Клуб не найден');
        throw ApiException('Клуб не найден', 404);
      } else {
        Logger.apiError(endpoint, response.statusCode, 'Ошибка проверки доступности');
        throw ApiException('Ошибка проверки доступности', response.statusCode);
      }
    } catch (e, stackTrace) {
      if (e is ApiException) {
        Logger.apiError('/api/clubs/$clubId/bookings/availability', 500, e.toString());
        rethrow;
      }
      Logger.apiError('/api/clubs/$clubId/bookings/availability', 500, e.toString());
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Проверка доступности кортов для бронирования сразу для нескольких таймслотов
  // Возвращает корты, которые доступны на ВСЕ переданные start_times
  static Future<Map<String, dynamic>> checkBookingAvailabilityBulk({
    required String clubId,
    required String bookingDate,
    required List<String> startTimes,
    required int durationMin,
  }) async {
    try {
      final endpoint = '/api/clubs/$clubId/bookings/availability/bulk';
      final body = {
        'booking_date': bookingDate,
        'start_times': startTimes,
        'duration_min': durationMin,
      };

      Logger.apiRequest(endpoint, body);

      final response = await authenticatedPost(endpoint, body);

      Logger.apiResponse(endpoint, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData;
      } else if (response.statusCode == 404) {
        Logger.apiError(endpoint, response.statusCode, 'Клуб не найден');
        throw ApiException('Клуб не найден', 404);
      } else {
        Logger.apiError(endpoint, response.statusCode, 'Ошибка проверки доступности');
        throw ApiException('Ошибка проверки доступности', response.statusCode);
      }
    } catch (e, stackTrace) {
      if (e is ApiException) {
        Logger.apiError('/api/clubs/$clubId/bookings/availability/bulk', 500, e.toString());
        rethrow;
      }
      Logger.apiError('/api/clubs/$clubId/bookings/availability/bulk', 500, e.toString());
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение списка всех доступных таймслотов для выбранной даты
  static Future<List<String>> getAvailableTimeSlots({
    required String clubId,
    required String bookingDate,
    int durationMin = 60,
  }) async {
    try {
      final queryParams = {
        'booking_date': bookingDate,
        'duration_min': durationMin.toString(),
      };
      
      final queryString = Uri(queryParameters: queryParams).query;
      final endpoint = '/api/clubs/$clubId/bookings/available-time-slots?$queryString';
      
      Logger.apiRequest(endpoint, queryParams);
      
      final response = await authenticatedGet(endpoint);
      
      Logger.apiResponse(endpoint, response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> slots = jsonData['available_time_slots'] ?? [];
        return slots.map((slot) => slot.toString()).toList();
      } else if (response.statusCode == 404) {
        Logger.apiError(endpoint, response.statusCode, 'Клуб не найден');
        throw ApiException('Клуб не найден', 404);
      } else {
        Logger.apiError(endpoint, response.statusCode, 'Ошибка получения доступных таймслотов');
        throw ApiException('Ошибка получения доступных таймслотов', response.statusCode);
      }
    } catch (e, stackTrace) {
      if (e is ApiException) {
        Logger.apiError('/api/clubs/$clubId/bookings/available-time-slots', 500, e.toString());
        rethrow;
      }
      Logger.apiError('/api/clubs/$clubId/bookings/available-time-slots', 500, e.toString());
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получение контактных данных пользователя
  static Future<ContactData> getContacts() async {
    final response = await authenticatedGet('/api/contacts');

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return ContactData.fromJson(jsonData);
    } else {
      throw ApiException('Ошибка получения контактных данных', response.statusCode);
    }
  }

  // Обновление контактных данных пользователя
  static Future<ContactData> updateContacts(ContactUpdateRequest request) async {
    final response = await authenticatedPut('/api/contacts', request.toJson());

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return ContactData.fromJson(jsonData);
    } else {
      throw ApiException('Ошибка обновления контактных данных', response.statusCode);
    }
  }

  // Тестирование подключения к API
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Получение контактных данных по ID пользователя
  static Future<ContactData> getContactsByUserId(String userId) async {
    final response = await authenticatedGet('/api/contacts/$userId');

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return ContactData.fromJson(jsonData);
    } else if (response.statusCode == 404) {
      // Возвращаем пустые данные, если контакты не найдены
      return ContactData();
    } else {
      throw ApiException('Ошибка получения контактных данных пользователя', response.statusCode);
    }
  }

   // Отмена отправленной заявки в друзья
  static Future<FriendActionResponse> cancelFriendRequest(String userId) async {
    final url = Uri.parse('$baseUrl/api/friends/$userId/request');
    final headers = await _getAuthHeaders();

    try {
      final response = await http.delete(url, headers: headers);

      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw ApiException('Сессия истекла. Войдите заново.', 401);
      }

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return FriendActionResponse.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        throw ApiException('Заявка не найдена', 404);
      } else {
        throw ApiException('Ошибка отмены заявки', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Регистрация через VK по профилю (без access_token): имя, фамилия, email, phone, avatar
  static Future<AuthResponse> vkRegisterProfile({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? avatarUrl,
    required String city,
    required int currentRating,
    String? preferredHand,
    String skillLevel = 'любитель',
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/vk/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'avatar_url': avatarUrl,
        'city': city,
        'current_rating': currentRating,
        'preferred_hand': preferredHand,
        'skill_level': skillLevel,
      }),
    );
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return AuthResponse.fromJson(jsonData);
    } else {
      String errorMsg = 'Ошибка регистрации через VK (profile)';
      try {
        final json = jsonDecode(response.body);
        errorMsg = json['detail'] ?? errorMsg;
      } catch (_) {}
      throw ApiException(errorMsg, response.statusCode);
    }
  }

  // ====== APPLE SIGN-IN ======
  static Future<UserAppleCallbackResponse> appleSignIn({
    required String idToken,
    String? authorizationCode,
    String? rawNonce,
    String? givenName,
    String? familyName,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/apple/callback');
    final Map<String, dynamic> body = {
      'idToken': idToken,
    };
    if (authorizationCode != null) body['authorizationCode'] = authorizationCode;
    if (rawNonce != null) body['rawNonce'] = rawNonce;
    if (givenName != null || familyName != null) {
      body['fullName'] = {
        if (givenName != null) 'givenName': givenName,
        if (familyName != null) 'familyName': familyName,
      };
    }

    Logger.apiRequest(url.toString(), body);
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    Logger.apiResponse(url.toString(), response.statusCode, response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonData = jsonDecode(response.body);
      return UserAppleCallbackResponse.fromJson(jsonData);
    }

    Logger.apiError(url.toString(), response.statusCode, 'Apple sign-in failed', null);
    throw ApiException('Ошибка авторизации через Apple: ${response.body}', response.statusCode);
  }

  // Завершение регистрации через Apple после прохождения теста уровня
  static Future<AuthResponse> appleRegister({
    required String idToken,
    required String rawNonce,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    required String city,
    required int currentRating,
    String skillLevel = 'любитель',
    String? preferredHand,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/apple/register');
    final Map<String, dynamic> body = {
      'idToken': idToken,
      'rawNonce': rawNonce,
      'city': city,
      'skill_level': skillLevel,
      'current_rating': currentRating,
    };
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (preferredHand != null) body['preferred_hand'] = preferredHand;

    Logger.apiRequest(url.toString(), body);
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    Logger.apiResponse(url.toString(), response.statusCode, response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final jsonData = jsonDecode(response.body);
      return AuthResponse.fromJson(jsonData);
    }
    Logger.apiError(url.toString(), response.statusCode, 'Apple register failed', null);
    throw ApiException('Ошибка регистрации через Apple: ${response.body}', response.statusCode);
  }

  // Метод для авторизованных DELETE запросов
  static Future<http.Response> authenticatedDelete(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getAuthHeaders();
    
    try {
      final response = await http.delete(url, headers: headers);
      
      if (response.statusCode == 401) {
        await AuthStorage.clearAuthData();
        throw ApiException('Токен недействителен', 401);
      }
      
      return response;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // ==================== МЕТОДЫ ДЛЯ РАБОТЫ С ТРЕНИРОВКАМИ ====================

  // Получить список доступных тренировок
  static Future<List<Training>> getTrainings({
    String? city,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    List<DateTime>? selectedDates,
    List<String>? selectedTimes,
    double? minLevel,
    double? maxLevel,
    String? clubId,
    double? userLatitude,
    double? userLongitude,
    double? maxDistanceKm,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      
      // Поиск по городу/клубу
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      
      // Тип тренировки
      if (type != null) queryParams['type'] = type;
      
      // Диапазон дат (date_from и date_to)
      if (startDate != null) {
        queryParams['date_from'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['date_to'] = endDate.toIso8601String();
      }
      
      // Конкретные даты (массив dates)
      if (selectedDates != null && selectedDates.isNotEmpty) {
        for (var date in selectedDates) {
          final dateStr = date.toIso8601String().split('T')[0]; // Только дата без времени
          queryParams['dates'] = queryParams['dates'] ?? [];
          (queryParams['dates'] as List).add(dateStr);
        }
      }
      
      // Выбранные часы (массив selected_times)
      if (selectedTimes != null && selectedTimes.isNotEmpty) {
        for (var time in selectedTimes) {
          queryParams['selected_times'] = queryParams['selected_times'] ?? [];
          (queryParams['selected_times'] as List).add(time);
        }
      }
      
      // Уровень сложности
      if (minLevel != null) queryParams['min_level'] = minLevel.toString();
      if (maxLevel != null) queryParams['max_level'] = maxLevel.toString();
      
      // Клуб
      if (clubId != null) queryParams['club_id'] = clubId;
      
      // Фильтр по расстоянию
      if (userLatitude != null && userLongitude != null && maxDistanceKm != null) {
        queryParams['user_latitude'] = userLatitude.toString();
        queryParams['user_longitude'] = userLongitude.toString();
        queryParams['max_distance_km'] = maxDistanceKm.toString();
      }
      
      // Строим URL с параметрами
      String queryString = '';
      if (queryParams.isNotEmpty) {
        final List<String> params = [];
        queryParams.forEach((key, value) {
          if (value is List) {
            // Для массивов добавляем каждый элемент отдельно
            for (var item in value) {
              params.add('$key=${Uri.encodeComponent(item.toString())}');
            }
          } else {
            params.add('$key=${Uri.encodeComponent(value.toString())}');
          }
        });
        queryString = '?${params.join('&')}';
      }
      
      final endpoint = '/api/trainings$queryString';
      
      // Детальное логирование запроса
      Logger.error('📡 ============ API REQUEST ============');
      Logger.error('🌐 Endpoint: $endpoint');
      Logger.error('📦 Query params: $queryParams');
      Logger.error('📍 Distance filter:');
      Logger.error('   userLatitude: $userLatitude');
      Logger.error('   userLongitude: $userLongitude');
      Logger.error('   maxDistanceKm: $maxDistanceKm');
      Logger.error('=====================================');
      
      Logger.apiRequest(endpoint, queryParams);
      
      final response = await authenticatedGet(endpoint);
      
      Logger.error('📡 ============ API RESPONSE ===========');
      Logger.error('🌐 Endpoint: $endpoint');
      Logger.error('📊 Status code: ${response.statusCode}');
      Logger.error('📝 Body length: ${response.body.length} characters');
      if (response.statusCode != 200) {
        Logger.error('❌ Error body: ${response.body}');
      }
      Logger.error('=====================================');
      
      Logger.apiResponse(endpoint, response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> trainingsJson = data['trainings'] ?? [];
        Logger.success('✅ Успешно загружено ${trainingsJson.length} тренировок');
        return trainingsJson.map((json) => Training.fromJson(json)).toList();
      } else {
        Logger.apiError(endpoint, response.statusCode, response.body);
        throw ApiException('Ошибка загрузки тренировок', response.statusCode);
      }
    } catch (e, stackTrace) {
      if (e is ApiException) {
        Logger.error('❌ Ошибка загрузки тренировок', e, stackTrace);
        rethrow;
      }
      Logger.error('❌ Неожиданная ошибка при загрузке тренировок', e, stackTrace);
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получить мои тренировки
  static Future<List<Training>> getMyTrainings() async {
    try {
      final endpoint = '/api/trainings/my';
      Logger.apiRequest(endpoint, {});
      
      final response = await authenticatedGet(endpoint);
      
      Logger.apiResponse(endpoint, response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Logger.info('📋 Данные моих тренировок: $data');
        
        // Сервер возвращает upcoming и past, объединяем их
        final List<dynamic> upcomingJson = data['upcoming'] ?? [];
        final List<dynamic> pastJson = data['past'] ?? [];
        
        Logger.info('📊 Предстоящих тренировок: ${upcomingJson.length}');
        Logger.info('📊 Прошедших тренировок: ${pastJson.length}');
        
        final upcoming = upcomingJson.map((json) {
          Logger.info('🔍 Парсинг предстоящей тренировки: $json');
          return Training.fromJson(json);
        }).toList();
        
        final past = pastJson.map((json) {
          Logger.info('🔍 Парсинг прошедшей тренировки: $json');
          return Training.fromJson(json);
        }).toList();
        
        // Объединяем все тренировки
        final allTrainings = [...upcoming, ...past];
        
        Logger.success('✅ Успешно загружено ${allTrainings.length} тренировок (${upcoming.length} предстоящих, ${past.length} прошедших)');
        return allTrainings;
      } else {
        Logger.apiError(endpoint, response.statusCode, response.body);
        throw ApiException('Ошибка загрузки моих тренировок', response.statusCode);
      }
    } catch (e, stackTrace) {
      if (e is ApiException) {
        Logger.error('❌ Ошибка загрузки моих тренировок', e, stackTrace);
        rethrow;
      }
      Logger.error('❌ Неожиданная ошибка при загрузке моих тренировок', e, stackTrace);
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Записаться на тренировку
  static Future<TrainingJoinResponse> joinTraining(String trainingId) async {
    try {
      final endpoint = '/api/trainings/$trainingId/join';
      Logger.apiRequest(endpoint, {});
      
      final response = await authenticatedPost(endpoint, {});
      
      Logger.apiResponse(endpoint, response.statusCode, response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        Logger.success('✅ Успешная запись на тренировку ID: $trainingId');
        
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        Logger.info('📋 Ответ сервера: $responseData');
        
        return TrainingJoinResponse.fromJson(responseData);
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? 'Нельзя записаться на эту тренировку';
        Logger.apiError(endpoint, response.statusCode, errorMessage);
        throw ApiException(errorMessage, 400);
      } else if (response.statusCode == 404) {
        Logger.apiError(endpoint, response.statusCode, 'Тренировка не найдена');
        throw ApiException('Тренировка не найдена', 404);
      } else {
        Logger.apiError(endpoint, response.statusCode, 'Неожиданный статус код: ${response.body}');
        throw ApiException('Ошибка записи на тренировку', response.statusCode);
      }
    } catch (e, stackTrace) {
      if (e is ApiException) {
        Logger.error('❌ Ошибка записи на тренировку', e, stackTrace);
        rethrow;
      }
      Logger.error('❌ Неожиданная ошибка при записи на тренировку', e, stackTrace);
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Отменить запись на тренировку
  static Future<bool> cancelTraining(String trainingId) async {
    try {
      // Сервер ожидает /leave, а не /cancel
      final endpoint = '/api/trainings/$trainingId/leave';
      Logger.apiRequest(endpoint, {});
      
      final response = await authenticatedPost(endpoint, {});
      
      Logger.apiResponse(endpoint, response.statusCode, response.body);
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        Logger.success('✅ Успешная отмена записи на тренировку ID: $trainingId');
        // Логируем результат от сервера
        if (response.body.isNotEmpty) {
          try {
            final responseData = jsonDecode(response.body);
            Logger.info('📋 Ответ сервера: $responseData');
          } catch (e) {
            Logger.warning('⚠️ Не удалось распарсить ответ сервера: ${response.body}');
          }
        }
        return true;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? 'Нельзя отменить запись на эту тренировку';
        Logger.apiError(endpoint, response.statusCode, errorMessage);
        throw ApiException(errorMessage, 400);
      } else if (response.statusCode == 404) {
        Logger.apiError(endpoint, response.statusCode, 'Тренировка не найдена');
        throw ApiException('Тренировка не найдена', 404);
      } else {
        Logger.apiError(endpoint, response.statusCode, 'Неожиданный статус код: ${response.body}');
        throw ApiException('Ошибка отмены записи на тренировку', response.statusCode);
      }
    } catch (e, stackTrace) {
      if (e is ApiException) {
        Logger.error('❌ Ошибка отмены записи на тренировку', e, stackTrace);
        rethrow;
      }
      Logger.error('❌ Неожиданная ошибка при отмене записи на тренировку', e, stackTrace);
      throw ApiException('Ошибка сети: $e', 500);
    }
  }

  // Получить детали тренировки
  static Future<Training> getTrainingDetails(String trainingId) async {
    try {
      final response = await authenticatedGet('/api/trainings/$trainingId');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Бэкенд возвращает объект тренировки напрямую. На всякий случай поддержим оба формата.
        final Map<String, dynamic> trainingJson = (data is Map && data['training'] is Map)
            ? Map<String, dynamic>.from(data['training'] as Map)
            : Map<String, dynamic>.from(data as Map);
        return Training.fromJson(trainingJson);
      } else if (response.statusCode == 404) {
        throw ApiException('Тренировка не найдена', 404);
      } else {
        throw ApiException('Ошибка загрузки деталей тренировки', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Ошибка сети: $e', 500);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class CompetitionTeamsApiResponse {
  final List<CompetitionTeam> teams;
  final String? myStatus; // 'pending' и т.п.

  CompetitionTeamsApiResponse({required this.teams, this.myStatus});
}

class InitializeRatingResponse {
  final String message;
  final bool success;
  final String userId;
  final int initialRating;
  final String ntrpLevel;
  final String ntrpDescription;

  InitializeRatingResponse({
    required this.message,
    required this.success,
    required this.userId,
    required this.initialRating,
    required this.ntrpLevel,
    required this.ntrpDescription,
  });

  factory InitializeRatingResponse.fromJson(Map<String, dynamic> json) {
    return InitializeRatingResponse(
      message: json['message'] as String,
      success: json['success'] as bool,
      userId: json['user_id'] as String,
      initialRating: json['initial_rating'] as int,
      ntrpLevel: json['ntrp_level'] as String,
      ntrpDescription: json['ntrp_description'] as String,
    );
  }
}

// Результат проверки доступности email
class EmailAvailabilityResult {
  final bool isAvailable;
  final String? existingUserName;

  EmailAvailabilityResult({
    required this.isAvailable,
    this.existingUserName,
  });
}


class EmailLoginInitResponse {
  final bool success;
  final String? message;
  final String? email;
  final int? expiresIn;

  EmailLoginInitResponse({
    required this.success,
    this.message,
    this.email,
    this.expiresIn,
  });

  factory EmailLoginInitResponse.fromJson(Map<String, dynamic> json) {
    return EmailLoginInitResponse(
      success: json['success'] ?? false,
      message: json['message'],
      email: json['email'],
      expiresIn: json['expires_in'],
    );
  }
}

