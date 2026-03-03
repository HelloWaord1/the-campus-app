import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/match.dart';
import '../screens/match_details_screen.dart';
import 'user_avatar.dart';

class MatchCard extends StatelessWidget {
  final Match match;
  final VoidCallback? onUpdated; // вызвать после возврата со страницы деталей
  final bool isTournament; // если true — показываем "Турнир" вместо типа матча

  const MatchCard({super.key, required this.match, this.onUpdated, this.isTournament = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 245,
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
              builder: (context) => MatchDetailsScreen(matchId: match.id, isTournament: isTournament),
            ),
          ).then((_) => onUpdated?.call());
        },
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Text(
                    (match.isTournament || isTournament)
                        ? 'Турнир'
                        : (match.isPrivate ? 'Закрытый матч' : 'Открытый матч'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF89867E),
                      fontFamily: 'Basis Grotesque Arabic Pro',
                      letterSpacing: -0.28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _teamRow(match, 0, isTournament: isTournament)),
                      Container(
                        width: 1,
                        height: 79,
                        color: const Color(0xFFECECEC),
                        margin: const EdgeInsets.symmetric(horizontal: 11),
                      ),
                      Expanded(child: _teamRow(match, 1, isTournament: isTournament)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(right: 120, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.clubName ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF222223),
                            fontFamily: 'Basis Grotesque Arabic Pro',
                            letterSpacing: -0.28,
                            height: 1.29,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          match.clubCity ?? 'Город не указан',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF89867E),
                            fontFamily: 'Basis Grotesque Arabic Pro',
                            letterSpacing: -0.28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 175,
              left: 0,
              right: 0,
              child: Container(height: 1, color: const Color(0xFFD9D9D9)),
            ),
            // Нижняя зона с действиями
            Positioned(
              bottom: 8,
              left: 12,
              right: 12,
              child: _buildBottomAction(match),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(Match match) {
    if (match.status.toLowerCase() == 'cancelled' || match.status.toLowerCase() == 'canceled') {
      return SizedBox(
        width: double.infinity,
        height: 40,
        child: ElevatedButton(
          onPressed: null, // некликабельная
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: const Color(0xFFF2F2F2),
            disabledForegroundColor: const Color(0xFF89867E),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Матч отменен', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
      );
    }
    // По умолчанию — ничего (оставляем существующую логику действий в других местах)
    return const SizedBox.shrink();
  }

  static Widget _teamRow(Match match, int team, {bool isTournament = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int maxPerTeam = match.maxParticipants ~/ 2;
        final double spacing = 8.0;
        final double available = constraints.maxWidth.isFinite ? constraints.maxWidth : (maxPerTeam * 75 + (maxPerTeam - 1) * spacing).toDouble();
        double cellWidth = (available - spacing * (maxPerTeam - 1)) / maxPerTeam;
        cellWidth = cellWidth.clamp(60.0, 75.0);
        final double radius = (24.0 * (cellWidth / 75.0)).clamp(18.0, 24.0);
        final bool isSingle = match.format.toLowerCase() == 'single';

        List<Widget> children = [];
        final String teamId = team == 0 ? 'A' : 'B';
        for (int i = 0; i < maxPerTeam; i++) {
          final MatchParticipant? p = _getParticipantForTeamAndPosition(match, teamId, i);
          if (p != null) {
            children.add(_participantColumn(p, cellWidth, radius));
          } else {
            children.add(_emptySlotColumn(cellWidth, radius, isTournament: isTournament, isSingle: isSingle));
          }
          if (i < maxPerTeam - 1) children.add(SizedBox(width: spacing));
        }

        return Row(
          mainAxisAlignment: isSingle ? MainAxisAlignment.center : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  static MatchParticipant? _getParticipantForTeamAndPosition(Match match, String team, int position) {
    final String normalizedTeam = team.toUpperCase();

    // 1) Участники с явным teamId имеют приоритет
    final List<MatchParticipant> withExplicitTeam = match.participants
        .where((p) => (p.teamId != null && p.teamId!.toUpperCase() == normalizedTeam))
        .toList();

    if (position < withExplicitTeam.length) {
      return withExplicitTeam[position];
    }

    // 2) Fallback: участники без teamId — детерминированно распределяем по индексу
    final List<MatchParticipant> withoutTeam = match.participants
        .where((p) => p.teamId == null)
        .toList();

    final List<MatchParticipant> inferredForTeam = withoutTeam.where((p) {
      final idx = match.participants.indexOf(p);
      final inferred = (idx % 2 == 0) ? 'A' : 'B';
      return inferred == normalizedTeam;
    }).toList();

    final int fallbackIndex = position - withExplicitTeam.length;
    if (fallbackIndex >= 0 && fallbackIndex < inferredForTeam.length) {
      return inferredForTeam[fallbackIndex];
    }

    return null;
  }

  static Widget _participantColumn(MatchParticipant participant, double cellWidth, double radius) {
    return SizedBox(
      width: cellWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(
            imageUrl: participant.avatarUrl,
            userName: participant.name,
            isDeleted: participant.isDeleted,
            radius: radius,
          ),
          const SizedBox(height: 4),
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
          const SizedBox(height: 2),
          Text(
            participant.formattedRating,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF262F63),
              fontFamily: 'Basis Grotesque Arabic Pro',
              letterSpacing: -0.28,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _emptySlotColumn(double cellWidth, double radius, {bool isTournament = false, bool isSingle = false}) {
    return SizedBox(
      width: cellWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(radius),
              border: (isTournament || isSingle)
                  ? Border.all(color: const Color(0xFFF7F7F7), width: 2)
                  : Border.all(color: const Color(0xFF262F63), width: 1),
            ),
            child: Center(
              child: (isTournament || isSingle)
                  ? SvgPicture.asset('assets/images/waiting.svg', width: 20, height: 20)
                  : const Icon(
                      Icons.add,
                      color: Color(0xFF262F63),
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (isTournament || isSingle) ? 'Ожидание' : 'Доступно',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: (isTournament || isSingle) ? const Color(0xFF89867E) : const Color(0xFF262F63),
              fontFamily: 'Basis Grotesque Arabic Pro',
              letterSpacing: -0.28,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static String _formatMatchDateTimeWithDuration(DateTime dateTime, int duration) {
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
}



