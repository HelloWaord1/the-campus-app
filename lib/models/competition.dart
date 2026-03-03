import '../utils/rating_utils.dart';
class CompetitionListResponse {
  final List<Competition> competitions;
  final int? totalCount;

  CompetitionListResponse({required this.competitions, this.totalCount});

  factory CompetitionListResponse.fromJson(dynamic json) {
    // Поддерживаем несколько возможных форматов ответа:
    // 1) { competitions: [...], total_count: N }
    // 2) { items: [...], total_count: N }
    // 3) [ ... ]
    if (json is List) {
      return CompetitionListResponse(
        competitions: json.map((e) => Competition.fromJson(e as Map<String, dynamic>)).toList(),
      );
    }
    if (json is Map<String, dynamic>) {
      final list = (json['competitions'] ?? json['items'] ?? json['data'] ?? []) as List<dynamic>;
      return CompetitionListResponse(
        competitions: list.map((e) => Competition.fromJson(e as Map<String, dynamic>)).toList(),
        totalCount: json['total_count'] as int?,
      );
    }
    return CompetitionListResponse(competitions: const []);
  }
}

class CompetitionListParticipant {
  final String? userId;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? name;
  final String? role;
  final String? status;
  final String? joinedAt;
  final int? userRating;

  CompetitionListParticipant({
    this.userId,
    this.firstName,
    this.lastName,
    this.name,
    this.avatarUrl,
    this.role,
    this.status,
    this.joinedAt,
    this.userRating,
  });

  factory CompetitionListParticipant.fromJson(Map<String, dynamic> json) {
    return CompetitionListParticipant(
      userId: (json['user_id'] ?? json['userId'])?.toString(),
      firstName: json['first_name'] as String? ?? json['firstName'] as String?,
      lastName: json['last_name'] as String? ?? json['lastName'] as String?,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      role: json['role'] as String?,
      status: json['status'] as String?,
      joinedAt: json['joined_at'] as String? ?? json['joinedAt'] as String?,
      // Используем текущий рейтинг, если доступен, иначе fallback на user_rating
      userRating: (json['current_rating'] as num?)?.toInt()
          ?? (json['currentRating'] as num?)?.toInt()
          ?? (json['user_rating'] as num?)?.toInt(),
    );
  }

  // Формат рейтинга как на карточке матча
  String get formattedRating {
    if (userRating == null) return 'D 1.00';
    
    // Используем единую функцию расчета рейтинга
    final rating = calculateRating(userRating!);
    final letter = ratingToLetter(rating);
    return '$letter ${rating.toStringAsFixed(2)}';
  }
}

class Competition {
  final String id;
  final DateTime startTime;
  final String name;
  final String? description;
  final String? prize;
  final String? chat;
  final String? clubName;
  final String? clubId;
  final String participantsGender; // all|male|female
  final String city;
  final String? status; // planned|started|finished
  final double? distanceKm;
  final double? minRating;
  final double? maxRating;
  final int? maxParticipants;
  final String? format; // single | double
  final String? myStatus; // e.g. 'pending' если заявка подана
  final List<CompetitionListParticipant> participants;
  // Итоговые места: список team_id по возрастанию места
  final List<String> finalStandingTeamIds;
  // Полные команды турнира с участниками
  final List<CompetitionTeam> teams;

  Competition({
    required this.id,
    required this.startTime,
    required this.name,
    this.description,
    this.prize,
    this.chat,
    this.clubName,
    this.clubId,
    this.status,
    required this.participantsGender,
    required this.city,
    this.distanceKm,
    this.minRating,
    this.maxRating,
    this.maxParticipants,
    this.format,
    this.myStatus,
    this.participants = const [],
    this.finalStandingTeamIds = const [],
    this.teams = const [],
  });

  factory Competition.fromJson(Map<String, dynamic> json) {
    final rawTime = json['start_time'] as String? ?? json['startTime'] as String? ?? '';
    DateTime parsed;
    try {
      parsed = DateTime.parse(rawTime);
    } catch (_) {
      parsed = DateTime.now();
    }
    return Competition(
      id: json['id'] as String,
      startTime: parsed,
      name: json['name'] as String? ?? 'Турнир',
      description: json['description'] as String?,
      prize: json['prize'] as String?,
      chat: json['chat'] as String?,
      clubName: json['club_name'] as String?,
      clubId: json['club_id'] as String?,
      status: json['status'] as String?,
      participantsGender: json['participants_gender'] as String? ?? 'all',
      city: json['city'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      minRating: (json['min_rating'] as num?)?.toDouble(),
      maxRating: (json['max_rating'] as num?)?.toDouble(),
      maxParticipants: json['max_participants'] as int?,
      format: (json['format'] as String?) ?? (json['competition_format'] as String?),
      myStatus: json['my_status'] as String?,
      participants: (json['participants'] as List?)
              ?.map((e) => CompetitionListParticipant.fromJson(e as Map<String, dynamic>))
              .toList() 
            ?? const [],
      finalStandingTeamIds: (() {
        final raw = json['final_standings'] ?? json['finalStandings'];
        if (raw is List) {
          final List<String> ids = [];
          for (final item in raw) {
            if (item is String) {
              ids.add(item);
            } else if (item is Map<String, dynamic>) {
              final id = (item['winner_team_id'] ?? item['team_id'] ?? item['teamId']);
              if (id != null) ids.add(id.toString());
            }
          }
          return ids;
        }
        return const <String>[];
      })(),
      teams: (json['teams'] as List?)
              ?.map((e) => CompetitionTeam.fromJson(Map<String, dynamic>.from(e)))
              .toList() 
            ?? const [],
    );
  }
}

// ======== Запрос/ответ для участия в соревновании ========
class CompetitionJoinRequest {
  final String? message;

