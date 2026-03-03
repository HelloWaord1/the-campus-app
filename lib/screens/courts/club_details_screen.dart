import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/club.dart';
import '../../models/match.dart';
import '../../models/competition.dart';
import '../../models/court.dart';
import '../../models/booking.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/match_card.dart';
import '../../widgets/competition_mini_card.dart';
import '../../widgets/user_avatar.dart';
import '../../utils/notification_utils.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../create_match_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../matches_screen.dart';
import '../home_screen.dart';
import '../competition_details_screen.dart';
import 'booking_confirmation_screen.dart';
import 'no_time_available_widget.dart';

class ClubDetailsScreen extends StatefulWidget {
  final Club club;

  const ClubDetailsScreen({super.key, required this.club});

  @override
  State<ClubDetailsScreen> createState() => _ClubDetailsScreenState();
}

class _ClubDetailsScreenState extends State<ClubDetailsScreen> {
  int _activeTabIndex = 0; // 0: Обзор, 1: Бронь, 2: Ближайшие матчи, 3: Турниры
  // Экран открыт вне нижнего таббара
  final int _currentIndex = 0;
  final ScrollController _tabsScrollController = ScrollController();
  final List<GlobalKey> _tabKeys = List.generate(4, (_) => GlobalKey());

  // Состояние вкладки "Ближайшие матчи"
  late DateTime _weekStart; // сегодняшняя дата (начало последовательности из 7 дней)
  int _selectedDayOffset = 0; // 0..6 в пределах недели; визуально выделяем сегодня
  bool _showUnavailable = false;
  bool _isLoadingMatches = false;
  String? _matchesError;
  List<Match> _clubMatches = [];
  int? _selectedHour; // null = весь день
  bool _unfilteredMode = true; // при первом входе показываем без фильтров (все даты и время)
  // Выбор времени как в фильтрах убран; время выбирается через слоты после выбора даты

  // Состояние вкладки "Турниры"
  bool _isLoadingCompetitions = false;
  String? _competitionsError;
  List<Competition> _clubCompetitions = const [];
  bool _showAllActivities = false;

  @override
  void initState() {
    super.initState();
    // Начинаем от сегодняшней даты
    final now = DateTime.now();
    _weekStart = DateTime(now.year, now.month, now.day);
    // Загрузим по умолчанию список на выбранный день
    _fetchClubMatches();
    _fetchClubCompetitions();
  }

  @override
  void dispose() {
    _tabsScrollController.dispose();
    super.dispose();
  }

  // Убрано вычисляемое свойство выбранной даты; используем _weekStart + _selectedDayOffset по месту

  Future<void> _fetchClubMatches() async {
    if (_isLoadingMatches) return;
    setState(() {
      _isLoadingMatches = true;
      _matchesError = null;
    });
    try {
      // Если без фильтров — тянем неделю вперёд; иначе только выбранный день
      late DateTime dateFrom;
      late DateTime dateTo;
      if (_unfilteredMode) {
        final DateTime start = DateTime(_weekStart.year, _weekStart.month, _weekStart.day, 0, 0, 0);
        final DateTime endDay = _weekStart.add(const Duration(days: 6));
        final DateTime end = DateTime(endDay.year, endDay.month, endDay.day, 23, 59, 59);
        dateFrom = start;
        dateTo = end;
      } else {
        final DateTime selected = _weekStart.add(Duration(days: _selectedDayOffset < 0 ? 0 : _selectedDayOffset));
        dateFrom = DateTime(selected.year, selected.month, selected.day, 0, 0, 0);
        dateTo = DateTime(selected.year, selected.month, selected.day, 23, 59, 59);
      }

      final searchRequest = MatchSearchRequest(
        timeRanges: [
          TimeRange(startTime: dateFrom, endTime: dateTo),
        ],
        city: widget.club.city,
        clubIds: [widget.club.id],
        format: null,
        level: null,
        isPrivate: null,
      );

      final res = await ApiService.searchMatches(searchRequest);
      setState(() {
        _clubMatches = res.matches;
        _isLoadingMatches = false;
      });
    } catch (e) {
      setState(() {
        _matchesError = e.toString();
        _isLoadingMatches = false;
        _clubMatches = [];
      });
    }
  }

  Future<void> _fetchClubCompetitions() async {
    if (_isLoadingCompetitions) return;
    setState(() {
      _isLoadingCompetitions = true;
      _competitionsError = null;
    });
    try {
      final resp = await ApiService.getCompetitions(
        search: widget.club.name,
      );
      setState(() {
        _clubCompetitions = resp.competitions;
        _isLoadingCompetitions = false;
      });
    } catch (e) {
      setState(() {
        _competitionsError = e.toString();
        _isLoadingCompetitions = false;
        _clubCompetitions = const [];
      });
    }
  }

  void _onToggleShowAllActivities(bool value) {
    setState(() {
      _showAllActivities = value;
    });
    // Пока функциональность только переключает состояние без влияния на выборку/фильтрацию
  }

  void _onToggleUnavailable(bool value) {
    // Отключаем влияние на фильтрацию. Меняем только состояние переключателя.
    setState(() {
      _showUnavailable = value;
    });
    // Ранее здесь могли перезапрашиваться матчи/перестраиваться сетки в зависимости от флага.
    // Это поведение закомментировано по требованию.
  }

  void _onSelectDay(int offset) {
    // Если мы в нефильтрованном режиме и пользователь кликает по уже выделенному (сегодня),
    // то применяем фильтр по дате (включаем режим фильтрации по дню)
    if (_unfilteredMode && offset == _selectedDayOffset) {
      setState(() {
        _selectedHour = null;
        _unfilteredMode = false;
      });
      _fetchClubMatches();
      return;
    }

    // Если выбран другой день — переключаемся на него и применяем фильтр
    if (offset != _selectedDayOffset) {
      setState(() {
        _selectedDayOffset = offset;
        _selectedHour = null; // сбрасываем час при смене дня
        _unfilteredMode = false; // с этого момента применяем фильтр по дате
      });
      _fetchClubMatches();
    }
  }

  void _onSelectHour(int hour) {
    setState(() {
      // Переключатель: повторный тап по активному часу снимает фильтр
      if (_selectedHour == hour) {
        _selectedHour = null;
      } else {
        _selectedHour = hour;
      }
    });
  }

  String _buildAddressWithCity() {
    final city = widget.club.city;
    final address = widget.club.address;
    
    if (address != null && address.isNotEmpty) {
      // Если есть адрес, добавляем город в начало через запятую
      if (city != null && city.isNotEmpty) {
        return '$city, $address';
      }
      return address;
    } else if (city != null && city.isNotEmpty) {
      // Если адреса нет, но есть город
      return city;
    }
    return 'Адрес не указан';
  }

