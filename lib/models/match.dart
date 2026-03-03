// Модели для работы с матчами
import '../utils/rating_utils.dart';
class Match {
  final String id;
  final DateTime dateTime;
  final int duration; // в минутах
  final String? clubId;
  final String? clubName;
  final String? clubPhoto;
  final String? clubCity; // Добавляем поле города клуба
  final String? courtId;
  final bool isBooked;
  final String format; // single, double
  final String? matchType; // competitive | friendly (нужно для редактирования)
  final String requiredLevel; // начинающий, любитель, продвинутый, профессионал
  final bool isPrivate;
  final String? description;
  final int maxParticipants;
  final int currentParticipants;
  final String organizerId;
  final String organizerName;
  final String? organizerAvatarUrl;
  final String status; // active, completed, cancelled
  final List<MatchParticipant> participants;
  final String? bookingId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? startedAt; // Время начала матча
  final DateTime? finishedAt; // Время завершения матча
  final String? courtName;
  final double? price;
  final int? courtNumber; // извлекается из court_booking_info.court_number
  final String? bookedByName; // извлекается из court_booking_info.booked_by_name
  final bool isTournament; // признак турнирного матча
  // Поля результата матча
  final String? winnerTeam; // 'A' | 'B' для парных матчей
  final String? winnerUserId; // для одиночных матчей
  final List<int>? teamASets; // очки по сетам команды A
  final List<int>? teamBSets; // очки по сетам команды B
  final bool canRatePlayers; // может ли текущий пользователь оценить участников
  final bool hostScoreFilled; // признак: хост уже внёс черновой счёт

  Match({
    required this.id,
    required this.dateTime,
    required this.duration,
    this.clubId,
    this.clubName,
    this.clubPhoto,
    this.clubCity,
    this.courtId,
    required this.isBooked,
    required this.format,
    this.matchType,
    required this.requiredLevel,
    required this.isPrivate,
    this.description,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.organizerId,
    required this.organizerName,
    this.organizerAvatarUrl,
    required this.status,
    required this.participants,
    this.bookingId,
    required this.createdAt,
    this.updatedAt,
    this.startedAt,
    this.finishedAt,
    this.courtName,
    this.price,
    this.courtNumber,
    this.bookedByName,
    this.isTournament = false,
    this.winnerTeam,
    this.winnerUserId,
    this.teamASets,
    this.teamBSets,
    this.canRatePlayers = false,
    this.hostScoreFilled = false,
  });

  // Вычисляемое свойство для доступных мест
  int get availableSlots => maxParticipants - currentParticipants;

  factory Match.fromJson(Map<String, dynamic> json) {
    // Объединяем organizer_first_name и organizer_last_name в organizer_name
    String organizerName = '';
    if (json['organizer_first_name'] != null && json['organizer_last_name'] != null) {
      organizerName = '${json['organizer_first_name']} ${json['organizer_last_name']}';
    } else if (json['organizer_first_name'] != null) {
      organizerName = json['organizer_first_name'];
    } else if (json['organizer_last_name'] != null) {
      organizerName = json['organizer_last_name'];
    } else if (json['organizer_name'] != null) {
      // Fallback для обратной совместимости
      organizerName = json['organizer_name'];
    }
    
    // Локальные хелперы для безопасного парсинга чисел (могут приходить строками)
    double? _parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', '.'));
      return null;
    }

    int? _parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    // Возможное вложенное поле с инфо о бронировании
    final Map<String, dynamic>? bookingInfo = json['court_booking_info'] as Map<String, dynamic>?;

    // court_name может отсутствовать, тогда пробуем собрать из номера
    final String? parsedCourtName = json['court_name'] ??
        (bookingInfo != null && bookingInfo['court_number'] != null
            ? 'Корт №${bookingInfo['court_number']}'
            : (json['court_number'] != null
                ? 'Корт №${json['court_number']}'
                : null));

