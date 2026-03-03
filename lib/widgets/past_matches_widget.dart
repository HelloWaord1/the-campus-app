import 'package:flutter/material.dart';
import '../models/match.dart';
import '../models/user.dart';
import '../screens/match_details_screen.dart';
import '../services/auth_storage.dart';
import '../utils/responsive_utils.dart';
import 'past_match_card.dart';

class PastMatchesWidget extends StatelessWidget {
  final List<Match> matches;
  final VoidCallback? onSeeAll;
  final List<RatingHistoryItem>? ratingHistory;
  final String? userIdOverride;

  const PastMatchesWidget({
    Key? key,
    required this.matches,
    this.onSeeAll,
    this.ratingHistory,
    this.userIdOverride,
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
                'История матчей',
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
          height: ResponsiveUtils.scaleHeight(context, 150),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final match = matches[index];
              // Если явно передали userIdOverride — считаем результат матча
              // относительно него, иначе используем текущего авторизованного пользователя.
              if (userIdOverride != null) {
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MatchDetailsScreen(matchId: match.id),
                      ),
                    );
                  },
                  child: PastMatchCard(
                    match: match,
                    currentUserId: userIdOverride,
                    ratingHistory: ratingHistory,
                  ),
                );
              }

              return FutureBuilder(
                future: AuthStorage.getUser(),
                builder: (context, snapshot) {
                  final currentUserId = snapshot.data?.id;
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => MatchDetailsScreen(matchId: match.id),
                        ),
                      );
                    },
                    child: PastMatchCard(
                      match: match,
                      currentUserId: currentUserId,
                      ratingHistory: ratingHistory,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
} 