import 'match.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String passwordHash;
  final String city;
  final String? avatarUrl;
  final String? currentRating;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.passwordHash,
    required this.city,
    this.avatarUrl,
    this.currentRating,
  
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
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
    
    return User(
      id: json['id'] ?? '',
      name: name,
      email: json['email'] ?? '',
      phone: json['phone'],
      passwordHash: json['password_hash'] ?? '',
      city: json['city'] ?? '',
      avatarUrl: json['avatar_url'],
      currentRating: json['current_rating'],
      status: json['status'] ?? 'active',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'password_hash': passwordHash,
      'city': city,
      'avatar_url': avatarUrl,
      'current_rating': currentRating,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class AuthResponse {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final User user;

  AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'],
      tokenType: json['token_type'],
      expiresIn: json['expires_in'] ?? 0,
      user: User.fromJson(json['user']),
    );
  }
}

class RegisterRequest {
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String? phone;
  final String city;
  final String skillLevel;
  final int currentRating;
  final String? preferredHand; // Добавляем поле

  RegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    this.phone,
    required this.city,
    required this.skillLevel,
    required this.currentRating,
    this.preferredHand, // Добавляем в конструктор
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
      'city': city,
      'skill_level': skillLevel,
      'current_rating': currentRating,
    };
    
    if (phone != null) data['phone'] = phone;
    if (preferredHand != null) data['preferred_hand'] = preferredHand;
    
    return data;
  }
}

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'login': email,
      'password': password,
    };
  }
}

class ForgotPasswordRequest {
  final String email;

  ForgotPasswordRequest({
    required this.email,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
    };
  }
}

// Новые классы для работы с телефоном

class PhoneInitRequest {
  final String phone;

  PhoneInitRequest({
    required this.phone,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
    };
  }
}

class PhoneInitResponse {
  final bool success;
  final String message;
  final String phone;
  final int expiresIn;

  PhoneInitResponse({
    required this.success,
    required this.message,
    required this.phone,
    required this.expiresIn,
  });

  factory PhoneInitResponse.fromJson(Map<String, dynamic> json) {
    return PhoneInitResponse(
      success: json['success'],
      message: json['message'],
      phone: json['phone'],
      expiresIn: json['expires_in'] ?? 0,
    );
  }
}

class PhoneCompleteRequest {
  final String phone;
  final String code;
  final String name;
  final String city;

  PhoneCompleteRequest({
    required this.phone,
    required this.code,
    required this.name,
    required this.city,
    String? skillLevel, // Игнорируем этот параметр для совместимости
  });

  Map<String, dynamic> toJson() {
    // Разделяем имя на first_name и last_name
    final nameParts = name.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    
    return {
      'phone': phone,
      'code': code,
      'first_name': firstName,
      'last_name': lastName,
      'city': city,
      'skill_level': 'любитель', // Значение по умолчанию
    };
  }
}

class PhoneLoginRequest {
  final String phone; // номер телефона
  final String code; // SMS код вместо пароля

  PhoneLoginRequest({
    required this.phone,
    required this.code,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'code': code,
    };
  }
}

// Модель профиля пользователя для GET /api/profile
class UserProfile {
  final String name;
  final String? email;
  final String? phone;
  final String city;
  final String? avatarUrl;
  final String? bio;
  final String? preferredHand;
  final DateTime createdAt;
  final int wins;
  final int defeats;
  final int totalMatches;
  final double winRate;
  final int friendsCount;
  final int? reliability;
  final int pendingReviewCount;
  final int? currentRating; // Текущий рейтинг пользователя
  final List<RatingHistoryItem> ratingHistory;
  final List<Match> upcomingMatches;
  final List<Match> pastMatches;
  final int totalUpcomingMatches;
  final int totalPastMatches;

