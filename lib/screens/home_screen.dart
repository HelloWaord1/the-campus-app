import 'package:flutter/material.dart' hide Match;
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_storage.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/match.dart';
import '../models/booking.dart';
import 'edit_profile_screen.dart';
import 'friends_screen.dart';
import 'notifications_screen.dart';
import 'matches_screen.dart';
import 'my_matches_screen.dart';
import '../widgets/profile_menu_button.dart';
import '../utils/rating_utils.dart';
import '../utils/date_utils.dart' as date_utils;
import '../widgets/level_badge.dart';
import '../widgets/reliability_rating_card.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/upcoming_matches_widget.dart';
import '../widgets/past_matches_widget.dart';
import 'create_match_screen.dart';
import '../utils/responsive_utils.dart';
import 'clubs/clubs_list_screen.dart';
import 'courts/booking_details_screen.dart';
import 'courts/all_bookings_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import 'skill_level_test_screen.dart'; // Импортируем новый экран
import 'rating_details_screen.dart';
import 'upcoming_matches_screen.dart';
import 'all_past_matches_screen.dart';
import 'all_matches_screen.dart';
import '../widgets/user_avatar.dart';
import '../widgets/contact_edit_modal.dart';
import 'package:url_launcher/url_launcher.dart';
import 'match_details_screen.dart';
import 'trainings_screen.dart';
import '../widgets/match_score_input.dart';
import '../widgets/score_confirmation_sheet.dart';
import '../widgets/match_score_card.dart';
import '../widgets/score_input_modal_content.dart';
import '../utils/notification_utils.dart';

enum RatingHistoryFilter { five, ten, all }

class _TruncateResult {
  final String truncatedText;
  final bool didTruncate;

  const _TruncateResult({required this.truncatedText, required this.didTruncate});
}

class HomeScreen extends StatefulWidget {
  final int? initialTabIndex;
  const HomeScreen({super.key, this.initialTabIndex});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _userName;
  String? _currentUserId;
  UserProfile? _userProfile;
  List<RatingHistoryItem> _ratingHistory = const [];
  ContactData? _contactData;
  bool _isLoadingProfile = false;
  String? _profileError;
  RatingHistoryFilter _selectedRatingFilter = RatingHistoryFilter.five;

  // Добавляем состояние для рейтинга
  UserRatingResponse? _userRating;
  bool _isRatingLoading = true;

