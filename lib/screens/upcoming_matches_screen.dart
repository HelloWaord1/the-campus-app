import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:padel/models/match.dart';
import 'package:padel/utils/rating_utils.dart';
import '../widgets/user_avatar.dart';

class UpcomingMatchesScreen extends StatelessWidget {
  final List<Match> matches;

  const UpcomingMatchesScreen({Key? key, required this.matches}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Ближайшие матчи',
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFD9D9D9),
            height: 0.5,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final match = matches[index];
          return MatchCard(match: match);
        },
        separatorBuilder: (context, index) => const SizedBox(height: 16),
      ),
    );
  }
}

class MatchCard extends StatelessWidget {
  final Match match;

  const MatchCard({Key? key, required this.match}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final date = match.dateTime;
    final timeStr = DateFormat('HH:mm').format(date);
    final endTime = date.add(Duration(minutes: match.duration));
    final endTimeStr = DateFormat('HH:mm').format(endTime);
    final dayMonth = DateFormat('d MMMM', 'ru').format(date);
    final isSingle = match.format.toLowerCase() == 'single';
    final teamSize = isSingle ? 1 : 2;
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
            // Left side
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
                        Container(width: 16, height: 1, color: const Color(0xFFECECEC)),
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
                    )
                  ],
                ),
              ),
            ),
            // Divider
            Container(width: 1, color: const Color(0xFFECECEC)),
            // Right side
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
            child: const Icon(Icons.add, color: Color(0xFF89867E)),
          ),
          const SizedBox(height: 6),
          const Text('', style: TextStyle(fontSize: 14)), // Placeholder for name
          const SizedBox(height: 6),
          const Text('', style: TextStyle(fontSize: 14)), // Placeholder for rating
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
            color: Color(0xFF00897B),
          ),
        ),
      ],
    );
  }
} 