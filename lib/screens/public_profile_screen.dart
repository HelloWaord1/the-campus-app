import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/notification_utils.dart';
import '../widgets/level_badge.dart';
import '../widgets/reliability_rating_card.dart';
import '../services/auth_storage.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_screen.dart';
import '../utils/rating_utils.dart';
import 'rating_details_screen.dart';
import '../widgets/user_avatar.dart';
import 'package:flutter/services.dart';
import '../models/match.dart';
import 'match_details_screen.dart';
import 'invite_to_game_select_match_screen.dart';
import '../widgets/past_matches_widget.dart';
import 'all_past_matches_screen.dart';

enum RatingHistoryFilter { five, ten, all }

class _TruncateResult {
  final String truncatedText;
  final bool didTruncate;

  const _TruncateResult({required this.truncatedText, required this.didTruncate});
}

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  UserProfile? _userProfile;
  FriendshipStatusResponse? _friendshipStatus;
  ContactData? _contactData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProfileDeleted = false; // Флаг для удаленного профиля
  RatingHistoryFilter _selectedRatingFilter = RatingHistoryFilter.five;
  // Управление разворачиванием текста "О себе"
  final ValueNotifier<bool> _showMoreBio = ValueNotifier<bool>(false);
  String? _authUserId;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadAuthUserId();
  }

  Future<void> _loadAuthUserId() async {
    try {
      final me = await AuthStorage.getUser();
      if (mounted) setState(() => _authUserId = me?.id);
    } catch (_) {}
  }

  Future<void> _inviteToGame() async {
    try {
      if (_authUserId == null) {
        await _loadAuthUserId();
      }
      // Загружаем профиль, в нём есть ближайшие матчи
      final profile = await ApiService.getProfile();
      bool isMine(Match m) {
        if (_authUserId == null) return false;
        if (m.organizerId == _authUserId) return true;
        return m.participants.any((p) => p.userId == _authUserId && (p.role == 'organizer' || p.isOrganizer));
      }
      final organizerMatches = profile.upcomingMatches.where(isMine).toList();
      if (!mounted) return;
      if (organizerMatches.isEmpty) {
        NotificationUtils.showInfo(context, 'У вас нет ближайших матчей, где вы организатор');
        return;
      }
      final match = await Navigator.of(context).push<Match>(
        MaterialPageRoute(
          builder: (_) => InviteToGameSelectMatchScreen(userIdToInvite: widget.userId),
        ),
      );
      if (match == null) return;

      await ApiService.inviteUserToMatch(match.id, widget.userId);
      if (!mounted) return;
      NotificationUtils.showSuccess(context, 'Приглашение отправлено');

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MatchDetailsScreen(matchId: match.id)),
      );
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(context, 'Ошибка: $e');
    }
  }

  String _formatMatchDateTime(DateTime dateTime, int duration) {
    final weekdays = ['Понедельник','Вторник','Среда','Четверг','Пятница','Суббота','Воскресенье'];
    final months = ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];
    final weekday = weekdays[dateTime.weekday - 1];
    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final startHour = dateTime.hour.toString().padLeft(2, '0');
    final startMinute = dateTime.minute.toString().padLeft(2, '0');
    if (duration > 60) {
      final end = dateTime.add(Duration(minutes: duration));
      final endHour = end.hour.toString().padLeft(2, '0');
      final endMinute = end.minute.toString().padLeft(2, '0');
      return '$weekday, $day $month, $startHour:$startMinute - $endHour:$endMinute';
    }
    return '$weekday, $day $month, $startHour:$startMinute';
  }

  @override
  void dispose() {
    _showMoreBio.dispose();
    super.dispose();
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

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _isProfileDeleted = false; // Сбрасываем флаг при перезагрузке
      });

      final profile = await ApiService.getUserProfileById(widget.userId);
      final friendshipStatus = await ApiService.getFriendshipStatus(widget.userId);
      final contactData = await ApiService.getContactsByUserId(widget.userId);
      
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _friendshipStatus = friendshipStatus;
          _contactData = contactData;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.statusCode == 410) {
          setState(() {
            _isProfileDeleted = true;
            _isLoading = false;
          });
        } else if (e.statusCode == 401) {
          // Глобальный обработчик уже показал диалог и инициировал навигацию
          setState(() {
            _isLoading = false;
          });
          return;
        } else {
          setState(() {
            _errorMessage = e.message;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
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

    // Проверяем, что добавление многоточия не «уведёт» текст дальше половины 3-й строки
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

  Future<void> _updateFriendshipStatus() async {
    try {
      final friendshipStatus = await ApiService.getFriendshipStatus(widget.userId);
      if (mounted) {
        setState(() {
          _friendshipStatus = friendshipStatus;
        });
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(context, 'Ошибка обновления статуса дружбы: $e');
      }
    }
  }

  Future<void> _shareProfile() async {
    final profileUrl = 'https://paddle-app.ru/profile/${widget.userId}';
    
    try {
      await Clipboard.setData(ClipboardData(text: profileUrl));
      
      if (mounted) {
        NotificationUtils.showSuccess(
          context, 
          'Ссылка на профиль скопирована в буфер обмена',
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(
          context, 
          'Ошибка при копировании ссылки',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: SvgPicture.asset('assets/images/back_icon.svg'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isProfileDeleted ? 'Профиль' : 'Профиль игрока',
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            color: Color(0xFF222223),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_isProfileDeleted) // Не показывать кнопку "Поделиться" для удаленного профиля
            IconButton(
              icon: SvgPicture.asset('assets/images/share_logo.svg'),
              onPressed: _shareProfile,
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3,
        onTabTapped: (idx) {
          if (idx != 3) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => HomeScreen(initialTabIndex: idx)),
            );
          }
        },
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

    if (_isProfileDeleted) {
      return _buildDeletedProfileView();
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
              'Ошибка загрузки профиля',
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
              onPressed: _loadUserProfile,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_userProfile == null) {
      return const Center(
        child: Text('Профиль не найден'),
      );
    }

    final profile = _userProfile!;

    // Вычисляем реальный рейтинг из профиля
    final int? ratingScore = profile.currentRating ?? 
      (profile.ratingHistory.isNotEmpty ? profile.ratingHistory.last.ratingAfter : null);
    
    final double? numericRating = ratingScore != null ? calculateRating(ratingScore) : null;
    final String? ratingLetter = numericRating != null ? ratingToLetter(numericRating) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileHeader(profile),
          const SizedBox(height: 24),
          _buildBioSection(profile),
          const SizedBox(height: 0),
          ReliabilityRatingCard(
            ntrpLevel: ratingLetter,
            rating: numericRating,
            reliability: profile.reliability,
            pendingReviewCount: profile.pendingReviewCount,
            totalMatches: profile.totalMatches,
            wins: profile.wins,
            losses: profile.defeats,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const RatingDetailsScreen(showRetestButton: false)),
              );
            },
          ),
          if (profile.ratingHistory.length >= 2) ...[
            const SizedBox(height: 24),
            _buildRatingHistoryChart(profile.ratingHistory),
            if (profile.pastMatches.isNotEmpty) ...[
              const SizedBox(height: 16),
              PastMatchesWidget(
                matches: profile.pastMatches,
                ratingHistory: profile.ratingHistory,
                userIdOverride: widget.userId,
                onSeeAll: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AllPastMatchesScreen(
                        matches: profile.pastMatches,
                        ratingHistory: profile.ratingHistory,
                        userIdOverride: widget.userId,
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 19),
          ] else ...[
            if (profile.pastMatches.isNotEmpty) ...[
              const SizedBox(height: 16),
              PastMatchesWidget(
                matches: profile.pastMatches,
                ratingHistory: profile.ratingHistory,
                userIdOverride: widget.userId,
                onSeeAll: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AllPastMatchesScreen(
                        matches: profile.pastMatches,
                        ratingHistory: profile.ratingHistory,
                        userIdOverride: widget.userId,
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 19),
          ],
        ],
      ),
    );
  }

  Widget _buildDeletedProfileView() {
    // Создаем "фейковый" профиль для использования существующего виджета шапки
    final deletedUserProfile = UserProfile(
      name: 'Удаленный Аккаунт',
      city: '',
      createdAt: DateTime.now(),
      wins: 0,
      defeats: 0,
      totalMatches: 0,
      winRate: 0.0,
      friendsCount: 0,
      avatarUrl: null, // UserAvatar виджет обработает null и покажет заглушку
      bio: null,
      preferredHand: null,
      ratingHistory: [],
      upcomingMatches: [],
      pastMatches: [],
      totalUpcomingMatches: 0,
      totalPastMatches: 0,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileHeader(deletedUserProfile, isDeletedProfile: true),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Аккаунт этого пользователя был удален',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF89867E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(UserProfile profile, {bool isDeletedProfile = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(
          imageUrl: profile.avatarUrl,
          userName: profile.name,
          isDeleted: isDeletedProfile,
          radius: 30,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_contactData?.contactPhone?.isNotEmpty ?? false)
                        GestureDetector(
                          onTap: () => _openPhone(_contactData!.contactPhone!),
                          child: SvgPicture.asset(
                            'assets/images/phone_icon_profile.svg',
                            width: 26,
                            height: 26,
                          ),
                        ),
                      if (_contactData?.telegram?.isNotEmpty ?? false) ...[
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => _openTelegram(_contactData!.telegram!),
                          child: SvgPicture.asset(
                            'assets/images/telegram_icon_profile.svg',
                            width: 26,
                            height: 26,
                          ),
                        ),
                      ],
                      if (_contactData?.whatsapp?.isNotEmpty ?? false) ...[
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => _openWhatsApp(_contactData!.whatsapp!),
                          child: SvgPicture.asset(
                            'assets/images/whatsapp_icon_profile.svg',
                            width: 26,
                            height: 26,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
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
    );
  }


  Widget _buildBioSection(UserProfile profile) {
    final String fullBio = profile.bio ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'О себе',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 18,
            color: Color(0xFF222223),
            letterSpacing: -0.36,
            fontWeight: FontWeight.w400,
          ),
        ),
        
        const SizedBox(height: 6),
        if (_getPreferredHandText(profile) != null)
          Text(
            'Ведущая рука в игре: ${_getPreferredHandText(profile)}',
            style: const TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 16,
              color: Color(0xFF222223),
              height: 1.25,
              letterSpacing: -0.32,
              fontWeight: FontWeight.w400,
            ),
          ),
        if (fullBio.isNotEmpty) ...[
          const SizedBox(height: 8),
          ValueListenableBuilder<bool>(
            valueListenable: _showMoreBio,
            builder: (context, expanded, _) {
              const textStyle = TextStyle(
                fontFamily: 'SF Pro Display',
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
                    Text(fullBio, style: textStyle),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => _showMoreBio.value = false,
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
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
                    fullBio,
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
                        const SizedBox(height: 0),
                        Transform.translate(
                          offset: const Offset(0, -20),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => _showMoreBio.value = true,
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
        ] else ...[
          const SizedBox(height: 18),
        ]
      ],
    );
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
        dataToShow = sorted;
        break;
    }
    // Если точек меньше двух, просто не рисуем график
    if (dataToShow.length < 2) return const SizedBox.shrink();

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
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Color(0xFF222223),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_friendshipStatus == null) {
      return const SizedBox.shrink(); 
    }

    Widget button;
    Color buttonColor = const Color(0xFF222223); // Default color
    Widget? secondaryButton;

    if (_friendshipStatus!.isAccepted) {
      buttonColor = const Color(0xFFEC2D20);
      button = _buildActionButton(
        svgAsset: 'assets/images/remove_friend.svg',
        text: 'Убрать из друзей',
        color: buttonColor,
        onTap: () async {
          try {
            await ApiService.removeFriend(widget.userId);
            NotificationUtils.showSuccess(context, 'Пользователь удален из друзей');
            await _updateFriendshipStatus();
          } catch (e) {
            NotificationUtils.showError(context, 'Ошибка: $e');
          }
        },
      );
    } else if (_friendshipStatus!.isSent) {
      buttonColor = const Color(0xFFEC2D20);
      button = _buildActionButton(
        svgAsset: 'assets/images/remove_friend.svg',
        text: 'Отменить заявку',
        color: buttonColor,
        onTap: () async {
          try {
            await ApiService.cancelFriendRequest(widget.userId);
            NotificationUtils.showSuccess(context, 'Заявка в друзья отменена');
            await _updateFriendshipStatus();
          } catch (e) {
            NotificationUtils.showError(context, 'Ошибка: $e');
          }
        },
      );
    } else if (_friendshipStatus!.isWaiting) {
      buttonColor = const Color(0xFF262F63);
      button = _buildActionButton(
        svgAsset: 'assets/images/add_friend.svg',
        text: 'Принять заявку в друзья',
        color: buttonColor,
        onTap: () async {
          try {
            await ApiService.acceptFriendRequest(widget.userId);
            NotificationUtils.showSuccess(context, 'Заявка в друзья принята');
            await _updateFriendshipStatus();
          } catch (e) {
            NotificationUtils.showError(context, 'Ошибка: $e');
          }
        },
      );
      // Кнопка "Отклонить заявку" чуть ниже
      secondaryButton = _buildActionButton(
        svgAsset: 'assets/images/remove_friend.svg',
        text: 'Отклонить заявку',
        color: const Color(0xFFEC2D20),
        onTap: () async {
          try {
            await ApiService.rejectFriendRequest(widget.userId);
            NotificationUtils.showSuccess(context, 'Заявка в друзья отклонена');
            await _updateFriendshipStatus();
          } catch (e) {
            NotificationUtils.showError(context, 'Ошибка: $e');
          }
        },
      );
    } else {
      button = _buildActionButton(
        svgAsset: 'assets/images/add_friend.svg',
        text: 'Добавить в друзья',
        onTap: () async {
          try {
            await ApiService.sendFriendRequest(widget.userId);
            NotificationUtils.showSuccess(context, 'Заявка в друзья отправлена');
            await _updateFriendshipStatus();
          } catch (e) {
            NotificationUtils.showError(context, 'Ошибка: $e');
          }
        },
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          button,
          if (secondaryButton != null) ...[
            const Divider(color: Color(0xFFD9D9D9), height: 1),
            secondaryButton,
          ],
          const Divider(color: Color(0xFFD9D9D9), height: 1),
          _buildActionButton(
            svgAsset: 'assets/images/invite_to_game.svg',
            text: 'Пригласить в игру',
            onTap: _inviteToGame,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({String? svgAsset, IconData? icon, required String text, required VoidCallback onTap, Color color = const Color(0xFF222223)}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
      children: [
            if (svgAsset != null)
              SvgPicture.asset(svgAsset, width: 24, height: 24, colorFilter: color == const Color(0xFF222223) ? null : ColorFilter.mode(color, BlendMode.srcIn))
            else if (icon != null)
              Icon(icon, color: color),
            const SizedBox(width: 12),
        Text(
              text,
          style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 16,
            color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Helpers to open contact links directly from public profile =====

  void _openPhone(String raw) async {
    String number = raw.trim();
    final RegExp digits = RegExp(r'\d+');
    final String onlyDigits = digits.allMatches(number).map((m) => m.group(0)).join();
    if (onlyDigits.isEmpty) return;
    if (number.startsWith('+')) {
      number = '+$onlyDigits';
    } else {
      number = '+$onlyDigits';
    }
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        NotificationUtils.showError(context, 'Не удалось открыть телефон');
      }
    } catch (_) {
      NotificationUtils.showError(context, 'Не удалось открыть телефон');
    }
  }

  void _openWhatsApp(String raw) async {
    String number = raw.trim();
    final RegExp digits = RegExp(r'\d+');
    final String onlyDigits = digits.allMatches(number).map((m) => m.group(0)).join();
    if (onlyDigits.isEmpty) return;
    if (number.startsWith('+')) {
      number = '+$onlyDigits';
    } else {
      number = onlyDigits;
    }
    final Uri waUri = Uri.parse('whatsapp://send?phone=$number');
    final Uri apiUri = Uri.parse('https://api.whatsapp.com/send?phone=$number');
    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(apiUri)) {
        await launchUrl(apiUri, mode: LaunchMode.externalApplication);
      } else {
        NotificationUtils.showError(context, 'Не удалось открыть WhatsApp');
      }
    } catch (_) {
      NotificationUtils.showError(context, 'Не удалось открыть WhatsApp');
    }
  }

  void _openTelegram(String raw) async {
    String v = raw.trim();
    if (v.startsWith('@')) {
      v = v.substring(1);
    }

    Uri uri;
    if (v.startsWith('http') || v.startsWith('tg://')) {
      uri = Uri.parse(v);
    } else {
      uri = Uri.parse('tg://resolve?domain=$v');
    }

    try {
      if (uri.scheme == 'tg') {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          final webUri = Uri.parse('https://t.me/$v');
          if (await canLaunchUrl(webUri)) {
            await launchUrl(webUri, mode: LaunchMode.externalApplication);
          } else {
            NotificationUtils.showError(context, 'Не удалось открыть Telegram');
          }
        }
      } else {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          NotificationUtils.showError(context, 'Не удалось открыть Telegram');
        }
      }
    } catch (_) {
      NotificationUtils.showError(context, 'Не удалось открыть Telegram');
    }
  }
}