  UserProfile({
    required this.name,
    this.email,
    this.phone,
    required this.city,
    this.avatarUrl,
    this.bio,
    this.preferredHand,
    required this.createdAt,
    required this.wins,
    required this.defeats,
    required this.totalMatches,
    required this.winRate,
    required this.friendsCount,
    this.reliability,
    this.pendingReviewCount = 0,
    this.currentRating,
    this.ratingHistory = const [],
    this.upcomingMatches = const [],
    this.pastMatches = const [],
    this.totalUpcomingMatches = 0,
    this.totalPastMatches = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
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
    
    return UserProfile(
      name: name,
      email: json['email'],
      phone: json['phone'],
      city: json['city'] ?? '',
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      preferredHand: json['preferred_hand'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      wins: json['wins'] ?? 0,
      defeats: json['defeats'] ?? 0,
      totalMatches: json['total_matches'] ?? 0,
      winRate: (json['win_rate'] ?? 0.0).toDouble(),
      friendsCount: json['friends_count'] ?? 0,
      reliability: json['reliability'],
      pendingReviewCount: json['pending_review_count'] ?? 0,
      currentRating: json['current_rating'],
      ratingHistory: (json['rating_history'] as List?)?.map((item) => RatingHistoryItem.fromJson(item)).toList() ?? [],
      upcomingMatches: (json['upcoming_matches'] as List?)?.map((item) => Match.fromJson(item)).toList() ?? [],
      pastMatches: (json['past_matches'] as List?)?.map((item) => Match.fromJson(item)).toList() ?? [],
      totalUpcomingMatches: json['total_upcoming_matches'] ?? 0,
      totalPastMatches: json['total_past_matches'] ?? 0,
    );
  }

  // Получить контактную информацию (email или телефон)
  String? get contactInfo {
    if (email != null && email!.isNotEmpty) {
      return email;
    }
    if (phone != null && phone!.isNotEmpty) {
      return phone;
    }
    return null;
  }

  // Получить тип контакта
  String get contactType {
    if (email != null && email!.isNotEmpty) {
      return 'email';
    }
    if (phone != null && phone!.isNotEmpty) {
      return 'phone';
    }
    return 'unknown';
  }

  // Получить время с момента регистрации
  String get membershipDuration {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays >= 365) {
      final years = (difference.inDays / 365).floor();
      return _pluralizeYears(years);
    } else if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return _pluralizeMonths(months);
    } else {
      return _pluralizeDays(difference.inDays);
    }
  }

  String _pluralizeYears(int years) {
    if (years % 10 == 1 && years % 100 != 11) {
      return '$years год';
    } else if ([2, 3, 4].contains(years % 10) && ![12, 13, 14].contains(years % 100)) {
      return '$years года';
    } else {
      return '$years лет';
    }
  }

  String _pluralizeMonths(int months) {
    if (months % 10 == 1 && months % 100 != 11) {
      return '$months месяц';
    } else if ([2, 3, 4].contains(months % 10) && ![12, 13, 14].contains(months % 100)) {
      return '$months месяца';
    } else {
      return '$months месяцев';
    }
  }

  String _pluralizeDays(int days) {
    if (days % 10 == 1 && days % 100 != 11) {
      return '$days день';
    } else if ([2, 3, 4].contains(days % 10) && ![12, 13, 14].contains(days % 100)) {
      return '$days дня';
    } else {
      return '$days дней';
    }
  }

  // Получить отображаемую предпочтительную руку
  String get displayPreferredHand {
    if (preferredHand == null) return 'Правая';
    switch (preferredHand!.toLowerCase()) {
      case 'left':
        return 'Левая';
      case 'right':
        return 'Правая';
      case 'both':
        return 'Обе';
      default:
        return 'Правая';
    }
  }
}

