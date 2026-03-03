import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../models/competition.dart';
import '../services/auth_storage.dart';
import 'package:flutter/services.dart';
import '../utils/notification_utils.dart';
import '../widgets/user_avatar.dart';
import '../widgets/profile_menu_button.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_screen.dart';
import '../widgets/custom_confirmation_dialog.dart';
import 'competition_teams_screen.dart';
import '../widgets/match_card.dart';
import '../widgets/past_match_card.dart';
import 'competition_results_screen.dart';
import '../models/match.dart';
import 'competition_matches_screen.dart';
import '../widgets/competition_status_badge.dart';
import '../widgets/club_card.dart';
import '../models/user.dart';

class CompetitionDetailsScreen extends StatefulWidget {
  final String competitionId;

  const CompetitionDetailsScreen({super.key, required this.competitionId});

  @override
  State<CompetitionDetailsScreen> createState() => _CompetitionDetailsScreenState();
}

class _CompetitionDetailsScreenState extends State<CompetitionDetailsScreen> {
  Future<Competition>? _future;
  String? _currentUserId;
  Future<List<Match>>? _matchesFuture;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getCompetitionById(widget.competitionId);
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthStorage.getUser();
    setState(() {
      _currentUserId = user?.id;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ApiService.getCompetitionById(widget.competitionId);
      _matchesFuture = ApiService.getUserCompetitionMatches(widget.competitionId);
    });
  }

  Future<void> _cancelJoinRequest() async {
    try {
      final resp = await ApiService.cancelCompetitionRequest(widget.competitionId);
      if (!mounted) return;
      NotificationUtils.showSuccess(context, resp.message ?? 'Заявка отменена');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Competition>(
        future: _future,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final hasError = snapshot.hasError;

          return Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero image (fixed, not collapsing)
                    Container(
                      width: double.infinity,
                      height: 246,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(
                            snapshot.data?.status == 'started'
                                ? 'assets/images/competition_detail_started.png'
                                : 'assets/images/competition_detail.png',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
                      child: loading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 48),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : hasError
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Ошибка: ${snapshot.error}'),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: _refresh,
                                      child: const Text('Повторить'),
                                    )
                                  ],
                                )
                              : _buildContent(snapshot.data!),
                    ),
                  ],
                ),
              ),
              // Back button - same style as club/match details
              Positioned(
                left: 16,
                top: MediaQuery.of(context).padding.top,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/images/back_icon.svg',
                          width: 24,
                          height: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Share button - same style as club/match details
              Positioned(
                right: 16,
                top: MediaQuery.of(context).padding.top,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _shareCompetition,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/images/share_logo.svg',
                          width: 18,
                          height: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTabTapped: (index) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(initialTabIndex: index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(Competition comp) {
    final levelText = _formatLevel(comp.minRating, comp.maxRating);
    final audienceText = _audienceText(comp.participantsGender);
    final capacity = comp.maxParticipants ?? 0;
    final registered = comp.participants.length;
    final isJoined = _currentUserId != null && comp.participants.any((p) => p.userId == _currentUserId);
    final isStarted = comp.status == 'started';
    final isCompleted = comp.status == 'completed';

    if (_matchesFuture == null && (isStarted || isCompleted) && isJoined) {
      _matchesFuture = ApiService.getUserCompetitionMatches(widget.competitionId);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок (для started - с большим кубком и бейджем, иначе - компактный)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              isStarted ? 'assets/images/trophy_icon.svg' : 'assets/images/competition_cup.svg',
              width: 64,
              height: 74,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comp.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF222223),
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -0.36,
                    ),
                  ),
                  Text(
                    _formatDateTime(comp.startTime),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF222223),
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -0.32,
                    ),
                  ),
                  // Бейдж статуса турнира
                  const SizedBox(height: 6),
                  CompetitionStatusBadge.fromCompetitionData(
                    competitionStatus: comp.status,
                    myStatus: comp.myStatus,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        SizedBox(
          height: 1,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -16,
                right: -16,
                top: 0,
                child: Divider(
                  height: 1,
                  thickness: isStarted ? 0.5 : 1,
                  color: const Color(0x1A000000),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Официальный организатор (только для started если есть club_name)
        if (isStarted && (comp.clubName ?? '').isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    'assets/images/organizer_badge.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Официальный организатор',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF89867E),
                          fontFamily: 'SF Pro Display',
                          letterSpacing: -0.28,
                        ),
                      ),
                      Text(
                        comp.clubName ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF222223),
                          fontFamily: 'SF Pro Display',
                          letterSpacing: -0.32,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Победители турнира (для завершённых)
        if (comp.status == 'completed') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Победители турниров',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF222223),
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.56,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CompetitionResultsScreen(
                        competitionId: comp.id,
                        finalStandingTeamIds: comp.finalStandingTeamIds,
                        teams: comp.teams,
                        participants: comp.participants,
                        competitionFormat: comp.format,
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: const Text(
                  'Все результаты',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF00897B),
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.62,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 0),
          _WinnersPodium(
            finalStandingTeamIds: comp.finalStandingTeamIds,
            teams: comp.teams,
            participants: comp.participants,
            competitionFormat: comp.format,
          ),
          const SizedBox(height: 22),
          const Divider(color: Color(0xFFE6E6E6), height: 1, thickness: 1),
          //const SizedBox(height: 16),
        ],

        // Мои матчи (для started/completed и если пользователь участвует)
        if ((isStarted || isCompleted) && isJoined) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Мои матчи',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF222223),
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.36,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CompetitionMatchesScreen(competitionId: comp.id, competitionFormat: comp.format),
                    ),
                  );
                },
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: const Text(
                  'Смотреть все',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF00897B),
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.32,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isStarted ? 16 : 4),
          FutureBuilder<List<Match>>(
            future: _matchesFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              if (snap.hasError) {
                return const SizedBox.shrink();
              }
              final matches = snap.data ?? const [];
              if (matches.isEmpty) return const SizedBox.shrink();
              if (isCompleted) {
                // Для завершенных турниров показываем последний сыгранный матч
                final completed = matches.where((m) {
                  final hasScore = (m.teamASets != null && m.teamASets!.isNotEmpty) || (m.teamBSets != null && m.teamBSets!.isNotEmpty);
                  final isCompletedMatch = m.status.toLowerCase() == 'completed';
                  return hasScore || isCompletedMatch;
                }).toList();
                if (completed.isEmpty) return const SizedBox.shrink();
                completed.sort((a, b) => a.dateTime.compareTo(b.dateTime));
                final lastMatch = completed.last;
                return SizedBox(
                  width: 370,
                  child: PastMatchCard(match: lastMatch, currentUserId: _currentUserId, isTournament: true),
                );
              } else {
                // Для текущих турниров показываем предстоящие матчи
                final visible = matches.where((m) {
                  final hasScore = (m.teamASets != null && m.teamASets!.isNotEmpty) || (m.teamBSets != null && m.teamBSets!.isNotEmpty);
                  final isCompletedMatch = m.status.toLowerCase() == 'completed';
                  return !(hasScore || isCompletedMatch);
                }).toList();
                if (visible.isEmpty) return const SizedBox.shrink();
                // Для started показываем только первый матч, для других - список
                if (isStarted) {
                  final m = visible.first;
                  return SizedBox(
                    width: 370,
                    child: MatchCard(match: m, isTournament: true),
                  );
                } else {
                  return SizedBox(
                    height: 255,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final m = visible[index];
                        return SizedBox(
                          width: 370,
                          child: MatchCard(match: m, isTournament: true),
                        );
                      },
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: const [
                Positioned(
                  left: -16,
                  right: -16,
                  top: 0,
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0x1A000000),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Чат с игроками (для started - новый стиль, для других - старый)
        if ((comp.chat ?? '').isNotEmpty) ...[
          if (isStarted)
            InkWell(
              onTap: () => _openChatLink(comp.chat!),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset('assets/images/chat_circle_dots.svg', width: 24, height: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Чат с игроками',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF222223),
                          fontFamily: 'SF Pro Display',
                          letterSpacing: -0.32,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF89867E), size: 24),
                  ],
                ),
              ),
            )
          else
            ProfileMenuButton(
              icon: Icons.chat_bubble_outline,
              customIcon: SvgPicture.asset('assets/images/chat_competition.svg', width: 22, height: 22, color: const Color(0xFF89867E)),
              label: 'Чат с игроками',
              onTap: () => _openChatLink(comp.chat!),
            ),
          const SizedBox(height: 24),
        ],

        // Participants & capacity progress (скрываем полностью при завершённом турнире)
        if (!isCompleted) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Игроки ($registered/$capacity)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF222223),
                  fontFamily: 'SF Pro Display',
                  letterSpacing: -0.36,
                ),
              ),
              if (registered > 0)
                Transform.translate(
                  offset: const Offset(0, 0),
                  child: TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                      builder: (_) => CompetitionTeamsScreen(competitionId: comp.id, myStatus: comp.myStatus),
                        ),
                      );
                      // После возврата обновим детали и список матчей
                      if (mounted) {
                        await _refresh();
                      }
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                    child: const Text(
                      'Смотреть все',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF00897B),
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -0.32,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (registered == 0)
            SizedBox(
              height: 100,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/images/nav_profile.svg',
                      width: 24,
                      height: 24,
                      color: const Color(0xFFB6B3AC),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Нет игроков',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF89867E),
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -0.36,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 82,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -16,
                    right: -16,
                    top: 0,
                    child: SizedBox(
                      height: 85,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (_, i) {
                          final p = comp.participants[i];
                          final full = p.name ?? [p.firstName, p.lastName].whereType<String>().where((s) => s.isNotEmpty).join(' ');
                          final firstOnly = (full.trim().isEmpty) ? '' : full.trim().split(' ').first;
                          return Column(
                            children: [
                              UserAvatar(
                                imageUrl: p.avatarUrl,
                                userName: full,
                                radius: 24,
                              ),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  firstOnly,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF222223),
                                    fontFamily: 'SF Pro Display',
                                    letterSpacing: -0.28,
                                  ),
                                ),
                              ),
                              Text(
                                p.formattedRating,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF00897B),
                                  fontFamily: 'SF Pro Display',
                                ),
                              ),
                            ],
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 0),
                        itemCount: comp.participants.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Header above progress: required players on the left, count on the right
          Row(
            children: [
              Expanded(
                child: Text(
                  _requiredPlayersText(registered, capacity),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF222223),
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.32,
                  ),
                ),
              ),
              Text(
                '$registered/$capacity',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF222223),
                  fontFamily: 'SF Pro Display',
                  letterSpacing: -0.32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _capacityBar(registered, capacity),
          const SizedBox(height: 22),
          const Divider(color: Color(0xFFE6E6E6), height: 1, thickness: 1),
          const SizedBox(height: 16),
        ],

        // Divider перед рейтингом только для started
        if (isStarted) ...[
          SizedBox(
            height: 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: const [
                Positioned(
                  left: -16,
                  right: -16,
                  top: 0,
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0x1A000000),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Рейтинг, пол, формат (для started - с иконками, для других - обычно)
          Column(
            children: [
              Row(
                children: [
                  SvgPicture.asset('assets/images/chart_bar_icon.svg', width: 24, height: 24),
                  const SizedBox(width: 8),
                  Text(
                    levelText,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF222223),
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -0.36,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SvgPicture.asset('assets/images/gender_intersex_icon.svg', width: 24, height: 24),
                  const SizedBox(width: 8),
                  Text(
                    audienceText,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF222223),
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -0.36,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SvgPicture.asset(
                    (comp.format == 'single' || comp.format == 'double') 
                        ? 'assets/images/trophy_outline.svg' 
                        : 'assets/images/table_icon.svg',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatName(comp.format),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF222223),
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -0.36,
                    ),
                  ),
                ],
              ),
            ],),
          
        const SizedBox(height: 20),

        // Description
        const Text(
          'Описание:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF89867E),
            fontFamily: 'SF Pro Display',
            letterSpacing: -0.32,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          (comp.description ?? '').isNotEmpty ? comp.description! : 'Описание отсутствует',
          style: const TextStyle(
            fontSize: 16, 
            color: Color(0xFF222223), 
            fontWeight: FontWeight.w400,
            height: 20/16, 
            letterSpacing: -0.32,
            fontFamily: 'SF Pro Display'),
        ),
        const SizedBox(height: 24),
        
        // Divider перед призами
        if (isStarted)
          SizedBox(
            height: 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: const [
                Positioned(
                  left: -16,
                  right: -16,
                  top: 0,
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0x1A000000),
                  ),
                ),
              ],
            ),
          )
        else
          const Divider(color: Color(0xFFE6E6E6), height: 1, thickness: 1),
        SizedBox(height: isStarted ? 24 : 16),

        // Prize
        const Text(
          'Призы',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF222223),
            fontFamily: 'SF Pro Display',
            letterSpacing: -0.36,
          ),
        ),
        SizedBox(height: isStarted ? 4 : 6),
        Text(
          (comp.prize ?? '').isNotEmpty ? comp.prize! : (isStarted ? 'Призы для этого соревнования не предусмотрены' : 'Призы для этого турнира не предусмотрены'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.32,
            color: Color(0xFF222223),
            height: 20 / 16,
            fontFamily: 'SF Pro Display',
          ),
        ),
        const SizedBox(height: 24),

        // Карточка клуба (если есть clubId)
        if (comp.clubId != null && (comp.clubName ?? '').isNotEmpty) ...[
          ClubCard(
            clubId: comp.clubId,
            clubName: comp.clubName ?? '',
            clubCity: comp.city,
            onContactsTap: () {
              // TODO: открыть контакты клуба
            },
          ),
          const SizedBox(height: 24),
        ],

        const SizedBox(height: 30), // space for bottom button

        // Bottom button floating — скрываем, если турнир начался
        if (comp.status == 'collecting')
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: Builder(builder: (_) {
                        final bool isPending = (comp.myStatus == 'pending');
                        if (isJoined) {
                          return _buildRedButton(
                            onPressed: () async {
                              final bool? confirm = await showCustomConfirmationDialog(
                                context: context,
                                title: 'Отменить участие',
                                content: 'Вы уверены что хотите отменить участие?',
                                confirmButtonText: 'Отменить',
                              );
                              if (confirm == true) {
                                await _leave();
                              }
                            },
                            text: 'Отменить участие',
                          );
                        }
                        if (isPending) {
                          return _buildRedButton(
                            onPressed: _cancelJoinRequest,
                            text: 'Отменить заявку',
                          );
                        }
                        return SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => _join(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00897B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Участвовать',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Basis Grotesque Arabic Pro',
                                letterSpacing: -0.32,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _capacityBar(int registered, int capacity) {
    final percent = capacity > 0 ? (registered / capacity).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: const Color(0xFFE6E6E6),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF00897B)),
              minHeight: 4,
            ),
          ),
        ),
      ],
    );
  }

  String _requiredPlayersText(int registered, int capacity) {
    final missing = (capacity - registered).clamp(0, capacity);
    if (missing <= 0) return 'Достигнут максимум игроков';
    final word = _pluralizePlayers(missing);
    return 'Требуется минимум $missing $word';
  }

  String _pluralizePlayers(int n) {
    final nAbs = n.abs();
    final n10 = nAbs % 10;
    final n100 = nAbs % 100;
    if (n10 == 1 && n100 != 11) return 'игрок';
    if (n10 >= 2 && n10 <= 4 && (n100 < 12 || n100 > 14)) return 'игрока';
    return 'игроков';
  }

  String _formatDateTime(DateTime dt) {
    final weekday = _weekdayRu(dt.weekday);
    final month = _monthRu(dt.month);
    final two = (int n) => n.toString().padLeft(2, '0');
    return '$weekday, ${dt.day} $month, ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _formatLevel(double? min, double? max) {
    if (min == null && max == null) return '—';
    if (min != null && max != null) return '${min.toStringAsFixed(2)} – ${max.toStringAsFixed(2)}';
    if (min != null) return 'от ${min.toStringAsFixed(2)}';
    return 'до ${max!.toStringAsFixed(2)}';
  }

  String _audienceText(String gender) {
    switch (gender) {
      case 'male':
        return 'Для мужчин';
      case 'female':
        return 'Для женщин';
      default:
        return 'Для всех';
    }
  }

  Widget _genderIcon(String? gender, {double size = 16}) {
    const color = Color(0xFF222223);
    if (gender == 'male') {
      return Icon(Icons.male, size: size, color: color);
    }
    if (gender == 'female') {
      return Icon(Icons.female, size: size, color: color);
    }
    return SvgPicture.asset(
      'assets/images/all_gender.svg',
      width: size,
      height: size,
    );
  }

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

  Future<void> _join() async {
    // Для парного single-elimination показываем нижнее меню как в фигме
    final comp = await _future;
    final Competition? c = (comp is Competition) ? comp : null;
    final String? format = c?.format;
    if (format == 'double') {
      _showJoinModeSheet();
      return;
    }
    try {
      final resp = await ApiService.joinCompetition(widget.competitionId, CompetitionJoinRequest());
      if (!mounted) return;
      NotificationUtils.showSuccess(context, resp.message ?? 'Заявка отправлена');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(context, e.toString());
    }
  }

  void _showJoinModeSheet() {
    int selectedMode = 0; // 0 = Один, 1 = Парой
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Заголовок
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Text(
                              'Хотите присоединиться\nодин или с парой?',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF222223),
                                fontFamily: 'SF Pro Display',
                                letterSpacing: -0.48,
                                height: 1.17,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6, right: 4),
                            child: InkWell(
                            onTap: () => Navigator.of(ctx).pop(),
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              width: 44.5,
                              height: 44.5,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFAEAEAE),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 0, color: Colors.transparent),
                    const SizedBox(height: 12),
                    // Кнопки выбора
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => selectedMode = 0),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: selectedMode == 0 ? const Color(0xFF00897B) : const Color(0xFFD9D9D9),
                                    width: selectedMode == 0 ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Один',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF222223),
                                    fontFamily: 'SF Pro Display',
                                    letterSpacing: -0.32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => selectedMode = 1),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: selectedMode == 1 ? const Color(0xFF00897B) : const Color(0xFFD9D9D9),
                                    width: selectedMode == 1 ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Парой',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF222223),
                                    fontFamily: 'SF Pro Display',
                                    letterSpacing: -0.32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Кнопка продолжить
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            if (selectedMode == 0) {
                              // Один
                              try {
                                final resp = await ApiService.joinCompetition(widget.competitionId, CompetitionJoinRequest());
                                if (!mounted) return;
                                NotificationUtils.showSuccess(context, resp.message ?? 'Заявка отправлена');
                                await _refresh();
                              } catch (e) {
                                if (!mounted) return;
                                NotificationUtils.showError(context, e.toString());
                              }
                            } else {
                              // Парой
                              _showPickCompanionSheet();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00897B),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            selectedMode == 0 ? 'Продолжить' : 'Выбрать напарника',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'SF Pro Display',
                              letterSpacing: -0.32,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Home indicator
                    Container(
                      height: 0,
                      alignment: Alignment.center,
                      child: Container(
                        width: 134,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFF222223),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _joinModeTile({required Widget icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6E6E6), width: 1),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF222223),
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -0.32,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF89867E),
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -0.28,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF89867E), size: 22),
          ],
        ),
      ),
    );
  }

  void _showPickCompanionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return _PickCompanionContent(
          onPick: (userId) async {
            Navigator.of(ctx).pop();
            try {
              final resp = await ApiService.joinCompetitionPair(widget.competitionId, userId);
              if (!mounted) return;
              NotificationUtils.showSuccess(context, resp.message ?? 'Парная заявка отправлена');
              await _refresh();
            } catch (e) {
              if (!mounted) return;
              NotificationUtils.showError(context, e.toString());
            }
          },
        );
      },
    );
  }

  Future<void> _leave() async {
    try {
      await ApiService.leaveCompetition(widget.competitionId);
      if (!mounted) return;
      // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Вы покинули турнир')));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _shareCompetition() async {
    final url = 'https://the-campus.app/competition/${widget.competitionId}';
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      NotificationUtils.showSuccess(context, 'Ссылка скопирована в буфер обмена');
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(context, 'Не удалось скопировать ссылку');
    }
  }

  Future<void> _openChatLink(String raw) async {
    String url = raw.trim();
    // Если это @username — преобразуем в https://t.me/username
    if (url.startsWith('@')) {
      url = 'https://t.me/${url.substring(1)}';
    }
    // Если без схемы — добавим https
    if (!url.startsWith('http') && !url.startsWith('tg://')) {
      url = 'https://$url';
    }
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        NotificationUtils.showError(context, 'Не удалось открыть ссылку на чат');
      }
    } catch (_) {
      if (!mounted) return;
      NotificationUtils.showError(context, 'Не удалось открыть чат');
    }
  }

  String _formatName(String? format) {
    switch (format) {
      case 'single':
        return 'Мексикано';
      case 'double':
        return 'Мексикано';
      case 'americano':
        return 'Американо';
      default:
        return 'Турнир';
    }
  }
}
class _PickCompanionContent extends StatefulWidget {
  final ValueChanged<String> onPick;
  const _PickCompanionContent({required this.onPick});

