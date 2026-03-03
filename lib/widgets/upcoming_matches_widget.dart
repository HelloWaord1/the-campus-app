import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/match.dart';
import '../utils/responsive_utils.dart';
import '../utils/rating_utils.dart';
import 'user_avatar.dart';

class UpcomingMatchesWidget extends StatelessWidget {
  final List<Match> matches;
  final void Function(Match)? onMatchTap;
  final void Function()? onSeeAll;

  const UpcomingMatchesWidget({
    Key? key,
    required this.matches,
    this.onMatchTap,
    this.onSeeAll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ближайшие матчи',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  color: Color(0xFF222223),
                ),
              ),
              if (onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Смотреть все',
                  style: TextStyle(
                      fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                      color: Color(0xFF262F63),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: ResponsiveUtils.scaleHeight(context, 248),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final match = matches[index];
              return _MatchCard(match: match, onTap: () => onMatchTap?.call(match));
            },
          ),
        ),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Match match;
  final VoidCallback? onTap;

  const _MatchCard({required this.match, this.onTap});

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
      List<MatchParticipant> teamAParticipants = match.participants.where((p) => p.teamId == 'A' || p.teamId == null).toList();
      List<MatchParticipant> teamBParticipants = match.participants.where((p) => p.teamId == 'B').toList();

      for (int i = 0; i < teamSize; i++) {
        team1Slots.add(i < teamAParticipants.length ? teamAParticipants[i] : null);
        team2Slots.add(i < teamBParticipants.length ? teamBParticipants[i] : null);
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ResponsiveUtils.scaleWidth(context, 330),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
        ),
        child: Row(
          children: [
            // Левая часть: дата, время, клуб, корт
            SizedBox(
              width: ResponsiveUtils.scaleWidth(context, 120),
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
                        match.clubName?.isNotEmpty == true ? match.clubName! : 'Клуб не указан',
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
                        match.courtName?.isNotEmpty == true ? match.courtName! : 'Корт не указан',
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
            const SizedBox(width: 16),
            Container(
              width: 2,
              color: const Color(0xFFECECEC),
            ),
            const SizedBox(width: 16),
            // Правая часть: участники
            Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                  _TeamSlots(slots: team1Slots),
                            Container(
                              height: 1,
                    color: const Color(0xFFECECEC),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  _TeamSlots(slots: team2Slots),
                  const SizedBox(height: 4),
                  Text(
                    match.isTournament ? 'Турнир' : (match.isPrivate ? 'Закрытый матч' : 'Открытый матч'),
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
      children: slots.map((p) => Expanded(child: _ParticipantSlotColumn(participant: p))).toList(),
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
          const SizedBox(height: 4),
          const Text('', style: TextStyle(fontSize: 13, height: 1.0)),
          const SizedBox(height: 2),
          const Text('', style: TextStyle(fontSize: 13, height: 1.0)),
        ],
      );
    }

    final ntrpScore = participant!.userRating != null ? calculateRating(participant!.userRating!) : 1.0;
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
        const SizedBox(height: 4),
        Text(
              participant!.name.split(' ').first,
              style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF222223),
                height: 1.0,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          formattedRating,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF262F63),
            height: 1.0,
            ),
          ),
        ],
    );
  }
} 