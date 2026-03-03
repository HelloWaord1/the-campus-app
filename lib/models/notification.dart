// no external imports

class NotificationItemV2 {
  final String id;
  final String? recipientUserId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final String? actorUserId;
  final String entityType;
  final String? entityId;
  final String? imageUrl;
  final String? deepLink;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isRead;

  NotificationItemV2({
    required this.id,
    this.recipientUserId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.actorUserId,
    required this.entityType,
    this.entityId,
    this.imageUrl,
    this.deepLink,
    required this.createdAt,
    this.readAt,
    required this.isRead,
  });

  factory NotificationItemV2.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    Map<String, dynamic>? parsedData;
    if (rawData is Map) {
      parsedData = Map<String, dynamic>.from(rawData as Map);
    }
    return NotificationItemV2(
      id: json['id'] ?? '',
      recipientUserId: json['recipient_user_id'],
      type: json['type'] ?? 'generic_info',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: parsedData,
      actorUserId: json['actor_user_id'],
      entityType: json['entity_type'] ?? 'user',
      entityId: json['entity_id'],
      imageUrl: json['image_url'],
      deepLink: json['deep_link'],
      createdAt: _parseDate(json['created_at']),
      readAt: _tryParseDate(json['read_at']),
      isRead: (json['is_read'] ?? (json['read_at'] != null)) == true,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }
    return DateTime.now();
  }

  static DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    try {
      if (value is String && value.isNotEmpty) {
        return DateTime.parse(value);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class NotificationsResponseV2 {
  final List<NotificationItemV2> notifications;

  NotificationsResponseV2({required this.notifications});

  factory NotificationsResponseV2.fromJson(Map<String, dynamic> json) {
    final raw = (json['notifications'] as List? ) ?? const [];
    return NotificationsResponseV2(
      notifications: raw
          .map((n) => NotificationItemV2.fromJson(Map<String, dynamic>.from(n)))
          .toList(),
    );
  }
}