  Widget _buildTabsRow() {
    TextStyle base = const TextStyle(
      fontFamily: 'SF Pro Display',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: Color(0xFF89867E),
      letterSpacing: -0.40,
    );
    TextStyle active = const TextStyle(
      fontFamily: 'SF Pro Display',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Color(0xFF222223),
      letterSpacing: -0.32,
    );

        String labelFor(int i) {
          switch (i) {
            case 0:
              return 'Обзор';
            case 1:
              return 'Бронь';
            case 2:
              return 'Ближайшие матчи';
            case 3:
              return 'Турниры';
            default:
              return '';
          }
        }

    final double tabPadding = 22.0; // Увеличенный паддинг

        Widget tab(int index) {
          final bool isActive = _activeTabIndex == index;
      return GestureDetector(
        key: _tabKeys[index],
        onTap: () {
          setState(() => _activeTabIndex = index);
          // Прокручиваем к активной вкладке после небольшой задержки для обновления layout
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_tabKeys[index].currentContext != null) {
              Scrollable.ensureVisible(
                _tabKeys[index].currentContext!,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: 0.5, // Центрируем вкладку
              );
            }
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: tabPadding, vertical: 8),
            child: Text(
              labelFor(index),
              style: isActive ? active : base,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
            ),
            // Индикатор под надписью, внутри прокручиваемой области
            Builder(
              builder: (context) {
                // Вычисляем ширину текста для индикатора
                final textPainter = TextPainter(
                  text: TextSpan(text: labelFor(index), style: isActive ? active : base),
                  textDirection: TextDirection.ltr,
                );
                textPainter.layout();
                final textWidth = textPainter.width;
                // Ширина индикатора = ширина текста + паддинги с обеих сторон
                final indicatorWidth = textWidth + (tabPadding * 2);
                
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  height: isActive ? 2 : 0,
                  width: indicatorWidth, // Ширина текста + паддинги
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF262F63) : Colors.transparent,
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              },
            ),
          ],
            ),
          );
        }

        return SizedBox(
      height: 42, // Увеличена высота для размещения индикатора
          child: Stack(
            clipBehavior: Clip.none,
            children: [
          // Горизонтально прокручиваемая строка вкладок
          SingleChildScrollView(
            controller: _tabsScrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
                children: [
                  tab(0),
                  tab(1),
                  tab(2),
                  tab(3),
                ],
              ),
          ),
          // Серая непрерывная линия по всей ширине экрана (под индикаторами)
              Positioned(
                bottom: 0,
            left: 0,
            right: 0,
            child: Container(height: 1, color: const Color(0xFFE6E6E6)),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            child: Column(
              children: [
                // Hero image (всегда показывается, как в Figma)
                Container(
                  width: double.infinity,
                  height: 239,
                  decoration: BoxDecoration(
                    image: widget.club.photoUrl != null && widget.club.photoUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(widget.club.photoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: widget.club.photoUrl == null || widget.club.photoUrl!.isEmpty
                        ? const Color(0xFFE0E0E0)
                        : null,
                  ),
                  child: widget.club.photoUrl == null || widget.club.photoUrl!.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.sports_tennis,
                            size: 64,
                            color: Color(0xFF9E9E9E),
                          ),
                        )
                      : null,
                ),
                
                // Content section
                Padding(
                  padding: const EdgeInsets.fromLTRB(0,16.0, 0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Club info section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
                                child: Text(
                                  widget.club.name,
                                  style: const TextStyle(
                                    fontFamily: 'SF Pro Display',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF222223),
                                    letterSpacing: -0.36,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
                                child: Text(
                                  _buildAddressWithCity(),
                                  style: const TextStyle(
                                    fontFamily: 'SF Pro Display',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF222223),
                                    letterSpacing: -0.28,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          _buildTabsRow(),
                          
                    
                          // const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: 0),
                            color: const Color(0xFFF7F7F7),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_activeTabIndex == 0) ...[
                                    // Обзор - Описание
                                    Container(
                                      width: double.infinity,
                                      // padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7F7F7),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Описание:',
                                            style: TextStyle(
                                              fontFamily: 'SF Pro Display',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w400,
                                              color: Color(0xFF89867E),
                                              letterSpacing: -0.32,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      widget.club.description ?? 'Описание отсутствует',
                                      style: const TextStyle(
                                        fontFamily: 'SF Pro Display',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF222223),
                                        letterSpacing: -0.32,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Divider(
                                      color: Color(0xFFE6E6E6),
                                      height: 1,
                                    ),
                                    const SizedBox(height: 18),
                                    // Количество кортов / Прокат
                                    Container(
                                      width: double.infinity,
                                      // padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7F7F7),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (widget.club.courtsCount != null) ...[
                                            Row(
                                              children: [
                                                SvgPicture.asset('assets/images/courts_number.svg', width: 16, height: 16, color: const Color(0xFF222223)),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Количество кортов: ${widget.club.courtsCount}',
                                                    style: const TextStyle(
                                                      fontFamily: 'SF Pro Display',
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w400,
                                                      color: Color(0xFF222223),
                                                      letterSpacing: -0.32,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                          if (widget.club.equipmentRental != null)
                                            Row(
                                              children: [
                                                SvgPicture.asset('assets/images/has_inventory.svg', width: 22, height: 22, color: const Color(0xFF222223)),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Прокат инвентаря: ${widget.club.equipmentRental == true ? 'Есть' : 'Нет'}',
                                                    style: const TextStyle(
                                                      fontFamily: 'SF Pro Display',
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w400,
                                                      color: Color(0xFF222223),
                                                      letterSpacing: -0.32,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Divider(
                                      color: Color(0xFFE6E6E6),
                                      height: 1,
                                    ),
                                    const SizedBox(height: 14),
                                    // Время работы
                                    if (widget.club.workSchedule != null)
                                      Container(
                                        width: double.infinity,
                                        // padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF7F7F7),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Время работы:',
                                              style: TextStyle(
                                                fontFamily: 'SF Pro Display',
                                                fontSize: 15,
                                                fontWeight: FontWeight.w400,
                                                color: Color(0xFF79766E),
                                                letterSpacing: -0.32,
                                              ),
                                            ),
                                            const SizedBox(height: 0),
                                            _buildWorkSchedule(widget.club.workSchedule!),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 20),

                                    // Построить маршрут
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton.icon(
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            // side: const BorderSide(color: Color(0xFFE6E6E6)),
                                          ),
                                        ),
                                        onPressed: () async {
                                          final double? clubLat = widget.club.latitude;
                                          final double? clubLon = widget.club.longitude;
                                          if (clubLat == null || clubLon == null) {
                                            NotificationUtils.showError(context, 'У клуба нет координат');
                                            return;
                                          }

                                          // Пытаемся взять последние координаты пользователя, без обязательного ожидания
                                          double? userLat;
                                          double? userLon;
                                          try {
                                            final last = await Geolocator.getLastKnownPosition();
                                            if (last != null) {
                                              userLat = last.latitude;
                                              userLon = last.longitude;
                                            }
                                          } catch (_) {}

                                          // Всегда открываем веб-версию Яндекс.Карт с маршрутом
                                          final String dest = '$clubLat,$clubLon';
                                          final String rtext = (userLat != null && userLon != null)
                                              ? '$userLat,$userLon~$dest'
                                              : '~$dest';
                                          final Uri webUri = Uri.https(
                                            'yandex.ru',
                                            '/maps/',
                                            {
                                              'rtext': rtext,
                                              'rtt': 'auto',
                                            },
                                          );
                                          try {
                                            await launchUrl(webUri, mode: LaunchMode.externalApplication);
                                          } catch (_) {
                                            // Фолбэк: та же ссылка через http(s) парсинг
                                            final Uri fallback = Uri.parse('https://yandex.ru/maps/?rtext=$rtext&rtt=auto');
                                            await launchUrl(fallback, mode: LaunchMode.externalApplication);
                                          }
                                        },
                                        icon: const Icon(Icons.map_outlined, color: Color(0xFF222223), size: 20),
                                        label: const Text(
                                          'Построить маршрут',
                                          style: TextStyle(
                                            fontFamily: 'SF Pro Display',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF222223),
                                            letterSpacing: -0.32,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Контакты (4 круглых)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildRoundContactButton(
                                          svgAsset: 'assets/images/phone_clubs.svg',
                                          label: 'Телефон',
                                          enabled: widget.club.phone != null && widget.club.phone!.isNotEmpty,
                                          onTap: () => _launchUrl('tel:${widget.club.phone}'),
                                        ),
                                        _buildRoundContactButton(
                                          svgAsset: 'assets/images/link_club.svg',
                                          label: 'Веб‑сайт',
                                          enabled: widget.club.website != null && widget.club.website!.isNotEmpty,
                                          onTap: () => _launchUrl(widget.club.website!),
                                        ),
                                        _buildRoundContactButton(
                                          svgAsset: 'assets/images/telegram_club.svg',
                                          label: 'Телеграм',
                                          enabled: widget.club.telegram != null && widget.club.telegram!.isNotEmpty,
                                          onTap: () => _openTelegram(widget.club.telegram!),
                                        ),
                                        _buildRoundContactButton(
                                          svgAsset: 'assets/images/whatsapp_club.svg',
                                          label: 'Ватсап',
                                          enabled: widget.club.whatsapp != null && widget.club.whatsapp!.isNotEmpty,
                                          onTap: () => _openWhatsApp(widget.club.whatsapp!),
                                        ),
                                      ],
                                    ),
                                  ] else if (_activeTabIndex == 1) ...[
                                    // Вкладка Бронь - встроенный функционал бронирования
                                    _BookingTab(club: widget.club),
                                  ] else if (_activeTabIndex == 2) ...[
                                    // Вкладка ближайших матчей: слоты времени появляются только после выбора даты
                                    _UpcomingMatchesTab(
                                      weekStart: _weekStart,
                                      selectedDayOffset: _selectedDayOffset,
                                      onSelectDay: _onSelectDay,
                                      showUnavailable: _showUnavailable,
                                      onToggleUnavailable: _onToggleUnavailable,
                                      isLoading: _isLoadingMatches,
                                      errorText: _matchesError,
                                      matches: _clubMatches,
                                      selectedHour: _selectedHour,
                                      onSelectHour: _onSelectHour,
                                      onCreateMatch: () {
                                        final DateTime sel = _selectedDayOffset >= 0 ? _weekStart.add(Duration(days: _selectedDayOffset)) : DateTime.now();
                                        final DateTime? initialDate = DateTime(sel.year, sel.month, sel.day);
                                        final TimeOfDay? initialTime = _selectedHour != null ? TimeOfDay(hour: _selectedHour!, minute: 0) : null;
                                        Navigator.of(context)
                                            .push(
                                          MaterialPageRoute(
                                            builder: (_) => CreateMatchScreen(
                                              initialClub: widget.club,
                                              initialDate: initialDate,
                                              initialTime: initialTime,
                                            ),
                                          ),
                                        )
                                            .then((_) => _fetchClubMatches());
                                      },
                                      onRefreshMatches: _fetchClubMatches,
                                      unfilteredMode: _unfilteredMode,
                                    ),
                                  ] else if (_activeTabIndex == 3) ...[
                                    // Вкладка Турниров
                                    _ClubCompetitionsTab(
                                      isLoading: _isLoadingCompetitions,
                                      errorText: _competitionsError,
                                      competitions: _clubCompetitions,
                                      onRefresh: _fetchClubCompetitions,
                                      showAllActivities: _showAllActivities,
                                      onToggleShowAllActivities: _onToggleShowAllActivities,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const Divider(
                        color: Color(0xFFF7F7F7),
                        height: 50,
                        thickness: 50,
                      ),
                    
                      
                      // Бронирование убрано по дизайну: экран — обзор
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Back button overlay
          Positioned(
            top: 54,
            left: 16,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
              child: IconButton(
                icon: SvgPicture.asset(
                  'assets/images/back_icon.svg',
                  width: 24,
                  height: 24,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // Share button overlay
          Positioned(
            top: 54,
            right: 16,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
              child: IconButton(
                icon: SvgPicture.asset(
                  'assets/images/share_logo.svg',
                  width: 18,
                  height: 18,
                ),
                onPressed: () async {
                  final String link = 'https://paddle-app.ru/club/${widget.club.id}';
                  await Clipboard.setData(ClipboardData(text: link));
                  NotificationUtils.showSuccess(context, 'Ссылка на клуб скопирована');
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTabTapped: _onTabTapped,
      ),
    );
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(initialTabIndex: index),
        ),
      );
    }
  }

  

  // _buildContactChip — не используется

  Widget _buildRoundContactButton({
    IconData? icon,
    String? svgAsset,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final Color fg = enabled ? const Color(0xFF222223) : const Color(0xFF222223).withOpacity(0.4);
    return Column(
      children: [
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
              ),
              child: Center(
                child: svgAsset != null
                    ? (() {
                        final bool isTelegram = svgAsset.contains('telegram');
                        final double svgSize = isTelegram ? 18 : 20;
                        final double dx = isTelegram ? -2.0 : 0.0;
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: enabled
                              ? SvgPicture.asset(svgAsset, width: svgSize, height: svgSize)
                              : SvgPicture.asset(svgAsset, width: svgSize, height: svgSize, color: fg),
                        );
                      }())
                    : Icon(
                        icon,
                        size: 20,
                        color: enabled ? const Color(0xFF262F63) : fg,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: fg,
            letterSpacing: -0.24,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkSchedule(String raw) {
    // Ожидаемый формат: "ПН - СБ 08:00-21:00"
    // Разделяем по первой цифре (началу времени)
    final RegExp timeStart = RegExp(r"\d");
    final int idx = raw.indexOf(timeStart);
    String days;
    String hours;
    if (idx > 0) {
      days = raw.substring(0, idx).trim();
      hours = raw.substring(idx).trim();
    } else {
      days = raw;
      hours = '';
    }

    // Приводим аббревиатуры дней недели к виду: Первая буква заглавная, вторая строчная
    days = _formatDaysAbbrev(days);
    // Только для часов: добавляем пробелы вокруг тире между временем (и используем короткое тире)
    hours = _formatTimeRangeSpacing(hours);

    return Row(
      children: [
        Flexible(
          flex: 0,
          child: Text(
            days,
            style: const TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: Color(0xFF222223),
              letterSpacing: -0.48,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            hours,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 20,
              fontWeight: FontWeight.w300,
              color: Color(0xFF79766E),
              letterSpacing: -0.48,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDaysAbbrev(String input) {
    final Map<String, String> map = {
      'ПН': 'Пн',
      'ВТ': 'Вт',
      'СР': 'Ср',
      'ЧТ': 'Чт',
      'ПТ': 'Пт',
      'СБ': 'Сб',
      'ВС': 'Вс',
    };
    // Матчим отдельные токены дней недели, окружённые началом строки/пробелами/знаками препинания/дефисами
    final RegExp token = RegExp(r'(^|[\s,;:\(\)\[\]\-–—])(ПН|ВТ|СР|ЧТ|ПТ|СБ|ВС)(?=($|[\s,;:\(\)\[\]\-–—]))', caseSensitive: false);
    return input.splitMapJoin(
      token,
      onMatch: (m) {
        final String prefix = m.group(1) ?? '';
        final String found = m.group(2) ?? '';
        final String repl = map[found.toUpperCase()] ?? found;
        return '$prefix$repl';
      },
      onNonMatch: (s) => s,
    );
  }

  String _formatTimeRangeSpacing(String input) {
    final RegExp re = RegExp(r'(\d{1,2}:\d{2})\s*[-–—]\s*(\d{1,2}:\d{2})');
    return input.replaceAllMapped(re, (m) => '${m.group(1)} - ${m.group(2)}');
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Logger.error('Не удалось открыть URL: $url');
      NotificationUtils.showError(context, 'Не удалось открыть ссылку');
    }
  }

  Future<void> _openTelegram(String raw) async {
    // Поддержка форматов: "@username", "https://t.me/username", "tg://resolve?domain=username"
    String username;
    String lower = raw.trim();
    if (lower.startsWith('http')) {
      // Попробуем вытащить имя после последнего '/'
      final Uri u = Uri.parse(lower);
      final String last = u.pathSegments.isNotEmpty ? u.pathSegments.last : '';
      username = last;
    } else if (lower.startsWith('tg://')) {
      final Uri u = Uri.parse(lower);
      username = u.queryParameters['domain'] ?? '';
    } else if (lower.startsWith('@')) {
      username = lower.substring(1);
    } else {
      username = lower;
    }

    if (username.isEmpty) {
      NotificationUtils.showError(context, 'Некорректный Telegram аккаунт');
      return;
    }

    final Uri schemeUri = Uri.parse('tg://resolve?domain=$username');
    final Uri webUri = Uri.parse('https://t.me/$username');
    if (await canLaunchUrl(schemeUri)) {
      await launchUrl(schemeUri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWhatsApp(String raw) async {
    String number = raw.trim();
    // Нормализуем: оставим только цифры, добавим '+' при необходимости
    final RegExp digits = RegExp(r'\d+');
    final String onlyDigits = digits.allMatches(number).map((m) => m.group(0)).join();
    if (onlyDigits.isEmpty) {
      NotificationUtils.showError(context, 'Некорректный номер WhatsApp');
      return;
    }
    // Пытаемся собрать международный формат. Если исходник начинался с '+', сохраним его
    if (number.startsWith('+')) {
      number = '+$onlyDigits';
    } else {
      number = onlyDigits;
    }

    // Предпочитаем официальный deeplink API, затем схему, затем веб
    final Uri apiUri = Uri.parse('https://api.whatsapp.com/send?phone=$number');
    final Uri waUri = Uri.parse('whatsapp://send?phone=$number');

    // Если установлено приложение — waUri откроется; иначе fallback на web API
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
      return;
    }
    if (await canLaunchUrl(apiUri)) {
      await launchUrl(apiUri, mode: LaunchMode.externalApplication);
      return;
    }
    NotificationUtils.showError(context, 'Не удалось открыть WhatsApp');
  }
}

class _BookingTab extends StatefulWidget {
  final Club club;
  
  const _BookingTab({required this.club});

  @override
  State<_BookingTab> createState() => _BookingTabState();
}

class _BookingTabState extends State<_BookingTab> {
  static const int _datesTotalDays = 30; // Показываем даты на месяц вперёд
  static const double _dateCellWidth = 60;
  static const double _dateCellGap = 12;
  static const double _dateCellExtent = _dateCellWidth + _dateCellGap; // шаг одного элемента в горизонтальном списке

  late final DateTime _datesStartDate; // сегодняшняя дата (старт ленты)
  late DateTime _selectedDate;
  late DateTime _monthTitleDate; // дата, от которой берём название месяца в заголовке (живёт от скролла)

  final ScrollController _datesScrollController = ScrollController();
  late final List<int> _monthStartIndices; // индексы элементов, где date.day == 1

  final Set<String> _selectedHours = <String>{};
  bool _showUnavailableSlots = false;
  bool _onlinePayment = true;
  bool _isLoadingCourts = false;
  bool _isLoadingTimeSlots = false;
  List<Court> _courts = [];
  List<Court?> _selectedCourts = [null]; // Список выбранных кортов
  List<String> _availableTimeSlots = []; // Список доступных таймслотов с сервера
  Set<String> _availableCourtIdsForSelection = <String>{}; // корты, доступные на ВСЕ выбранные слоты
  // Динамическая цена (с учётом rules/overrides) по выбранным слотам: court_id -> price_total
  Map<String, double> _availableCourtTotalPrices = <String, double>{};
  final List<GlobalKey> _courtSelectorKeys = [GlobalKey()];
  
  // Полный список слотов в течение рабочего времени кортов
  List<String> _timeSlots = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _datesStartDate = DateTime(now.year, now.month, now.day);
    _selectedDate = _datesStartDate;
    _monthTitleDate = _datesStartDate;
    _monthStartIndices = List<int>.generate(_datesTotalDays, (i) => i)
        .where((i) => _datesStartDate.add(Duration(days: i)).day == 1)
        .toList();

    _datesScrollController.addListener(_onDatesScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncMonthTitleToScroll(force: true));

    _loadCourts();
    _loadAvailableTimeSlots();
  }

  @override
  void dispose() {
    _datesScrollController.removeListener(_onDatesScroll);
    _datesScrollController.dispose();
    super.dispose();
  }

  void _onDatesScroll() {
    _syncMonthTitleToScroll(force: false);
  }

  void _syncMonthTitleToScroll({required bool force}) {
    if (!_datesScrollController.hasClients || _monthStartIndices.isEmpty) return;

    final current = _datesScrollController.offset;

    // Симметричная логика вперёд/назад:
    // берём последний старт месяца, который уже "слева" (boundary <= текущего offset).
    DateTime newTitle = _datesStartDate;
    for (final i in _monthStartIndices) {
      final boundary = i * _dateCellExtent;
      if (current >= boundary) {
        newTitle = _datesStartDate.add(Duration(days: i));
      }
    }

    if (newTitle.month == _monthTitleDate.month && newTitle.year == _monthTitleDate.year) return;

    if (!mounted) return;
    setState(() {
      _monthTitleDate = newTitle;
    });
  }

  // Строим список тайм-слотов на основе времени работы всех кортов клуба
  List<String> _computeTimeSlotsFromCourts(List<Court> courts) {
    if (courts.isEmpty) {
      // Запасной вариант по умолчанию
      return [
        '08:00', '09:00', '10:00', '11:00',
        '12:00', '13:00', '14:00', '15:00',
        '16:00', '17:00', '18:00', '19:00',
        '20:00', '21:00', '22:00',
      ];
    }

    int? minOpenHour;
    int? maxCloseHour;

    for (final court in courts) {
      final openParts = court.openTime.split(':');
      final closeParts = court.closeTime.split(':');
      final openHour = int.tryParse(openParts.first) ?? 8;
      final closeHour = int.tryParse(closeParts.first) ?? 22;

      if (minOpenHour == null || openHour < minOpenHour) {
        minOpenHour = openHour;
      }
      if (maxCloseHour == null || closeHour > maxCloseHour) {
        maxCloseHour = closeHour;
      }
    }

    // Безопасные границы
    minOpenHour = (minOpenHour ?? 8).clamp(0, 23);
    maxCloseHour = (maxCloseHour ?? 22).clamp(1, 24);

    // Стартовые времена слотов: каждый час, пока корт работает
    final List<String> slots = [];
    for (int h = minOpenHour; h < maxCloseHour; h++) {
      final hh = h.toString().padLeft(2, '0');
      slots.add('$hh:00');
    }
    return slots;
  }

  Future<void> _loadCourts() async {
    if (_isLoadingCourts) return;
    
    setState(() {
      _isLoadingCourts = true;
    });

    try {
      final response = await ApiService.getCourts(widget.club.id);
      final courts = response.courts;
      final slots = _computeTimeSlotsFromCourts(courts);

      if (!mounted) return;

      setState(() {
        _courts = courts;
        _timeSlots = slots;
        _isLoadingCourts = false;
      });
    } catch (e) {
      Logger.error('Ошибка загрузки кортов: $e');

      if (!mounted) return;

      setState(() {
        _isLoadingCourts = false;
      });
      NotificationUtils.showError(context, 'Ошибка загрузки кортов');
    }
  }

  Future<void> _loadAvailableTimeSlots() async {
    if (_isLoadingTimeSlots) return;

    setState(() {
      _isLoadingTimeSlots = true;
    });

    try {
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final availableSlots = await ApiService.getAvailableTimeSlots(
        clubId: widget.club.id,
        bookingDate: dateStr,
        durationMin: 60,
      );

      if (!mounted) return;

      setState(() {
        _availableTimeSlots = availableSlots;
        _isLoadingTimeSlots = false;
      });
    } catch (e) {
      Logger.error('Ошибка загрузки доступных таймслотов: $e');

      if (!mounted) return;

      setState(() {
        _availableTimeSlots = [];
        _isLoadingTimeSlots = false;
      });
    }
  }

  Future<void> _refreshAvailabilityForSelectedHours() async {
    if (_selectedHours.isEmpty) {
      if (!mounted) return;
      setState(() {
        _availableCourtIdsForSelection = <String>{};
        _availableCourtTotalPrices = <String, double>{};
      });
      return;
    }

    try {
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final hoursSorted = _selectedHours.toList()..sort();
      final res = await ApiService.checkBookingAvailabilityBulk(
        clubId: widget.club.id,
        bookingDate: dateStr,
        startTimes: hoursSorted,
        durationMin: 60,
      );

      final availableCourts = res['available_courts'] as List? ?? [];
      final Set<String> courtIds = availableCourts
          .map((c) => c['court_id'] as String)
          .toSet();
      final Map<String, double> priceMap = <String, double>{};
      for (final c in availableCourts) {
        try {
          final String id = (c['court_id'] as String?) ?? '';
          if (id.isEmpty) continue;
          final dynamic raw = c['price_total'];
          if (raw == null) continue;
          final double v = (raw as num).toDouble();
          priceMap[id] = v;
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        _availableCourtIdsForSelection = courtIds;
        _availableCourtTotalPrices = priceMap;
      });
    } catch (e) {
      Logger.error('Ошибка bulk-проверки доступности: $e');
      if (!mounted) return;
      setState(() {
        _availableCourtIdsForSelection = <String>{};
        _availableCourtTotalPrices = <String, double>{};
      });
    }
  }

  String _formatCourtPriceText(Court court) {
    // Если есть выбранные слоты и сервер вернул price_total — показываем её (актуальная цена по времени)
    final double? total = _availableCourtTotalPrices[court.id];
    if (total != null && _selectedHours.isNotEmpty) {
      final int hours = _selectedHours.length; // каждый слот = 1 час
      final String hoursLabel = hours == 1 ? '1 час' : '$hours ч';
      return '${total.toStringAsFixed(0)} ₽ ($hoursLabel)';
    }
    // Fallback: базовая цена (как раньше)
    return '${court.pricePerHour.toStringAsFixed(0)} ₽/час';
  }

  void _onToggleHour(String hour) {
    setState(() {
      if (_selectedHours.contains(hour)) {
        _selectedHours.remove(hour);
      } else {
        _selectedHours.add(hour);
      }

      // При смене набора времен сбрасываем выбор кортов, чтобы избежать неконсистентности
      _selectedCourts = [null];
      _courtSelectorKeys.clear();
      _courtSelectorKeys.add(GlobalKey());
    });

    _refreshAvailabilityForSelectedHours();
  }

  void _proceedToPayment() {
    if (_selectedHours.isEmpty || !_selectedCourts.any((court) => court != null)) {
      NotificationUtils.showError(context, 'Выберите время и хотя бы один корт');
      return;
    }

    final selectedCourts = _selectedCourts
        .where((court) => court != null)
        .cast<Court>()
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingConfirmationScreen(
          club: widget.club,
        bookingDate: _selectedDate,
        startTimes: (_selectedHours.toList()..sort()),
          selectedCourts: selectedCourts,
          onlinePayment: _onlinePayment,
        ),
      ),
    ).then((_) {
      // Обновляем данные после возврата с экрана подтверждения
        _loadCourts();
    });
  }

  bool get _canProceed => _selectedHours.isNotEmpty && _selectedCourts.any((court) => court != null);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        
        // Заголовок месяца
        Text(
          _getMonthName(_monthTitleDate.month),
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF222223),
            letterSpacing: -0.36,
          ),
        ),
        const SizedBox(height: 12),
        
        // Календарь-полоска (неделя)
        _buildWeekStrip(),
        
        const SizedBox(height: 28),
        
        // Переключатель недоступных слотов
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Показывать недоступные слоты',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF222223),
                letterSpacing: -0.32,
              ),
            ),
            AppSwitch(
              value: _showUnavailableSlots,
              onChanged: (value) => setState(() => _showUnavailableSlots = value),
            ),
          ],
        ),
        
        const SizedBox(height: 38),
        
        // Сетка временных слотов
        _buildTimeSlots(),
        
        const SizedBox(height: 16),
        
        // Выбор кортов
        if (_selectedHours.isNotEmpty) ...[
          // Проверяем, есть ли доступные корты для выбранного времени
          if (_availableCourtIdsForSelection.isEmpty) ...[
            const NoTimeAvailableWidget(),
            const SizedBox(height: 14),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Выберите корт',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF838A91),
                    letterSpacing: -0.32,
                    height: 3.5,
                  ),
                ),
                GestureDetector(
                  onTap: (_courts.isNotEmpty && _selectedCourts.length < _courts.length)
                      ? _addCourtSelector
                      : null,
                  child: Text(
                    'Добавить корт',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: (_courts.isNotEmpty && _selectedCourts.length < _courts.length)
                          ? const Color(0xFF262F63)
                          : const Color(0xFFCACACA),
                      letterSpacing: -0.52,
                    ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 0),
            ..._buildCourtSelectors(),
            const SizedBox(height: 16),
          ],
        ],

        const SizedBox(height: 16),

        // Переключатель "Оплата онлайн"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Оплата онлайн',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222223),
                letterSpacing: -0.32,
              ),
            ),
            AppSwitch(
              value: _onlinePayment,
              onChanged: (value) => setState(() => _onlinePayment = value),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        
        // Кнопка "Перейти к оплате"
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _canProceed ? _proceedToPayment : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF262F63),
              disabledBackgroundColor: const Color(0xFF262F63).withOpacity(0.45),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _onlinePayment ? 'Перейти к оплате' : 'Забронировать',
              style: const TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.32,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildWeekStrip() {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    
    return SizedBox(
      height: 70,
      child: ListView.builder(
        controller: _datesScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _datesTotalDays,
        itemBuilder: (context, index) {
          final date = _datesStartDate.add(Duration(days: index));
          final isSelected = date.day == _selectedDate.day &&
              date.month == _selectedDate.month &&
              date.year == _selectedDate.year;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
                _selectedHours.clear();
                _selectedCourts = [null];
                _courtSelectorKeys.clear();
                _courtSelectorKeys.add(GlobalKey());
                _availableCourtIdsForSelection = <String>{};
              });
              _loadAvailableTimeSlots();
            },
            child: Container(
              width: _dateCellWidth,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF262F63) : Colors.white,
                border: Border.all(
                  color: isSelected ? const Color(0xFF262F63) : const Color(0xFFD9D9D9),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    days[date.weekday - 1],
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF838A91),
                      letterSpacing: -0.28,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF2A2C36),
                      letterSpacing: -0.40,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSlots() {
    if (_isLoadingTimeSlots) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final visibleSlots = <Widget>[];
    
    // Проверяем, является ли выбранная дата сегодняшней
    final now = DateTime.now();
    final selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final isToday = selectedDate.isAtSameMomentAs(today);
    
    // Определяем, какие слоты показывать
    final slotsToShow = _showUnavailableSlots ? _timeSlots : _availableTimeSlots;
    
    for (final time in slotsToShow) {
      // Если выбранная дата - сегодня, скрываем прошедшие слоты
      if (isToday) {
        final timeParts = time.split(':');
        if (timeParts.length == 2) {
          final slotHour = int.tryParse(timeParts[0]);
          final slotMinute = int.tryParse(timeParts[1]);
          if (slotHour != null && slotMinute != null) {
            final slotTime = TimeOfDay(hour: slotHour, minute: slotMinute);
            final currentTime = TimeOfDay.fromDateTime(now);
            // Сравниваем время: если слот уже прошёл, пропускаем его
            if (slotTime.hour < currentTime.hour || 
                (slotTime.hour == currentTime.hour && slotTime.minute < currentTime.minute)) {
              continue;
            }
          }
        }
      }
      
      final isSelected = _selectedHours.contains(time);
      final isAvailable = _availableTimeSlots.contains(time);
      
      // Если слот недоступен и не показываем недоступные, пропускаем
      if (!isAvailable && !_showUnavailableSlots) {
        continue;
      }
      
      visibleSlots.add(
        GestureDetector(
          onTap: isAvailable 
              ? () => _onToggleHour(time) 
              : (_showUnavailableSlots ? () => _onToggleHour(time) : null),
          child: Container(
            width: 80,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: isSelected 
                    ? const Color(0xFF262F63) 
                    : (isAvailable ? const Color(0xFFD9D9D9) : const Color(0xFFE6E6E6)),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                time,
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isAvailable 
                      ? const Color(0xFF2A2C36) 
                      : const Color(0xFF2A2C36).withOpacity(0.4),
                  letterSpacing: -0.32,
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    // Если нет доступных слотов, показываем сообщение
    if (visibleSlots.isEmpty) {
      return const NoTimeAvailableWidget();
    }
    
    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: visibleSlots,
        ),
      ],
    );
  }

  void _addCourtSelector() {
    setState(() {
      _selectedCourts.add(null);
      _courtSelectorKeys.add(GlobalKey());
    });
  }

  void _removeLastCourtSelector() {
    if (_selectedCourts.length > 1) {
      setState(() {
        _selectedCourts.removeLast();
        _courtSelectorKeys.removeLast();
      });
    }
  }

  List<Widget> _buildCourtSelectors() {
    final List<Widget> selectors = [];
    
    for (int i = 0; i < _selectedCourts.length; i++) {
      if (i > 0) {
        selectors.add(const SizedBox(height: 12));
      }
      
      selectors.add(_buildCourtSelector(i));
    }
    
    // Добавляем кнопку "Удалить корт" если полей больше 1
    if (_selectedCourts.length > 1) {
      selectors.add(const SizedBox(height: 12));
      selectors.add(
        GestureDetector(
          onTap: _removeLastCourtSelector,
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Удалить корт',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFFEC2D20),
                letterSpacing: -0.32,
              ),
            ),
          ),
        ),
      );
    }
    
    return selectors;
  }

  Widget _buildCourtSelector(int index) {
    if (_isLoadingCourts) {
      return Container(
        width: double.infinity,
        height: 60,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_courts.isEmpty) {
      return Container(
        width: double.infinity,
        height: 60,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Корты не найдены',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF838A91),
              letterSpacing: -0.32,
            ),
          ),
        ),
      );
    }

    final selectedCourt = _selectedCourts[index];

    // Собираем id кортов, уже выбранных в других полях
    final selectedOtherCourtIds = _selectedCourts
        .asMap()
        .entries
        .where((entry) => entry.key != index && entry.value != null)
        .map((entry) => entry.value!.id)
        .toSet();

    // Фильтруем корты, доступные для ВСЕХ выбранных времен
    final baseCourts = _availableCourtIdsForSelection.isEmpty
        ? _courts
        : _courts.where((c) => _availableCourtIdsForSelection.contains(c.id)).toList();

    // Исключаем уже выбранные в других полях корты из списка выбора,
    // но оставляем текущий выбранный корт для этого поля
    final displayCourts = baseCourts.where((court) {
      if (selectedCourt != null && court.id == selectedCourt.id) {
        return true;
      }
      return !selectedOtherCourtIds.contains(court.id);
    }).toList();

    return GestureDetector(
      key: _courtSelectorKeys[index],
      onTap: () => _showCourtSelectionBottomSheet(displayCourts, index),
      child: Container(
      width: double.infinity,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9D9D9)),
      ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                selectedCourt != null 
                    ? '${selectedCourt.name} — ${_formatCourtPriceText(selectedCourt)}'
                    : 'Выберите корт',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 16,
              fontWeight: FontWeight.w400,
                  color: selectedCourt != null ? const Color(0xFF2A2C36) : const Color(0xFF838A91),
              letterSpacing: -0.32,
            ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Color(0xFF838A91)),
          ],
        ),
      ),
    );
  }

  void _showCourtSelectionBottomSheet(List<Court> courts, int fieldIndex) {
    final RenderBox? renderBox = _courtSelectorKeys[fieldIndex].currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Вычисляем высоту меню
    final menuHeight = courts.length * 56.0 + (courts.length - 1); // высота элементов + разделители
    final gap = 4.0; // отступ между кнопкой и меню
    final upshift = 70.0; // поднимаем меню на 70 пикселей выше
    
    // Позиция сразу под кнопкой
    final topPosition = position.dy + size.height + gap - upshift;
    final bottomSpace = screenHeight - topPosition;
    
    // Определяем финальную позицию
    double finalTop;
    double maxHeight;
    
    if (bottomSpace >= menuHeight) {
      // Меню полностью помещается снизу
      finalTop = topPosition;
      maxHeight = bottomSpace - 16; // 16 - отступ от низа экрана
    } else {
      // Меню не помещается снизу, поднимаем его
      finalTop = screenHeight - menuHeight - 16 - upshift;
      maxHeight = menuHeight;
      
      // Если меню все равно не помещается, уменьшаем его высоту
      if (finalTop < 16) {
        finalTop = 16;
        maxHeight = screenHeight - 32; // отступы сверху и снизу
      }
    }
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          // Прозрачный фон для закрытия меню при клике вне его
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Меню
          Positioned(
            left: 16,
            right: 16,
            top: finalTop,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: maxHeight,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      courts.length * 2 - 1,
                      (index) {
                        if (index.isOdd) {
                          // Разделитель
                          return Container(
                            height: 1,
                            color: const Color(0xFF2A2C36).withOpacity(0.1),
                          );
                        }
                        
                        final courtIndex = index ~/ 2;
                        final court = courts[courtIndex];

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCourts[fieldIndex] = court;
                            });
                            Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.vertical(
                            top: courtIndex == 0 ? const Radius.circular(12) : Radius.zero,
                            bottom: courtIndex == courts.length - 1 ? const Radius.circular(12) : Radius.zero,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  court.name,
                                  textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                                    color: Color(0xFF2A2C36),
                        letterSpacing: -0.32,
                                    height: 1.125,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  // Показываем динамическую цену по выбранным слотам (если есть),
                                  // иначе базовую цену корта.
                                  (_availableCourtTotalPrices[court.id] != null && _selectedHours.isNotEmpty)
                                      ? '${_availableCourtTotalPrices[court.id]!.toStringAsFixed(0)} ₽'
                                      : '${court.pricePerHour.toStringAsFixed(0)}₽',
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    fontFamily: 'SF Pro Display',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF262F63),
                                    letterSpacing: -0.28,
                                    height: 1.14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return months[month - 1];
  }
}

class _ClubCompetitionsTab extends StatelessWidget {
  final bool isLoading;
  final String? errorText;
  final List<Competition> competitions;
  final Future<void> Function() onRefresh;
  final bool showAllActivities;
  final ValueChanged<bool> onToggleShowAllActivities;

  const _ClubCompetitionsTab({required this.isLoading, required this.errorText, required this.competitions, required this.onRefresh, required this.showAllActivities, required this.onToggleShowAllActivities});

  String _weekdayRu(int weekday) {
    switch (weekday) {
      case 1:
        return 'Понедельник';
      case 2:
        return 'Вторник';
      case 3:
        return 'Среда';
      case 4:
        return 'Четверг';
      case 5:
        return 'Пятница';
      case 6:
        return 'Суббота';
      case 7:
      default:
        return 'Воскресенье';
    }
  }

  String _monthRu(int month) {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return months[month - 1];
  }

  String _formatLevel(double? min, double? max) {
    if (min == null && max == null) return '—';
    if (min != null && max != null) return '${min.toStringAsFixed(2)}–${max.toStringAsFixed(2)}';
    if (min != null) return 'от ${min.toStringAsFixed(2)}';
    return 'до ${max!.toStringAsFixed(1)}';
  }

  String _audienceText(String gender) {
    switch (gender) {
      case 'male':
        return 'Мужчины';
      case 'female':
        return 'Женщины';
      default:
        return 'Для всех';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Column(
        children: const [
          SizedBox(height: 12),
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 120),
        ],
      );
    }
    if (errorText != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            errorText!,
            style: const TextStyle(color: Color(0xFF79766E)),
          ),
        ),
      );
    }

    final grouped = <String, List<Competition>>{};
    for (final c in competitions) {
      final date = DateTime(c.startTime.year, c.startTime.month, c.startTime.day);
      final weekday = _weekdayRu(date.weekday);
      final label = '$weekday, ${date.day} ${_monthRu(date.month)}';
      grouped.putIfAbsent(label, () => []).add(c);
    }

    if (grouped.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 0),
          child: Text(
            'Турниров не найдено',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF222223),
              fontFamily: 'SF Pro Display',
              letterSpacing: -0.32,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _AllActivitiesToggle(value: showAllActivities, onChanged: onToggleShowAllActivities);
          }
          final key = grouped.keys.elementAt(index - 1);
          final comps = grouped[key]!;
          final cards = comps.map((c) => CompetitionMiniCard(
                title: c.name,
                startTime: c.startTime,
                levelText: _formatLevel(c.minRating, c.maxRating),
                audienceText: _audienceText(c.participantsGender),
                participantsGender: c.participantsGender,
                participantAvatarUrls: c.participants.map((p) => p.avatarUrl).whereType<String>().toList(),
                participantNames: c.participants
                    .map((p) => [p.name].whereType<String>().where((s) => s.isNotEmpty).join(' '))
                    .toList(),
                registeredCount: c.participants.length,
                capacity: c.maxParticipants ?? 0,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CompetitionDetailsScreen(competitionId: c.id),
                    ),
                  ).then((_) => onRefresh());
                },
              ));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                child: Text(
                  key,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222223),
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.36,
                  ),
                ),
              ),
              ...cards
                  .expand(
                    (c) => [
                      c,
                      const SizedBox(height: 12)
                    ],
                  )
                  .toList()
                  .sublist(0, comps.length * 2 - 1),
            ],
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 0),
        itemCount: grouped.length + 1,
      ),
    );
  }
}

