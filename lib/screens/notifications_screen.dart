import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import '../models/notification.dart';
import '../widgets/user_avatar.dart';
import '../services/api_service.dart';
import 'match_details_screen.dart';
import 'public_profile_screen.dart';
import 'competition_details_screen.dart';
import 'notification_settings_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItemV2> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, String> _actorNames = {}; // userId -> name
  final Set<String> _actorNamesLoading = {}; // in-flight
  // Регулятор дополнительного отступа под «чёлку». Меняй по вкусу (px)
  static const double _appBarTopInset = 58.0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getNotificationsV2();
      final items = List<NotificationItemV2>.from(response.notifications);
      // Сортируем по убыванию времени
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: AppBar(
            toolbarHeight: 44 + _appBarTopInset,
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            centerTitle: true,
            title: const Padding(
              padding: EdgeInsets.only(top: _appBarTopInset),
              child: Text(
                'Уведомления',
                style: TextStyle(
		       color: Colors.black, 
		       fontSize: 18, 
 		       fontWeight: FontWeight.w500,
		       letterSpacing: -0.36,
		),
              ),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFE7E9EB)),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(top: _appBarTopInset),
                child: IconButton(
                  icon: SvgPicture.asset(
                    'assets/images/settings_notifications.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(Color(0xFF89867E), BlendMode.srcIn),
                  ),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                    );
                    // После возврата обновляем список уведомлений
                    if (mounted) {
                      _loadNotifications();
                    }
                  },
                  tooltip: 'Настройки уведомлений',
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Container(
          color: Colors.white,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.green,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ошибка загрузки уведомлений',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 60),
              Text(
                'Уведомлений нет',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF222223),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Вы в курсе последних событий!'
                ,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF222223),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = _groupByDate(_notifications);
    final hasUnread = _notifications.any((n) => !n.isRead);

    return Stack(
      children: [
        RefreshIndicator(
          color: const Color(0xFF00897B),
          onRefresh: _loadNotifications,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 120), // место под кнопку
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final group = grouped[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.label,
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF222223),
                      letterSpacing: -0.36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F5F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < group.notifications.length; i++)
                          _buildNotificationItem(
                            group.notifications[i],
                            isLast: i == group.notifications.length - 1,
                          ),
                      ],
                    ),
                  ),
                  if (index != grouped.length - 1) const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 10, // над нижней панелью
          child: Center(
            child: ElevatedButton(
              onPressed: hasUnread
                  ? () async {
                      try {
                        await ApiService.markAllNotificationsReadV2();
                        setState(() {
                          _notifications = _notifications
                              .map((n) => NotificationItemV2(
                                    id: n.id,
                                    recipientUserId: n.recipientUserId,
                                    type: n.type,
                                    title: n.title,
                                    body: n.body,
                                    actorUserId: n.actorUserId,
                                    entityType: n.entityType,
                                    entityId: n.entityId,
                                    imageUrl: n.imageUrl,
                                    deepLink: n.deepLink,
                                    createdAt: n.createdAt,
                                    readAt: DateTime.now(),
                                    isRead: true,
                                  ))
                              .toList();
                        });
                      } catch (_) {}
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasUnread ? const Color(0xFF00897B) : const Color(0xFF7F8AC0),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF7F8AC0),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                elevation: 0,
              ),
              child: const Text('Прочитать всё', style: TextStyle(
                fontFamily: "SF Pro Display", 
                fontSize: 16, 
                fontWeight: FontWeight.w500, 
                letterSpacing: -0.75,
                color: Colors.white,
              )),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationItem(NotificationItemV2 notification, {bool isLast = false}) {
    // Обеспечим подгрузку имени актёра для инициалов
    _ensureActorNameLoaded(notification.actorUserId);
    final displayName = _actorNames[notification.actorUserId] ?? 'Пользователь';

    // Для match_updated строим локализованный текст (toLocal()) из payload data,
    // чтобы время матча показывалось так же, как на странице матчей.
    String titleText = notification.title;
    String bodyText = notification.body;

    DateTime? _parseIsoLocal(dynamic v) {
      if (v is String && v.trim().isNotEmpty) {
        try {
          return DateTime.parse(v).toLocal();
        } catch (_) {}
      }
      return null;
    }

    String _ruDayMonth(DateTime dt) {
      const months = [
        'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
        'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    }

    String _hhmm(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (notification.type == 'match_updated' && notification.data != null) {
      final d = notification.data!;
      final oldMap = (d['old'] is Map) ? Map<String, dynamic>.from(d['old']) : <String, dynamic>{};
      final newMap = (d['new'] is Map) ? Map<String, dynamic>.from(d['new']) : <String, dynamic>{};

      final oldDt = _parseIsoLocal(oldMap['date_time']);
      final newDt = _parseIsoLocal(newMap['date_time']);
      final oldClub = (oldMap['club_name'] ?? newMap['club_name'] ?? 'Матч').toString().trim();
      final oldCity = (oldMap['city'] ?? newMap['city'] ?? '').toString().trim();

      if (oldDt != null) {
        final parts = <String>[
          oldClub,
          if (oldCity.isNotEmpty) oldCity,
          _ruDayMonth(oldDt),
          _hhmm(oldDt),
        ];
        titleText = 'Изменения матча ${parts.join(' ')}:';
      }

      // Если есть newDt и сервер не прислал body/или прислал "старый" — покажем локальный вариант изменения времени
      if (newDt != null && oldDt != null) {
        final lines = <String>[];
        if (_ruDayMonth(oldDt) != _ruDayMonth(newDt)) {
          lines.add('Дата изменена на ${_ruDayMonth(newDt)}');
        }
        if (_hhmm(oldDt) != _hhmm(newDt)) {
          lines.add('Время изменено на ${_hhmm(newDt)}');
        }
        // Остальные строки оставляем как пришли с сервера (клуб/бронь/приватность/корт),
        // чтобы не дублировать бизнес-логику. Если сервер уже прислал body, но в нём нет
        // time/date — добавим сверху.
        final serverLines = notification.body.trim().isNotEmpty ? notification.body.trim().split('\n') : <String>[];
        for (final l in serverLines) {
          if (l.trim().isEmpty) continue;
          // Сервер может уже прислать строки про дату/время, но в другом часовом поясе.
          // Чтобы не было дублей и "неправильного" времени, оставляем только локально посчитанные.
          final normalized = l.trim().toLowerCase();
          if (normalized.startsWith('время измен') || normalized.startsWith('дата измен')) {
            continue;
          }
          if (!lines.contains(l.trim())) lines.add(l.trim());
        }
        bodyText = lines.join('\n');
      }
    }

    // match_invitation: формируем локальный заголовок/текст как у изменений матча
    if (notification.type == 'match_invitation' && notification.data != null) {
      final d = notification.data!;
      final matchMap = (d['match'] is Map) ? Map<String, dynamic>.from(d['match']) : <String, dynamic>{};
      final dt = _parseIsoLocal(matchMap['date_time']);
      final club = (matchMap['club_name'] ?? 'Матч').toString().trim();
      final city = (matchMap['city'] ?? '').toString().trim();
      final organizer = (matchMap['organizer_name'] ?? '').toString().trim();
      final formatRaw = (matchMap['format'] ?? '').toString().toLowerCase();
      final duration = matchMap['duration'];
      final msg = (d['message'] ?? '').toString().trim();

      // Заголовок — строго как в ТЗ
      titleText = 'Приглашение на матч';

      // Текст — в одном формате, как в примере, но с локальным временем
      final formatText = (formatRaw == 'single')
          ? 'одиночный'
          : (formatRaw == 'double')
              ? 'парный'
              : 'матч';

      String locationInfo = '';
      if (club.isNotEmpty && city.isNotEmpty) {
        locationInfo = ' в клубе $club, $city';
      } else if (city.isNotEmpty) {
        locationInfo = ' в городе $city';
      } else if (club.isNotEmpty) {
        locationInfo = ' в клубе $club';
      }

      final sb = StringBuffer();
      if (organizer.isNotEmpty) {
        sb.write('$organizer приглашает вас на $formatText матч');
      } else {
        sb.write('Вас пригласили на $formatText матч');
      }

      if (dt != null) {
        final dateStr =
            '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
        sb.write(' $dateStr в ${_hhmm(dt)}');
      }

      if (locationInfo.isNotEmpty) {
        sb.write(locationInfo);
      }

      sb.write('.');

      if (duration != null) {
        sb.write(' Продолжительность: $duration минут.');
      }
      if (msg.isNotEmpty) {
        sb.write(' Сообщение: $msg');
      }

      bodyText = sb.toString();
    }

    return InkWell(
      onTap: () async {
        // Помечаем как прочитанное
        try {
          await ApiService.markNotificationReadV2(notification.id);
          // Локально обновляем флаг
          setState(() {
            final idx = _notifications.indexWhere((n) => n.id == notification.id);
            if (idx >= 0) {
              _notifications[idx] = NotificationItemV2(
                id: notification.id,
                recipientUserId: notification.recipientUserId,
                type: notification.type,
                title: notification.title,
                body: notification.body,
                actorUserId: notification.actorUserId,
                entityType: notification.entityType,
                entityId: notification.entityId,
                imageUrl: notification.imageUrl,
                deepLink: notification.deepLink,
                createdAt: notification.createdAt,
                readAt: DateTime.now(),
                isRead: true,
              );
            }
          });
        } catch (_) {}

        // Переходим по deep_link, если он задан
        if (notification.deepLink != null && notification.deepLink!.isNotEmpty) {
          final uri = Uri.tryParse(notification.deepLink!);
          if (uri != null) {
            // Простая маршрутизация по path
            final segments = uri.pathSegments;
            if (segments.isNotEmpty) {
              if (segments[0] == 'match' && segments.length > 1) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MatchDetailsScreen(matchId: segments[1])),
                );
              } else if (segments[0] == 'profile' && segments.length > 1) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: segments[1])),
                );
              } else if (segments[0] == 'competition' && segments.length > 1) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CompetitionDetailsScreen(competitionId: segments[1])),
                );
              } else if (segments[0] == 'club' && segments.length > 1) {
                // Для клуба нужен объект, здесь упрощённо откроем по id, если есть экран-заглушка
                // В текущем проекте экран клуба ожидает целый Club, поэтому переход по deep_link на клуб
                // нужно будет прокинуть через общий роутер. Пока игнорируем.
              }
            }
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: Color(0xFFDFE2E6), width: 1),
                ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Аватар со значком непрочитанного
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: 30,
                  height: 30,
                  child: ClipOval(
                    child: UserAvatar(
                      imageUrl: notification.imageUrl,
                      userName: displayName,
                      radius: 15,
                    ),
                  ),
                ),
                if (!notification.isRead)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          titleText,
                          softWrap: true,
                          style: const TextStyle(
                            fontFamily: "SF Pro Display",
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2A2C36),
                            letterSpacing: -0.32,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(notification.createdAt),
                        style: const TextStyle(
                          fontFamily: "SF Pro Display",
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF838A91),
                          letterSpacing: -0.28,
                          height: 1.43,
                        ),
                      ),
                    ],
                  ),
                  if (notification.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      bodyText,
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: "SF Pro Display",
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF838A91),
                        letterSpacing: -0.28,
                        height: 1.43,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_DateGroup> _groupByDate(List<NotificationItemV2> items) {
    final List<_DateGroup> result = [];
    DateTime? currentDay;
    List<NotificationItemV2> bucket = [];
    for (final n in items) {
      final local = n.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (currentDay == null || day.isBefore(currentDay) || day.isAfter(currentDay)) {
        if (currentDay != null) {
          result.add(_DateGroup(_formatDateRu(currentDay), List<NotificationItemV2>.from(bucket)));
          bucket.clear();
        }
        currentDay = day;
      }
      bucket.add(n);
    }
    if (currentDay != null) {
      result.add(_DateGroup(_formatDateRu(currentDay), List<NotificationItemV2>.from(bucket)));
    }
    return result;
  }

  String _formatDateRu(DateTime date) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _ensureActorNameLoaded(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    if (_actorNames.containsKey(userId) || _actorNamesLoading.contains(userId)) return;
    _actorNamesLoading.add(userId);
    try {
      final profile = await ApiService.getUserProfileById(userId);
      if (!mounted) return;
      setState(() {
        _actorNames[userId] = profile.name;
        _actorNamesLoading.remove(userId);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _actorNames[userId] = 'Пользователь';
        _actorNamesLoading.remove(userId);
      });
    }
  }
} 

class _DateGroup {
  final String label;
  final List<NotificationItemV2> notifications;
  _DateGroup(this.label, this.notifications);
}
