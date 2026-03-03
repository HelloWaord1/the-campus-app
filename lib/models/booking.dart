// Модели для работы с бронированиями кортов

class Booking {
  final String id;
  final String clubId;
  final String? courtId;
  final String? courtName;
  final String clubName;
  final String? clubPhotoUrl;
  final String? clubCity;
  final DateTime bookingDate;
  final String startTime;
  final int durationMin;
  final String userId;
  final String userName;
  final String status; // pending, confirmed, cancelled, completed
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? price;
  final String? courtPaymentId; // Ссылка на запись об оплате
  // Опциональные поля из court_payment (для отображения, заполняются через JOIN)
  final String? paymentUrl;
  final String? paymentId;
  final String? paymentStatus;
  final double? amount; // Сумма оплаты в рублях

  Booking({
    required this.id,
    required this.clubId,
    this.courtId,
    this.courtName,
    required this.clubName,
    this.clubPhotoUrl,
    this.clubCity,
    required this.bookingDate,
    required this.startTime,
    required this.durationMin,
    required this.userId,
    required this.userName,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.price,
    this.courtPaymentId,
    this.paymentUrl,
    this.paymentId,
    this.paymentStatus,
    this.amount,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    // Объединяем first_name и last_name в user_name
    String userName = '';
    if (json['first_name'] != null && json['last_name'] != null) {
      userName = '${json['first_name']} ${json['last_name']}';
    } else if (json['first_name'] != null) {
      userName = json['first_name'];
    } else if (json['last_name'] != null) {
      userName = json['last_name'];
    } else if (json['user_first_name'] != null && json['user_last_name'] != null) {
      // Fallback для старого формата
      userName = '${json['user_first_name']} ${json['user_last_name']}';
    } else if (json['user_name'] != null) {
      // Fallback для обратной совместимости
      userName = json['user_name'];
    }
    
    return Booking(
      id: json['id'] ?? '',
      clubId: json['club_id'] ?? '',
      courtId: json['court_id'],
      courtName: json['court_name'],
      clubName: json['club_name'] ?? '',
      clubPhotoUrl: json['club_photo_url'],
      clubCity: json['club_city'],
      bookingDate: DateTime.parse(json['booking_date'] ?? DateTime.now().toIso8601String()),
      startTime: json['start_time'] ?? '',
      durationMin: json['duration_min'] ?? 60,
      userId: json['user_id'] ?? '',
      userName: userName.isNotEmpty ? userName : 'Пользователь',
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      price: json['price']?.toDouble(),
      courtPaymentId: json['court_payment_id'],
      paymentUrl: json['payment_url'],
      paymentId: json['payment_id'],
      paymentStatus: json['payment_status'],
      amount: json['amount']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'club_id': clubId,
      'court_id': courtId,
      'court_name': courtName,
      'club_name': clubName,
      'club_photo_url': clubPhotoUrl,
      'club_city': clubCity,
      'booking_date': bookingDate.toIso8601String(),
      'start_time': startTime,
      'duration_min': durationMin,
      'user_id': userId,
      'user_name': userName,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'price': price,
      'court_payment_id': courtPaymentId,
      'payment_url': paymentUrl,
      'payment_id': paymentId,
      'payment_status': paymentStatus,
      'amount': amount,
    };
  }
}

class BookingCreate {
  final String clubId;
  final String? courtId;
  final DateTime bookingDate;
  final String startTime;
  final int durationMin;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final String? whatsapp;
  final String? telegram;

  BookingCreate({
    required this.clubId,
    this.courtId,
    required this.bookingDate,
    required this.startTime,
    required this.durationMin,
    this.firstName,
    this.lastName,
    this.phone,
    this.email,
    this.whatsapp,
    this.telegram,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'club_id': clubId,
      'booking_date': bookingDate.toIso8601String().split('T')[0], // Только дата
      'start_time': startTime,
      'duration_min': durationMin,
    };
    
    // Имя клиента (для YCLIENTS/чеков). Отправляем, только если задано.
    if (firstName != null && firstName!.trim().isNotEmpty) data['first_name'] = firstName!.trim();
    if (lastName != null && lastName!.trim().isNotEmpty) data['last_name'] = lastName!.trim();

    // Добавляем court_id если указан
    if (courtId != null && courtId!.isNotEmpty) {
      data['court_id'] = courtId;
    }
    
    // Добавляем контактную информацию только если она предоставлена
    if (phone != null && phone!.isNotEmpty) data['phone'] = phone;
    if (email != null && email!.isNotEmpty) data['email'] = email;
    if (whatsapp != null && whatsapp!.isNotEmpty) data['whatsapp'] = whatsapp;
    if (telegram != null && telegram!.isNotEmpty) data['telegram'] = telegram;
    
    return data;
  }
}

class BookingCancel {
  final String bookingId;

  BookingCancel({
    required this.bookingId,
  });

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
    };
  }
}

class BookingListResponse {
  final List<Booking> bookings;
  final int total;

  BookingListResponse({
    required this.bookings,
    required this.total,
  });

  factory BookingListResponse.fromJson(Map<String, dynamic> json) {
    return BookingListResponse(
      bookings: (json['bookings'] as List)
          .map((booking) => Booking.fromJson(booking))
          .toList(),
      total: json['total'] ?? 0,
    );
  }
} 