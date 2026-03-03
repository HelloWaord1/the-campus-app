import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
// import '../services/auth_storage.dart';
import '../models/match.dart';
import '../models/user.dart';
import '../utils/responsive_utils.dart';
import '../utils/rating_utils.dart';
import 'user_avatar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../screens/match_details_screen.dart';

class PastMatchCard extends StatelessWidget {
  final Match match;
  final String? currentUserId;
  final bool isTournament; // если true — показываем "Турнир" вместо типа матча
  final List<RatingHistoryItem>? ratingHistory;

  const PastMatchCard({
    required this.match,
    this.currentUserId,
    this.isTournament = false,
    this.ratingHistory,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDouble = match.format.toLowerCase() == 'double';
    bool isWin = false;
    final String statusLower = match.status.toLowerCase();
    final bool isCancelled = statusLower == 'cancelled' || statusLower == 'canceled';

    // Составы команд
    final teamA = match.participants.where((p) => p.teamId == 'A' || p.teamId == null).toList();
    final teamB = match.participants.where((p) => p.teamId == 'B').toList();

    if (!isDouble) {
      if (match.winnerUserId != null && currentUserId != null) {
        isWin = (match.winnerUserId == currentUserId);
      } else if (currentUserId != null && match.teamASets != null && match.teamBSets != null) {
        // Фолбэк: определяем победителя по количеству выигранных сетов
        final inA = teamA.any((p) => p.userId == currentUserId);
        final inB = teamB.any((p) => p.userId == currentUserId);
        int setsA = 0, setsB = 0;
        final len = (match.teamASets!.length < match.teamBSets!.length) ? match.teamASets!.length : match.teamBSets!.length;
        for (int i = 0; i < len; i++) {
          if (match.teamASets![i] > match.teamBSets![i]) setsA++; else if (match.teamASets![i] < match.teamBSets![i]) setsB++;
        }
        final winnerTeam = setsA > setsB ? 'A' : (setsB > setsA ? 'B' : null);
        if (winnerTeam != null) {
          isWin = (inA && winnerTeam == 'A') || (inB && winnerTeam == 'B');
        }
      }
    } else {
      if (currentUserId != null) {
        final inA = teamA.any((p) => p.userId == currentUserId);
        final inB = teamB.any((p) => p.userId == currentUserId);
        if (match.winnerTeam != null) {
          isWin = (inA && match.winnerTeam == 'A') || (inB && match.winnerTeam == 'B');
        } else if (match.teamASets != null && match.teamBSets != null) {
          int setsA = 0, setsB = 0;
          final len = (match.teamASets!.length < match.teamBSets!.length) ? match.teamASets!.length : match.teamBSets!.length;
          for (int i = 0; i < len; i++) {
            if (match.teamASets![i] > match.teamBSets![i]) setsA++; else if (match.teamASets![i] < match.teamBSets![i]) setsB++;
          }
          final winnerTeam = setsA > setsB ? 'A' : (setsB > setsA ? 'B' : null);
          if (winnerTeam != null) {
            isWin = (inA && winnerTeam == 'A') || (inB && winnerTeam == 'B');
          }
        }
      }
    }

    // Счёт из модели, если пришёл
    final scoreTeam1 = match.teamASets ?? const [];
    final scoreTeam2 = match.teamBSets ?? const [];

    // final team1 = match.participants.where((p) => p.teamId == 'A' || p.teamId == null).toList();
    // final team2 = match.participants.where((p) => p.teamId == 'B').toList();

    // Для одиночных матчей отображаем по одной аватарке сверху/снизу
    final List<MatchParticipant> displayTop =
        (match.format.toLowerCase() == 'single')
            ? (match.participants.isNotEmpty ? [match.participants[0]] : <MatchParticipant>[])
            : teamA;
    final List<MatchParticipant> displayBottom =
        (match.format.toLowerCase() == 'single')
            ? (match.participants.length > 1 ? [match.participants[1]] : <MatchParticipant>[])
            : teamB;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MatchDetailsScreen(matchId: match.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
      width: ResponsiveUtils.scaleWidth(context, 340),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9D9D9)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (match.isTournament || isTournament)
                    ? 'Турнир'
                    : (match.isPrivate ? 'Закрытый матч' : 'Открытый матч'),
                style: const TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF222223),
                ),
              ),
              Text(
                _formatMatchDateTime(match.dateTime),
                style: const TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 14,
                  color: Color(0xFF89867E),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          SizedBox(
            height: ResponsiveUtils.scaleHeight(context, 70),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatars
                Expanded(flex: 2, child: _buildTeamAvatars(displayTop, displayBottom)),
                SizedBox(
                  height: double.infinity,
                  child: const VerticalDivider(color: Color(0xFFECECEC)),
                ),
                // Score
                Expanded(flex: 3, child: _buildTeamScores(scoreTeam1, scoreTeam2)),
                SizedBox(
                  height: double.infinity,
                  child: const VerticalDivider(color: Color(0xFFECECEC)),
                ),
                // Outcome
                Expanded(flex: 3, child: _buildOutcome(isWin, isCancelled)),
                SizedBox(
                  height: double.infinity,
                  child: const VerticalDivider(color: Color(0xFFECECEC)),
                ),
                // Experience
                Expanded(flex: 2, child: _buildExperience(isWin, isCancelled)),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildTeamAvatars(List<MatchParticipant> team1, List<MatchParticipant> team2) {
    return Column(
      children: [
        Expanded(child: _buildAvatarStack(team1)),
        const Divider(color: Color(0xFFECECEC), height: 1),
        Expanded(child: _buildAvatarStack(team2)),
      ],
    );
  }

  Widget _buildAvatarStack(List<MatchParticipant> team) {
    // Если один игрок — центрируем аватар строго по центру
    if (team.length <= 1) {
      final participant = team.isNotEmpty ? team.first : null;
      return Center(
        child: participant == null
            ? const SizedBox(height: 32, width: 32)
            : UserAvatar(
                radius: 16,
                imageUrl: participant.avatarUrl,
                userName: participant.name,
                isDeleted: participant.isDeleted,
                borderColor: Color(0xFFECECEC),
                borderWidth: 2,
              ),
      );
    }

    // Если 2 игрока — рисуем перекрывающиеся аватары, адаптируя размер под доступную ширину
    return LayoutBuilder(
      builder: (context, constraints) {
        // Предпочитаем не использовать intrinsic-вычисления: адаптируемся к доступной ширине
        // Если ширина неизвестна, используем безопасные дефолты
        final double maxW = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 56.0;
        const double maxRadius = 16.0;
        // Сдвиг между центрами аватаров
        double spacing = maxW / 2; // чтобы поместить два круга в maxW
        double radius = min(maxRadius, maxW / 3); // немного меньше половины spacing

        // Гарантируем минимальные размеры
        radius = radius.clamp(10.0, maxRadius);
        spacing = max(0.0, min(spacing, radius * 1.6));

        final double totalWidth = spacing + 2 * radius;
        final double totalHeight = 2 * radius;

        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              height: totalHeight,
              width: totalWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: List.generate(min(team.length, 2), (index) {
                  final participant = team[index];
                  return Positioned(
                    left: index * spacing,
                    child: UserAvatar(
                      radius: radius,
                      imageUrl: participant.avatarUrl,
                      userName: participant.name,
                      isDeleted: participant.isDeleted,
                      borderColor: Color(0xFFECECEC),
                      borderWidth: 2,
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeamScores(List<int> team1Score, List<int> team2Score) {
    return Column(
      children: [
        Expanded(child: _buildScoreRow(team1Score)),
        const Divider(color: Color(0xFFECECEC), height: 1),
        Expanded(child: _buildScoreRow(team2Score)),
      ],
    );
  }

  Widget _buildScoreRow(List<int> scores) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: scores.map((s) => Text(
          s.toString(),
          style: const TextStyle(fontSize: 16, fontFamily: 'SF Pro Display'),
        )).toList(),
      ),
    );
  }


  Widget _buildOutcome(bool isWin, bool isCancelled) {
    if (isCancelled) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Матч отменён',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.28,
              color: Color(0xFF89867E),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isWin ? 'Победа' : 'Поражение',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.28,
            color: isWin ? const Color(0xFF262F63) : const Color(0xFFEC2D20),
          ),
        ),
        const SizedBox(height: 8),
        SvgPicture.asset(
          isWin ? 'assets/images/rating_up.svg' : 'assets/images/rating_down.svg',
          width: 24,
          height: 24,
        ),
      ],
    );
  }

  /// Находит изменение рейтинга по этому матчу из истории ratingHistory.
  /// Возвращает разницу в "человеческой" шкале (1.0–5.0), либо null если данных нет.
  double? _getRatingDelta() {
    print('🔍 [PastMatchCard] _getRatingDelta: called for matchId=${match.id}, historyLen=${ratingHistory?.length ?? 0}');
    if (ratingHistory == null) return null;

    RatingHistoryItem? item;
    for (final h in ratingHistory!) {
      if (h.matchId == match.id) {
        item = h;
        break;
      }
    }

    if (item == null) {
      print('⚠️ [PastMatchCard] rating delta: no ratingHistory item for matchId=${match.id}');
      return null;
    }

    print('✅ [PastMatchCard] _getRatingDelta: found item for matchId=${match.id}');

    // Сервер иногда не присылает rating_before, но присылает rating_change.
    // Тогда восстанавливаем rating_before из rating_after - rating_change.
    final int? beforeScore = item.ratingBefore ??
        (item.ratingChange != null ? (item.ratingAfter - item.ratingChange!) : null);
    
    if (beforeScore == null) {
      print(
        '⚠️ [PastMatchCard] rating delta: beforeScore is null for matchId=${match.id}; '
        'ratingBefore=${item.ratingBefore}, ratingAfter=${item.ratingAfter}, ratingChange=${item.ratingChange}',
      );
      return null;
    }

    final before = calculateRating(beforeScore);
    final after = calculateRating(item.ratingAfter);
    final delta = after - before;
    print('✅ [PastMatchCard] _getRatingDelta: computed delta=$delta for matchId=${match.id}');
    return delta;
  }

  Widget _buildExperience(bool isWin, bool isCancelled) {
    final delta = _getRatingDelta();
    final mt = (match.matchType ?? '').toLowerCase().trim();
    final bool isTournamentMatch = (match.isTournament || isTournament);
    // Основной признак — matchType из сервера. Фолбэк: если matchType не пришёл,
    // но в истории рейтинга нет записи по матчу (delta == null), показываем "Опыт".
    final bool isFriendly = !isTournamentMatch && (mt == 'friendly' || (mt.isEmpty && delta == null));

    if (isCancelled || isFriendly) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Опыт',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 14,
              color: Color(0xFF89867E),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '—',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF89867E),
            ),
          ),
        ],
      );
    }

    // Если по какой-то причине нет данных по рейтингу для этого матча — показываем прочерк
    final String valueText;
    if (delta == null) {
      valueText = '—';
    } else {
      final sign = delta > 0 ? '+' : '';
      valueText = '$sign${delta.toStringAsFixed(2)}';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Рейтинг',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 12,
            color: isWin ? const Color(0xFF262F63) : const Color(0xFFEC2D20),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          valueText,
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: isWin ? const Color(0xFF262F63) : const Color(0xFFEC2D20),
          ),
        ),
      ],
    );
  }

  String _formatMatchDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day;
    final months = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    final month = months[local.month - 1];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    
    return '$day $month, $hour:$minute';
  }

  // Убрано рандомное формирование счета — используем данные с сервера
} 