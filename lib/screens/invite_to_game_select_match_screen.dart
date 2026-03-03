import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../models/match.dart';
import '../utils/notification_utils.dart';
import 'match_details_screen.dart';
import '../widgets/user_avatar.dart';

class InviteToGameSelectMatchScreen extends StatefulWidget {
  final String userIdToInvite;

  const InviteToGameSelectMatchScreen({super.key, required this.userIdToInvite});

  @override
  State<InviteToGameSelectMatchScreen> createState() => _InviteToGameSelectMatchScreenState();
}

class _InviteToGameSelectMatchScreenState extends State<InviteToGameSelectMatchScreen> {
  bool _isLoading = true;
  String? _error;
  String? _authUserId;
  List<Match> _organizerMatches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final me = await AuthStorage.getUser();
      _authUserId = me?.id;
      final profile = await ApiService.getProfile();
      bool isMine(Match m) {
        if (_authUserId == null) return false;
        if (m.organizerId == _authUserId) return true;
        return m.participants.any((p) => p.userId == _authUserId && (p.role == 'organizer' || p.isOrganizer));
      }
      final list = profile.upcomingMatches.where(isMine).toList();
      if (!mounted) return;
      setState(() { _organizerMatches = list; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _inviteToMatch(Match match) async {
    try {
      await ApiService.inviteUserToMatch(match.id, widget.userIdToInvite);
      if (!mounted) return;
      NotificationUtils.showSuccess(context, 'Приглашение отправлено');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MatchDetailsScreen(matchId: match.id)),
      );
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(context, 'Ошибка: $e');
    }
  }

  // (no-op) removed legacy formatter; card uses _formatMatchDateTimeWithDuration

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Выберите матч',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF222223),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF89867E), size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF00897B),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)))
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _organizerMatches.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'У вас нет ближайших матчей, где вы организатор',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF222223),
                              letterSpacing: -0.28,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _organizerMatches.length,
                        itemBuilder: (context, index) {
                          final match = _organizerMatches[index];
                          return _MatchCardSelectable(match: match, onSelect: () => _inviteToMatch(match));
                        },
                      ),
      ),
    );
  }
}

class _MatchCardSelectable extends StatelessWidget {
  final Match match;
  final VoidCallback onSelect;
  const _MatchCardSelectable({required this.match, required this.onSelect});

  String _formatMatchDateTimeWithDuration(DateTime dateTime, int duration) {
    final weekdays = ['Понедельник','Вторник','Среда','Четверг','Пятница','Суббота','Воскресенье'];
    final months = ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];
    final weekday = weekdays[dateTime.weekday - 1];
    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final startHour = dateTime.hour.toString().padLeft(2, '0');
    final startMinute = dateTime.minute.toString().padLeft(2, '0');
    if (duration > 60) {
      final endTime = dateTime.add(Duration(minutes: duration));
      final endHour = endTime.hour.toString().padLeft(2, '0');
      final endMinute = endTime.minute.toString().padLeft(2, '0');
      return '$weekday, $day $month, $startHour:$startMinute - $endHour:$endMinute';
    } else {
      return '$weekday, $day $month, $startHour:$startMinute';
    }
  }

  List<Widget> _buildTeamParticipants(Match match, int team) {
    List<Widget> participants = [];
    int maxPerTeam = match.maxParticipants ~/ 2;
    String teamId = team == 0 ? 'A' : 'B';
    for (int i = 0; i < maxPerTeam; i++) {
      MatchParticipant? participant;
      if (teamId == 'A' && i == 0) {
        final organizerList = match.participants.where((p) => p.userId == match.organizerId).toList();
        if (organizerList.isNotEmpty) {
          participant = organizerList.first;
        } else if (match.participants.isNotEmpty) {
          participant = match.participants.first;
        }
      } else {
        final nonOrganizer = match.participants.where((p) => p.userId != match.organizerId).toList();
        final filtered = nonOrganizer.where((p) => (p.teamId ?? ((match.participants.indexOf(p) % 2 == 0) ? 'A' : 'B')) == teamId).toList();
        final adjustedIndex = teamId == 'A' ? i - 1 : i;
        if (adjustedIndex >= 0 && adjustedIndex < filtered.length) {
          participant = filtered[adjustedIndex];
        }
      }
      if (participant != null) {
        participants.add(_ParticipantAvatar(
          name: participant.name,
          url: participant.avatarUrl,
          ratingText: participant.formattedRating,
        ));
      } else {
        participants.add(_EmptySlot());
      }
      if (i < maxPerTeam - 1) {
        participants.add(const SizedBox(width: 8));
      }
    }
    return participants;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 230,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
      ),
      child: InkWell(
        onTap: onSelect,
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
                    match.isPrivate ? 'Закрытый матч' : 'Открытый матч',
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
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildTeamParticipants(match, 0),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 79,
                        color: const Color(0xFFECECEC),
                        margin: const EdgeInsets.symmetric(horizontal: 11),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildTeamParticipants(match, 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(right: 120, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.clubName ?? 'Клуб "Ракетка"',
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
              top: 170,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                color: const Color(0xFFD9D9D9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final String ratingText;
  const _ParticipantAvatar({required this.name, this.url, required this.ratingText});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 75,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(
            imageUrl: url,
            userName: name,
            radius: 24,
          ),
          const SizedBox(height: 0),
          Text(
            name.split(' ').first,
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
          SizedBox(
            height: 16,
            child: Center(
              child: Text(
                ratingText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF00897B),
                  fontFamily: 'Basis Grotesque Arabic Pro',
                  letterSpacing: -0.28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 75,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00897B), width: 1),
            ),
            child: const Icon(
              Icons.add,
              color: Color(0xFF00897B),
              size: 20,
            ),
          ),
          const SizedBox(height: 0),
          const Text(
            'Доступно',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF00897B),
              fontFamily: 'Basis Grotesque Arabic Pro',
              letterSpacing: -0.28,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}