  @override
  State<_PickCompanionContent> createState() => _PickCompanionContentState();
}

class _PickCompanionContentState extends State<_PickCompanionContent> {
  FriendsApiResponse? _friends;
  bool _loading = true;
  int _selectedTab = 0; // 0 = Мои друзья, 1 = Комьюнити
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      final nextQuery = _searchController.text;
      if (nextQuery != _searchQuery) {
        setState(() {
          _searchQuery = nextQuery;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final f = await ApiService.getFriends();
      if (!mounted) return;
      setState(() {
        _friends = f;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          minHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок с кнопкой закрытия
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFCCCCCC), width: 0.5)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          'Добавить напарника',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF222223),
                            fontFamily: 'SF Pro Display',
                            letterSpacing: -0.48,
                            height: 1.5,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 0, right: 0),
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Container(
                                width: 31,
                                height: 31,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFAEAEAE),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 21,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  // Вкладки
                  Container(
                    height: 34,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedTab = 0),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: _selectedTab == 0 ? Border.all(color: const Color(0xFFEFEEEC), width: 0.5) : null,
                                boxShadow: _selectedTab == 0
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: const Text(
                                'Мои друзья',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF222223),
                                  fontFamily: 'SF Pro Display',
                                  letterSpacing: -0.32,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedTab = 1),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: _selectedTab == 1 ? Border.all(color: const Color(0xFFEFEEEC), width: 0.5) : null,
                                boxShadow: _selectedTab == 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: const Text(
                                'Комьюнити',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF222223),
                                  fontFamily: 'SF Pro Display',
                                  letterSpacing: -0.32,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Поиск
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF222223),
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -0.2,
                      ),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Поиск',
                        hintStyle: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF79766E),
                          fontFamily: 'SF Pro Display',
                          letterSpacing: -0.8,
                        ),
                        prefixIcon: Icon(Icons.search, color: Color(0xFF89867E), size: 22),
                        prefixIconConstraints: BoxConstraints(minWidth: 28),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Список друзей
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_selectedTab == 1)
              const Expanded(
                child: Center(
                  child: Text(
                    'Комьюнити пока недоступно',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF89867E),
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -0.32,
                    ),
                  ),
                ),
              )
            else if ((_friends?.friends ?? []).isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Список друзей пуст',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF89867E),
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -0.32,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: Builder(
                  builder: (context) {
                    final all = _friends!.friends;
                    final q = _searchQuery.trim().toLowerCase();
                    final filtered = q.isEmpty
                        ? all
                        : all.where((f) => f.name.toLowerCase().contains(q)).toList();
                    return ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(top: 18, bottom: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final friend = filtered[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          child: Row(
                            children: [
                              UserAvatar(imageUrl: friend.avatarUrl, userName: friend.name, radius: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  friend.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF222223),
                                    fontFamily: 'SF Pro Display',
                                    letterSpacing: -0.28,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => widget.onPick(friend.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00897B),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 1),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Добавить',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'SF Pro Display',
                                    letterSpacing: -0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

          ],
        ),
      ),
    );
  }
}