  CompetitionJoinRequest({this.message});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (message != null && message!.isNotEmpty) {
      data['message'] = message;
    }
    return data;
  }
}

class CompetitionJoinResponse {
  final bool success;
  final String? status;
  final String? message;
  final String? competitionId;

  CompetitionJoinResponse({
    required this.success,
    this.status,
    this.message,
    this.competitionId,
  });

  factory CompetitionJoinResponse.fromJson(Map<String, dynamic> json) {
    return CompetitionJoinResponse(
      success: (json['success'] as bool?) ?? (json['ok'] as bool?) ?? true,
      status: json['status'] as String?,
      message: json['message'] as String? ?? json['detail'] as String?,
      competitionId: (json['competition_id'] ?? json['competitionId']) as String?,
    );
  }
}

// ======== Команды соревнования ========
class CompetitionTeam {
  final String id;
  final String? name; // 'A', 'B' или произвольное название
  final int? capacity;
  final List<CompetitionListParticipant> participants;
  final int? seed;
  final double? teamRating;

  CompetitionTeam({
    required this.id,
    this.name,
    this.capacity,
    this.participants = const [],
    this.seed,
    this.teamRating,
  });

  factory CompetitionTeam.fromJson(Map<String, dynamic> json) {
    final List<CompetitionListParticipant> members = (json['members'] as List?)
            ?.map((e) => CompetitionListParticipant.fromJson(e as Map<String, dynamic>))
            .toList() 
          ?? (json['participants'] as List?)
              ?.map((e) => CompetitionListParticipant.fromJson(e as Map<String, dynamic>))
              .toList() 
          ?? const [];

    final int? explicitCapacity = (json['capacity'] as num?)?.toInt() ?? json['max_participants'] as int?;
    final int computedCapacity = members.length < 2 ? 2 : members.length;

    return CompetitionTeam(
      id: (json['id'] ?? json['team_id'] ?? json['teamId']).toString(),
      name: json['name'] as String? ?? json['label'] as String?,
      capacity: explicitCapacity ?? computedCapacity,
      participants: members,
      seed: (json['seed'] as num?)?.toInt(),
      teamRating: (json['team_rating'] as num?)?.toDouble() ?? (json['teamRating'] as num?)?.toDouble(),
    );
  }

  String get formattedRating {
    if (teamRating == null) return 'D 1.00';
    
    // Используем единую функцию расчета рейтинга
    final rating = calculateRating(teamRating!.toInt());
    final letter = ratingToLetter(rating);
    return '$letter ${rating.toStringAsFixed(2)}';
  }
  int get filled => participants.length;
  bool get hasVacancy => capacity == null || filled < capacity!;
}

// ======== Матчи соревнования (упрощённые структуры ответа) ========
class CompetitionTeamBrief {
  final String? teamId; // Опционально для Americano (там нет team_id)
  final double? teamRating;
  final List<CompetitionListParticipant> members;

  CompetitionTeamBrief({this.teamId, this.teamRating, this.members = const []});

  factory CompetitionTeamBrief.fromJson(Map<String, dynamic> json) {
    final List<CompetitionListParticipant> ms = (json['members'] as List?)
            ?.map((e) => CompetitionListParticipant.fromJson(Map<String, dynamic>.from(e)))
            .toList() ?? const [];
    return CompetitionTeamBrief(
      teamId: (json['team_id'] ?? json['id'])?.toString(),
      teamRating: (json['team_rating'] as num?)?.toDouble(),
      members: ms,
    );
  }
}

class CompetitionMatchItem {
  final String competitionMatchId;
  final int? round;
  final int? indexInRound;
  final DateTime? scheduledTime;
  final String? matchId;
  final dynamic score;
  final String? winnerTeamId; // для single/double (UUID команды)
  final String? winnerTeam; // для americano ('A' или 'B')
  final String? matchStatus; // для americano (статус матча)
  final String? teamAId;
  final String? teamBId;
  final CompetitionTeamBrief? teamA;
  final CompetitionTeamBrief? teamB;
  final String? clubName;
  final String? city;

  CompetitionMatchItem({
    required this.competitionMatchId,
    this.round,
    this.indexInRound,
    this.scheduledTime,
    this.matchId,
    this.score,
    this.winnerTeamId,
    this.winnerTeam,
    this.matchStatus,
    this.teamAId,
    this.teamBId,
    this.teamA,
    this.teamB,
    this.clubName,
    this.city,
  });

  factory CompetitionMatchItem.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    final st = json['scheduled_time'];
    if (st is String && st.isNotEmpty) {
      try { dt = DateTime.parse(st); } catch (_) {}
    }
    return CompetitionMatchItem(
      competitionMatchId: (json['competition_match_id'] ?? json['id']).toString(),
      round: (json['round'] as num?)?.toInt(),
      indexInRound: (json['index_in_round'] as num?)?.toInt(),
      scheduledTime: dt,
      matchId: json['match_id'] as String?,
      score: json['score'],
      winnerTeamId: json['winner_team_id'] as String?,
      winnerTeam: json['winner_team'] as String?,
      matchStatus: json['match_status'] as String?,
      teamAId: json['team_a_id'] as String?,
      teamBId: json['team_b_id'] as String?,
      teamA: (json['team_a'] is Map<String, dynamic>) ? CompetitionTeamBrief.fromJson(Map<String, dynamic>.from(json['team_a'])) : null,
      teamB: (json['team_b'] is Map<String, dynamic>) ? CompetitionTeamBrief.fromJson(Map<String, dynamic>.from(json['team_b'])) : null,
      clubName: json['club_name'] as String?,
      city: json['city'] as String?,
    );
  }
}

