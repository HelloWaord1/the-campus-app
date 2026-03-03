import 'package:flutter/material.dart';
import '../models/match.dart';
import '../models/club.dart';
import '../services/api_service.dart';
import '../screens/match_details_screen.dart';
import '../screens/match_filters_screen.dart';
import 'create_match_screen.dart';
import '../widgets/user_avatar.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MatchesScreen extends StatefulWidget {
  final String? fixedClubId; // если задан, клуб фиксирован и менять нельзя
  final String? fixedCity;   // город для предустановки
  final List<DateTime>? initialDates; // предустановленные даты
  final String? initialTimeRange; // предустановленное время
  const MatchesScreen({super.key, this.fixedClubId, this.fixedCity, this.initialDates, this.initialTimeRange});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<Match> _matches = [];
  bool _isLoading = false;
  bool _hasError = false;
  
  // Фильтры
  String? _selectedCity;
  List<DateTime> _selectedDates = [];
  String _selectedTimeRange = 'Весь день';
  List<String> _selectedClubs = [];

  bool get _areFiltersApplied {
    // final bool cityApplied = _selectedCity != null;
    final bool clubsApplied = _selectedClubs.isNotEmpty;
    final bool datesApplied = _selectedDates.isNotEmpty;
    final bool timeApplied = _selectedTimeRange != 'Весь день';
    return clubsApplied || datesApplied || timeApplied;
  }

  @override
  void initState() {
    super.initState();
    if (widget.fixedCity != null) {
      _selectedCity = widget.fixedCity;
    }
    if (widget.fixedClubId != null) {
      _selectedClubs = [widget.fixedClubId!];
    }
    if (widget.initialDates != null && widget.initialDates!.isNotEmpty) {
      _selectedDates = List<DateTime>.from(widget.initialDates!);
    }
    if (widget.initialTimeRange != null && widget.initialTimeRange!.isNotEmpty) {
      _selectedTimeRange = widget.initialTimeRange!;
    }
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      List<TimeRange> timeRanges = _buildTimeRanges();

      // Построение новых полей dates/start_time/end_time
      // Определяем временные границы на основе выбранного диапазона
      TimeOfDay startTimeOfDay, endTimeOfDay;
      switch (_selectedTimeRange) {
        case 'Утро с 8 до 12':
          startTimeOfDay = const TimeOfDay(hour: 8, minute: 0);
          endTimeOfDay = const TimeOfDay(hour: 12, minute: 0);
          break;
        case 'День с 12 до 18':
          startTimeOfDay = const TimeOfDay(hour: 12, minute: 0);
          endTimeOfDay = const TimeOfDay(hour: 18, minute: 0);
          break;
        case 'Вечер с 18 до 24':
          startTimeOfDay = const TimeOfDay(hour: 18, minute: 0);
          endTimeOfDay = const TimeOfDay(hour: 23, minute: 59);
          break;
        default: // 'Весь день' и любые другие значения
          startTimeOfDay = const TimeOfDay(hour: 0, minute: 0);
          endTimeOfDay = const TimeOfDay(hour: 23, minute: 59);
          break;
      }

      String _formatTimeOfDay(TimeOfDay t) {
        final String hh = t.hour.toString().padLeft(2, '0');
        final String mm = t.minute.toString().padLeft(2, '0');
        return '$hh:$mm';
      }

      String _formatDateYmd(DateTime d) {
        final String y = d.year.toString().padLeft(4, '0');
        final String m = d.month.toString().padLeft(2, '0');
        final String day = d.day.toString().padLeft(2, '0');
        return '$y-$m-$day';
      }

      final List<String> requestDates = _selectedDates.map(_formatDateYmd).toList();

      final searchRequest = MatchSearchRequest(
        timeRanges: timeRanges,
        city: _selectedCity,
        clubIds: _selectedClubs.isNotEmpty ? _selectedClubs : null,
        format: null,
        level: null,
        isPrivate: null,
        dates: requestDates.isNotEmpty ? requestDates : null,
        startTime: _formatTimeOfDay(startTimeOfDay),
        endTime: _formatTimeOfDay(endTimeOfDay),
      );

      final response = await ApiService.searchMatches(searchRequest);
      
      // Фильтруем матчи - показываем только будущие
      final now = DateTime.now();
      final filteredMatches = response.matches.where((match) {
        return match.dateTime.isAfter(now);
      }).toList();
      
      if (mounted) {
        setState(() {
          _matches = filteredMatches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  List<TimeRange> _buildTimeRanges() {
    if (_selectedDates.isEmpty) {
      return [];
    }

    List<TimeRange> timeRanges = [];
    
    // Определяем временные границы на основе выбранного диапазона
    TimeOfDay startTime, endTime;
    switch (_selectedTimeRange) {
      case 'Утро с 8 до 12':
        startTime = const TimeOfDay(hour: 8, minute: 0);
        endTime = const TimeOfDay(hour: 12, minute: 0);
        break;
      case 'День с 12 до 18':
        startTime = const TimeOfDay(hour: 12, minute: 0);
        endTime = const TimeOfDay(hour: 18, minute: 0);
        break;
      case 'Вечер с 18 до 24':
        startTime = const TimeOfDay(hour: 18, minute: 0);
        endTime = const TimeOfDay(hour: 23, minute: 59);
        break;
      default: // 'Весь день'
        startTime = const TimeOfDay(hour: 0, minute: 0);
        endTime = const TimeOfDay(hour: 23, minute: 59);
        break;
    }
    
    // Создаем временные диапазоны для каждой выбранной даты
    for (DateTime date in _selectedDates) {
      final startDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        startTime.hour,
        startTime.minute,
      );
      
      final endDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        endTime.hour,
        endTime.minute,
      );
      
      timeRanges.add(TimeRange(
        startTime: startDateTime,
        endTime: endDateTime,
      ));
    }
    
    return timeRanges;
  }

  Future<void> _showFilters() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MatchFiltersScreen(
        selectedCity: _selectedCity,
        selectedClubs: _selectedClubs,
        selectedDates: _selectedDates,
        selectedTimeRange: _selectedTimeRange,
        lockClubSelection: false,
        initialLockedClubs: const [],
      ),
    );
    
    if (result != null) {
      setState(() {
        _selectedCity = result["city"];
        final List<dynamic> clubsList = result["clubs"] as List<dynamic>? ?? [];
        _selectedClubs = clubsList.cast<String>();
        final List<dynamic> datesList = result["dates"] as List<dynamic>? ?? [];
        _selectedDates = datesList.map((date) {
          if (date is DateTime) {
            return date;
          } else if (date is String) {
            return DateTime.parse(date);
          } else {
            return DateTime.now();
          }
        }).toList();
        _selectedTimeRange = result["timeRange"] ?? "";
      });
      _loadMatches();
    }
  }

  Widget _buildMatchCard(Match match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 230, // уменьшили общую высоту на ~10px
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MatchDetailsScreen(matchId: match.id),
            ),
          ).then((_) {
            // Этот код выполнится после возвращения с экрана деталей матча
            _loadMatches();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Основное содержимое карточки
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Дата и время
                  Text(
                    _formatMatchDateTimeWithDuration(match.dateTime, match.duration),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF222223),
                      fontFamily: 'Basis Grotesque Arabic Pro',
                      letterSpacing: -0.32,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Статус матча
                  Text(
                    match.isPrivate ? 'Закрытый матч' : 'Открытый матч',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF89867E),
                      fontFamily: 'Basis Grotesque Arabic Pro',
                      letterSpacing: -0.28,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Участники с командами
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Первая команда
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildTeamParticipants(match, 0),
                        ),
                      ),
                      
                      // Вертикальная разделительная линия
                      Container(
                        width: 1,
                        height: 79,
                        color: const Color(0xFFECECEC),
                        margin: const EdgeInsets.symmetric(horizontal: 11),
                      ),
                      
                      // Вторая команда
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildTeamParticipants(match, 1),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Информация о клубе
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.clubName ?? 'Клуб "Ракетка"',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF222223),
                          fontFamily: 'SF Pro Display',
                          letterSpacing: -0.33,
                          height: 1.286,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        match.clubCity ?? 'Город не указан',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF89867E),
                          fontFamily: 'SF Pro Display',
                          letterSpacing: -0.33,
                          height: 1.286,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            /*
            // Зеленый блок с ценой - точно на 174px от верха (234-60=174)
            Positioned(
              top: 161, // Точное позиционирование: 234 - 60 = 174
              right: 0,
              child: Container(
                height: 61, // Точная высота зеленого блока
                width: 104,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0FAF4),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_getMatchPrice(match)} ₽',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF222223),
                        fontFamily: 'Basis Grotesque Arabic Pro',
                        letterSpacing: -0.32,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${match.duration} мин',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF222223),
                        fontFamily: 'Basis Grotesque Arabic Pro',
                        letterSpacing: -0.28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            */
            // Горизонтальная разделительная линия от края до края
            Positioned(
              top: 170, // ближе к блоку участников, чтобы уменьшить отступ
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                color: const Color(0xFFD9D9D9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTeamParticipants(Match match, int team) {
    List<Widget> participants = [];
    int maxPerTeam = match.maxParticipants ~/ 2;
    
    // Определяем команду (0 = A, 1 = B)
    String teamId = team == 0 ? 'A' : 'B';
    
    // Добавляем участников команды
    for (int i = 0; i < maxPerTeam; i++) {
      MatchParticipant? participant = _getParticipantForTeamAndPosition(match, teamId, i);
      
      if (participant != null) {
        participants.add(_buildParticipantColumn(participant));
      } else {
        participants.add(_buildEmptySlotColumn());
      }
      
      if (i < maxPerTeam - 1) {
        participants.add(const SizedBox(width: 8));
      }
    }
    
    return participants;
  }

  MatchParticipant? _getParticipantForTeamAndPosition(Match match, String team, int position) {
    // Особый случай: первый слот команды А всегда для организатора
    if (team == 'A' && position == 0) {
      // Ищем организатора по organizer_id вместо role
      final organizerList = match.participants.where((p) => p.userId == match.organizerId).toList();
      if (organizerList.isNotEmpty) {
        return organizerList.first;
      }
      // Fallback: если нет организатора, берем первого участника
      if (match.participants.isNotEmpty) {
        return match.participants.first;
      }
      return null;
    }

    // Для остальных позиций: исключаем организатора и распределяем по командам
    final nonOrganizerParticipants = match.participants.where((participant) {
      // Исключаем организатора
      if (participant.userId == match.organizerId) {
        return false;
      }
      return true;
    }).toList();

    // Распределяем оставшихся участников по командам на основе team_id
    final teamParticipants = nonOrganizerParticipants.where((participant) {
      if (participant.teamId != null) {
        return participant.teamId == team;
      }
      
      // Fallback для участников без team_id
      final participantIndex = match.participants.indexOf(participant);
      final participantTeam = (participantIndex % 2 == 0) ? 'A' : 'B';
      return participantTeam == team;
    }).toList();

    // Возвращаем участника для данной позиции
    if (team == 'A') {
      // Для команды А корректируем позицию (т.к. 0 занят организатором)
      final adjustedPosition = position - 1;
      if (adjustedPosition >= 0 && adjustedPosition < teamParticipants.length) {
        return teamParticipants[adjustedPosition];
      }
    } else {
      // Для команды Б используем позицию как есть
      if (position < teamParticipants.length) {
        return teamParticipants[position];
      }
    }

    return null;
  }

  Widget _buildParticipantColumn(MatchParticipant participant) {
    return SizedBox(
      width: 72,
      height: 88, // Фиксированная высота для выравнивания с пустыми слотами
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Аватар
          UserAvatar(
            imageUrl: participant.avatarUrl,
            userName: participant.name,
            isDeleted: participant.isDeleted,
            radius: 24,
          ),
          const SizedBox(height: 0),
          // Имя
          Text(
            participant.name.split(' ').first,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF222223),
              fontFamily: 'Basis Grotesque Arabic Pro',
              letterSpacing: -0.28,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Фиксированная высота блока рейтинга для выравнивания по вертикали
          SizedBox(
            height: 16,
            child: Center(
              child: Text(
                participant.formattedRating,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF262F63),
                  fontFamily: 'Basis Grotesque Arabic Pro',
                  letterSpacing: -0.28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySlotColumn() {
    return SizedBox(
      width: 72,
      height: 88, // Фиксированная высота для выравнивания с участниками
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Кнопка добавления
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF262F63), width: 1),
            ),
            child: const Icon(
              Icons.add,
              color: Color(0xFF262F63),
              size: 20,
            ),
          ),
          const SizedBox(height: 0),
          // Текст "Доступно"
          const Text(
            'Доступно',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF262F63),
              fontFamily: 'Basis Grotesque Arabic Pro',
              letterSpacing: -0.28,
            ),
            textAlign: TextAlign.center,
          ),
          // Пустой фиксированный блок для выравнивания с рейтингом
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Удалены неиспользуемые вспомогательные методы

  String _formatMatchDateTimeWithDuration(DateTime dateTime, int duration) {
    final local = dateTime.toLocal();
    final weekdays = [
      'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'
    ];
    
    final months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    
    final weekday = weekdays[local.weekday - 1];
    final day = local.day;
    final month = months[local.month - 1];
    final startHour = local.hour.toString().padLeft(2, '0');
    final startMinute = local.minute.toString().padLeft(2, '0');
    
    if (duration > 60) {
      final endTime = local.add(Duration(minutes: duration));
      final endHour = endTime.hour.toString().padLeft(2, '0');
      final endMinute = endTime.minute.toString().padLeft(2, '0');
      return '$weekday, $day $month, $startHour:$startMinute - $endHour:$endMinute';
    } else {
      return '$weekday, $day $month, $startHour:$startMinute';
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              // Верхняя область с белым фоном (включая dynamic island)
              Container(
                color: Colors.white,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    height: 56,
                    color: Colors.white,
                    child: Stack(
                      children: [
                        // Кнопка назад
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: SvgPicture.asset(
                              'assets/images/back_icon.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                        
                        // Заголовок по центру
                        const Center(
                          child: Text(
                            'Матчи',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF222223),
                              fontFamily: 'Basis Grotesque Arabic Pro',
                              letterSpacing: -0.36,
                            ),
                          ),
                        ),
                        
                        // Кнопка фильтров с индикатором применённых фильтров
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _showFilters,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.tune,
                                        color: Color(0xFF262F63),
                                        size: 24,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Фильтры',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF262F63),
                                          fontFamily: 'Basis Grotesque Arabic Pro',
                                          letterSpacing: -0.28,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_areFiltersApplied)
                                    const Positioned(
                                      left: 16,
                                      top: 0,
                                      child: SizedBox(
                                        width: 8,
                                        height: 8,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Color(0xFFFF3B30),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Основной контент
              Expanded(
                child: Container(
                  color: const Color(0xFFF3F5F6),
                  child: RefreshIndicator(
                    onRefresh: _loadMatches,
                    color: const Color(0xFF262F63),
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF262F63),
                            ),
                          )
                        : _hasError
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 64,
                                      color: Color(0xFF7F8AC0),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Ошибка загрузки',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFF7F8AC0),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _loadMatches,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF262F63),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Повторить'),
                                    ),
                                  ],
                                ),
                              )
                            : _matches.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: _areFiltersApplied
                                          ? Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: const [
                                                Text(
                                                  'По выбранным параметрам матчи не найдены.',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFF222223),
                                                    fontWeight: FontWeight.w400,
                                                    fontFamily: 'SF Pro Display',
                                                    letterSpacing: -0.28,
                                                  ),
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  'Создайте свой матч и найдите соперников!',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFF222223),
                                                    fontWeight: FontWeight.w400,
                                                    fontFamily: 'SF Pro Display',
                                                    letterSpacing: -0.28,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: const [
                                                Text(
                                                  'Матчей пока нет',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFF222223),
                                                    fontWeight: FontWeight.w600,
                                                    fontFamily: 'SF Pro Display',
                                                    letterSpacing: -0.28,
                                                  ),
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  'Создайте свой матч или дождитесь,\nпока кто-то другой начнёт',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFF222223),
                                                    fontWeight: FontWeight.w400,
                                                    fontFamily: 'SF Pro Display',
                                                    letterSpacing: -0.28,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _matches.length,
                                    itemBuilder: (context, index) {
                                      final match = _matches[index];
                                      return _buildMatchCard(match);
                                    },
                                  ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Кнопка "Создать матч" (уменьшенная по высоте)
        floatingActionButton: Transform.translate(
          offset: const Offset(0, 16), // опускаем ниже на 6px, уменьшая отступ от нижнего края
          child: SizedBox(
            height: 47,
            child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateMatchScreen(),
                ),
              ).then((_) => _loadMatches());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF262F63),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(52),
              ),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              'Создать матч',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'SF Pro Display',
                letterSpacing: -0.28,
              ),
            ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
} 
