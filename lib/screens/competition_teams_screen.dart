import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/competition.dart';
import '../services/auth_storage.dart';
import '../utils/notification_utils.dart';
import '../widgets/user_avatar.dart';
import '../widgets/custom_confirmation_dialog.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CompetitionTeamsScreen extends StatefulWidget {
  final String competitionId;
  final String? myStatus; // pending если заявка подана, приходит с прошлого экрана

  const CompetitionTeamsScreen({super.key, required this.competitionId, this.myStatus});

  @override
  State<CompetitionTeamsScreen> createState() => _CompetitionTeamsScreenState();
}

class _CompetitionTeamsScreenState extends State<CompetitionTeamsScreen> {
  List<CompetitionTeam> _teams = const [];
  bool _loading = true;
  String? _currentUserId;
  String? _currentTeamId;
  String? _competitionFormat; // single | double
  String? _myStatus;

  @override
  void initState() {
    super.initState();
    _myStatus = widget.myStatus;
    _init();
  }

  Future<void> _init() async {
    final user = await AuthStorage.getUser();
    _currentUserId = user?.id;
    await _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _loading = true;
    });
    try {
      final apiResp = await ApiService.getCompetitionTeams(widget.competitionId);
      final teams = apiResp.teams;
      // Also fetch competition to know its format (my_status теперь тоже приходит с teams)
      final competition = await ApiService.getCompetitionById(widget.competitionId);
      _competitionFormat = competition.format;
      _myStatus = apiResp.myStatus ?? _myStatus;
      String? myTeamId;
      for (final t in teams) {
        if (t.participants.any((p) => p.userId == _currentUserId)) {
          myTeamId = t.id;
          break;
        }
      }
      setState(() {
        _teams = teams;
        _currentTeamId = myTeamId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      NotificationUtils.showError(context, e.toString());
    }
  }

  Future<void> _cancelJoinRequest() async {
    try {
      final resp = await ApiService.cancelCompetitionRequest(widget.competitionId);
      if (!mounted) return;
      NotificationUtils.showSuccess(context, resp.message ?? 'Заявка отменена');
      setState(() { _myStatus = null; });
      await _loadTeams();
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(context, e.toString());
    }
  }

  Future<void> _switchToTeam(String teamId) async {
    try {
      await ApiService.switchCompetitionTeam(widget.competitionId, teamId);
      if (!mounted) return;
      NotificationUtils.showSuccess(context, 'Вы отправили заявку на присоединение в команду');
      setState(() { _myStatus = 'pending'; });
      await _loadTeams();
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(context, e.toString());
    }
  }

  Future<void> _joinCompetition() async {
    try {
      final resp = await ApiService.joinCompetition(widget.competitionId, CompetitionJoinRequest());
      if (!mounted) return;
      NotificationUtils.showSuccess(context, resp.message ?? 'Заявка отправлена');
      await _loadTeams();
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(context, e.toString());
    }
  }

  Future<void> _leaveCompetition() async {
    try {
      await ApiService.leaveCompetition(widget.competitionId);
      if (!mounted) return;
      NotificationUtils.showSuccess(context, 'Вы покинули турнир');
      await _loadTeams();
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset('assets/images/back_icon.svg', width: 24, height: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Игроки',
          style: TextStyle(
            color: Color(0xFF222223),
            fontSize: 18,
            fontWeight: FontWeight.w500,
            fontFamily: 'SF Pro Display',
            letterSpacing: -0.36,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFCCCCCC),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeams,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 92),
                itemCount: _teams.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Container(
                      color: Color(0xFFF3F5F6),
                      padding: const EdgeInsets.fromLTRB(16, 00, 16, 0),
                      child: Row(
                        children: const [
                          Spacer(),
                          Text(
                            'Уровень',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF89867E),
                              fontFamily: 'SF Pro Display',
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.32,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final team = _teams[index - 1];
                  return Column(
                    children: [
                      _TeamListRow(
                        team: team,
                        currentUserId: _currentUserId,
                        isSingle: (_competitionFormat == 'single'),
                        onJoin: team.hasVacancy
                            ? () {
                                if (_currentTeamId == team.id) return; // уже здесь
                                _switchToTeam(team.id);
                              }
                            : null,
                      ),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE6E6E6)),
                    ],
                  );
                },
              ),
            ),
      bottomNavigationBar: FutureBuilder<Competition>(
        future: ApiService.getCompetitionById(widget.competitionId),
        builder: (context, snapshot) {
          final String? st = snapshot.data?.status;
          final bool shouldHide = st == 'started' || st == 'completed';
          if (shouldHide) return const SizedBox.shrink();
          return SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: 48,
                  child: (_currentTeamId != null)
                      ? _buildRedButton(
                          text: 'Отменить участие',
                          onPressed: () async {
                            final bool? confirm = await showCustomConfirmationDialog(
                              context: context,
                              title: 'Отменить участие',
                              content: 'Вы уверены что хотите отменить участие?',
                              confirmButtonText: 'Отменить',
                            );
                            if (confirm == true) {
                              await _leaveCompetition();
                            }
                          },
                        )
                      : (_myStatus == 'pending')
                          ? _buildRedButton(
                              text: 'Отменить заявку',
                              onPressed: _cancelJoinRequest,
                            )
                          : ElevatedButton(
                              onPressed: _joinCompetition,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF262F63),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Участвовать',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Basis Grotesque Arabic Pro',
                                  letterSpacing: -0.32,
                                ),
                              ),
                            ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRedButton({
    required String text,
    required VoidCallback onPressed,
    Color backgroundColor = const Color(0xFFF7F7F7),
    Color textColor = Colors.red,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // No per-member rows in the new design
}

class _TeamListRow extends StatelessWidget {
  final CompetitionTeam team;
  final VoidCallback? onJoin;
  final String? currentUserId;
  final bool isSingle;

  const _TeamListRow({required this.team, this.onJoin, this.currentUserId, this.isSingle = false});

  @override
  Widget build(BuildContext context) {
    final leftParticipant = team.participants.isNotEmpty ? team.participants.first : null;
    final rightParticipant = team.participants.length > 1 ? team.participants[1] : null;
    final hasVacancy = team.hasVacancy;
    final full = team.formattedRating;
    final numericRating = (full.length > 2) ? full.substring(2) : full;
    return Container(
      color: Color(0xFFF3F5F6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Left mini tile (player-like)
          _MiniUserTile(participant: leftParticipant, isYou: leftParticipant?.userId == currentUserId),

          const SizedBox(width: 0),

          // Right mini tile logic depends on format
          if (isSingle)
            // Single format: only one avatar, no plus even if vacancy exists
            const SizedBox(width: 70)
          else
            (
              rightParticipant != null
                ? _MiniUserTile(participant: rightParticipant, isYou: rightParticipant.userId == currentUserId)
                : _VacancyTile(onTap: hasVacancy ? onJoin : null)
            ),

          const Spacer(),

          // Team rating at far right with alignment
          Text(
            numericRating,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF222223),
              fontFamily: 'SF Pro Display',
              fontWeight: FontWeight.w400,
              letterSpacing: -0.32,
            ),
          ),
        ],
      ),
    );
  }

  static String firstNameOf(CompetitionListParticipant? p) {
    if (p == null) return '—';
    final full = p.name ?? [p.firstName, p.lastName]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' ');
    if (full.trim().isEmpty) return '—';
    return full.trim().split(' ').first;
  }
}

