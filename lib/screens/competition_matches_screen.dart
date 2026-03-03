import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
// no-op
import '../services/api_service.dart';
import '../models/competition.dart';
import '../models/match.dart';
import '../widgets/match_card.dart';
import '../widgets/past_match_card.dart';
import '../services/auth_storage.dart';

class CompetitionMatchesScreen extends StatefulWidget {
  final String competitionId;
  final String? competitionFormat; // single | double

  const CompetitionMatchesScreen({super.key, required this.competitionId, this.competitionFormat});

  @override
  State<CompetitionMatchesScreen> createState() => _CompetitionMatchesScreenState();
}

class _CompetitionMatchesScreenState extends State<CompetitionMatchesScreen> {
  late Future<Map<String, dynamic>> _future;
  String? _currentUserId;
  String _competitionFormat = 'single';
  // Динамические ключи заголовков раундов и сегменты между ними
  List<GlobalKey> _titleKeys = [];
  List<double> _segments = [];
  double _topPadding = 8.0; // отступ сверху для левой шкалы (вычислим динамически)
  final GlobalKey _progressKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _future = ApiService.getUserCompetitionMatchesWithFormat(widget.competitionId);
    _loadUser();
  }

  String _roundTitle(int round, String format) {
    // Для Americano: раунды идут просто по порядку (Раунд 1, Раунд 2, и т.д.)
    if (format == 'americano') {
      return 'Матч $round';
    }
    // Для single/double: round: 1 -> Финал, 2 -> 1/2 финала, 3 -> 1/4 финала, 4 -> 1/8 финала, и т.д.
    if (round <= 1) return 'Финал';
    final denom = 1 << (round - 1); // 2^(round-1)
    return '1/$denom финала';
  }

  Future<void> _loadUser() async {
    final u = await AuthStorage.getUser();
    setState(() { _currentUserId = u?.id; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset('assets/images/back_icon.svg', width: 24, height: 24),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Мои матчи',
          style: TextStyle(
            color: Color(0xFF222223),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFCCCCCC)),
        ),
      ),
      backgroundColor: const Color(0xFFF3F5F6),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('Нет данных'));
          }
          final items = (data['matches'] as List<CompetitionMatchItem>?) ?? const [];
          final format = (data['format'] as String?) ?? widget.competitionFormat ?? 'single';
          _competitionFormat = format;
          
          // Собираем раунды динамически
          final Map<int, List<CompetitionMatchItem>> byRound = <int, List<CompetitionMatchItem>>{};
          int maxRound = 1;
          for (final it in items) {
            final r = (it.round ?? 0);
            if (r > 0) {
              (byRound[r] ??= []).add(it);
              if (r > maxRound) maxRound = r;
            }
          }
          
          // Порядок сверху вниз зависит от формата
          final List<int> orderedRounds;
          if (format == 'americano') {
            // Для Americano: сортируем раунды - сначала завершенные, потом незавершенные
            final completedRounds = <int>[];
            final upcomingRounds = <int>[];
            
            for (int r = 1; r <= maxRound; r++) {
              final roundMatches = byRound[r] ?? [];
              if (roundMatches.isEmpty) continue;
              
              // Проверяем, завершен ли матч в этом раунде
              final isCompleted = roundMatches.any((m) => m.matchStatus?.toLowerCase() == 'completed');
              
              if (isCompleted) {
                completedRounds.add(r);
              } else {
                upcomingRounds.add(r);
              }
            }
            
            // Сначала завершенные, потом незавершенные
            orderedRounds = [...completedRounds, ...upcomingRounds];
          } else {
            // Для single/double: от maxRound до 1 (четвертьфинал -> полуфинал -> финал)
            orderedRounds = List<int>.generate(maxRound, (i) => maxRound - i);
          }
          
          // Показываем только те раунды, где у пользователя есть матч (непустые)
          final List<int> nonEmptyRounds = [
            for (final r in orderedRounds)
              if ((byRound[r]?.isNotEmpty ?? false)) r
          ];
          // Обновляем ключи под количество непустых раундов
          if (_titleKeys.length != nonEmptyRounds.length) {
            _titleKeys = List<GlobalKey>.generate(nonEmptyRounds.length, (_) => GlobalKey());
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // После построения измеряем высоты секций
              WidgetsBinding.instance.addPostFrameCallback((_) { _measureHeights(); });
              // _topPadding будет выставлен точно в _measureHeights на основе реальных позиций
              // Определяем статус каждого раунда (завершен или нет)
              final List<bool> roundsCompleted = [];
              for (int i = 0; i < nonEmptyRounds.length; i++) {
                final r = nonEmptyRounds[i];
                final list = byRound[r] ?? const <CompetitionMatchItem>[];
                bool allFinished = list.isNotEmpty && list.every((it) {
                  if (format == 'americano') {
                    // Для Americano проверяем matchStatus
                    return it.matchStatus?.toLowerCase() == 'completed';
                  } else {
                    // Для single/double проверяем score и winnerTeamId
                    final s = it.score;
                    return (s is String && s.trim().isNotEmpty) || it.winnerTeamId != null;
                  }
                });
                roundsCompleted.add(allFinished);
              }
              
              // Показываем линию для всех раундов
              final int totalRounds = nonEmptyRounds.length;
              final int segCount = totalRounds > 0 ? (totalRounds - 1) : 0;
              final List<double> visibleSegments = (_segments.length >= segCount)
                  ? _segments.sublist(0, segCount)
                  : List<double>.from(_segments);
              // оставляем флаг для возможной дальнейшей логики, но сейчас он не используется
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        key: _progressKey,
                        child: _RoundsProgress(segments: visibleSegments, roundsCompleted: roundsCompleted, topPadding: _topPadding),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < nonEmptyRounds.length; i++)
                              _buildRoundBlock(
                                context,
                                // Для Americano используем порядковый номер (i+1), для остальных - реальный номер раунда
                                format == 'americano' ? 'Раунд ${i + 1}' : _roundTitle(nonEmptyRounds[i], format),
                                byRound[nonEmptyRounds[i]] ?? const [],
                                titleKey: _titleKeys[i],
                                showTitle: true,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _measureHeights() {
    if (_titleKeys.isEmpty) return;
    // центры заголовков (используем геометрический центр строки)
    final List<double> centers = [];
    for (final k in _titleKeys) {
      final rb = k.currentContext?.findRenderObject() as RenderBox?;
      if (rb == null) return; // ещё не построено
      final Offset topLeft = rb.localToGlobal(Offset.zero);
      final double dy = topLeft.dy + rb.size.height / 2; // центр заголовка
      centers.add(dy);
    }
    if (centers.length < 2) return;
    final List<double> segs = [];
    for (int i = 0; i < centers.length - 1; i++) {
      segs.add((centers[i + 1] - centers[i]).clamp(0.0, double.infinity));
    }
    // Рассчитываем topPadding так, чтобы центр первой точки совпал с центром первого заголовка
    final RenderBox? pb = _progressKey.currentContext?.findRenderObject() as RenderBox?;
    if (pb != null) {
      final double progressTop = pb.localToGlobal(Offset.zero).dy;
      final double desiredTopPadding = (centers.first - progressTop) - 5.0; // радиус точки = 5
      if (desiredTopPadding.isFinite && desiredTopPadding >= 0) {
        _topPadding = desiredTopPadding;
      }
    }
    // сравниваем
    bool changed = segs.length != _segments.length;
    if (!changed) {
      for (int i = 0; i < segs.length; i++) {
        if ((segs[i] - _segments[i]).abs() > 0.5) { changed = true; break; }
      }
    }
    if (changed) setState(() { _segments = segs; });
  }

  // baseline helper больше не нужен — используем центр строки

  Widget _buildRoundBlock(BuildContext context, String title, List<CompetitionMatchItem> roundItems, {Key? titleKey, bool showTitle = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            title,
            key: titleKey,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF222223),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Column(
          children: roundItems.map((it) {
            final match = _toMatch(it);
            final finished = match.status == 'completed';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: finished
                  ? PastMatchCard(match: match, currentUserId: _currentUserId, isTournament: true)
                  : MatchCard(match: match, isTournament: true),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Match _toMatch(CompetitionMatchItem item) {
    final participants = <MatchParticipant>[];
    void addMembers(CompetitionTeamBrief? t, String teamId) {
      if (t == null) return;
      for (final m in t.members) {
        final name = (m.name ?? ((m.firstName ?? '') + ' ' + (m.lastName ?? ''))).trim();
        participants.add(MatchParticipant(
          id: null,
          userId: m.userId ?? '',
          name: name.isEmpty ? 'Игрок' : name,
          avatarUrl: m.avatarUrl,
          userRating: m.userRating,
          role: null,
          status: null,
          teamId: teamId,
          approvedByOrganizer: null,
          joinedAt: null,
          createdAt: null,
        ));
      }
    }
    addMembers(item.teamA, 'A');
    addMembers(item.teamB, 'B');

    // Определяем завершён ли матч
    // Для Americano используем matchStatus, для single/double - проверяем score и winnerTeamId
    final bool finished = (_competitionFormat == 'americano')
        ? (item.matchStatus?.toLowerCase() == 'completed')
        : ((item.score is String && (item.score as String).trim().isNotEmpty) || item.winnerTeamId != null);

    // Разбор счёта из строки вида "6-3, 4-6, 10-8"
    List<int>? aSets;
    List<int>? bSets;
    final dynamic scoreJson = item.score;
    if (scoreJson is String && scoreJson.trim().isNotEmpty) {
      final parts = scoreJson.split(',');
      final List<int> aa = [];
      final List<int> bb = [];
      for (final p in parts) {
        final ab = p.trim().split(RegExp(r'[:\-]'));
        if (ab.length >= 2) {
          final a = int.tryParse(ab[0].trim()) ?? 0;
          final b = int.tryParse(ab[1].trim()) ?? 0;
          aa.add(a);
          bb.add(b);
        }
      }
      if (aa.isNotEmpty && bb.isNotEmpty) {
        aSets = aa;
        bSets = bb;
      }
    }

    String? winnerTeam;
    if (_competitionFormat == 'americano') {
      // Для Americano используем winnerTeam напрямую ('A' или 'B')
      winnerTeam = item.winnerTeam;
    } else {
      // Для single/double определяем по winnerTeamId
      if (item.winnerTeamId != null) {
        if (item.winnerTeamId == item.teamAId) winnerTeam = 'A';
        if (item.winnerTeamId == item.teamBId) winnerTeam = 'B';
      }
    }

    final dt = item.scheduledTime ?? DateTime.now();

    // Определяем формат по размеру команд или используем формат турнира
    final int teamASize = item.teamA?.members.length ?? 0;
    final int teamBSize = item.teamB?.members.length ?? 0;
    final bool isSingle = (teamASize <= 1) && (teamBSize <= 1);
    final String inferredFormat = _competitionFormat.isNotEmpty 
        ? _competitionFormat 
        : (widget.competitionFormat ?? (isSingle ? 'single' : 'double'));

    return Match(
      id: item.matchId ?? item.competitionMatchId,
      dateTime: dt,
      duration: 60,
      clubId: null,
      clubName: item.clubName,
      clubPhoto: null,
      clubCity: item.city,
      courtId: null,
      isBooked: false,
      format: inferredFormat,
      requiredLevel: 'любитель',
      isPrivate: false,
      description: null,
      maxParticipants: (inferredFormat == 'single') ? 2 : 4,
      currentParticipants: participants.length,
      organizerId: participants.isNotEmpty ? participants.first.userId : '',
      organizerName: participants.isNotEmpty ? participants.first.name : 'Организатор',
      organizerAvatarUrl: participants.isNotEmpty ? participants.first.avatarUrl : null,
      status: finished ? 'completed' : 'active',
      participants: participants,
      bookingId: null,
      createdAt: dt,
      updatedAt: null,
      courtName: null,
      price: null,
      courtNumber: null,
      bookedByName: null,
      winnerTeam: winnerTeam,
      winnerUserId: null,
      teamASets: aSets,
      teamBSets: bSets,
    );
  }
}

class _RoundsProgress extends StatelessWidget {
  final List<double> segments; // расстояния между центрами заголовков
  final List<bool> roundsCompleted; // статус завершенности каждого раунда
  final double topPadding;
  const _RoundsProgress({required this.segments, required this.roundsCompleted, required this.topPadding});

  @override
  Widget build(BuildContext context) {
    const Color completedColor = Color(0xFF00897B); // Зеленый для завершенных
    const Color upcomingColor = Color(0xFFE6E6E6); // Серый для предстоящих
    const double d = 10.0; // диаметр точки

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        children: [
          for (int i = 0; i < roundsCompleted.length; i++) ...[
            _dot(roundsCompleted[i] ? completedColor : upcomingColor),
            if (i < segments.length)
              // Линия зеленая только если оба раунда (текущий и следующий) завершены
              _bar(
                (roundsCompleted[i] && (i + 1 < roundsCompleted.length ? roundsCompleted[i + 1] : false)) 
                  ? completedColor 
                  : upcomingColor, 
                (segments[i] - d).clamp(0.0, double.infinity)
              ),
          ],
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _bar(Color color, double height) {
    if (height <= 0) {
      return const SizedBox(height: 0);
    }
    // Вычитаем диаметр точки (10), чтобы линия шла от нижней точки до верхней следующей
    final double barHeight = (height - 10).clamp(0.0, double.infinity);
    return Container(
      width: 1,
      height: barHeight,
      color: color,
    );
  }
}


