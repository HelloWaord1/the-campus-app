import 'match.dart';

// Модель города
class City {
  final String id;
  final String name;
  final String? region;

  City({
    required this.id,
    required this.name,
    this.region,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'],
      name: json['name'],
      region: json['region'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'region': region,
    };
  }
}

class CitiesResponse {
  final List<City> cities;

  CitiesResponse({
    required this.cities,
  });

  factory CitiesResponse.fromJson(List<dynamic> json) {
    return CitiesResponse(
      cities: json.map((city) => City.fromJson(city)).toList(),
    );
  }
}

class Club {
  final String id;
  final String name;
  final String? photoUrl;
  final String? city;
  final String address;
  final String? description;
  final List<String> photos;
  final double? minPrice;
  final String? phone;
  // Количество кортов (если приходит от API)
  final int? courtsCount;
  // Новые поля по дизайну (после адреса)
  final String? workSchedule;
  final bool? equipmentRental;
  final String? whatsapp;
  final String? telegram;
  final String? website;
  final String? email;
  // Новые опциональные поля для фильтров и совместимости с API
  final String? courtType; // indoor, outdoor, shaded
  final String? courtSize; // two-seater, four-seater
  final double? distanceKm; // может приходить от API при использовании геофильтров
  final double? latitude;
  final double? longitude;

  Club({
    required this.id,
    required this.name,
    this.photoUrl,
    this.city,
    required this.address,
    this.description,
    this.photos = const [],
    this.minPrice,
    this.phone,
    this.courtsCount,
    this.workSchedule,
    this.equipmentRental,
    this.whatsapp,
    this.telegram,
    this.website,
    this.email,
    this.courtType,
    this.courtSize,
    this.distanceKm,
    this.latitude,
    this.longitude,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'],
      name: json['name'],
      photoUrl: json['photo_url'],
      city: json['city'],
      address: json['address'] ?? '',
      description: json['description'],
      photos: List<String>.from(json['photos'] ?? []),
      minPrice: (json['min_price'] as num?)?.toDouble(),
      phone: json['phone'],
      courtsCount: (json['number_of_courts'] ?? json['courts_count']) as int?,
      workSchedule: json['work_schedule'] as String?,
      equipmentRental: json['has_inventory'] as bool?,
      whatsapp: json['whatsapp'] as String?,
      telegram: json['telegram'] as String?,
      website: json['website'] as String?,
      email: json['email'] as String?,
      courtType: json['court_type'],
      courtSize: json['court_size'],
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'photo_url': photoUrl,
      'city': city,
      'address': address,
      'description': description,
      'photos': photos,
      'min_price': minPrice,
      'phone': phone,
      'number_of_courts': courtsCount,
      'work_schedule': workSchedule,
      'equipment_rental': equipmentRental,
      'whatsapp': whatsapp,
      'telegram': telegram,
      'website': website,
      'email': email,
      'court_type': courtType,
      'court_size': courtSize,
      'distance_km': distanceKm,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class ClubsResponse {
  final List<Club> clubs;
  final int total;

  ClubsResponse({
    required this.clubs,
    required this.total,
  });

  factory ClubsResponse.fromJson(Map<String, dynamic> json) {
    return ClubsResponse(
      clubs: (json['clubs'] as List)
          .map((club) => Club.fromJson(club))
          .toList(),
      total: json['total'],
    );
  }
}

// Новый ответ для клубов по городу
class ClubsByCityResponse {
  final List<Club> clubs;
  final int total;

  ClubsByCityResponse({
    required this.clubs,
    required this.total,
  });

  factory ClubsByCityResponse.fromJson(Map<String, dynamic> json) {
    return ClubsByCityResponse(
      clubs: (json['clubs'] as List)
          .map((club) => Club.fromJson(club))
          .toList(),
      total: json['total'],
    );
  }
}

class MatchSearchRequest {
  final List<TimeRange> timeRanges;
  final String? city;
  final List<String>? clubIds;
  final String? format;
  final String? level;
  final bool? isPrivate;
  // Новые поля для фильтрации по времени без обязательных дат
  // dates: список дат в формате YYYY-MM-DD
  // start_time / end_time: время в формате HH:mm
  final List<String>? dates;
  final String? startTime;
  final String? endTime;

  MatchSearchRequest({
    required this.timeRanges,
    this.city,
    this.clubIds,
    this.format,
    this.level,
    this.isPrivate,
    this.dates,
    this.startTime,
    this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      if (timeRanges.isNotEmpty) 'time_ranges': timeRanges.map((range) => range.toJson()).toList(),
      if (city != null) 'city': city,
      if (clubIds != null && clubIds!.isNotEmpty) 'club_ids': clubIds,
      if (format != null) 'format': format,
      if (level != null) 'level': level,
      if (isPrivate != null) 'is_private': isPrivate,
      if (dates != null && dates!.isNotEmpty) 'dates': dates,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
    };
  }
}

class TimeRange {
  final DateTime startTime;
  final DateTime endTime;

  TimeRange({
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
    };
  }
}

class MatchSearchResponse {
  final List<Match> matches;
  final int totalCount;
  final Map<String, dynamic> filtersApplied;

  MatchSearchResponse({
    required this.matches,
    required this.totalCount,
    required this.filtersApplied,
  });

  factory MatchSearchResponse.fromJson(Map<String, dynamic> json) {
    return MatchSearchResponse(
      matches: (json['matches'] as List)
          .map((match) => Match.fromJson(match))
          .toList(),
      totalCount: json['total_count'],
      filtersApplied: json['filters_applied'],
    );
  }
} 