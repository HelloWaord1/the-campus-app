import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Виджет карточки матча с отображением счёта, времени и участников
/// Поддерживает форматы 2x2 (doubles) и 1x1 (singles)
class MatchScoreCard extends StatelessWidget {
  /// ID игроков команды A (1 или 2 игрока)
  final List<String> teamAPlayerIds;
  
  /// ID игроков команды B (1 или 2 игрока)
  final List<String> teamBPlayerIds;
  
  /// Время матча в формате Duration
  final Duration matchDuration;
  
  /// Счёт команды A (например, 3)
  final int teamAScore;
  
  /// Счёт команды B (например, 2)
  final int teamBScore;

  const MatchScoreCard({
    Key? key,
    required this.teamAPlayerIds,
    required this.teamBPlayerIds,
    required this.matchDuration,
    required this.teamAScore,
    required this.teamBScore,
  }) : super(key: key);

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 358,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFD9D9D9),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Время матча
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Время матча',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF89867E),
                  letterSpacing: -0.32,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDuration(matchDuration),
                style: const TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF222223),
                  letterSpacing: -0.48,
                  height: 1.1666666666666667,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Счёт и аватары
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              // Команда A
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Аватары команды A
                    _buildTeamAvatars(teamAPlayerIds),
                    const SizedBox(width: 12),
                    // Счёт команды A
                    _buildScoreBox(teamAScore),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Разделитель
              const Text(
                ':',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF222223),
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 6),
              // Команда B
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Счёт команды B
                    _buildScoreBox(teamBScore),
                    const SizedBox(width: 12),
                    // Аватары команды B
                    _buildTeamAvatars(teamBPlayerIds),
                  ],
                ),
              ),
            ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamAvatars(List<String> playerIds) {
    if (playerIds.isEmpty) {
      return const SizedBox(width: 50, height: 50);
    }

    if (playerIds.length == 1) {
      // Одиночный игрок
      return _buildAvatar(playerIds[0]);
    }

    // Два игрока - накладываем друг на друга
    return SizedBox(
      width: 92, // 50 + 50 - 12 (overlap) + 4 для border
      height: 54, // 50 + 4 для border
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: _buildAvatar(playerIds[0]),
          ),
          Positioned(
            left: 38, // 50 - 12 overlap
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: _buildAvatar(playerIds[1]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String userId) {
    return FutureBuilder<String?>(
      future: _getAvatarUrl(userId),
      builder: (context, snapshot) {
        final avatarUrl = snapshot.data;
        
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE0E0E0),
            image: avatarUrl != null && avatarUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(avatarUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: avatarUrl == null || avatarUrl.isEmpty
              ? const Icon(
                  Icons.person,
                  color: Color(0xFF89867E),
                  size: 30,
                )
              : null,
        );
      },
    );
  }

  Widget _buildScoreBox(int score) {
    return Container(
      width: 44,
      height: 54,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          score.toString(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 24,
            fontWeight: FontWeight.w400,
            color: Color(0xFF222223),
            height: 1.1666666666666667,
          ),
        ),
      ),
    );
  }

  Future<String?> _getAvatarUrl(String userId) async {
    try {
      final profile = await ApiService.getUserProfileById(userId);
      return profile.avatarUrl;
    } catch (e) {
      return null;
    }
  }
}