class _MiniUserTile extends StatelessWidget {
  final CompetitionListParticipant? participant;
  final bool isYou;
  const _MiniUserTile({required this.participant, this.isYou = false});

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      width: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (participant != null)
            UserAvatar(
              imageUrl: participant!.avatarUrl,
              userName: participant!.name ?? '',
              radius: 27,
              backgroundColor: Colors.white,
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF262F63)),
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            isYou ? '(Вы)' : _TeamListRow.firstNameOf(participant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF222223),
              fontFamily: 'SF Pro Display',
              letterSpacing: -0.28,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            participant?.formattedRating ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF262F63),
              fontFamily: 'SF Pro Display',
              letterSpacing: -0.28,
            ),
          ),
        ],
      ),
    );
  }
}

class _VacancyTile extends StatelessWidget {
  final VoidCallback? onTap;
  const _VacancyTile({this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _PlusCircle(),
            SizedBox(height: 2),
            Text(
              'Доступно',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF262F63),
                fontFamily: 'SF Pro Display',
                letterSpacing: -0.28,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF262F63),
                fontFamily: 'SF Pro Display',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlusCircle extends StatelessWidget {
  const _PlusCircle();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF262F63)),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(Icons.add, color: Color(0xFF262F63), size: 22),
      ),
    );
  }
}
// Removed old per-member row widget and helpers as the design now shows one row per team


