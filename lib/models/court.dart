// Модель для корта в клубе
class Court {
  final String id;
  final String clubId;
  final String name;
  final String openTime; // Формат "08:00"
  final String closeTime; // Формат "22:00"
  final double pricePerHour;

  Court({
    required this.id,
    required this.clubId,
    required this.name,
    required this.openTime,
    required this.closeTime,
    required this.pricePerHour,
  });

  factory Court.fromJson(Map<String, dynamic> json) {
    return Court(
      id: json['id'] ?? '',
      clubId: json['club_id'] ?? '',
      name: json['name'] ?? '',
      openTime: json['open_time'] ?? '08:00',
      closeTime: json['close_time'] ?? '22:00',
      pricePerHour: (json['price_per_hour'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'club_id': clubId,
      'name': name,
      'open_time': openTime,
      'close_time': closeTime,
      'price_per_hour': pricePerHour,
    };
  }
}

// Ответ со списком кортов
class CourtsResponse {
  final List<Court> courts;
  final int total;

  CourtsResponse({
    required this.courts,
    required this.total,
  });

  factory CourtsResponse.fromJson(Map<String, dynamic> json) {
    return CourtsResponse(
      courts: (json['courts'] as List? ?? [])
          .map((court) => Court.fromJson(court))
          .toList(),
      total: json['total'] ?? 0,
    );
  }
}

// Информация о доступном слоте времени для корта
class TimeSlot {
  final String time; // Формат "08:00"
  final bool isAvailable;
  final List<String> availableCourtIds; // ID кортов, доступных в это время

  TimeSlot({
    required this.time,
    required this.isAvailable,
    required this.availableCourtIds,
  });
}