// Old chip widget removed; we now use _WinnersPodium

class _WinnersPodium extends StatelessWidget {
  final List<String> finalStandingTeamIds;
  final List<CompetitionTeam> teams;
  final List<CompetitionListParticipant> participants;
  final String? competitionFormat;

  const _WinnersPodium({
    required this.finalStandingTeamIds,
    this.teams = const [],
    this.participants = const [],
    this.competitionFormat,
  });

  CompetitionTeam _teamById(String id) {
    return teams.firstWhere(
      (t) => t.id.toString() == id.toString(),
      orElse: () => CompetitionTeam(id: id.toString(), participants: const []),
    );
  }

  CompetitionListParticipant? _participantById(String id) {
    try {
      return participants.firstWhere(
        (p) => p.userId.toString() == id.toString(),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAmericano = competitionFormat == 'americano';
    final bool isSingle = (competitionFormat == 'single') || isAmericano;
    
    final String? t1 = finalStandingTeamIds.isNotEmpty ? finalStandingTeamIds[0] : null;
    final String? t2 = finalStandingTeamIds.length > 1 ? finalStandingTeamIds[1] : null;
    final String? t3 = finalStandingTeamIds.length > 2 ? finalStandingTeamIds[2] : null;
    const double r1 = 26;
    const double r2 = 21;
    const double r3 = 21;
    final double baselineHeight = [r1, r2, r3].reduce((a, b) => a > b ? a : b) * 3;

    // Для Americano получаем участников напрямую, для single/double - из команд
    List<CompetitionListParticipant> getParticipantsForPlace(String? id) {
      if (id == null) return const [];
      if (isAmericano) {
        final p = _participantById(id);
        return p != null ? [p] : const [];
      } else {
        return _teamById(id).participants;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _PlaceColumn(
              place: 2,
              participants: getParticipantsForPlace(t2),
              avatarRadius: 21,
              showTrophy: false,
              align: CrossAxisAlignment.center,
              baselineHeight: baselineHeight,
              isSingle: isSingle,
            ),
          ),
          Container(width: 1, height: 65, color: const Color(0xFFE6E6E6)),
          Expanded(
            child: _PlaceColumn(
              place: 1,
              participants: getParticipantsForPlace(t1),
              avatarRadius: 26,
              showTrophy: true,
              align: CrossAxisAlignment.center,
              baselineHeight: baselineHeight,
              isSingle: isSingle,
            ),
          ),
          Container(width: 1, height: 65, color: const Color(0xFFE6E6E6)),
          Expanded(
            child: _PlaceColumn(
              place: 3,
              participants: getParticipantsForPlace(t3),
              avatarRadius: 21,
              showTrophy: false,
              align: CrossAxisAlignment.center,
              baselineHeight: baselineHeight,
              isSingle: isSingle,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceColumn extends StatelessWidget {
  final int place;
  final List<CompetitionListParticipant> participants;
  final double avatarRadius;
  final bool showTrophy;
  final CrossAxisAlignment align;
  final double? baselineHeight;
  final bool isSingle;

  const _PlaceColumn({
    required this.place,
    required this.participants,
    required this.avatarRadius,
    required this.showTrophy,
    required this.align,
    this.baselineHeight,
    this.isSingle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        SizedBox(
          height: baselineHeight ?? (avatarRadius * 2),
          // Для single (Мексикано) немного увеличим ширину, чтобы метка "2 место" не переносилась
          width: isSingle
              ? math.max((avatarRadius * 2) + 8, 76)
              : (avatarRadius * 2 + avatarRadius * 0.8),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: (avatarRadius * 2) + 6,
                child: const SizedBox(),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: (avatarRadius * 2) + 6,
                child: Center(
                  child: Text(
                    '$place место',
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF00897B),
                      letterSpacing: -0.28,
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ),
              if (isSingle)
                _centeredAvatar(0, 0)
              else ...[
                _centeredAvatar(0, -avatarRadius * 0.8),
                _centeredAvatar(1, avatarRadius * 0.8),
              ],
              if (showTrophy && !isSingle) ...[
                Positioned(
                  right: -16,
                  bottom: -8,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: SvgPicture.asset('assets/images/winner_cup.svg', width: 18, height: 18),
                    ),
                  ),
                ),
              ],
              if (showTrophy && isSingle) ...[
                Positioned(
                  right: -6,
                  bottom: -8,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: SvgPicture.asset('assets/images/winner_cup.svg', width: 18, height: 18),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (isSingle) ...[
          const SizedBox(height: 4),
          _winnerName(),
          const SizedBox(height: 2),
          _winnerRating(),
        ],
      ],
    );
  }

  Widget _centeredAvatar(int index, double dx) {
    final CompetitionListParticipant? p = (index < participants.length) ? participants[index] : null;
    final String name = (p?.name ?? ((p?.firstName ?? '') + ' ' + (p?.lastName ?? ''))).trim();
    return Transform.translate(
      offset: Offset(dx, 0),
      child: SizedBox(
        width: avatarRadius * 2,
        height: avatarRadius * 2,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: UserAvatar(
            imageUrl: p?.avatarUrl,
            userName: name.isNotEmpty ? name : 'Игрок',
            radius: avatarRadius,
            borderColor: const Color(0xFFECECEC),
            borderWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _winnerRating() {
    final CompetitionListParticipant? p = participants.isNotEmpty ? participants.first : null;
    final String rating = p?.formattedRating ?? '';
    return Text(
      rating,
      style: const TextStyle(
        fontFamily: 'SF Pro Display',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF00897B),
        letterSpacing: -0.28,
      ),
    );
  }

  Widget _winnerName() {
    final CompetitionListParticipant? p = participants.isNotEmpty ? participants.first : null;
    final String full = (p?.name ?? ((p?.firstName ?? '') + ' ' + (p?.lastName ?? ''))).trim();
    final String first = full.isNotEmpty ? full.split(' ').first : '';
    return Text(
      first,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'SF Pro Display',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFF222223),
        letterSpacing: -0.28,
      ),
    );
  }
}

Widget _buildRedButton({
  required String text,
  required VoidCallback onPressed,
  Color backgroundColor = const Color(0xFFF7F7F7),
  Color textColor = Colors.red,
}) {
  return SizedBox(
    width: double.infinity,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}