class Friend {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String city;
  final String? avatarUrl;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Friend({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.city,
    this.avatarUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
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
    
    return Friend(
      id: json['id'] ?? '',
      name: name,
      email: json['email'] ?? '',
      phone: json['phone'],
      city: json['city'] ?? '',
      avatarUrl: json['avatar_url'],
      status: json['status'] ?? 'active',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'city': city,
      'avatar_url': avatarUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class FriendsResponse {
  final List<Friend> friends;

  FriendsResponse({
    required this.friends,
  });

  factory FriendsResponse.fromJson(List<dynamic> json) {
    return FriendsResponse(
      friends: List<Friend>.from(json.map((x) => Friend.fromJson(x))),
    );
  }
}

// Модели для работы с друзьями
class FriendItem {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? userStatus; // active/blocked/deleted/pending

  FriendItem({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.userStatus,
  });

  factory FriendItem.fromJson(Map<String, dynamic> json) {
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
    
    return FriendItem(
      id: json['id'],
      name: name,
      avatarUrl: json['avatar_url'],
      userStatus: json['user_status'],
    );
  }

  bool get isDeleted => (userStatus?.toLowerCase() == 'deleted');
}

class FriendsApiResponse {
  final List<FriendItem> friends;
  final int totalCount;
  final int pendingRequestsCount;

  FriendsApiResponse({
    required this.friends,
    required this.totalCount,
    required this.pendingRequestsCount,
  });

  factory FriendsApiResponse.fromJson(Map<String, dynamic> json) {
    return FriendsApiResponse(
      friends: (json['friends'] as List)
          .map((item) => FriendItem.fromJson(item))
          .toList(),
      totalCount: json['total_count'] ?? 0,
      pendingRequestsCount: json['pending_requests_count'] ?? 0,
    );
  }
}

// Новые модели для заявок в друзья
class FriendRequest {
  final String friendshipId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String? userStatus; // active/blocked/deleted/pending
  final int? currentRating;
  final DateTime createdAt;

  FriendRequest({
    required this.friendshipId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    this.userStatus,
    this.currentRating,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    // Объединяем user_first_name и user_last_name в user_name
    String userName = '';
    if (json['user_first_name'] != null && json['user_last_name'] != null) {
      userName = '${json['user_first_name']} ${json['user_last_name']}';
    } else if (json['user_first_name'] != null) {
      userName = json['user_first_name'];
    } else if (json['user_last_name'] != null) {
      userName = json['user_last_name'];
    } else if (json['user_name'] != null) {
      // Fallback для обратной совместимости
      userName = json['user_name'];
    }
    
    return FriendRequest(
      friendshipId: json['friendship_id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: userName,
      userAvatarUrl: json['user_avatar_url'],
      userStatus: json['user_status'],
      currentRating: json['current_rating'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  bool get isDeleted => (userStatus?.toLowerCase() == 'deleted');
  
  // Метод для получения отформатированного рейтинга
  String get formattedRating {
    if (currentRating == null) return '—';
    
    // Используем единую функцию расчета рейтинга
    final rating = _calculateRating(currentRating!);
    final letter = _ratingToLetter(rating);
    return '$letter ${rating.toStringAsFixed(2)}';
  }
  
  // Локальная копия calculateRating для избежания циклических зависимостей
  static double _calculateRating(int score) {
    if (score < 600) return 1.0;
    if (score > 2000) return 5.0;
    
    // Равномерная шкала: 600 -> 1.00, 2000 -> 5.00
    return 1.0 + (score - 600) * 4.0 / (2000 - 600);
  }
  
  // Преобразует числовой рейтинг в буквенное обозначение
  static String _ratingToLetter(double rating) {
    if (rating < 3.0) return 'D';
    if (rating < 4.0) return 'C';
    if (rating < 5.0) return 'B';
    return 'A';
  }
}

class FriendRequestsResponse {
  final List<FriendRequest> requests;
  final int totalCount;

  FriendRequestsResponse({
    required this.requests,
    required this.totalCount,
  });

  factory FriendRequestsResponse.fromJson(Map<String, dynamic> json) {
    return FriendRequestsResponse(
      requests: (json['requests'] as List)
          .map((item) => FriendRequest.fromJson(item))
          .toList(),
      totalCount: json['total_count'] ?? 0,
    );
  }
}

class FriendActionResponse {
  final String message;
  final String status;
  final String? friendshipId;

  FriendActionResponse({
    required this.message,
    required this.status,
    this.friendshipId,
  });

  factory FriendActionResponse.fromJson(Map<String, dynamic> json) {
    return FriendActionResponse(
      message: json['message'] ?? 'Операция выполнена успешно',
      status: json['status'] ?? 'success',
      friendshipId: json['friendship_id'],
    );
  }
}

// Модели для уведомлений
class NotificationItem {
  final String id;
  final String notificationText;
  final DateTime notificationCreationDate;

  NotificationItem({
    required this.id,
    required this.notificationText,
    required this.notificationCreationDate,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? '',
      notificationText: json['notification_text'] ?? '',
      notificationCreationDate: DateTime.parse(json['notification_creation_date'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Проверяем, является ли уведомление запросом в друзья
  bool get isFriendRequest {
    // Проверяем русские варианты
    if (notificationText.contains('запрос в дружбы') || 
        notificationText.contains('заявку в друзья') ||
        notificationText.contains('принял ваш запрос') ||
        notificationText.contains('отправил вам запрос')) {
      return true;
    }
    
    // Проверяем английские варианты
    if (notificationText.contains('Friend Request') ||
        notificationText.contains('friend request') ||
        notificationText.contains('New Friend Request') ||
        notificationText.contains('Friend Request Accepted')) {
      return true;
    }
    
    return false;
  }

  // Получаем имя пользователя из текста уведомления (если это запрос в друзья)
  String? get friendRequestUserName {
    if (!isFriendRequest) return null;
    
    // Попытка извлечь имя из текста типа "Иван Иванов отправил вам запрос в дружбы"
    final regex = RegExp(r'^(.+?) отправил');
    final match = regex.firstMatch(notificationText);
    return match?.group(1);
  }

  // Форматирование времени уведомления
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(notificationCreationDate);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} дн. назад';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ч. назад';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} мин. назад';
    } else {
      return 'Только что';
    }
  }
}

class NotificationsResponse {
  final List<NotificationItem> notifications;

  NotificationsResponse({
    required this.notifications,
  });

  factory NotificationsResponse.fromJson(Map<String, dynamic> json) {
    return NotificationsResponse(
      notifications: (json['notifications'] as List)
          .map((item) => NotificationItem.fromJson(item))
          .toList(),
    );
  }
}

// Модели для поиска пользователей
class SearchUser {
  final String id;
  final String name;
  final String? avatarUrl;
  final String city;

  SearchUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.city,
  });

  factory SearchUser.fromJson(Map<String, dynamic> json) {
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
    
    return SearchUser(
      id: json['id'] ?? '',
      name: name.isNotEmpty ? name : 'Неизвестный пользователь',
      avatarUrl: json['avatar_url'],
      city: json['city'] ?? 'Город не указан',
    );
  }
}

class SearchUsersResponse {
  final List<SearchUser> users;
  final int totalCount;
  final String? searchQuery;

  SearchUsersResponse({
    required this.users,
    required this.totalCount,
    this.searchQuery,
  });

  factory SearchUsersResponse.fromJson(Map<String, dynamic> json) {
    return SearchUsersResponse(
      users: (json['users'] as List)
          .map((item) => SearchUser.fromJson(item))
          .toList(),
      totalCount: json['total_count'] ?? 0,
      searchQuery: json['search_query'],
    );
  }
}

// Модель для статуса дружбы
class FriendshipStatusResponse {
  final String userId;
  final String targetUserId;
  final String status;
  final String message;

  FriendshipStatusResponse({
    required this.userId,
    required this.targetUserId,
    required this.status,
    required this.message,
  });

  factory FriendshipStatusResponse.fromJson(Map<String, dynamic> json) {
    return FriendshipStatusResponse(
      userId: json['user_id'],
      targetUserId: json['target_user_id'],
      status: json['status'],
      message: json['message'],
    );
  }

  // Новые статусы дружбы
  bool get isNone => status == 'none';           // Нет связи - показываем кнопку "Добавить в друзья"
  bool get isSent => status == 'sent';           // Запрос отправлен - показываем серую кнопку "Запрос отправлен"
  bool get isWaiting => status == 'waiting';     // Ждем принятия - показываем кнопку "Принять приглашение"
  bool get isAccepted => status == 'accepted';   // Друзья - показываем кнопки "Пригласить в матч" и "Удалить из друзей"
  
  // Устаревшие статусы для обратной совместимости
  bool get isPending => status == 'pending' || status == 'sent';
  bool get isRejected => status == 'rejected';
}

// Модель рейтинга пользователя для /api/ratings/current
class UserRatingResponse {
  final String? ntrpLevel; // Например: D 1.5 или A
  final double? rating;   // Числовой рейтинг
  final String? ntrpDescription;

  UserRatingResponse({
    this.ntrpLevel,
    this.rating,
    this.ntrpDescription,
  });

  factory UserRatingResponse.fromJson(Map<String, dynamic> json) {
    print('📊 UserRatingResponse.fromJson: Parsing JSON: $json');
    
    final ntrpLevel = json['ntrp_level'];
    final currentRating = json['current_rating'];
    final ntrpDescription = json['ntrp_description'];
    
    print('📊 UserRatingResponse.fromJson: ntrp_level=$ntrpLevel (${ntrpLevel.runtimeType})');
    print('📊 UserRatingResponse.fromJson: current_rating=$currentRating (${currentRating.runtimeType})');
    print('📊 UserRatingResponse.fromJson: ntrp_description=$ntrpDescription');
    
    double? rating;
    if (currentRating != null) {
      try {
        rating = (currentRating as num).toDouble();
        print('📊 UserRatingResponse.fromJson: Successfully converted rating to double: $rating');
      } catch (e) {
        print('❌ UserRatingResponse.fromJson: Error converting rating to double: $e');
        print('💡 Original value: $currentRating (${currentRating.runtimeType})');
        rating = null;
      }
    }
    
    final result = UserRatingResponse(
      ntrpLevel: ntrpLevel,
      rating: rating,
      ntrpDescription: ntrpDescription,
    );
    
    print('📊 UserRatingResponse.fromJson: Created object with rating=${result.rating}');
    return result;
  }
}

// Модель для элемента истории рейтинга
class RatingHistoryItem {
  final String id;
  final int? ratingBefore;
  final int ratingAfter;
  final int? ratingChange;
  final String changeReason;
  final String? opponentId;
  final String? opponentName;
  final int? opponentRating;
  final String? matchId;
  final DateTime createdAt;

  RatingHistoryItem({
    required this.id,
    this.ratingBefore,
    required this.ratingAfter,
    this.ratingChange,
    required this.changeReason,
    this.opponentId,
    this.opponentName,
    this.opponentRating,
    this.matchId,
    required this.createdAt,
  });

  factory RatingHistoryItem.fromJson(Map<String, dynamic> json) {
    int? _parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim());
      return null;
    }

    // Объединяем opponent_first_name и opponent_last_name в opponent_name
    String opponentName = '';
    if (json['opponent_first_name'] != null && json['opponent_last_name'] != null) {
      opponentName = '${json['opponent_first_name']} ${json['opponent_last_name']}';
    } else if (json['opponent_first_name'] != null) {
      opponentName = json['opponent_first_name'];
    } else if (json['opponent_last_name'] != null) {
      opponentName = json['opponent_last_name'];
    } else if (json['opponent_name'] != null) {
      // Fallback для обратной совместимости
      opponentName = json['opponent_name'];
    }
    
    return RatingHistoryItem(
      id: json['id'] ?? '',
      ratingBefore: _parseInt(json['rating_before'] ?? json['ratingBefore']),
      ratingAfter: _parseInt(json['rating_after'] ?? json['ratingAfter']) ?? 0,
      ratingChange: _parseInt(json['rating_change'] ?? json['ratingChange']),
      changeReason: (json['change_reason'] ?? json['changeReason']) ?? 'Неизвестная причина',
      opponentId: json['opponent_id'] ?? json['opponentId'],
      opponentName: opponentName.isNotEmpty ? opponentName : null,
      opponentRating: _parseInt(json['opponent_rating'] ?? json['opponentRating']),
      matchId: json['match_id'] ?? json['matchId'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
} 

class UserYandexCallbackResponse {
  final bool firstTime;
  final AuthResponse? auth;

  UserYandexCallbackResponse({
    required this.firstTime,
    required this.auth,
  });

  factory UserYandexCallbackResponse.fromJson(Map<String, dynamic> json) {
    return UserYandexCallbackResponse(
      firstTime: json["first_time"],
      auth: json['auth'] != null ? AuthResponse.fromJson(json['auth']) : null,
    );
  }
}

class UserVkCallbackResponse {
  final bool firstTime;
  final AuthResponse? auth;

  UserVkCallbackResponse({
    required this.firstTime,
    required this.auth,
  });

  factory UserVkCallbackResponse.fromJson(Map<String, dynamic> json) {
    return UserVkCallbackResponse(
      firstTime: json["first_time"],
      auth: json['auth'] != null ? AuthResponse.fromJson(json['auth']) : null,
    );
  }
}

class UserAppleCallbackResponse {
  final bool firstTime;
  final AuthResponse? auth;

  UserAppleCallbackResponse({
    required this.firstTime,
    required this.auth,
  });

  factory UserAppleCallbackResponse.fromJson(Map<String, dynamic> json) {
    return UserAppleCallbackResponse(
      firstTime: json['first_time'] ?? false,
      auth: json['auth'] != null ? AuthResponse.fromJson(json['auth']) : null,
    );
  }
}

// Модели для работы с контактными данными
class ContactData {
  final String? contactPhone;
  final String? whatsapp;
  final String? telegram;

  ContactData({
    this.contactPhone,
    this.whatsapp,
    this.telegram,
  });

  factory ContactData.fromJson(Map<String, dynamic> json) {
    return ContactData(
      contactPhone: json['contact_phone'],
      whatsapp: json['whatsapp'],
      telegram: json['telegram'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contact_phone': contactPhone,
      'whatsapp': whatsapp,
      'telegram': telegram,
    };
  }
}

class ContactUpdateRequest {
  final String? contactPhone;
  final String? whatsapp;
  final String? telegram;

  ContactUpdateRequest({
    this.contactPhone,
    this.whatsapp,
    this.telegram,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (contactPhone != null) data['contact_phone'] = contactPhone;
    if (whatsapp != null) data['whatsapp'] = whatsapp;
    if (telegram != null) data['telegram'] = telegram;
    return data;
  }
}