    // Цена: сначала плоское поле price, затем верхнеуровневый booking_cost, затем вложенный booking_cost
    final double? parsedPrice = _parseDouble(json['price'])
        ?? _parseDouble(json['booking_cost'])
        ?? _parseDouble(bookingInfo != null ? bookingInfo['booking_cost'] : null);

    bool _parseBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.toLowerCase().trim();
        return s == 'true' || s == '1' || s == 'yes';
      }
      return false;
    }

    // Разбор счета
    List<int>? parsedTeamASets;
    List<int>? parsedTeamBSets;
    final dynamic scoreJson = json['score'];
    if (scoreJson is List) {
      final a = <int>[];
      final b = <int>[];
      for (final s in scoreJson) {
        if (s is Map<String, dynamic>) {
          final aa = _parseInt(s['a']) ?? 0;
          final bb = _parseInt(s['b']) ?? 0;
          a.add(aa);
          b.add(bb);
        } else if (s is List) {
          if (s.length >= 2) {
            final aa = _parseInt(s[0]) ?? 0;
            final bb = _parseInt(s[1]) ?? 0;
            a.add(aa);
            b.add(bb);
          }
        } else if (s is String) {
          final parts = s.split(RegExp(r'[:\-]'));
          if (parts.length >= 2) {
            final aa = _parseInt(parts[0]) ?? 0;
            final bb = _parseInt(parts[1]) ?? 0;
            a.add(aa);
            b.add(bb);
          }
        }
      }
      if (a.isNotEmpty && b.isNotEmpty) {
        parsedTeamASets = a;
        parsedTeamBSets = b;
      }
    } else if (scoreJson is String) {
      // Формат строки: "6-3, 4-6, 10-8"
      final sets = scoreJson.split(',');
      final a = <int>[];
      final b = <int>[];
      for (final setStr in sets) {
        final parts = setStr.trim().split(RegExp(r'[:\-]'));
        if (parts.length >= 2) {
          final aa = int.tryParse(parts[0].trim()) ?? 0;
          final bb = int.tryParse(parts[1].trim()) ?? 0;
          a.add(aa);
          b.add(bb);
        }
      }
      if (a.isNotEmpty && b.isNotEmpty) {
        parsedTeamASets = a;
        parsedTeamBSets = b;
      }
    }

    return Match(
      id: json['id'] ?? '',
      dateTime: DateTime.parse(json['date_time'] ?? DateTime.now().toIso8601String()),
      duration: _parseInt(json['duration']) ?? 60,
      clubId: json['club_id'],
      clubName: json['club_name'],
      clubPhoto: json['club_photo_url'],
      clubCity: json['city'], // Исправлено: используем 'city' вместо 'club_city'
      courtId: json['court_id'],
      isBooked: json['is_booked'] ?? false,
      format: json['format'] ?? 'double',
      matchType: json['match_type'] as String? ?? json['matchType'] as String?,
      requiredLevel: json['required_level'] ?? 'начинающий',
      isPrivate: json['is_private'] ?? false,
      description: json['description'],
      maxParticipants: _parseInt(json['max_participants']) ?? 4,
      currentParticipants: _parseInt(json['current_participants']) ?? 0,
      organizerId: json['organizer_id'] ?? '',
      organizerName: organizerName.isNotEmpty ? organizerName : 'Организатор',
      organizerAvatarUrl: json['organizer_avatar_url'],
      status: json['status'] ?? 'active',
      participants: (json['participants'] as List<dynamic>?)
          ?.map((p) => MatchParticipant.fromJson(p))
          .toList() ?? [],
      bookingId: json['booking_id'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      finishedAt: json['finished_at'] != null ? DateTime.parse(json['finished_at']) : null,
      courtName: parsedCourtName,
      price: parsedPrice,
      courtNumber: _parseInt(json['court_number'])
          ?? _parseInt(bookingInfo != null ? bookingInfo['court_number'] : null),
      bookedByName: json['booked_by_name'] as String? ?? (bookingInfo != null ? bookingInfo['booked_by_name'] as String? : null),
      isTournament: _parseBool(json['is_tournament'] ?? json['isTournament']),
      winnerTeam: json['winner_team'],
      winnerUserId: json['winner_user_id'],
      teamASets: parsedTeamASets,
      teamBSets: parsedTeamBSets,
      canRatePlayers: _parseBool(json['can_rate_players'] ?? false),
      hostScoreFilled: _parseBool(json['host_score_filled'] ?? false),
    );
  }

  // Проверка доступности для присоединения
  bool get canJoin => 
      status == 'active' && 
      availableSlots > 0 &&
      !isPrivate;

  // Проверка, является ли текущий пользователь участником матча
  bool get isParticipant {
    // TODO: Нужно получить ID текущего пользователя из AuthStorage
    // Пока возвращаем false, так как нет доступа к текущему пользователю
    return false;
  }

  // Проверка, является ли текущий пользователь организатором матча
  bool get isOrganizer {
    // TODO: Нужно получить ID текущего пользователя из AuthStorage
    // Пока возвращаем false, так как нет доступа к текущему пользователю
    return false;
  }

  // Получить отображаемый уровень
  String get displayRequiredLevel {
    switch (requiredLevel.toLowerCase()) {
      case 'начинающий':
        return 'Начинающий';
      case 'любитель':
        return 'Средний';
      case 'продвинутый':
        return 'Продвинутый';
      case 'профессионал':
        return 'Профессионал';
      default:
        return 'Средний';
    }
  }

  // Получить отображаемый формат
  String get displayFormat {
    switch (format.toLowerCase()) {
      case 'single':
        return 'Одиночный';
      case 'double':
        return 'Парный';
      default:
        return format;
    }
  }

  // Форматирование даты и времени
  String get formattedDateTime {
    final months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    
    final weekdays = [
      'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'
    ];
    
    final weekday = weekdays[dateTime.weekday - 1];
    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$weekday, $day $month, $hour:$minute';
  }

  // Короткое форматирование даты
  String get shortFormattedDate {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$day.$month в $hour:$minute';
  }

  // Алиас для совместимости с экранами
  String get formattedDate => formattedDateTime;
}