  // Добавляем состояние для бронирований
  List<Booking> _myBookings = [];
  bool _isLoadingBookings = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTabIndex != null) {
      _currentIndex = widget.initialTabIndex!;
    }
    // Важно: _currentUserId нужен для корректной подгрузки истории рейтинга через /api/users/{me}/profile.
    // Поэтому сперва грузим пользователя, затем профиль.
    _loadUserData().then((_) => _loadProfile());
    _loadUserRating();
    _loadContactData();
    _loadMyBookings();
  }

  Future<void> _loadContactData() async {
    try {
      final contacts = await ApiService.getContacts();
      if (!mounted) return;
      setState(() {
        _contactData = contacts;
      });
    } catch (e) {
      // Handle error appropriately
      print('Error loading contacts: $e');
    }
  }

  Future<void> _loadMyBookings() async {
    setState(() {
      _isLoadingBookings = true;
    });
    
    try {
      // Загружаем будущие бронирования (все кроме cancelled)
      final now = DateTime.now();
      final allBookings = await ApiService.getMyBookings(
        startDate: now,
      );
      
      // Фильтруем отмененные бронирования
      final bookings = allBookings.where((b) => b.status != 'cancelled').toList();
      
      if (!mounted) return;
      
      setState(() {
        _myBookings = bookings;
        _isLoadingBookings = false;
      });
    } catch (e) {
      print('Error loading bookings: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingBookings = false;
      });
    }
  }

  _TruncateResult _truncateToTwoAndHalfLines(
    String text,
    TextStyle style,
    double maxWidth,
    TextDirection textDirection,
  ) {
    if (text.isEmpty) {
      return const _TruncateResult(truncatedText: '', didTruncate: false);
    }

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      maxLines: null,
      ellipsis: null,
    )..layout(maxWidth: maxWidth);

    final lines = painter.computeLineMetrics();
    if (lines.length <= 2) {
      return _TruncateResult(truncatedText: text, didTruncate: false);
    }

    final l3 = lines[2];
    final dx = l3.left + (l3.width * 0.5);
    final dy = l3.baseline;
    final pos = painter.getPositionForOffset(Offset(dx, dy));
    int cut = pos.offset;
    if (cut < 0) cut = 0;
    if (cut > text.length) cut = text.length;

    String truncated = text.substring(0, cut).trimRight();

    final testPainter = TextPainter(
      text: TextSpan(text: '$truncated…', style: style),
      textDirection: textDirection,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    final testLines = testPainter.computeLineMetrics();
    if (testLines.length >= 3 && testLines[2].width > l3.width * 0.5 + 1) {
      final backtrackCount = truncated.length >= 2 ? 2 : 0;
      if (backtrackCount > 0) {
        truncated = truncated.substring(0, truncated.length - backtrackCount).trimRight();
      }
    }

    return _TruncateResult(truncatedText: '$truncated…', didTruncate: true);
  }

  Future<void> _loadUserData() async {
    final user = await AuthStorage.getUser();
    if (user != null && mounted) {
      setState(() {
        _userName = user.name;
        _currentUserId = user.id;
      });
    }
  }

  Future<void> _loadProfile() async {
    print('🔄 _loadProfile: Starting profile load');
    if (!mounted) return;
    setState(() {
      _isLoadingProfile = true;
      _profileError = null;
    });

    try {
      print('🔄 _loadProfile: Calling ApiService.getProfile()');
      final profile = await ApiService.getProfile();
      print('✅ _loadProfile: Profile loaded successfully');
      print('📊 Profile data: name=${profile.name}, totalMatches=${profile.totalMatches}');
      if (!mounted) return;
      setState(() {
        _userProfile = profile;
        _ratingHistory = profile.ratingHistory;
        _isLoadingProfile = false;
      });
      
      print('📊 Rating history loaded: ${_ratingHistory.length} items');
      for (final h in _ratingHistory.take(5)) {
        print('  - matchId=${h.matchId}, ratingBefore=${h.ratingBefore}, ratingAfter=${h.ratingAfter}, ratingChange=${h.ratingChange}');
      }

      // Важно: иногда /api/profile приходит без полей, нужных для расчёта дельты рейтинга по матчам
      // (например, нет rating_before и rating_change). Тогда подтягиваем историю из /api/users/{me}/profile.
      final bool hasUsefulRatingHistory = profile.ratingHistory.any((h) =>
          (h.matchId != null && h.matchId!.isNotEmpty) &&
          (h.ratingBefore != null || h.ratingChange != null));
      if (!hasUsefulRatingHistory && _currentUserId != null) {
        try {
          final alt = await ApiService.getUserProfileById(_currentUserId!);
          final bool altUseful = alt.ratingHistory.any((h) =>
              (h.matchId != null && h.matchId!.isNotEmpty) &&
              (h.ratingBefore != null || h.ratingChange != null));
          if (!mounted) return;
          if (altUseful) {
            setState(() {
              _ratingHistory = alt.ratingHistory;
            });
          }
        } catch (_) {
          // тихо: остаёмся на данных из /api/profile
        }
      }
    } catch (e, stackTrace) {
      print('❌ _loadProfile: Error occurred: $e');
      print('📍 Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _profileError = e.toString();
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadUserRating() async {
    print('🔄 _loadUserRating: Starting rating load');
    if (!mounted) return;
    setState(() {
      _isRatingLoading = true;
    });
    try {
      print('🔄 _loadUserRating: Calling ApiService.getCurrentUserRating()');
      final rating = await ApiService.getCurrentUserRating();
      print('✅ _loadUserRating: Rating loaded successfully');
      print('📊 Rating data: ntrpLevel=${rating?.ntrpLevel}, rating=${rating?.rating}');
      if (!mounted) return;
      setState(() {
        _userRating = rating;
        _isRatingLoading = false;
      });
    } catch (e, stackTrace) {
      print('❌ _loadUserRating: Error occurred: $e');
      print('📍 Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _userRating = null;
        _isRatingLoading = false;
      });
    }
  }

  Future<void> _openTelegramSupport() async {
    final Uri tgUri = Uri.parse('tg://resolve?domain=ace_padel_support');
    final Uri httpsUri = Uri.parse('https://t.me/ace_padel_support');
    try {
      if (await canLaunchUrl(tgUri)) {
        await launchUrl(tgUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _openExternalUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _onTabTapped(int index) {
    print('🎯 _onTabTapped: Switching to tab $index');
    setState(() {
      _currentIndex = index;
    });
    
    // Если переключились на вкладку Home (индекс 0), обновляем бронирования и профиль
    if (index == 0) {
      print('🎯 _onTabTapped: Home tab selected, loading bookings and profile');
      _loadMyBookings();
      _loadProfile();
    }
    // Если переключились на вкладку профиля (индекс 3), загружаем профиль
    else if (index == 3) {
      print('🎯 _onTabTapped: Profile tab selected, loading profile');
      _loadProfile();
    }
  }

  Future<void> _logout() async {
    await AuthStorage.clearAuthData();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  void _showLogoutDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 0.0, right: 0.0, top: 0.0, bottom: 0.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Выход из профиля',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222223),
                      ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0E0E0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFF89867E),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Вы уверены что хотите выйти из профиля?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF222223),
                      ),
              textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 32),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _logout();
                            },
                            style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC2D20),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text('Выйти', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F3F3),
                      foregroundColor: const Color(0xFF222223),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text('Отмена', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ],
                    ),
                  ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Удаление профиля',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222223),
                      ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0E0E0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Color(0xFF89867E),
                      size: 20,
                    ),
                  ),
                ),
              ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Вы уверены что хотите удалить профиль?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF222223),
                      ),
              textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 32),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              try {
                                await ApiService.deleteProfile();
                                // Очищаем локальные данные и уходим на экран регистрации/онбординга
                                await AuthStorage.clearAuthData();
                                if (context.mounted) {
                                  Navigator.of(context).pushNamedAndRemoveUntil('/register', (route) => false);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  NotificationUtils.showError(context, 'Ошибка удаления профиля: ${e.toString()}');
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC2D20),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text('Удалить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F3F3),
                      foregroundColor: const Color(0xFF222223),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text('Отмена', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ],
                    ),
                  ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return Container(
      color: const Color(0xFF262F63), // Зелёный фон для всего экрана
      child: Column(
        children: [
          // Верхний зелёный блок с приветствием
          Container(
            width: double.infinity,
            color: const Color(0xFF262F63),
            child: SafeArea(
              bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20), // Увеличен нижний отступ
              child: Text(
                'Добро пожаловать, ${(_userProfile?.name ?? _userName)?.split(' ').first ?? 'Михаил'}!',
                style: const TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w600,
                  fontSize: 21,
                  height: 1.2,
                  letterSpacing: -1.2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          ),
          
          // Основной контент с белым фоном и скругленными углами
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    
                    // Секция "Мои бронирования"
                    _buildMyBookingsSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Секция "Мои матчи"
                    _buildMyMatchesSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Секция карточек (Корты, Матчи, Тренировки, Турниры)
                    _buildMainCardsSection(),
                    
                    const SizedBox(height: 100), // Отступ для нижней панели
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyMatchesSection() {
    // Получаем матчи из профиля и фильтруем турнирные и старые (более 2.5 дней)
    final cutoffTime = DateTime.now().subtract(const Duration(hours: 60)); // 2.5 дня
    final upcomingMatches = (_userProfile?.upcomingMatches ?? [])
        .where((match) => /*!match.isTournament && */match.dateTime.isAfter(cutoffTime))
        .toList();
    final pastMatches = (_userProfile?.pastMatches ?? [])
        .where((match) => /*!match.isTournament && */match.dateTime.isAfter(cutoffTime))
        .toList();
    
    // Сортируем прошлые матчи по дате убыванию и берём самые свежие
    final sortedPast = List<Match>.from(pastMatches)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    
    // Объединяем текущие и завершенные матчи для показа
    final allMatches = [...upcomingMatches, ...sortedPast.take(3)];
    
    if (allMatches.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Мои матчи',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                  height: 1.22,
                  letterSpacing: -0.8,
                  color: Color(0xFF222223),
              ),
            ),
              GestureDetector(
                onTap: () {
                  // Получаем все матчи из профиля (без фильтрации по времени)
                  final allUpcoming = _userProfile?.upcomingMatches
                          .where((match) => !match.isTournament)
                          .toList() ??
                      [];
                  final allPast = _userProfile?.pastMatches
                          .where((match) => !match.isTournament)
                          .toList() ??
                      [];
                  
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AllMatchesScreen(
                        upcomingMatches: allUpcoming,
                        pastMatches: allPast,
                      ),
                    ),
                  ).then((_) {
                    // Обновляем профиль при возврате
                    _loadProfile();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: const Text(
                    'Смотреть все',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      height: 1.25,
                      letterSpacing: -0.8,
                      color: Color(0xFF262F63),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        
        // Горизонтальный список карточек матчей
        SizedBox(
          height: 168,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: allMatches.length,
            itemBuilder: (context, index) {
              final match = allMatches[index];
              final isCurrent = match.status.toLowerCase() != 'completed';
              return Padding(
                padding: EdgeInsets.only(right: index < allMatches.length - 1 ? 12 : 0),
                child: _buildMatchCard(
                  match,
                  isCurrent
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMyBookingsSection() {
    // Показываем только будущие бронирования
    if (_myBookings.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 0),
        // Заголовок секции
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Мои бронирования',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                  height: 1.22,
                  letterSpacing: -0.8,
                  color: Color(0xFF222223),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AllBookingsScreen(),
                    ),
                  ).then((_) {
                    // Обновляем список при возврате
                    _loadMyBookings();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: const Text(
                    'Смотреть все',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      height: 1.25,
                      letterSpacing: -0.8,
                      color: Color(0xFF262F63),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        
        // Горизонтальный список карточек бронирований
        SizedBox(
          // Высота подгоняется под контент карточки (divider справа 120px)
          height: 140,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _myBookings.length,
            itemBuilder: (context, index) {
              final booking = _myBookings[index];
              return Padding(
                padding: EdgeInsets.only(right: index < _myBookings.length - 1 ? 8 : 0),
                child: _buildBookingCard(booking),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBookingCard(Booking booking) {
    // Форматируем дату
    final weekdays = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    
    final weekday = weekdays[booking.bookingDate.weekday - 1];
    final day = booking.bookingDate.day;
    final month = months[booking.bookingDate.month - 1];
    final formattedDate = '$weekday, $day $month';
    
    // Форматируем время (убираем секунды)
    final startTime = booking.startTime;
    final parts = startTime.split(':');
    final startHour = int.tryParse(parts.first) ?? 0;
    var minutes = parts.length > 1 ? parts[1] : '00';
    // Убираем секунды, если они есть
    if (minutes.length > 2) {
      minutes = minutes.substring(0, 2);
    }
    final endHour = (startHour + (booking.durationMin ~/ 60)) % 24;
    final formattedStart = '${startHour.toString().padLeft(2, '0')}:$minutes';
    final timeRange = '$formattedStart - ${endHour.toString().padLeft(2, '0')}:$minutes';
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BookingDetailsScreen(booking: booking),
          ),
        ).then((_) {
          // Обновляем список при возврате с экрана деталей бронирования
          _loadMyBookings();
        });
      },
      child: Container(
        width: 358,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF2A2C36),
                          height: 1.3,
                          letterSpacing: -0.40,
                        ),
                      ),
                      Text(
                        timeRange,
                        style: const TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF2A2C36),
                          height: 1.3,
                          letterSpacing: -0.40,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 21),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.clubName,
                        style: const TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF2A2C36),
                          height: 1.125,
                          letterSpacing: -0.32,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.courtName ?? 'Корт не указан',
                        style: const TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF838A91),
                          height: 1.285,
                          letterSpacing: -0.28,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 120,
              color: const Color(0xFFECECEC),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 4),
                const Icon(
                  Icons.access_time_outlined,
                  size: 24,
                  color: Color(0xFF2A2C36),
                ),
                const SizedBox(height: 4),
                Text(
                  '${booking.durationMin} мин',
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF2A2C36),
                    height: 1.125,
                    letterSpacing: -0.32,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showScoreInputModal(Match match) {
    // Инициализируем контроллеры для ввода счёта
    final teamAControllers = List.generate(3, (_) => TextEditingController(text: '0'));
    final teamBControllers = List.generate(3, (_) => TextEditingController(text: '0'));
    
    // Разделяем участников на команды (1x1 -> по одному в каждую команду)
    late final List<MatchParticipant?> participantsA;
    late final List<MatchParticipant?> participantsB;
    if (match.participants.length == 2) {
      participantsA = [match.participants[0]];
      participantsB = [match.participants[1]];
    } else {
      participantsA = List<MatchParticipant?>.from(match.participants.take(2));
      participantsB = List<MatchParticipant?>.from(match.participants.skip(2).take(2));
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ScoreInputModal(
        match: match,
        teamAControllers: teamAControllers,
        teamBControllers: teamBControllers,
        participantsA: participantsA,
        participantsB: participantsB,
      ),
    );
  }

  double? _getRatingDeltaForMatch(String matchId, List<RatingHistoryItem>? ratingHistory) {
    print('🔍 _getRatingDeltaForMatch: called for matchId=$matchId, historyLen=${ratingHistory?.length ?? 0}');
    if (ratingHistory == null) return null;

    RatingHistoryItem? item;
    for (final h in ratingHistory) {
      if (h.matchId == matchId) {
        item = h;
        break;
      }
    }
    if (item == null) {
      // debug-only: помогает понять, почему для "того же матча" в одном месте есть дельта, а в другом нет
      final sample = ratingHistory
          .map((h) => h.matchId)
          .where((id) => id != null && id!.isNotEmpty)
          .take(8)
          .toList();
      print(
        '⚠️ rating delta: no ratingHistory item for matchId=$matchId; '
        'historyLen=${ratingHistory.length}; sampleMatchIds=$sample',
      );
      return null;
    }

    print('✅ _getRatingDeltaForMatch: found item for matchId=$matchId');
    
    // Сервер иногда не присылает rating_before, но присылает rating_change.
    // Тогда восстанавливаем rating_before из rating_after - rating_change.
    final int? beforeScore = item.ratingBefore ??
        (item.ratingChange != null ? (item.ratingAfter - item.ratingChange!) : null);
    if (beforeScore == null) {
      print(
        '⚠️ rating delta: beforeScore is null for matchId=$matchId; '
        'ratingBefore=${item.ratingBefore}, ratingAfter=${item.ratingAfter}, ratingChange=${item.ratingChange}',
      );
      return null;
    }

    final before = calculateRating(beforeScore);
    final after = calculateRating(item.ratingAfter);
    final delta = after - before;
    print('✅ _getRatingDeltaForMatch: computed delta=$delta for matchId=$matchId');
    return delta;
  }

  bool? _didCurrentUserWin(Match match) {
    final meId = _currentUserId;
    if (meId == null) return null;

    final String statusLower = match.status.toLowerCase();
    final bool isCancelled = statusLower == 'cancelled' || statusLower == 'canceled';
    if (isCancelled) return null;

    // Составы команд
    final teamA = match.participants.where((p) => p.teamId == 'A' || p.teamId == null).toList();
    final teamB = match.participants.where((p) => p.teamId == 'B').toList();
    final inA = teamA.any((p) => p.userId == meId);
    final inB = teamB.any((p) => p.userId == meId);
    if (!inA && !inB) return null;

    // Если сервер дал победителя — используем его
    if (match.winnerUserId != null) {
      return match.winnerUserId == meId;
    }
    if (match.winnerTeam != null) {
      return (inA && match.winnerTeam == 'A') || (inB && match.winnerTeam == 'B');
    }

    // Фолбэк: определяем победителя по сетам
    final aSets = match.teamASets;
    final bSets = match.teamBSets;
    if (aSets == null || bSets == null || aSets.isEmpty || bSets.isEmpty) return null;

    int setsA = 0, setsB = 0;
    final len = aSets.length < bSets.length ? aSets.length : bSets.length;
    for (int i = 0; i < len; i++) {
      if (aSets[i] > bSets[i]) {
        setsA++;
      } else if (aSets[i] < bSets[i]) {
        setsB++;
      }
    }
    final winnerTeam = setsA > setsB ? 'A' : (setsB > setsA ? 'B' : null);
    if (winnerTeam == null) return null;
    return (inA && winnerTeam == 'A') || (inB && winnerTeam == 'B');
  }

  Widget _buildMatchCard(Match match, bool isCurrent) {
    // Форматируем дату
    final formattedDate = date_utils.DateUtils.formatMatchDate(match.dateTime);
    
    // Получаем первых 2 участников для показа
    final displayParticipants = match.participants.take(2).toList();
    final bool isSingles = match.participants.length == 2;
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MatchDetailsScreen(matchId: match.id),
          ),
        ).then((_) {
          // Обновляем профиль при возврате, чтобы матч переехал из текущих в завершенные
          _loadProfile();
        });
      },
      child: Container(
        width: 368,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Статус и дата
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  match.startedAt == null && 
                  match.status != 'cancelled' && 
                  match.dateTime.isAfter(DateTime.now().add(const Duration(hours: 1)))
                      ? 'Ближайший матч'
                      : (isCurrent && match.status != 'cancelled' ? 'Текущий матч' : 'Завершенный матч'),
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    height: 1.125,
                    letterSpacing: -0.32,
                    color: Color(0xFF222223),
                  ),
                ),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    height: 1.29,
                    letterSpacing: -0.28,
                    color: Color(0xFF89867E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Участники
            Row(
              children: [
                // Команда A (первые 2 участника) - выровнена вправо
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 0.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: isSingles
                          ? [
                              Padding(
                                padding: const EdgeInsets.only(right: 11.0),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: UserAvatar(
                                    imageUrl: match.participants[0].avatarUrl,
                                    userName: match.participants[0].name,
                                    radius: 28,
                                    backgroundColor: const Color(0xFFE0E0E0),
                                    borderColor: null,
                                    borderWidth: 0,
                                  ),
                                ),
                              ),
                            ]
                          : List.generate(
                              displayParticipants.length,
                              (index) => Padding(
                                padding: EdgeInsets.only(
                                  left: index > 0 ? 0 : 0,
                                  right: index < displayParticipants.length - 1 ? 0 : 0,
                                ),
                                child: Transform.translate(
                                  offset: Offset(index * -12.0, 0),
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: UserAvatar(
                                      imageUrl: displayParticipants[index].avatarUrl,
                                      userName: displayParticipants[index].name,
                                      radius: 28,
                                      backgroundColor: const Color(0xFFE0E0E0),
                                      borderColor: null,
                                      borderWidth: 0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              const SizedBox(width: 5),
                
                // Разделитель в центре
          Container(
                  width: 1,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECECEC),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 5),
                
                // Команда B (если есть еще участники) - выровнена влево
                Expanded(
                  child: isSingles
                      ? Padding(
                          padding: const EdgeInsets.only(left: 13.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: UserAvatar(
                                  imageUrl: match.participants[1].avatarUrl,
                                  userName: match.participants[1].name,
                                  isDeleted: match.participants[1].isDeleted,
                                  radius: 28,
                                  backgroundColor: const Color(0xFFE0E0E0),
                                  borderColor: null,
                                  borderWidth: 0,
                                ),
                              ),
                            ],
                          ),
                        )
                      : match.participants.length > 2
                      ? Padding(
                          padding: const EdgeInsets.only(left: 13.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: List.generate(
                              match.participants.skip(2).take(2).length,
                              (index) {
                                final participant = match.participants.skip(2).elementAt(index);
                                return Padding(
                                  padding: EdgeInsets.only(left: index > 0 ? 0 : 0),
                                  child: Transform.translate(
                                    offset: Offset(index * -12.0, 0),
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: UserAvatar(
                                        imageUrl: participant.avatarUrl,
                                        userName: participant.name,
                                        isDeleted: participant.isDeleted,
                                        radius: 28,
                                        backgroundColor: const Color(0xFFE0E0E0),
                                        borderColor: null,
                                        borderWidth: 0,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 15),
            
            // Адрес клуба и кнопка
            Row(
              children: [
                Expanded(
                  child: Text(
                    match.clubName ?? 'Адрес клуба',
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.29,
                      letterSpacing: -0.28,
                      color: Color(0xFF222223),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _onScoreButtonTap(match, isCurrent),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262F63),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCurrent ? 'К матчу' : 'Счёт',
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        height: 1.19,
                        letterSpacing: -0.28,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onScoreButtonTap(Match match, bool isCurrent) async {
    if (isCurrent) {
      // Текущий матч → детали
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MatchDetailsScreen(matchId: match.id),
        ),
      ).then((_) => _loadProfile());
      return;
    }

    // Завершенный матч: особая логика
    // Если результат уже финализирован (есть финальные сеты или победитель), просто открываем детали
    final bool hasFinalResult = ((match.teamASets?.isNotEmpty ?? false) ||
        (match.teamBSets?.isNotEmpty ?? false) ||
        match.winnerTeam != null ||
        match.winnerUserId != null);
    if (hasFinalResult) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MatchDetailsScreen(matchId: match.id),
        ),
      ).then((_) => _loadProfile());
      return;
    }

    final bool isOrganizer = _currentUserId != null && match.organizerId == _currentUserId;
    // По текущим правилам финальный результат может выставить только организатор (host)
    if (isOrganizer) {
      _showFinishAsHostModal(match);
    } else {
      if (!mounted) return;
      NotificationUtils.showError(context, 'Только организатор матча может выставить результат');
    }
  }

  Future<bool> _isCurrentUserHost(String matchId) async {
    try {
      final details = await ApiService.getMatchDetails(matchId);
      final meId = _currentUserId;
      if (meId == null) return false;
      for (final p in details.participants) {
        final status = (p.scoreConfirmationStatus ?? '').toString().toLowerCase();
        if (p.userId == meId && status == 'host') {
          return true;
        }
      }
      // Фоллбэк: если сервер не прислал статус по участникам,
      // считаем организатора хостом при наличии hostScoreFilled
      /*if (details.organizerId == meId && details.hostScoreFilled == true) {
        return true;
      }*/
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasCurrentUserResponded(String matchId) async {
    try {
      final details = await ApiService.getMatchDetails(matchId);
      final meId = _currentUserId;
      if (meId == null) return false;

      for (final p in details.participants) {
        final status = (p.scoreConfirmationStatus ?? '').toString().toLowerCase();
        if (p.userId == meId && (status == 'accept' || status == 'dispute')) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  void _showFinishAsHostModal(Match match) {
    final teamAControllers = List.generate(3, (_) => TextEditingController(text: '0'));
    final teamBControllers = List.generate(3, (_) => TextEditingController(text: '0'));

    final List<MatchParticipant?> participantsA;
    final List<MatchParticipant?> participantsB;
    if (match.participants.length == 2) {
      participantsA = [match.participants[0]];
      participantsB = [match.participants[1]];
    } else {
      participantsA = List<MatchParticipant?>.from(match.participants.take(2));
      participantsB = List<MatchParticipant?>.from(match.participants.skip(2).take(2));
    }

    Future<void> submit() async {
      // Собираем счёт в формате "A-B, C-D, ..."
      final sets = <String>[];
      for (int i = 0; i < teamAControllers.length; i++) {
        final a = int.tryParse(teamAControllers[i].text.trim()) ?? 0;
        final b = int.tryParse(teamBControllers[i].text.trim()) ?? 0;
        if (a == 0 && b == 0) continue;
        sets.add('$a-$b');
      }
      if (sets.isEmpty) {
        if (!mounted) return;
        NotificationUtils.showError(context, 'Укажите хотя бы один сет');
        return;
      }

      final score = sets.join(', ');
      try {
        await ApiService.finishMatchAsHost(match.id, score: score);
        if (!mounted) return;
        Navigator.of(context).pop();
        NotificationUtils.showSuccess(context, 'Результат зафиксирован');
        await _loadProfile();
      } catch (e) {
        if (!mounted) return;
        NotificationUtils.showError(context, 'Ошибка отправки результата: $e');
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScoreInputModalContent(
        teamAControllers: teamAControllers,
        teamBControllers: teamBControllers,
        participantsA: participantsA,
        participantsB: participantsB,
        duration: match.finishedAt != null && match.startedAt != null
            ? match.finishedAt!.difference(match.startedAt!).abs()
            : Duration.zero,
        isLocked: false,
        onAddSet: () {
          teamAControllers.add(TextEditingController(text: '0'));
          teamBControllers.add(TextEditingController(text: '0'));
          // Обновить UI модалки
          (context as Element).markNeedsBuild();
        },
        onSubmit: submit,
        isFormValid: true,
        isSubmitting: false,
        titleText: 'Введите результат матча',
        subtitleText: 'Он будет учитываться для всех участников',
        submitButtonText: 'Отправить',
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildMainCardsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Первый ряд карточек
                Row(
                  children: [
                    Expanded(
                      child: _buildMainCard(
                  'Бронь кортов',
                  'assets/images/home_booking.png',
                  'assets/images/court_icon_correct.svg',
                        () {
                            // ВРЕМЕННО: открываем "Мои бронирования" для тестирования
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const ClubsListScreen(),
                              ),
                            );
                            // TODO: вернуть ClubsListScreen после тестирования
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMainCard(
                  'Поиск матчей',
                  'assets/images/home_matches.png',
                  'assets/images/tennis_icon_correct.svg',
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const MatchesScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                // Второй ряд карточек
                Row(
                  children: [
                    Expanded(
                      child: _buildMainCard(
                        'Тренировки',
                  'assets/images/home_trainings.png',
                  'assets/images/academic_cap_icon_correct.svg',
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TrainingsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMainCard(
                        'Турниры',
                  'assets/images/home_tournaments.png',
                  'assets/images/tournament_icon_correct.svg',
                        () {
                          Navigator.of(context).pushNamed('/competitions');
                        },
                      ),
                    ),
                  ],
                ),
              ],
      ),
    );
  }

  Widget _buildMainCard(String title, String imageAssetPath, String iconAssetPath, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 184,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Изображение
                Container(
                  width: double.infinity,
                  height: 113,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    image: DecorationImage(
                      image: AssetImage(imageAssetPath),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Отступ между изображением и текстом
                const Spacer(),
                // Нижняя белая часть с заголовком
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 11),
                  child: Align(
                    alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                              fontWeight: FontWeight.w500,
                        fontSize: 16,
                        height: 1.25,
                        letterSpacing: -0.9,
                              color: Color(0xFF222223),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          ),
                        ),
                      ],
                    ),
            // Иконка поверх изображения
            Positioned(
              left: 16,
              top: 89,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF262F63),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                    child: SvgPicture.asset(
                      iconAssetPath,
                    width: 24,
                    height: 24,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: iconColor,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.groups,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Комьюнити',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Этот раздел находиться в разработке, здесь вы сможете общаться с игроками, находить партнеров и узнавать новости сообщества',
              style: TextStyle(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsTab() {
    return const NotificationsScreen();
  }

  Widget _buildProfileTab() {
    print('🎯 _buildProfileTab: Called');
    print('🎯 _buildProfileTab: _isLoadingProfile=$_isLoadingProfile');
    print('🎯 _buildProfileTab: _profileError=$_profileError');
    print('🎯 _buildProfileTab: _userProfile=${_userProfile?.name}');
    print('🎯 _buildProfileTab: _userRating=${_userRating?.ntrpLevel}');
    
    if (_isLoadingProfile) {
      print('🎯 _buildProfileTab: Showing loading indicator');
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF262F63),
        ),
      );
    }
    
    if (_profileError != null) {
      print('🎯 _buildProfileTab: Showing error: $_profileError');
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
              'Ошибка загрузки профиля',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _profileError!,
              style: const TextStyle(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _loadProfile,
                  child: const Text('Повторить'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    await AuthStorage.clearAuthData();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Выйти'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    if (_userProfile == null) {
      // Если профиль не загружен, запускаем загрузку
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadProfile();
      });
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF262F63),
        ),
      );
    }
    
    final profile = _userProfile!;
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // Заголовок с кнопкой редактирования
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 70, 16, 16), // Добавил отступ сверху для dynamic island
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Профиль',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                    letterSpacing: -0.44,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    _navigateToEditProfile(profile);
                  },
                  child: const Text(
                    'Редактировать',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF262F63),
                      letterSpacing: -0.52,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Аватар и основная информация
          _buildProfileHeader(profile),
          const SizedBox(height: 4),
          
          // О себе
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: _buildBioSection(profile),
          ),
          const SizedBox(height: 0), // Added 24px spacing
          // Мои друзья
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFriendsSection(profile),
          ),
          const SizedBox(height: 16),
          // Контакты
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ProfileMenuButton(
              icon: Icons.contact_phone_outlined,
              customIcon: SvgPicture.asset('assets/images/contacts_profile.svg', width: 22, height: 22),
              label: 'Контакты',
              onTap: () {
                _showEditContactsModal(
                  context,
                  phone: _contactData?.contactPhone,
                  whatsapp: _contactData?.whatsapp,
                  telegram: _contactData?.telegram,
                  onSave: (phone, whatsapp, telegram) async {
                    try {
                      final request = ContactUpdateRequest(
                        contactPhone: phone,
                        whatsapp: whatsapp,
                        telegram: telegram,
                      );
                      await ApiService.updateContacts(request);
                      await _loadContactData(); // Reload data after saving
                      if (mounted) {
                        Navigator.of(context).pop();
                        NotificationUtils.showSuccess(context, 'Контакты успешно сохранены');
                      }
                    } catch (e) {
                      if (mounted) {
                        NotificationUtils.showError(context, 'Ошибка сохранения контактов: $e');
                      }
                    }
                  },
                );
              },
            ),
          ),
          
          const SizedBox(height: 16), // Added vertical spacing
          const Divider(
            color: Color(0xFFF7F7F7),
            thickness: 4,
            indent: 16,
            endIndent: 16,
          ), // Added horizontal divider with padding
          // Виджет уровня и надёжности — отдельный блок
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: ReliabilityRatingCard(
              ntrpLevel: _userRating?.ntrpLevel,
              rating: _userRating?.rating != null ? calculateRating(_userRating!.rating!.toInt()) : null,
              reliability: _userProfile?.reliability,
              pendingReviewCount: _userProfile?.pendingReviewCount,
              totalMatches: _userProfile?.totalMatches ?? 0,
              wins: _userProfile?.wins ?? 0,
              losses: _userProfile?.defeats ?? 0,
              onTap: () async {
                final bool hasAnyMatches = (_userProfile?.totalMatches ?? 0) > 0;
                if (_userRating != null && _userRating!.ntrpLevel != null && _userRating!.rating != null) {
                  final updated = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => RatingDetailsScreen(
                        showRetestButton: !hasAnyMatches,
                      ),
                    ),
                  );
                  if (updated == true) {
                    await _loadUserRating();
                    await _loadProfile();
                    if (mounted) setState(() {});
                  }
                } else {
                  _showLevelIntroModal(context);
                }
              },
            ),
          ),
          // График истории рейтинга
          if (_userProfile?.ratingHistory.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildRatingHistoryChart(_userProfile!.ratingHistory),
            ),
            
          // Виджет прошедших матчей (на главном экране показываем 3 последних нетурнирных матча,
          // включая отменённые; фильтрация по статусу делается только на экране "Смотреть все")
          Builder(
            builder: (context) {
              final nonTournamentPastMatches = profile.pastMatches
                  .where((match) => !match.isTournament)
                  .take(3)
                  .toList();
              if (nonTournamentPastMatches.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: PastMatchesWidget(
                  matches: nonTournamentPastMatches,
                  ratingHistory: _ratingHistory,
                  onSeeAll: () {
                    // В истории "Смотреть все" показываем все прошедшие матчи (без турниров), без ограничения по времени
                    final allNonTournamentPast = profile.pastMatches
                        .where((match) => !match.isTournament)
                        .toList();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AllPastMatchesScreen(
                          matches: allNonTournamentPast,
                          ratingHistory: _ratingHistory,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
            
          // Виджет предстоящих матчей (без турнирных и не старше 2.5 дней)
          Builder(
            builder: (context) {
              final cutoffTime = DateTime.now().subtract(const Duration(hours: 60)); // 2.5 дня
              final nonTournamentUpcomingMatches = profile.upcomingMatches
                  .where((match) => !match.isTournament && match.dateTime.isAfter(cutoffTime))
                  .toList();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: UpcomingMatchesWidget(
                  matches: nonTournamentUpcomingMatches,
                  onSeeAll: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => UpcomingMatchesScreen(matches: nonTournamentUpcomingMatches),
                      ),
                    );
                  },
                  onMatchTap: (match) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MatchDetailsScreen(matchId: match.id),
                      ),
                    ).then((_) {
                      _loadProfile();
                    });
                  },
                ),
              );
            },
          ),
          
          const SizedBox(height: 8),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Divider(color: Color(0xFFF7F7F7), thickness: 4),
          ),
          const SizedBox(height: 16),
          // Кнопки меню (оплата, поддержка, опд, политика)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // ProfileMenuButton(
                //   icon: Icons.credit_card,
                //   label: 'Оплата',
                //   onTap: () {},
                // ),
                // const SizedBox(height: 16),
                ProfileMenuButton(
                  icon: Icons.help_outline,
                  customIcon: SvgPicture.asset('assets/images/support.svg', width: 22, height: 22),
                  label: 'Чат с поддержкой',
                  onTap: _openTelegramSupport,
                ),
                const SizedBox(height: 16),
                ProfileMenuButton(
                  icon: Icons.description,
                  customIcon: SvgPicture.asset('assets/images/data_processing.svg', width: 22, height: 22),
                  label: 'Обработка персональных данных',
                  onTap: () => _openExternalUrl('https://paddle-app.ru/data-processing-policy.pdf'),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(0),
                    bottomRight: Radius.circular(0),
                  ),
                ),
                // Без отступа между пунктами "Обработка персональных данных" и "Политика конфиденциальности"
                ProfileMenuButton(
                  icon: Icons.visibility,
                  customIcon: SvgPicture.asset('assets/images/privacy_policy.svg', width: 22, height: 22),
                  label: 'Политика конфиденциальности',
                  onTap: () => _openExternalUrl('https://paddle-app.ru/privacy-policy.pdf'),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(0),
                    topRight: Radius.circular(0),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Кнопки выхода и удаления
          _buildActionButtons(),
          const SizedBox(height: 100), // Отступ для нижней панели
        ],
      ),
    );
  }
  
  Widget _buildProfileHeader(UserProfile profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Аватар слева
          UserAvatar(
            imageUrl: profile.avatarUrl,
            userName: profile.name,
            radius: 30,
          ),
          
          const SizedBox(width: 16),
          
          // Информация справа от аватара
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Имя
                const SizedBox(height: 8),
                Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                    letterSpacing: -0.2,
                  ),
                ),
                
                
                
                // const SizedBox(height: 1),
                
                // Город
                Text(
                  profile.city,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRatingBadge(UserRatingResponse? rating) {
    final levelBadge = LevelBadge(
      ntrpLevel: rating?.ntrpLevel,
      score: rating?.rating?.toInt(), // Конвертируем double в int для расчета
      totalMatches: _userProfile?.totalMatches,
      wins: _userProfile?.wins,
      losses: _userProfile?.defeats,
      onTap: () async {
        final bool hasAnyMatches = (_userProfile?.totalMatches ?? 0) > 0;
        if (rating != null && rating.ntrpLevel != null && rating.rating != null) {
          final updated = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RatingDetailsScreen(
                showRetestButton: !hasAnyMatches,
              ),
            ),
          );
          if (updated == true) {
            await _loadUserRating();
            await _loadProfile();
            if (mounted) setState(() {});
          }
        } else {
          _showLevelIntroModal(context);
        }
      },
    );

    // Если рейтинга нет, показываем основной badge и отдельный блок статистики
    if (rating == null || rating.ntrpLevel == null || rating.rating == null) {
      final statsCard = levelBadge.getStatsCard();
      if (statsCard != null) {
        return Column(
          children: [
            levelBadge,
            const SizedBox(height: 8),
            statsCard,
          ],
        );
      }
    }

    return levelBadge;
  }

  void _showLevelInfoModal(BuildContext context, UserRatingResponse rating) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            bottom: true,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 24,
                bottom: 8, // минимальный отступ до home indicator
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        child: Text(
                          'Твой уровень',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF222223),
                            fontFamily: 'Basis Grotesque Arabic Pro',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: Material(
                          color: const Color(0xFFF7F7F7),
                          shape: const CircleBorder(),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => Navigator.of(context).pop(),
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(Icons.close, size: 20, color: Color(0xFF222223)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '${rating.ntrpLevel}  ${rating.rating?.toStringAsFixed(1) ?? '0.0'}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF222223),
                            fontFamily: 'Basis Grotesque Arabic Pro',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Текущий уровень определён по системе International Padel Rating (IPR).',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Color(0xFF7F8AC0)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Рейтинг будет обновляться автоматически после каждого матча — по результатам твоих игр.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Color(0xFF7F8AC0)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Ок', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF262F63),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero, // убрать лишний padding
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLevelIntroModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Шапка: заголовок и крестик
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          'Определить мой уровень',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    Material(
                      color: const Color(0xFFF7F7F7),
                      shape: const CircleBorder(),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => Navigator.of(context).pop(),
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.close, color: Color(0xFF222223), size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Разделитель
                const Divider(height: 1, color: Color(0xFFE7E9EB)),
                const SizedBox(height: 20),
                // Стилизованный текст
                Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Ответь на 5 простых вопросов — и мы подберём тебе начальный уровень.',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Вопросы основаны на системе International Padel Rating (IPR).',
                        style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Постарайся оценить свои навыки объективно.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Лучше немного занизить уровень, чем переоценить — так ты начнёшь играть с более слабыми соперниками, чаще побеждать и твой рейтинг быстрее поднимется до реального уровня.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Повышать рейтинг через победы — приятнее, чем терпеть поражения из-за слишком высокого старта.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text(
                  'После первого матча рейтинг будет обновляться автоматически — по результатам твоих игр.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showLevelTestStepperModal(context);
                        },
                        child: const Text('Начать'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0BAB53),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Отмена'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF222223),
                          backgroundColor: Color(0xFFF7F7F7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          side: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLevelTestStepperModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return _LevelTestStepperModal(
          onRatingInitialized: _loadUserRating,
        );
      },
    );
  }

  Widget _buildMatchStats(UserProfile profile) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE0E0E0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatColumn(value: '${profile.totalMatches}', label: 'Матчей'),
          Container(
            width: 1,
            height: 40,
            margin: EdgeInsets.symmetric(vertical: 12),
            color: Color(0xFFE7E9EB),
          ),
          _StatColumn(value: '${profile.wins}', label: 'Побед'),
          Container(
            width: 1,
            height: 40,
            margin: EdgeInsets.symmetric(vertical: 12),
            color: Color(0xFFE7E9EB),
          ),
          _StatColumn(value: '${profile.defeats}', label: 'Проигрышей'),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
  
  Widget _buildBioSection(UserProfile profile) {
    final String? bio = (profile.bio != null && profile.bio!.trim().isNotEmpty)
        ? profile.bio!.trim()
        : null;
    // Если нет ни био, ни ведущей руки — вовсе не показываем блок
    final bool hasPreferredHand = profile.preferredHand != null && profile.preferredHand!.isNotEmpty;
    if (bio == null && !hasPreferredHand) {
      return const SizedBox.shrink();
    }

    final showMore = ValueNotifier(false);
    return SizedBox(
      width: double.infinity,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
	const SizedBox(height: 2),
        const Text(
          'О себе',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: Color(0xFF222223),
            letterSpacing: -0.36,
          ),
        ),
        const SizedBox(height: 4),
        if (hasPreferredHand)
          Text(
            'Ведущая рука в игре: ${_getPreferredHandText(profile) ?? 'Рука не указана'}',
            style: const TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 16,
              color: Color(0xFF222223),
              height: 1.25,
              letterSpacing: -0.32,
              fontWeight: FontWeight.w400,
            ),
          ),
        if (bio != null) ...[
          const SizedBox(height: 8),
          ValueListenableBuilder<bool>(
            valueListenable: showMore,
            builder: (context, expanded, _) {
              const textStyle = TextStyle(
                fontSize: 16,
                color: Color(0xFF89867E),
                height: 1.25,
                letterSpacing: -0.32,
                fontWeight: FontWeight.w400,
              );

              if (expanded) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bio, style: textStyle),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => showMore.value = false,
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                          child: Text(
                            'Свернуть',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              color: Color(0xFF222223),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.32,
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF222223),
                              decorationThickness: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final res = _truncateToTwoAndHalfLines(
                    bio,
                    textStyle,
                    constraints.maxWidth,
                    Directionality.of(context),
                  );

                  final truncatedText = res.truncatedText;
                  final didTruncate = res.didTruncate;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(truncatedText, style: textStyle),
                      if (didTruncate) ...[
                        Transform.translate(
                          offset: const Offset(0, -20),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => showMore.value = true,
                              child: const Text(
                                'Показать',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Display',
                                  color: Color(0xFF222223),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.32,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFF222223),
                                  decorationThickness: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 18),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ],
    ));
  }
  
  Widget _buildAdditionalInfoSection(UserProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Дополнительная информация',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildInfoRow('Дата регистрации', _formatDate(profile.createdAt), Icons.calendar_today),
              if (_getPreferredHandText(profile) != null) ...[
                const SizedBox(height: 12),
                _buildInfoRow('Игровая рука', _getPreferredHandText(profile)!, Icons.sports_tennis),
              ],
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${_getYearWord(years)} назад';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${_getMonthWord(months)} назад';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${_getDayWord(difference.inDays)} назад';
    } else {
      return 'Сегодня';
    }
  }

  String _getYearWord(int years) {
    if (years % 10 == 1 && years % 100 != 11) return 'год';
    if ([2, 3, 4].contains(years % 10) && ![12, 13, 14].contains(years % 100)) return 'года';
    return 'лет';
  }

  String _getMonthWord(int months) {
    if (months % 10 == 1 && months % 100 != 11) return 'месяц';
    if ([2, 3, 4].contains(months % 10) && ![12, 13, 14].contains(months % 100)) return 'месяца';
    return 'месяцев';
  }

  String _getDayWord(int days) {
    if (days % 10 == 1 && days % 100 != 11) return 'день';
    if ([2, 3, 4].contains(days % 10) && ![12, 13, 14].contains(days % 100)) return 'дня';
    return 'дней';
  }

  String? _getPreferredHandText(UserProfile profile) {
    if (profile.preferredHand == null) return null;
    
    switch (profile.preferredHand!.toLowerCase()) {
      case 'right':
        return 'Правая';
      case 'left':
        return 'Левая';
      case 'both':
        return 'Обе';
      default:
        return profile.preferredHand;
    }
  }
  
  Widget _buildFriendsSection(UserProfile profile) {
    return ProfileMenuButton(
      icon: Icons.people,
      customIcon: SvgPicture.asset('assets/images/my_friends.svg', width: 22, height: 22),
      label: 'Мои друзья',
      labelWidget: RichText(
        text: TextSpan(
          children: [
            const TextSpan(
              text: 'Мои друзья',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Color(0xFF222223),
                letterSpacing: -0.32,
                height: 1.25,
              ),
            ),
            TextSpan(
              text: '   ${profile.friendsCount}',
              style: const TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Color(0xFF89867E),
                letterSpacing: -0.32,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FriendsScreen(),
          ),
        ).then((_) {
          _loadProfile();
        });
      },
    );
  }
  
  Widget _buildMatchesSection() {
    return Column(
      children: [
        ProfileMenuButton(
          icon: Icons.sports_tennis,
          label: 'Найти матчи',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const MatchesScreen(),
              ),
            );
          },
          iconColor: Colors.green,
        ),
        const SizedBox(height: 12),
        ProfileMenuButton(
          icon: Icons.schedule,
          label: 'Мои матчи',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const MyMatchesScreen(),
              ),
            );
          },
          iconColor: Colors.orange,
        ),
      ],
    );
  }
  
  Widget _buildActionButtons() {
    return Column(
      children: [
        // Выйти из профиля
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: InkWell(
            onTap: _showLogoutDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Выйти из профиля',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.red.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Удалить профиль
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: InkWell(
            onTap: _showDeleteAccountDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Удалить профиль',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.red.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  void _navigateToEditProfile(UserProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(profile: profile),
      ),
    ).then((_) {
      // Обновляем профиль после возвращения с экрана редактирования
      _loadProfile();
    });
  }

  Widget _buildContactsSection(UserProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Контакты',
                style: TextStyle(
                  fontFamily: 'BasisGrotesqueArabicPro',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF222223),
                  letterSpacing: -0.2,
                  height: 1.25,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFF7F8AC0), size: 22),
                onPressed: () {
                  _showEditContactsModal(context,
                    phone: profile.phone,
                    onSave: (phone, whatsapp, telegram) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Контакты сохранены (заглушка)')),
                      );
                    },
                  );
                },
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ContactChip(
                customIcon: SvgPicture.asset('assets/telegram.svg', width: 16, height: 16),
                label: 'Telegram',
                color: Color(0xFF229ED9),
                onTap: () {},
              ),
              _ContactChip(
                customIcon: SvgPicture.asset('assets/whatsapp.svg', width: 16, height: 16),
                label: 'WhatsApp',
                color: Color(0xFF25D366),
                onTap: () {},
              ),
              _ContactChip(
                icon: Icons.phone,
                label: 'Телефон',
                color: Colors.black,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditContactsModal(BuildContext context, {String? phone, String? whatsapp, String? telegram, void Function(String, String, String)? onSave}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ContactEditModal(
        phone: phone,
        whatsapp: whatsapp,
        telegram: telegram,
        onSave: onSave,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🎯 HomeScreen.build: Called with _currentIndex=$_currentIndex');
    
    try {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false, // Отключаем верхний SafeArea чтобы считать от края экрана
        bottom: false,
          child: Builder(
            builder: (context) {
              try {
                print('🎯 HomeScreen.build: Building IndexedStack with index $_currentIndex');
                return IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeTab(),
            _buildTournamentsTab(),
            _buildFriendsTab(),
                    Builder(
                      builder: (context) {
                        try {
                          print('🎯 HomeScreen.build: Building profile tab');
                          return _buildProfileTab();
                        } catch (e, stackTrace) {
                          print('❌ HomeScreen.build: Error in _buildProfileTab: $e');
                          print('📍 Stack trace: $stackTrace');
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error, size: 64, color: Colors.red),
                                const SizedBox(height: 16),
                                const Text('Ошибка сборки профиля', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Text('$e', style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => setState(() {}),
                                  child: const Text('Повторить'),
                                ),
          ],
                            ),
                          );
                        }
                      },
                    ),
                  ],
                );
              } catch (e, stackTrace) {
                print('❌ HomeScreen.build: Error in IndexedStack: $e');
                print('📍 Stack trace: $stackTrace');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Ошибка сборки интерфейса', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('$e', style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                    ],
                  ),
                );
              }
            },
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTabTapped: _onTabTapped,
      ),
    );
    } catch (e, stackTrace) {
      print('❌ HomeScreen.build: Error in HomeScreen: $e');
      print('📍 Stack trace: $stackTrace');
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Произошла ошибка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('$e', style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() {}),
                child: const Text('Повторить'),
              ),
            ],
        ),
      ),
    );
    }
  }

  

  Widget _buildRatingHistoryChart(List<RatingHistoryItem> history) {
    List<RatingHistoryItem> dataToShow;
    final sorted = List<RatingHistoryItem>.from(history)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    switch (_selectedRatingFilter) {
      case RatingHistoryFilter.five:
        dataToShow = sorted.length > 5 ? sorted.sublist(sorted.length - 5) : sorted;
        break;
      case RatingHistoryFilter.ten:
        dataToShow = sorted.length > 10 ? sorted.sublist(sorted.length - 10) : sorted;
        break;
      case RatingHistoryFilter.all:
      default:
        dataToShow = sorted;
        break;
    }
    
    if (dataToShow.isEmpty) {
      return Container(
        alignment: Alignment.center,
        height: 250,
        child: const Text('Недостаточно данных для построения графика.'),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < dataToShow.length; i++) {
      spots.add(FlSpot(i.toDouble(), calculateRating(dataToShow[i].ratingAfter)));
    }
    
    final xLabels = <int, String>{};
    for (int i = 0; i < dataToShow.length; i++) {
      final date = dataToShow[i].createdAt;
      xLabels[i] = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
    }

    final minRating = dataToShow.map((e) => calculateRating(e.ratingAfter)).reduce((a, b) => a < b ? a : b);
    final maxRating = dataToShow.map((e) => calculateRating(e.ratingAfter)).reduce((a, b) => a > b ? a : b);

    // Динамический отступ для оси Y
    final yPadding = (maxRating - minRating) * 0.2 > 0 ? (maxRating - minRating) * 0.2 : 0.2;
    final minY = minRating - yPadding;
    final maxY = maxRating + yPadding;
    // Рассчитываем интервал для 4-х линий сетки (3 интервала)
    final gridInterval = (maxY - minY) / 3 > 0 ? (maxY - minY) / 3 : 0.1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 0, bottom: 12),
          child: Text(
            'Прогресс уровня',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF222223),
            ),
          ),
        ),
        // Фильтры как в макете
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRatingFilter = RatingHistoryFilter.five;
                  });
                },
                child: _buildFilterButton('5 матчей', _selectedRatingFilter == RatingHistoryFilter.five),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRatingFilter = RatingHistoryFilter.ten;
                  });
                },
                child: _buildFilterButton('10 матчей', _selectedRatingFilter == RatingHistoryFilter.ten),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRatingFilter = RatingHistoryFilter.all;
                  });
                },
                child: _buildFilterButton('Все матчи', _selectedRatingFilter == RatingHistoryFilter.all),
              ),
            ],
          ),
        ),
            Container(
          margin: const EdgeInsets.only(bottom: 0),
          padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            height: 185,
            width: 358,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  horizontalInterval: gridInterval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFFECECEC),
                      strokeWidth: 1,
                      dashArray: [8, 8], // Пунктирные линии как в макете
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: gridInterval,
                      getTitlesWidget: (value, meta) {
                        // Строго показываем метки только для крайних значений
                        const epsilon = 0.001;
                        if ((value - minY).abs() < epsilon || (value - maxY).abs() < epsilon) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              value.toStringAsFixed(1),
              style: const TextStyle(
                                fontSize: 12,
                fontWeight: FontWeight.w400,
                                color: Color(0xFF89867E),
                              ),
                              textAlign: TextAlign.right,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: minY,
                maxY: maxY,
                // Вертикальная пунктирная линия от текущей точки
                extraLinesData: ExtraLinesData(),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false, // Ломаная линия
                    color: const Color(0xFF262F63),
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF262F63),
                          strokeWidth: 0,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF262F63).withOpacity(0.12), // чуть заметнее, как в макете
                          const Color(0xFF262F63).withOpacity(0.0),
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: const Color(0xFF262F63),
                    tooltipRoundedRadius: 20,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          spot.y.toStringAsFixed(2),
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: const Color(0xFF262F63),
                          strokeWidth: 2,
                          dashArray: [8, 8],
                        ),
                        FlDotData(show: false), // кружок не показываем
                      );
                    }).toList();
                  },
                  touchCallback: (FlTouchEvent event, LineTouchResponse? response) {},
                  handleBuiltInTouches: true,
                  touchSpotThreshold: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? const Color(0xFF262F63) : const Color(0xFFD9D9D9),
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF222223),
        ),
      ),
    );
  }

  Widget _buildPreferredHandSection(UserProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Ведущая рука в игре: ${_getPreferredHandText(profile) ?? ''}',
        style: const TextStyle(
          fontFamily: 'SF Pro Display',
          fontSize: 16,
          color: Color(0xFF222223),
          height: 1.25,
          letterSpacing: -0.2,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _DisputeScoreModal extends StatefulWidget {
  final Match match;
  final List<TextEditingController> teamAControllers;
  final List<TextEditingController> teamBControllers;
  final List<MatchParticipant?> participantsA;
  final List<MatchParticipant?> participantsB;

  const _DisputeScoreModal({
    required this.match,
    required this.teamAControllers,
    required this.teamBControllers,
    required this.participantsA,
    required this.participantsB,
  });

  @override
  State<_DisputeScoreModal> createState() => _DisputeScoreModalState();
}

class _DisputeScoreModalState extends State<_DisputeScoreModal> {
  Duration _matchDuration = Duration.zero;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    // Слушаем изменения в контроллерах для валидации
    for (final controller in widget.teamAControllers) {
      controller.addListener(_validateForm);
    }
    for (final controller in widget.teamBControllers) {
      controller.addListener(_validateForm);
    }
    // Реальная длительность: finished_at - started_at
    try {
      final startedAt = widget.match.startedAt;
      final finishedAt = (widget.match as dynamic).finishedAt as DateTime?;
      if (startedAt != null && finishedAt != null) {
        _matchDuration = finishedAt.difference(startedAt).abs();
      }
    } catch (_) {
      _matchDuration = Duration.zero;
    }
  }

  @override
  void dispose() {
    // Очищаем контроллеры
    for (final controller in widget.teamAControllers) {
      controller.removeListener(_validateForm);
      controller.dispose();
    }
    for (final controller in widget.teamBControllers) {
      controller.removeListener(_validateForm);
      controller.dispose();
    }
    super.dispose();
  }

  void _validateForm() {
    // Проверяем, что все поля заполнены (не пусты и не равны '0')
    bool allFilled = true;
    for (int i = 0; i < widget.teamAControllers.length; i++) {
      final a = widget.teamAControllers[i].text.trim();
      final b = i < widget.teamBControllers.length ? widget.teamBControllers[i].text.trim() : '';
      
      // Проверяем, что оба поля не пусты
      if (a.isEmpty || b.isEmpty) {
        allFilled = false;
        break;
      }
      
      // Проверяем, что хотя бы одно из полей не равно '0'
      final aNum = int.tryParse(a) ?? 0;
      final bNum = int.tryParse(b) ?? 0;
      if (aNum == 0 && bNum == 0) {
        allFilled = false;
        break;
      }
    }
    
    if (!mounted) return;
      setState(() {
        _isFormValid = allFilled;
      });
  }

  void _addSet() {
    if (!mounted) return;
    setState(() {
      widget.teamAControllers.add(TextEditingController(text: '0'));
      widget.teamBControllers.add(TextEditingController(text: '0'));
      // Добавляем слушателя для нового контроллера
      widget.teamAControllers.last.addListener(_validateForm);
      widget.teamBControllers.last.addListener(_validateForm);
    });
  }

  Future<void> _submitScore() async {
    // Собираем счёт в формате "6-4, 5-2, 3-7"
    final sets = <String>[];
    for (int i = 0; i < widget.teamAControllers.length; i++) {
      final a = widget.teamAControllers[i].text.trim();
      final b = i < widget.teamBControllers.length ? widget.teamBControllers[i].text.trim() : '0';
      if (a.isEmpty && b.isEmpty) continue;
      sets.add('${int.tryParse(a) ?? 0}-${int.tryParse(b) ?? 0}');
    }

    if (sets.isEmpty) {
      NotificationUtils.showError(context, 'Укажите хотя бы один сет');
      return;
    }

    final disputeScore = sets.join(', ');
    try {
      await ApiService.disputeHostScore(widget.match.id, score: disputeScore);
      if (!mounted) return;
    Navigator.of(context).pop();
      NotificationUtils.showSuccess(context, 'Оспаривание отправлено');
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(context, 'Ошибка оспаривания: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    int _calcWins(List<TextEditingController> a, List<TextEditingController> b) {
      int wins = 0;
      for (int i = 0; i < a.length; i++) {
        final aa = int.tryParse(a[i].text.trim()) ?? 0;
        final bb = i < b.length ? int.tryParse(b[i].text.trim()) ?? 0 : 0;
        if (aa > bb) wins++;
      }
      return wins;
    }

    final teamAIds = widget.participantsA.where((p) => p != null).map((p) => (p!).userId).toList(growable: false);
    final teamBIds = widget.participantsB.where((p) => p != null).map((p) => (p!).userId).toList(growable: false);
    final aWins = _calcWins(widget.teamAControllers, widget.teamBControllers);
    final bWins = _calcWins(widget.teamBControllers, widget.teamAControllers);

    return ScoreInputModalContent(
                teamAControllers: widget.teamAControllers,
                teamBControllers: widget.teamBControllers,
                participantsA: widget.participantsA,
                participantsB: widget.participantsB,
                duration: _matchDuration,
                isLocked: false,
                onAddSet: _addSet,
      onSubmit: _isFormValid ? _submitScore : () {},
      isFormValid: _isFormValid,
      isSubmitting: false,
      titleText: 'Введите результаты матча',
      subtitleText: 'Матч сохранён. Ваш счёт будет учтён только для вас в случае разногласий.',
      submitButtonText: 'Отправить',
      onClose: () => Navigator.of(context).pop(),
    );
  }
}

class _ScoreInputModal extends StatefulWidget {
  final Match match;
  final List<TextEditingController> teamAControllers;
  final List<TextEditingController> teamBControllers;
  final List<MatchParticipant?> participantsA;
  final List<MatchParticipant?> participantsB;

  const _ScoreInputModal({
    required this.match,
    required this.teamAControllers,
    required this.teamBControllers,
    required this.participantsA,
    required this.participantsB,
  });

  @override
  State<_ScoreInputModal> createState() => _ScoreInputModalState();
}

class _ScoreInputModalState extends State<_ScoreInputModal> {
  Duration _matchDuration = Duration.zero;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _prefillHostDraft();
    // Реальная длительность: finished_at - started_at
    try {
      final startedAt = widget.match.startedAt;
      final finishedAt = (widget.match as dynamic).finishedAt as DateTime?;
      if (startedAt != null && finishedAt != null) {
        _matchDuration = finishedAt.difference(startedAt).abs();
      }
    } catch (_) {
      _matchDuration = Duration.zero;
    }
  }

  @override
  void dispose() {
    // Очищаем контроллеры
    for (final controller in widget.teamAControllers) {
      controller.dispose();
    }
    for (final controller in widget.teamBControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addSet() {
    if (!mounted) return;
    setState(() {
      widget.teamAControllers.add(TextEditingController(text: '0'));
      widget.teamBControllers.add(TextEditingController(text: '0'));
    });
  }

  void _submitScore() {
    // Собираем счёт
    final scores = <String>[];
    for (int i = 0; i < widget.teamAControllers.length; i++) {
      final a = widget.teamAControllers[i].text;
      final b = i < widget.teamBControllers.length ? widget.teamBControllers[i].text : '0';
      scores.add('$a:$b');
    }

    // Валидация: проверяем, что все поля заполнены
    bool hasEmptyFields = false;
    for (int i = 0; i < widget.teamAControllers.length; i++) {
      final a = widget.teamAControllers[i].text.trim();
      final b = i < widget.teamBControllers.length ? widget.teamBControllers[i].text.trim() : '';
      if (a.isEmpty || b.isEmpty) {
        hasEmptyFields = true;
        break;
      }
    }

    if (hasEmptyFields) {
      NotificationUtils.showError(context, 'Заполните все поля счёта');
      return;
    }

    // Здесь можно добавить отправку на сервер
    Navigator.of(context).pop();
    NotificationUtils.showSuccess(context, 'Счёт сохранён: ${scores.join(', ')}');
  }

  Future<void> _prefillHostDraft() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    try {
      final draft = await ApiService.getHostDraftScore(widget.match.id);
      if (draft == null || draft.trim().isEmpty) {
        if (!mounted) return;
        setState(() { _isLoading = false; });
        return;
      }
      final sets = draft.split(',');
      final needed = sets.length;
      if (needed > 0) {
        if (!mounted) return;
        setState(() {
          while (widget.teamAControllers.length < needed) {
            widget.teamAControllers.add(TextEditingController(text: '0'));
            widget.teamBControllers.add(TextEditingController(text: '0'));
          }
          for (int i = 0; i < sets.length; i++) {
            final setStr = sets[i].trim();
            final parts = setStr.split('-');
            if (parts.length != 2) continue;
            final a = int.tryParse(parts[0].trim());
            final b = int.tryParse(parts[1].trim());
            if (a != null) widget.teamAControllers[i].text = a.toString();
            if (b != null) widget.teamBControllers[i].text = b.toString();
          }
        });
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _confirmHostScore() async {
    try {
      await ApiService.confirmHostScore(widget.match.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      NotificationUtils.showSuccess(context, 'Результаты подтверждены');
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(context, 'Ошибка подтверждения: $e');
    }
  }

  void _onDispute() {
    // Закрываем текущую модалку и открываем модалку оспаривания
    Navigator.of(context).pop();
    
    // Создаём новые контроллеры для оспаривания
    final disputeTeamAControllers = List.generate(3, (_) => TextEditingController(text: '0'));
    final disputeTeamBControllers = List.generate(3, (_) => TextEditingController(text: '0'));
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DisputeScoreModal(
        match: widget.match,
        teamAControllers: disputeTeamAControllers,
        teamBControllers: disputeTeamBControllers,
        participantsA: widget.participantsA,
        participantsB: widget.participantsB,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int _calcWins(List<TextEditingController> a, List<TextEditingController> b) {
      int wins = 0;
      for (int i = 0; i < a.length; i++) {
        final aa = int.tryParse(a[i].text.trim()) ?? 0;
        final bb = i < b.length ? int.tryParse(b[i].text.trim()) ?? 0 : 0;
        if (aa > bb) wins++;
      }
      return wins;
    }

    final teamAIds = widget.participantsA.where((p) => p != null).map((p) => (p!).userId).toList(growable: false);
    final teamBIds = widget.participantsB.where((p) => p != null).map((p) => (p!).userId).toList(growable: false);
    final aWins = _calcWins(widget.teamAControllers, widget.teamBControllers);
    final bWins = _calcWins(widget.teamBControllers, widget.teamAControllers);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 10 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок с кнопкой закрытия
              SizedBox(
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Результаты матча',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF222223),
                            letterSpacing: -0.8,
                            height: 1.25,
                          ),
                        ),
                        SizedBox(height: 0),
                        Text(
                          'Подтвердите результаты',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF89867E),
                            letterSpacing: -0.32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SvgPicture.asset(
                              'assets/images/close_button_bg.svg',
                              width: 30,
                              height: 30,
                            ),
                            SvgPicture.asset(
                              'assets/images/close_icon_x.svg',
                              width: 11,
                              height: 11,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              
              // Карточка матча с реальным временем и текущим счётом по сетам (по черновику хоста)
              MatchScoreCard(
                teamAPlayerIds: teamAIds.length > 2 ? teamAIds.sublist(0, 2) : teamAIds,
                teamBPlayerIds: teamBIds.length > 2 ? teamBIds.sublist(0, 2) : teamBIds,
                matchDuration: _matchDuration,
                teamAScore: aWins,
                teamBScore: bWins,
              ),
              
              const SizedBox(height: 26),
              
              // Кнопка подтверждения
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _confirmHostScore,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF262F63),
                    padding: const EdgeInsets.symmetric(vertical: 14.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Подтвердить',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.32,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  const _StatColumn({required this.value, required this.label, super.key});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactChip({
    this.icon,
    this.customIcon,
    required this.label,
    required this.color,
    required this.onTap,
  }) : assert(icon != null || customIcon != null, 'Either icon or customIcon must be provided');

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (customIcon != null)
                customIcon!
              else
                Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'BasisGrotesqueArabicPro',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  const _ContactField({required this.label, required this.controller, required this.hint, required this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'BasisGrotesqueArabicPro',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF7F8AC0),
            letterSpacing: -0.2,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: 'BasisGrotesqueArabicPro',
              fontSize: 16,
              color: Color(0xFF22211E),
              letterSpacing: -0.2,
              height: 1.25,
            ),
            filled: true,
            fillColor: Color(0xFFF7F7F7),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelTestStepperModal extends StatefulWidget {
  final VoidCallback? onRatingInitialized;
  const _LevelTestStepperModal({this.onRatingInitialized});
  @override
  State<_LevelTestStepperModal> createState() => _LevelTestStepperModalState();
}

class _LevelTestStepperModalState extends State<_LevelTestStepperModal> {
  int _currentStep = 0;
  bool _showFinal = false;
  final List<int> _answers = [];
  int? _finalScore;
  String? _finalLetter;
  bool _isLoading = false;
  String? _error;

  final List<_LevelTestStepData> _steps = [
    _LevelTestStepData(
      questionNumber: 1,
      questionText: 'Как долго ты играешь в падел (или похожие ракеточные виды спорта)?',
      answers: [
        'Я только начинаю',
        'Меньше года',
        '1-2 года',
        '2-3 года',
        'Больше 3 лет',
      ],
    ),
    _LevelTestStepData(
      questionNumber: 2,
      questionText: 'Как ты играешь от стекла?',
      answers: [
        'Пока не использую отскоки от стен',
        'Иногда пробую, но не всегда получается',
        'Получается отбивать после прямого отскока',
        'Уверенно играю после отскока от заднего и бокового стекла',
        'Использую стекло как часть тактики, могу перевести розыгрыш в свою пользу',
      ],
    ),
    _LevelTestStepData(
      questionNumber: 3,
      questionText: 'Что ты делаешь, когда мяч летит высоко в центр корта?',
      answers: [
        'Просто подставляю ракетку',
        'Пробую смэш, иногда получается',
        'Бью смэш или бандеху, в зависимости от ситуации',
        'Могу выполнить и бандеру, и вибору, и атакующий смэш',
        'Владею всеми видами смэшей, варьирую силу и направление осознанно',
      ],
    ),
    _LevelTestStepData(
      questionNumber: 4,
      questionText: 'Как ты двигаешься по корту?',
      answers: [
        'Стараюсь бегать за мячиком. Отскоки от стен сильно сбивают.',
        'Двигаюсь вперед-назад на своей половине корта. После подачи иду к сетке.',
        'Всё из пункта 2 и иногда получается догонять смэши и вернуть их сопернику.',
        'Всё из пункта 3 и правильно выбираю позицию чтобы вернуть мяч, отскочивший от 1-ой или 2-ух стен. Могу догонять смэши и забивать их сопернику.',
        'Быстро и эффективно двигаюсь по корту, понимаю куда и с какой скоростью прилетит мяч. Не испытываю проблем с отскоками от нескольких стен подряд.',
      ],
    ),
    _LevelTestStepData(
      questionNumber: 5,
      questionText: 'Как ты работаешь над своей игрой в падел?',
      answers: [
        'Я не тренирусь и играю как получается ради развлечения',
        'Сходил на 1-3 тренировки. Мне пока этого хватает',
        'Я иногда посещаю тренировки или работаю над определенными элементами игры',
        'Я регулярно тренируюсь и стараюсь развивать все аспекты своей игры',
        'Я систематически тренируюсь, анализирую свои матчи и работаю с тренером',
      ],
    ),
  ];

  void _onAnswer(int answerIndex) {
    if (_answers.length > _currentStep) {
      _answers[_currentStep] = answerIndex;
    } else {
      _answers.add(answerIndex);
    }
    if (_currentStep < _steps.length - 1) {
      if (!mounted) return;
      setState(() {
        _currentStep++;
      });
    } else {
      final totalScore = _answers.fold(0, (sum, idx) => sum + (idx + 1));
      final letter = scoreToNtrpLetter(totalScore);
      if (!mounted) return;
      setState(() {
        _finalScore = totalScore;
        _finalLetter = letter;
        _showFinal = true;
      });
    }
  }

  void _restartTest() {
    if (!mounted) return;
    setState(() {
      _currentStep = 0;
      _showFinal = false;
      _answers.clear();
      _finalScore = null;
      _finalLetter = null;
      _error = null;
    });
  }

  Future<void> _onSave() async {
    if (_finalLetter == null) return;
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      await ApiService.initializeUserRating(_finalLetter!);
      if (mounted) {
        Navigator.of(context).pop();
        if (widget.onRatingInitialized != null) {
          widget.onRatingInitialized!();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showFinal) {
      return _LevelTestFinalModal(
        onRestart: _restartTest,
        onSave: _onSave,
        letter: _finalLetter ?? 'D',
        isLoading: _isLoading,
        error: _error,
      );
    }
    final step = _steps[_currentStep];
    return _LevelTestQuestionModal(
      questionNumber: step.questionNumber,
      questionText: step.questionText,
      answers: step.answers,
      onAnswer: (answerIndex) => _onAnswer(answerIndex),
    );
  }
}

class _LevelTestStepData {
  final int questionNumber;
  final String questionText;
  final List<String> answers;
  _LevelTestStepData({required this.questionNumber, required this.questionText, required this.answers});
}

class _LevelTestQuestionModal extends StatelessWidget {
  final int questionNumber;
  final String questionText;
  final List<String> answers;
  final void Function(int answerIndex) onAnswer;

  const _LevelTestQuestionModal({
    required this.questionNumber,
    required this.questionText,
    required this.answers,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Шапка: заголовок и крестик
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'Определить мой уровень',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF222223),
                        fontFamily: 'Basis Grotesque Arabic Pro',
                      ),
                    ),
                  ),
                ),
                Material(
                  color: const Color(0xFFF7F7F7),
                  shape: const CircleBorder(),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.close, size: 20, color: Color(0xFF222223)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 24),
            // Счётчик вопроса
            Text(
              '${questionNumber}/5',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xFF7F8AC0),
                fontFamily: 'Basis Grotesque Arabic Pro',
              ),
            ),
            const SizedBox(height: 12),
            // Вопрос
            Text(
              questionText,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xFF222223),
                fontFamily: 'Basis Grotesque Arabic Pro',
              ),
            ),
            const SizedBox(height: 24),
            // Варианты ответов
            ...List.generate(answers.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _LevelTestAnswerButton(
                text: answers[i],
                onTap: () => onAnswer(i),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _LevelTestAnswerButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const _LevelTestAnswerButton({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, color: Color(0xFF222223)),
        ),
      ),
    );
  }
}