class _AllActivitiesToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _AllActivitiesToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 0),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Показывать все активности',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF222223),
                letterSpacing: -0.32,
              ),
            ),
            AppSwitch(value: value, onChanged: onChanged),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _UpcomingMatchesTab extends StatefulWidget {
  final DateTime weekStart; // понедельник
  final int selectedDayOffset; // 0..6
  final ValueChanged<int> onSelectDay;
  final bool showUnavailable;
  final ValueChanged<bool> onToggleUnavailable;
  final bool isLoading;
  final String? errorText;
  final List<Match> matches;
  final int? selectedHour;
  final ValueChanged<int> onSelectHour;
  final VoidCallback onCreateMatch;
  final VoidCallback onRefreshMatches;
  final bool unfilteredMode;

  const _UpcomingMatchesTab({
    required this.weekStart,
    required this.selectedDayOffset,
    required this.onSelectDay,
    required this.showUnavailable,
    required this.onToggleUnavailable,
    required this.isLoading,
    required this.errorText,
    required this.matches,
    required this.selectedHour,
    required this.onSelectHour,
    required this.onCreateMatch,
    required this.onRefreshMatches,
    required this.unfilteredMode,
  });

  @override
  State<_UpcomingMatchesTab> createState() => _UpcomingMatchesTabState();
}