class MatchParticipant {
  final String? id;
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? userStatus; // статус профиля пользователя (например: active/blocked/deleted)
  final int? userRating;
  final String? role;
  final String? status;
  final String? teamId; // Добавляем поле команды
  final bool? approvedByOrganizer;
  final DateTime? joinedAt;
  final DateTime? createdAt;
  final String? draftScore;
  final String? scoreConfirmationStatus; // 'host' | 'accept' | 'dispute'

  MatchParticipant({
    this.id,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.userStatus,
    this.userRating,
    this.role,
    this.status,
    this.teamId,
    this.approvedByOrganizer,
    this.joinedAt,
    this.createdAt,
    this.draftScore,
    this.scoreConfirmationStatus,
  });

  factory MatchParticipant.fromJson(Map<String, dynamic> json) {
    // Объединяем first_name и last_name в name
    String name = '';
    if (json['first_name'] != null && json['last_name'] != null) {
      name = '${json['first_name']} ${json['last_name']}';
    } else if (json['first_name'] != null) {
      name = json['first_name'];
    } else if (json['last_name'] != null) {
      name = json['last_name'];
    } else if (json['name'] != null) {
      // Fallback для обратной совместимости
      name = json['name'];
    }
    
    return MatchParticipant(
      id: json['id'],
      userId: json['user_id'],
      name: name,
      avatarUrl: json['avatar_url'],
      userStatus: json['user_status'],
      userRating: json['user_rating'],
      role: json['role'],
      status: json['status'],
      teamId: json['team_id'],
      approvedByOrganizer: json['approved_by_organizer'],
      joinedAt: json['joined_at'] != null ? DateTime.parse(json['joined_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      draftScore: json['draft_score'],
      scoreConfirmationStatus: json['score_confirmation_status'],
    );
  }

  // Геттеры для совместимости с экранами
  String get userName => name;
  String? get userAvatarUrl => avatarUrl;
  bool get isOrganizer => role == 'organizer';
  bool get isDeleted => (userStatus?.toLowerCase() == 'deleted');
  
  // Метод для получения отформатированного рейтинга
  String get formattedRating {
    if (userRating == null) return 'D 1.00';
    
    // Используем единую функцию расчета рейтинга
    final rating = calculateRating(userRating!);
    final letter = ratingToLetter(rating);
    return '$letter ${rating.toStringAsFixed(2)}';
  }
}

class MatchRequest {
  final String id;
  final String matchId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String? userSkillLevel;
  final int? userRating;
  final String status;

  MatchRequest({
    required this.id,
    required this.matchId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    this.userSkillLevel,
    this.userRating,
    required this.status,
  });

  factory MatchRequest.fromJson(Map<String, dynamic> json) {
    return MatchRequest(
      id: json['id'],
      matchId: json['match_id'],
      userId: json['user_id'],
      userName: json['user_name'] ?? 'Неизвестный игрок',
      userAvatarUrl: json['user_avatar_url'],
      userSkillLevel: json['user_skill_level'],
      userRating: json['user_rating'],
      status: json['status'],
    );
  }

  String get formattedRating {
    if (userRating == null) return '—';
    
    // Используем ту же логику, что и в профиле
    final rating = calculateRating(userRating!);
    final letter = ratingToLetter(rating);
    return '$letter ${rating.toStringAsFixed(2)}';
  }
}

// Ответы API
class MatchListResponse {
  final List<Match> matches;
  final int totalCount;
  final Map<String, dynamic> appliedFilters;

  MatchListResponse({
    required this.matches,
    required this.totalCount,
    required this.appliedFilters,
  });

  factory MatchListResponse.fromJson(Map<String, dynamic> json) {
    return MatchListResponse(
      matches: (json['matches'] as List)
          .map((m) => Match.fromJson(m))
          .toList(),
      totalCount: json['total_count'],
      appliedFilters: json['applied_filters'] ?? {},
    );
  }
}

class MyMatchesResponse {
  final List<Match> upcomingMatches;
  final List<Match> pastMatches;

  MyMatchesResponse({
    required this.upcomingMatches,
    required this.pastMatches,
  });

  factory MyMatchesResponse.fromJson(Map<String, dynamic> json) {
    return MyMatchesResponse(
      upcomingMatches: (json['upcoming_matches'] as List?)
              ?.map((m) => Match.fromJson(m))
              .toList() ??
          const [],
      pastMatches: (json['past_matches'] as List?)
              ?.map((m) => Match.fromJson(m))
              .toList() ??
          const [],
    );
  }
}

class MatchInvitation {
  final String id;
  final String matchId;
  final String fromUserId;
  final String fromUserName;
  final String? fromUserAvatarUrl;
  final String? message;
  final DateTime createdAt;
  final Match match;

  MatchInvitation({
    required this.id,
    required this.matchId,
    required this.fromUserId,
    required this.fromUserName,
    this.fromUserAvatarUrl,
    this.message,
    required this.createdAt,
    required this.match,
  });

  factory MatchInvitation.fromJson(Map<String, dynamic> json) {
    // Объединяем from_user_first_name и from_user_last_name в from_user_name
    String fromUserName = '';
    if (json['from_user_first_name'] != null && json['from_user_last_name'] != null) {
      fromUserName = '${json['from_user_first_name']} ${json['from_user_last_name']}';
    } else if (json['from_user_first_name'] != null) {
      fromUserName = json['from_user_first_name'];
    } else if (json['from_user_last_name'] != null) {
      fromUserName = json['from_user_last_name'];
    } else if (json['from_user_name'] != null) {
      // Fallback для обратной совместимости
      fromUserName = json['from_user_name'];
    }
    
    return MatchInvitation(
      id: json['id'],
      matchId: json['match_id'],
      fromUserId: json['from_user_id'],
      fromUserName: fromUserName,
      fromUserAvatarUrl: json['from_user_avatar_url'],
      message: json['message'],
      createdAt: DateTime.parse(json['created_at']),
      match: Match.fromJson(json['match']),
    );
  }
}

// Запросы для создания/обновления матчей
class CourtBookingInfo {
  final int courtNumber;
  final String bookedByName;
  final double bookingCost;

  CourtBookingInfo({
    required this.courtNumber,
    required this.bookedByName,
    required this.bookingCost,
  });

  Map<String, dynamic> toJson() {
    return {
      'court_number': courtNumber,
      'booked_by_name': bookedByName,
      'booking_cost': bookingCost,
    };
  }
}

class MatchCreate {
  final DateTime dateTime;
  final int duration;
  final String clubId; // Теперь обязательное поле
  final String format;
  final String matchType;
  final bool isPrivate;
  final String? description; // Добавляем поле description
  final int maxParticipants;
  final bool isBooked;
  final CourtBookingInfo? courtBookingInfo;

  MatchCreate({
    required this.dateTime,
    required this.duration,
    required this.clubId, // Обязательное поле
    required this.format,
    required this.matchType,
    required this.isPrivate,
    this.description, // Опциональное поле
    required this.maxParticipants,
    required this.isBooked,
    this.courtBookingInfo,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'date_time': dateTime.toUtc().toIso8601String(),
      'duration': duration,
      'club_id': clubId, // Добавляем club_id в JSON
      'format': format,
      'match_type': matchType,
      'is_private': isPrivate,
      'max_participants': maxParticipants,
      'is_booked': isBooked,
    };

    if (description != null) {
      data['description'] = description;
    }

    if (courtBookingInfo != null) {
      data['court_booking_info'] = courtBookingInfo!.toJson();
    }

    return data;
  }
}

class MatchUpdate {
  final DateTime? dateTime;
  final int? duration;
  final String? clubId;
  final String? format;
  final String? requiredLevel;
  final bool? isPrivate;
  final String? description;
  final int? maxParticipants;
  final String? matchType; // competitive | friendly
  final bool? isBooked;
  final CourtBookingInfo? courtBookingInfo;

  MatchUpdate({
    this.dateTime,
    this.duration,
    this.clubId,
    this.format,
    this.requiredLevel,
    this.isPrivate,
    this.description,
    this.maxParticipants,
    this.matchType,
    this.isBooked,
    this.courtBookingInfo,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (dateTime != null) data['date_time'] = dateTime!.toUtc().toIso8601String();
    if (duration != null) data['duration'] = duration;
    if (clubId != null) data['club_id'] = clubId;
    if (format != null) data['format'] = format;
    if (requiredLevel != null) data['required_level'] = requiredLevel;
    if (isPrivate != null) data['is_private'] = isPrivate;
    if (description != null) data['description'] = description;
    if (maxParticipants != null) data['max_participants'] = maxParticipants;
    if (matchType != null) data['match_type'] = matchType;
    if (isBooked != null) data['is_booked'] = isBooked;
    if (courtBookingInfo != null) data['court_booking_info'] = courtBookingInfo!.toJson();
    return data;
  }
}

class MatchJoinRequest {
  final String? message;
  final String? teamId;

  MatchJoinRequest({this.message, this.teamId});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (message != null) {
      data['message'] = message;
    }
    if (teamId != null) {
      data['team_id'] = teamId;
    }
    return data;
  }
}

class MatchInviteRequest {
  final String userId;
  final String? message;

  MatchInviteRequest({
    required this.userId,
    this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'message': message,
    };
  }
} 