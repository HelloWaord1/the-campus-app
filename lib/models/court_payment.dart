// Модель для работы с оплатами бронирований кортов

class CourtPayment {
  final String id;
  final String paymentId; // ID платежа в ЮКассе
  final String? paymentUrl;
  final String? paymentStatus;
  final double amount; // Сумма оплаты в рублях
  final String userId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CourtPayment({
    required this.id,
    required this.paymentId,
    this.paymentUrl,
    this.paymentStatus,
    required this.amount,
    required this.userId,
    required this.createdAt,
    this.updatedAt,
  });

  factory CourtPayment.fromJson(Map<String, dynamic> json) {
    return CourtPayment(
      id: json['id'] ?? '',
      paymentId: json['payment_id'] ?? '',
      paymentUrl: json['payment_url'],
      paymentStatus: json['payment_status'],
      amount: (json['amount'] ?? 0).toDouble(),
      userId: json['user_id'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payment_id': paymentId,
      'payment_url': paymentUrl,
      'payment_status': paymentStatus,
      'amount': amount,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