class _UpcomingMatchesTabState extends State<_UpcomingMatchesTab> {
  bool _slotsEmpty = false;

  @override
  Widget build(BuildContext context) {
    bool slotsEmptyNow() {
      // Функциональность недоступности отключена — считаем, что слоты не пустые.
      return false;
    }

    final bool isSlotsEmpty = slotsEmptyNow();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeekStrip(
          weekStart: widget.weekStart,
          selectedOffset: widget.selectedDayOffset,
          onSelect: widget.onSelectDay,
        ),
        const SizedBox(height: 16),
        _ToggleRow(
          value: widget.showUnavailable,
          onChanged: widget.onToggleUnavailable,
        ),
        const SizedBox(height: 8),
        if (widget.isLoading)
          Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFF7F7F7),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: const Center(child: CircularProgressIndicator()),
              ),
              const SizedBox(height: 120),
            ],
          )
        else if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                widget.errorText!,
                style: const TextStyle(color: Color(0xFF79766E)),
              ),
            ),
          )
        else ...[
          if (widget.unfilteredMode) ...[
            const SizedBox(height: 8),
            _SlotsGrid(
              day: widget.weekStart,
              matches: widget.matches,
              showUnavailable: widget.showUnavailable,
              selectedHour: widget.selectedHour,
              onSelectHour: widget.onSelectHour,
              onSlotsEmptyChanged: (isEmpty) {
                if (mounted && _slotsEmpty != isEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _slotsEmpty = isEmpty);
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            _HourFilteredMatches(
              matches: widget.matches,
              selectedHour: widget.selectedHour,
              onCreateMatch: widget.onCreateMatch,
              onMatchUpdated: widget.onRefreshMatches,
              selectedDay: widget.weekStart,
            ),
            const SizedBox(height: 16),
          ] else ...[
            _SlotsGrid(
            day: widget.weekStart.add(Duration(days: widget.selectedDayOffset)),
            matches: widget.matches,
            showUnavailable: widget.showUnavailable,
            selectedHour: widget.selectedHour,
            onSelectHour: widget.onSelectHour,
            onSlotsEmptyChanged: (isEmpty) {
              if (mounted && _slotsEmpty != isEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _slotsEmpty = isEmpty);
                });
              }
            },
            ),
            const SizedBox(height: 8),
            if (!isSlotsEmpty)
              _HourFilteredMatches(
                matches: widget.matches,
                selectedHour: widget.selectedHour,
                onCreateMatch: widget.onCreateMatch,
                onMatchUpdated: widget.onRefreshMatches,
                selectedDay: widget.weekStart.add(Duration(days: widget.selectedDayOffset)),
              ),
            // CTA для создания матча передаём через родителя
            // onCreateMatch будет использован внутри пустого состояния
            const SizedBox(height: 16),
            if (isSlotsEmpty) const SizedBox(height: 120),
          ],
        ],
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final DateTime weekStart;
  final int selectedOffset;
  final ValueChanged<int> onSelect;

  const _WeekStrip({
    required this.weekStart,
    required this.selectedOffset,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const days = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
    const months = [
      'Янв', 'Февр', 'Март', 'Апр', 'Май', 'Июнь',
      'Июль', 'Авг', 'Сент', 'Окт', 'Нояб', 'Дек'
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final date = weekStart.add(Duration(days: i));
        final bool isSelected = i == selectedOffset;
        final int weekdayIndex = date.weekday == 7 ? 6 : date.weekday - 1; // 0..6 для ПН..ВС
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  days[weekdayIndex],
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222223),
                    letterSpacing: -0.32,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF262F63) : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF262F63) : const Color(0x00000000),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      date.day.toString(),
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF222223),
                        letterSpacing: -0.32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    months[date.month - 1],
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF222223),
                      letterSpacing: -0.28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Показывать недоступные слоты',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF222223),
            letterSpacing: -0.32,
          ),
        ),
        AppSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _SlotsGrid extends StatelessWidget {
  final DateTime day;
  final List<Match> matches;
  final bool showUnavailable;
  final int? selectedHour;
  final ValueChanged<int> onSelectHour;
  final ValueChanged<bool>? onSlotsEmptyChanged;
  const _SlotsGrid({required this.day, required this.matches, required this.showUnavailable, required this.selectedHour, required this.onSelectHour, this.onSlotsEmptyChanged});

  // Полоска часов должна идти последовательно и переноситься через 5 колонок
  List<int> get _allHours => [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];

  @override
  Widget build(BuildContext context) {
    return _RowOfSlots(
      hours: _allHours,
      day: day,
      matches: matches,
      showUnavailable: showUnavailable,
      selectedHour: selectedHour,
      onSelectHour: onSelectHour,
      onSlotsEmptyChanged: onSlotsEmptyChanged,
    );
  }
}

