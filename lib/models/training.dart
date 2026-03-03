class TrainingJoinResponse {
  final bool success;
  final bool paymentRequired;
  final String? paymentUrl;
  final String? paymentId;

  const TrainingJoinResponse({
    required this.success,
    this.paymentRequired = false,
    this.paymentUrl,
    this.paymentId,
  });

  factory TrainingJoinResponse.fromJson(Map<String, dynamic> json) {
    return TrainingJoinResponse(
      success: json['success'] ?? true,
      paymentRequired: json['payment_required'] ?? false,
      paymentUrl: json['payment_url'],
      paymentId: json['payment_id'],
    );
  }
}

class TrainingParticipant {
  final String userId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final int? rating;
  final DateTime? joinedAt;

  const TrainingParticipant({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.rating,
    this.joinedAt,
  });

  String get fullName => '$firstName $lastName';

  factory TrainingParticipant.fromJson(Map<String, dynamic> json) {
    return TrainingParticipant(
      userId: json['user_id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      avatarUrl: json['avatar_url'],
      rating: json['user_rating'],
      joinedAt: json['joined_at'] != null ? DateTime.parse(json['joined_at']) : null,
    );
  }
}

class Training {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String type; // 'group' или 'individual'
  final String? clubId; // ID клуба для перехода на детали
  final String clubName;
  final String clubCity;
  final String? clubAddress; // Адрес клуба
  final double? clubLatitude; // Широта клуба
  final double? clubLongitude; // Долгота клуба
  final double price;
  final String trainerName;
  final String? trainerAvatar;
  final int? trainerRating;
  final String? trainerId; // ID тренера для перехода на профиль
  final int currentParticipants;
  final int maxParticipants;
  final double minLevel;
  final double maxLevel;
  final List<String> participantAvatars; // Для обратной совместимости
  final List<TrainingParticipant> participants; // Полные данные участников
  final String? backgroundImage;
  final String? iconUrl;
  final bool isMyTraining; // Флаг, что это тренировка пользователя
  // Статус оплаты текущего пользователя (если он участник тренировки)
  // Значения: pending, succeeded, canceled, waiting_for_capture, null
  final String? myPaymentStatus;

  const Training({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.type,
    this.clubId,
    required this.clubName,
    required this.clubCity,
    this.clubAddress,
    this.clubLatitude,
    this.clubLongitude,
    required this.price,
    required this.trainerName,
    this.trainerAvatar,
    this.trainerRating,
    this.trainerId,
    required this.currentParticipants,
    required this.maxParticipants,
    this.minLevel = 0.0,
    this.maxLevel = 10.0,
    required this.participantAvatars,
    this.participants = const [],
    this.backgroundImage,
    this.iconUrl,
    this.isMyTraining = false,
    this.myPaymentStatus,
  });

  factory Training.fromJson(Map<String, dynamic> json) {
    // Безопасное преобразование price в double
    double parsePrice(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Парсинг участников
    List<TrainingParticipant> parseParticipants(dynamic participantsData) {
      if (participantsData == null) return [];
      if (participantsData is! List) return [];
      return participantsData
          .map((p) => TrainingParticipant.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    final participants = parseParticipants(json['participants']);

    return Training(
      id: json['id'] ?? '',
      title: json['name'] ?? json['title'] ?? '',
      description: json['description'] ?? '',
      startTime: DateTime.parse(json['start_time'] ?? DateTime.now().toIso8601String()),
      endTime: json['end_time'] != null 
          ? DateTime.parse(json['end_time'])
          : DateTime.parse(json['start_time'] ?? DateTime.now().toIso8601String()).add(const Duration(hours: 1)),
      type: json['type'] ?? 'group',
      // Поддержка обоих форматов: прямые поля и вложенный объект club
      clubId: json['club']?['id'] ?? json['club_id'],
      clubName: json['club']?['name'] ?? json['club_name'] ?? '',
      clubCity: json['club']?['city'] ?? json['club_city'] ?? json['city'] ?? '',
      clubAddress: json['club']?['address'] ?? json['club_address'],
      clubLatitude: (json['club']?['latitude'] ?? json['club_latitude'])?.toDouble(),
      clubLongitude: (json['club']?['longitude'] ?? json['club_longitude'])?.toDouble(),
      price: parsePrice(json['price']),
      trainerName: json['coach']?['first_name'] != null && json['coach']?['last_name'] != null
          ? '${json['coach']['first_name']} ${json['coach']['last_name']}'
          : json['trainer_name'] ?? 'Тренер',
      trainerAvatar: json['coach']?['avatar_url'] ?? json['trainer_avatar'],
      trainerRating: json['coach']?['user_rating'],
      trainerId: json['coach']?['user_id'] ?? json['coach_id'],
      currentParticipants: participants.isNotEmpty
          ? participants.length
          : (json['participants_count'] ?? json['current_participants'] ?? 0),
      maxParticipants: json['max_participants'] ?? 8,
      minLevel: (json['min_level'] ?? 1.0).toDouble(),
      maxLevel: (json['max_level'] ?? 5.0).toDouble(),
      participantAvatars: participants.isNotEmpty
          ? participants.map((p) => p.avatarUrl ?? '').where((url) => url.isNotEmpty).toList()
          : List<String>.from(json['participant_avatars'] ?? []),
      participants: participants,
      backgroundImage: json['background_image'],
      iconUrl: json['icon_url'],
      isMyTraining: json['is_my_training'] ?? false,
      myPaymentStatus: json['my_payment_status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'type': type,
      'club_name': clubName,
      'club_city': clubCity,
      'club_address': clubAddress,
      'club_latitude': clubLatitude,
      'club_longitude': clubLongitude,
      'price': price,
      'trainer_name': trainerName,
      'trainer_avatar': trainerAvatar,
      'min_level': minLevel,
      'max_level': maxLevel,
      'current_participants': currentParticipants,
      'max_participants': maxParticipants,
      'participant_avatars': participantAvatars,
      'background_image': backgroundImage,
      'icon_url': iconUrl,
      'is_my_training': isMyTraining,
      'my_payment_status': myPaymentStatus,
    };
  }

  String get formattedTime {
    final hour = startTime.hour.toString().padLeft(2, '0');
    final minute = startTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get formattedDate {
    final months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    final weekdays = [
      'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'
    ];
    
    final weekday = weekdays[startTime.weekday - 1];
    final day = startTime.day;
    final month = months[startTime.month - 1];
    
    return '$weekday, $day $month';
  }

  String get typeDisplayName {
    switch (type) {
      case 'group':
        return 'Групповая';
      case 'individual':
        return 'Индивидуальная';
      default:
        return type;
    }
  }

  String get levelRange {
    // Форматируем уровни с двумя цифрами после точки
    final minFormatted = minLevel.toStringAsFixed(2);
    final maxFormatted = maxLevel.toStringAsFixed(2);
    return '$minFormatted-$maxFormatted';
  }

  bool get isGroup => type == 'group';
  bool get isIndividual => type == 'individual';
  bool get isFull => currentParticipants >= maxParticipants;
  bool get hasSpots => currentParticipants < maxParticipants;
}
