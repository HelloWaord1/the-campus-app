import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../models/match.dart';
import '../models/user.dart';
import '../services/auth_storage.dart';
import '../services/api_service.dart';
import '../widgets/past_match_card.dart';
import '../utils/rating_utils.dart';
import '../widgets/user_avatar.dart';
import 'match_details_screen.dart';

class AllMatchesScreen extends StatefulWidget {
  final List<Match> upcomingMatches;
  final List<Match> pastMatches;

  const AllMatchesScreen({
    Key? key,
    required this.upcomingMatches,
    required this.pastMatches,
  }) : super(key: key);

  @override
  State<AllMatchesScreen> createState() => _AllMatchesScreenState();
}

class _AllMatchesScreenState extends State<AllMatchesScreen> {
  String? _currentUserId;
  List<RatingHistoryItem> _ratingHistory = [];
  bool _isLoadingRatingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadRatingHistory();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthStorage.getUser();
    if (!mounted) return;
    setState(() {
      _currentUserId = user?.id;
    });
  }

  Future<void> _loadRatingHistory() async {
    try {
      // Загружаем профиль текущего пользователя с историей рейтинга
      final profile = await ApiService.getProfile();
      if (!mounted) return;
      setState(() {
        _ratingHistory = profile.ratingHistory;
        _isLoadingRatingHistory = false;
      });
    } catch (e) {
      print('❌ Error loading rating history: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingRatingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Объединяем все матчи и фильтруем аннулированные
    final allMatches = <Match>[
      ...widget.upcomingMatches,
      ...widget.pastMatches,
    ].where((match) {
      // Исключаем аннулированные матчи
      final status = match.status.toLowerCase();
      return status != 'cancelled' && status != 'canceled';
    }).toList();

    // Сортируем все матчи: предстоящие первыми (по возрастанию dateTime), 
    // затем завершенные (по убыванию finishedAt/dateTime)
    allMatches.sort((a, b) {
      final aIsCompleted = a.status == 'completed';
      final bIsCompleted = b.status == 'completed';
      
      // Предстоящие матчи идут первыми
      if (!aIsCompleted && bIsCompleted) {
        return -1;
      } else if (aIsCompleted && !bIsCompleted) {
        return 1;
      }
      
      // Для завершенных матчей используем finishedAt, если есть, иначе dateTime
      final aTime = (aIsCompleted && a.finishedAt != null)
          ? a.finishedAt!
          : a.dateTime;
      final bTime = (bIsCompleted && b.finishedAt != null)
          ? b.finishedAt!
          : b.dateTime;
      
      // Предстоящие по возрастанию, завершенные по убыванию
      return aIsCompleted ? bTime.compareTo(aTime) : aTime.compareTo(bTime);
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Мои матчи',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w500,
            fontSize: 18,
            color: Color(0xFF222223),
          ),
        ),
        leading: IconButton(
          icon: SvgPicture.asset('assets/images/back_icon.svg'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: allMatches.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sports_tennis,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет матчей',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Создайте матч или присоединитесь к существующему',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: allMatches.length,
              itemBuilder: (context, index) {
                final match = allMatches[index];
                final isCompleted = match.status == 'completed';
                
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MatchDetailsScreen(matchId: match.id),
                      ),
                    );
                  },
                  child: isCompleted
                      ? PastMatchCard(
                          match: match,
                          currentUserId: _currentUserId,
                          ratingHistory: _ratingHistory,
                        )
                      : _UpcomingMatchCard(match: match),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 16),
            ),
    );
  }
}

class _UpcomingMatchCard extends StatelessWidget {
  final Match match;

  const _UpcomingMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final date = match.dateTime.toLocal();
    final timeStr = DateFormat('HH:mm').format(date);
    final endTime = date.add(Duration(minutes: match.duration));
    final endTimeStr = DateFormat('HH:mm').format(endTime);
    final dayMonth = DateFormat('d MMMM', 'ru').format(date);

    final isSingle = match.format.toLowerCase() == 'single';
    final teamSize = isSingle ? 1 : 2;

    // Распределение участников по командам
    final team1Slots = <MatchParticipant?>[];
    final team2Slots = <MatchParticipant?>[];

    if (isSingle) {
      team1Slots.add(match.participants.isNotEmpty ? match.participants[0] : null);
      team2Slots.add(match.participants.length > 1 ? match.participants[1] : null);
    } else {
      List<MatchParticipant> teamAParticipants =
          match.participants.where((p) => p.teamId == 'A' || p.teamId == null).toList();
      List<MatchParticipant> teamBParticipants =
          match.participants.where((p) => p.teamId == 'B').toList();

      for (int i = 0; i < teamSize; i++) {
        team1Slots.add(i < teamAParticipants.length ? teamAParticipants[i] : null);
        team2Slots.add(i < teamBParticipants.length ? teamBParticipants[i] : null);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Левая часть: дата, время, клуб, корт
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Text(
                          dayMonth,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                            color: Color(0xFF222223),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 16,
                          height: 1,
                          color: const Color(0xFFECECEC),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$timeStr - $endTimeStr',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                            color: Color(0xFF222223),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          match.clubName?.isNotEmpty == true
                              ? match.clubName!
                              : 'Клуб не указан',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Color(0xFF222223),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          match.courtName?.isNotEmpty == true
                              ? match.courtName!
                              : 'Корт не указан',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            color: Color(0xFF222223),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Разделитель
            Container(width: 1, color: const Color(0xFFECECEC)),
            // Правая часть: участники
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TeamSlots(slots: team1Slots),
                    Container(
                      height: 1,
                      color: const Color(0xFFECECEC),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    _TeamSlots(slots: team2Slots),
                    const SizedBox(height: 4),
                    Text(
                      match.isTournament
                          ? 'Турнир'
                          : (match.isPrivate ? 'Закрытый матч' : 'Открытый матч'),
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF89867E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamSlots extends StatelessWidget {
  final List<MatchParticipant?> slots;
  const _TeamSlots({required this.slots});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: slots
          .map((p) => Expanded(child: _ParticipantSlotColumn(participant: p)))
          .toList(),
    );
  }
}

class _ParticipantSlotColumn extends StatelessWidget {
  final MatchParticipant? participant;
  const _ParticipantSlotColumn({this.participant});

  @override
  Widget build(BuildContext context) {
    if (participant == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF89867E), width: 1),
            ),
            child: const Icon(Icons.add, color: Color(0xFF89867E), size: 20),
          ),
          const SizedBox(height: 6),
          const Text('', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 6),
          const Text('', style: TextStyle(fontSize: 14)),
        ],
      );
    }

    final ntrpScore = participant!.userRating != null
        ? calculateRating(participant!.userRating!)
        : 1.0;
    final letter = ratingToLetter(ntrpScore);
    final formattedRating = '$letter ${ntrpScore.toStringAsFixed(2)}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(
          imageUrl: participant!.avatarUrl,
          userName: participant!.name,
          radius: 24,
        ),
        const SizedBox(height: 6),
        Text(
          participant!.name.split(' ').first,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF222223),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          formattedRating,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF262F63),
          ),
        ),
      ],
    );
  }
}