class _RowOfSlots extends StatelessWidget {
  final List<int> hours;
  final DateTime day;
  final List<Match> matches;
  final bool showUnavailable;
  final int? selectedHour;
  final ValueChanged<int> onSelectHour;
  final ValueChanged<bool>? onSlotsEmptyChanged;
  const _RowOfSlots({required this.hours, required this.day, required this.matches, required this.showUnavailable, required this.selectedHour, required this.onSelectHour, this.onSlotsEmptyChanged});

  @override
  Widget build(BuildContext context) {
    // Сначала сформируем список видимых слотов с учётом свитча
    final List<Widget> visible = [];
    // Базовая ширина ячейки как при 5 колонках, чтобы слоты не растягивались
    const double spacing = 8;
    final double availableWidth = MediaQuery.of(context).size.width - 24; // паддинг 12 слева/справа
    final double baseItemWidth = (availableWidth - (5 - 1) * spacing) / 5;

    for (int i = 0; i < hours.length; i++) {
      final int h = hours[i];
      final slotMatches = matches.where((m) =>
        m.dateTime.year == day.year &&
        m.dateTime.month == day.month &&
        m.dateTime.day == day.day &&
        m.dateTime.hour == h
      ).toList();

      // Отключаем логику недоступности: считаем все слоты доступными

      // Если все матчи в слоте заняты и свитч выключен — ранее скрывали слот.
      // По требованию временно отключаем функциональность скрытия и всегда показываем слот,
      // меняем только визуальное состояние переключателя.
      // if (isUnavailable && !showUnavailable) {
      //   continue;
      // }

      // Аватарки должны агрегироваться по всем матчам этого слота
      final Color borderColor = const Color(0xFFD9D9D9);
      final bool isSelected = selectedHour != null && selectedHour == h;

      visible.add(
        SizedBox(
          width: baseItemWidth,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelectHour(h),
              child: Container(
                padding: const EdgeInsets.all(0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF262F63) : borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Text(
                        _formatHour(h),
                        style: const TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF222223),
                          letterSpacing: -0.32,
                        ),
                      ),
                    ),
                    if (slotMatches.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: -6,
                        child: _TinyParticipantsRowAggregated(matches: slotMatches),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (visible.isEmpty) {
      onSlotsEmptyChanged?.call(true);
      // Все слоты закрыты (или скрыты настройкой) — показываем карточку пустого состояния
      return Container
      (
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE6E6E6)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.access_time_rounded, size: 20, color: Color(0xFF79766E)),
            const SizedBox(height: 8),
            const Text(
              'Свободного времени нет',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF222223),
                letterSpacing: -0.32,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Попробуйте выбрать другой день или время',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF79766E),
                letterSpacing: -0.28,
              ),
            ),
          ],
        ),
      );
    }

    onSlotsEmptyChanged?.call(false);
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: visible,
    );
  }

  String _formatHour(int h) {
    final hh = h.toString().padLeft(1, '0');
    return '$hh:00';
  }
}

