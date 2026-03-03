import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_storage.dart';
import '../models/match.dart';
import '../models/user.dart';
// import '../utils/responsive_utils.dart';
import '../widgets/past_match_card.dart';

class AllPastMatchesScreen extends StatefulWidget {
  final List<Match> matches;
  final List<RatingHistoryItem>? ratingHistory;
  final String? userIdOverride;

  const AllPastMatchesScreen({
    Key? key,
    required this.matches,
    this.ratingHistory,
    this.userIdOverride,
  }) : super(key: key);

  @override
  _AllPastMatchesScreenState createState() => _AllPastMatchesScreenState();
}

class _AllPastMatchesScreenState extends State<AllPastMatchesScreen> {
  String _filter = 'Все';
  String _searchQuery = '';
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthStorage.getUser();
    if (!mounted) return;
    setState(() {
      _currentUserId = user?.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUserId = widget.userIdOverride ?? _currentUserId;

    final filteredMatches = widget.matches.where((match) {
      if (_filter == 'Все') {
        return true;
      }
      // Если текущий пользователь неизвестен, не применяем фильтр по исходу
      if (effectiveUserId == null || effectiveUserId.isEmpty) {
        return true;
      }
      final bool isWin = _isWinForMatch(match, effectiveUserId);
      if (_filter == 'Выигранные') {
        return isWin;
      }
      if (_filter == 'Проигранные') {
        return !isWin;
      }
      return true;
    }).where((match) {
      if (_searchQuery.isEmpty) {
        return true;
      }
      return match.participants.any((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'История матчей',
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
          preferredSize: const Size.fromHeight(120.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Найти игрока',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF2F2F2),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildFilterButton('Все'),
                    const SizedBox(width: 12),
                    _buildFilterButton('Выигранные'),
                    const SizedBox(width: 12),
                    _buildFilterButton('Проигранные'),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: filteredMatches.length,
        itemBuilder: (context, index) {
          final match = filteredMatches[index];
          return PastMatchCard(
            match: match,
            currentUserId: effectiveUserId,
            ratingHistory: widget.ratingHistory,
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 16),
      ),
    );
  }

  Widget _buildFilterButton(String title) {
    final isSelected = _filter == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF262F63) : const Color(0xFFD9D9D9),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF222223),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  bool _isWinForMatch(Match match, String currentUserId) {
    final bool isDouble = match.format.toLowerCase() == 'double';
    bool isWin = false;

    final teamA = match.participants.where((p) => p.teamId == 'A' || p.teamId == null).toList();
    final teamB = match.participants.where((p) => p.teamId == 'B').toList();

    if (!isDouble) {
      if (match.winnerUserId != null) {
        isWin = (match.winnerUserId == currentUserId);
      } else if (match.teamASets != null && match.teamBSets != null) {
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

    return isWin;
  }
} 