class _LevelTestFinalModal extends StatelessWidget {
  final VoidCallback onRestart;
  final Future<void> Function() onSave;
  final String letter;
  final bool isLoading;
  final String? error;
  const _LevelTestFinalModal({required this.onRestart, required this.onSave, required this.letter, this.isLoading = false, this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Шапка: заголовок и крестик
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'Определить мой уровень',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF222223),
                        fontFamily: 'Basis Grotesque Arabic Pro',
                      ),
                    ),
                  ),
                ),
                Material(
                  color: const Color(0xFFF7F7F7),
                  shape: const CircleBorder(),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.close, size: 20, color: Color(0xFF222223)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 24),
            // Рейтинг (примерный)
            Center(
              child: Column(
                children: [
                  const Text(
                    'Твой рейтинг (пока примерный)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF222223),
                      fontFamily: 'Basis Grotesque Arabic Pro',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        letter,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF262F63),
                          fontFamily: 'Basis Grotesque Arabic Pro',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Описание (без серого фона)
            const Text(
              'Первые 15 матчей формируют приблизительный рейтинг. Чем больше сыгранных матчей — тем точнее он становится.',
              style: TextStyle(fontSize: 16, color: Color(0xFF222223)),
            ),
            SizedBox(height: 8),
            const Text(
              'После 40+ матчей рейтинг считается достоверным.',
              style: TextStyle(fontSize: 16, color: Color(0xFF222223)),
            ),
            SizedBox(height: 8),
            const Text(
              'Сейчас ты можешь пройти тест повторно.',
              style: TextStyle(fontSize: 16, color: Color(0xFF262F63), fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            const Text(
              'Также ты сможешь перепройти его из профиля — но только до того, как запишешь первый матч.',
              style: TextStyle(fontSize: 16, color: Color(0xFF222223)),
            ),
            SizedBox(height: 8),
            const Text(
              'После первого матча рейтинг будет обновляться автоматически — по результатам твоих игр.',
              style: TextStyle(fontSize: 16, color: Color(0xFF222223)),
            ),
            const SizedBox(height: 24),
            if (error != null) ...[
              Text(
                error!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            // Кнопки
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF262F63),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Сохранить'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading ? null : onRestart,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF222223),
                      backgroundColor: const Color(0xFFF7F7F7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      side: BorderSide.none,
                    ),
                    child: const Text('Пройти тест заново'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
}

Widget _buildRatingHistoryChart(List<RatingHistoryItem> history) {
  final sorted = List<RatingHistoryItem>.from(history)
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final spots = <FlSpot>[];
  for (int i = 0; i < sorted.length; i++) {
    spots.add(FlSpot(i.toDouble(), sorted[i].ratingAfter.toDouble()));
  }
  final xLabels = <int, String>{};
  for (int i = 0; i < sorted.length; i++) {
    final date = sorted[i].createdAt;
    xLabels[i] = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(left: 0, bottom: 8),
        child: Text(
          'История рейтинга',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF222223),
          ),
        ),
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const chartHeight = 180.0;
            const chartPadding = 0.0; // fl_chart по умолчанию не добавляет padding
            return Stack(
              children: [
                SizedBox(
                  height: chartHeight,
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 32), // место для подписей
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.round();
                                if (xLabels.containsKey(idx)) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      xLabels[idx]!,
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF7F8AC0)),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              interval: 1,
                              reservedSize: 28,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: true),
                        minY: sorted.map((e) => e.ratingAfter).reduce((a, b) => a < b ? a : b).toDouble() - 10,
                        maxY: sorted.map((e) => e.ratingAfter).reduce((a, b) => a > b ? a : b).toDouble() + 10,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 3,
                            dotData: FlDotData(show: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Минимум и максимум — сразу за границей графика
                Positioned(
                  right: 4,
                  top: 0,
                  child: Text(
                    (sorted.map((e) => e.ratingAfter).reduce((a, b) => a > b ? a : b)).toString(),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF222223)),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 28,
                  child: Text(
                    (sorted.map((e) => e.ratingAfter).reduce((a, b) => a < b ? a : b)).toString(),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF222223)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
  }
} 