// Удалена одиночная версия ряда участников, используется агрегированная версия

class _TinyParticipantsRowAggregated extends StatelessWidget {
  final List<Match> matches;
  const _TinyParticipantsRowAggregated({required this.matches});

  @override
  Widget build(BuildContext context) {
    // Собираем участников всех матчей слота, ограничиваем первыми 3
    final participants = <MatchParticipant>[];
    for (final m in matches) {
      for (final p in m.participants) {
        if (participants.length >= 3) break;
        // Избегаем дублей по userId
        if (!participants.any((x) => x.userId == p.userId)) {
          participants.add(p);
          if (participants.length >= 3) break;
        }
      }
      if (participants.length >= 3) break;
    }

    final int totalParticipants = matches.fold(0, (sum, m) => sum + m.participants.length);
    final int extra = totalParticipants - participants.length;

    final double step = 12; // сдвиг перекрытия
    final double baseWidth = participants.isEmpty ? 0 : 16 + (participants.length - 1) * step;
    final double totalWidth = baseWidth + (extra > 0 ? step : 0);

    return SizedBox(
      width: totalWidth,
      height: 16,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < participants.length; i++)
            Positioned(
              left: i * step,
              top: 0,
              child: _TinyUserAvatar(url: participants[i].avatarUrl, name: participants[i].name),
            ),
          if (extra > 0)
            Positioned(
              left: baseWidth,
              top: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7F8AC0)),
                ),
                child: Center(
                  child: Text(
                    '+$extra',
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF262F63),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TinyUserAvatar extends StatelessWidget {
  final String? url;
  final String name;
  const _TinyUserAvatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipOval(
              child: UserAvatar(
                imageUrl: url,
                userName: name,
                radius: 8,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// _AvailableMatchesSection удалён: по требованию показываем только результаты фильтра

class _HourFilteredMatches extends StatelessWidget {
  final List<Match> matches;
  final int? selectedHour;
  final VoidCallback onCreateMatch;
  final VoidCallback? onMatchUpdated;
  final DateTime selectedDay; // добавлено: выбранный день для фильтра
  const _HourFilteredMatches({required this.matches, required this.selectedHour, required this.onCreateMatch, this.onMatchUpdated, required this.selectedDay});

  @override
  Widget build(BuildContext context) {
    // Подготовим список к показу — либо все за день, либо только выбранный час
    final List<Match> list = selectedHour == null
        ? matches
        : matches.where((m) => m.dateTime.hour == selectedHour).toList();
    // Показываем все матчи, не скрываем заполненные
    final List<Match> visibleList = list;

    if (visibleList.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Нет доступных матчей',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF222223),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Попробуйте выбрать другое время или создать свой матч',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF222223),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCreateMatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF262F63),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Создать матч',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Доступные Матчи',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF222223),
              ),
            ),
            GestureDetector(
              onTap: () {
                // Передаём день и временной диапазон согласно выбранному фильтру
                final DateTime day = selectedDay;
                final List<DateTime> initialDates = [DateTime(day.year, day.month, day.day)];
                final String? initialTimeRange = selectedHour == null
                    ? 'Весь день'
                    : (() {
                        final int h = selectedHour!;
                        if (h >= 8 && h < 12) return 'Утро с 8 до 12';
                        if (h >= 12 && h < 18) return 'День с 12 до 18';
                        if (h >= 18 && h <= 23) return 'Вечер с 18 до 24';
                        return 'Весь день';
                      })();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MatchesScreen(
                      fixedClubId: visibleList.isNotEmpty ? visibleList.first.clubId : null,
                      fixedCity: visibleList.isNotEmpty ? visibleList.first.clubCity : null,
                      initialDates: initialDates,
                      initialTimeRange: initialTimeRange,
                    ),
                  ),
                );
              },
              child: const Text(
                'Смотреть всё',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF262F63),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...visibleList.map((m) => MatchCard(match: m, onUpdated: onMatchUpdated)),
      ],
    );
  }
}
