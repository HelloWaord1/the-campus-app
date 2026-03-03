import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../models/match.dart';
import '../widgets/match_score_card.dart';
import '../widgets/match_score_input.dart';
import '../utils/notification_utils.dart';
import '../services/auth_storage.dart';
import '../utils/logger.dart';

/// Показывает модальное окно подтверждения/оспаривания результата матча
Future<void> showMatchResultConfirmationSheet({
  required BuildContext context,
  required String matchId,
  required List<MatchParticipant?> participantsA,
  required List<MatchParticipant?> participantsB,
  List<int>? hostTeamASets,
  List<int>? hostTeamBSets,
  Duration matchDuration = Duration.zero,
  VoidCallback? onUpdated,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _ConfirmSheetContent(
        matchId: matchId,
        participantsA: participantsA,
        participantsB: participantsB,
        hostTeamASets: hostTeamASets,
        hostTeamBSets: hostTeamBSets,
        onUpdated: onUpdated,
      );
    },
  );
}

class _ConfirmSheetContent extends StatefulWidget {
  final String matchId;
  final List<MatchParticipant?> participantsA;
  final List<MatchParticipant?> participantsB;
  final List<int>? hostTeamASets;
  final List<int>? hostTeamBSets;
  final VoidCallback? onUpdated;

  const _ConfirmSheetContent({
    required this.matchId,
    required this.participantsA,
    required this.participantsB,
    this.hostTeamASets,
    this.hostTeamBSets,
    this.onUpdated,
  });

  @override
  State<_ConfirmSheetContent> createState() => _ConfirmSheetContentState();
}

class _ConfirmSheetContentState extends State<_ConfirmSheetContent> {
  bool _loading = false;
  bool _hideDispute = false; // скрывать "Оспорить" по правилам 24ч для организатора
  Duration _matchDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _evaluatePermissions();
  }

  Future<void> _evaluatePermissions() async {
    try {
      // Получаем текущего пользователя и детали матча (организатор, finished_at)
      final user = await AuthStorage.getUser();
      final match = await ApiService.getMatchDetails(widget.matchId);

      final isOrganizer = (user?.id != null) && (match.organizerId == user!.id);
      final finishedAt = match.finishedAt; // может быть null, если матч ещё не завершён
      final startedAt = match.startedAt;

      bool hideDispute = false;
      if (isOrganizer && finishedAt != null) {
        final now = DateTime.now();
        final limit = finishedAt.add(const Duration(hours: 24));
        // В течение 24 часов после конца матча организатор не может оспаривать — только подтверждать
        if (now.isBefore(limit)) {
          hideDispute = true;
        }
      }

      // Реальная длительность: finished_at - started_at
      var realDuration = Duration.zero;
      if (finishedAt != null && startedAt != null) {
        realDuration = finishedAt.difference(startedAt).abs();
      }

      if (mounted) {
        setState(() {
          _hideDispute = hideDispute;
          _matchDuration = realDuration;
        });
      }
    } catch (_) {
      // В случае ошибки не скрываем кнопку, чтобы не блокировать UX
    }
  }

  int _calcWins(List<int>? a, List<int>? b) {
    if (a == null || b == null || a.isEmpty || b.isEmpty) return 0;
    int wins = 0;
    final len = a.length > b.length ? a.length : b.length;
    for (int i = 0; i < len; i++) {
      final aa = i < a.length ? a[i] : 0;
      final bb = i < b.length ? b[i] : 0;
      if (aa > bb) wins++;
    }
    return wins;
  }

  String _scoreToLabel(List<int>? a, List<int>? b) {
    if (a == null || b == null || a.isEmpty || b.isEmpty) return '—';
    final sets = <String>[];
    final len = a.length > b.length ? a.length : b.length;
    for (int i = 0; i < len; i++) {
      final aa = i < a.length ? a[i] : 0;
      final bb = i < b.length ? b[i] : 0;
      sets.add('$aa-$bb');
    }
    return sets.join(', ');
  }

  Future<void> _confirm() async {
    Logger.info('🟢 Начало подтверждения счёта для матча: ${widget.matchId}');
    setState(() => _loading = true);
    try {
      Logger.info('🟢 Вызов ApiService.confirmHostScore...');
      await ApiService.confirmHostScore(widget.matchId);
      Logger.success('✅ ApiService.confirmHostScore завершён успешно');
      if (!mounted) return;
      Navigator.of(context).pop();
      NotificationUtils.showSuccess(context, 'Результаты подтверждены');
      Logger.info('🟢 Вызов onUpdated callback...');
      widget.onUpdated?.call();
      Logger.info('🟢 Подтверждение счёта завершено');
    } catch (e) {
      Logger.error('❌ Ошибка при подтверждении счёта', e);
      if (!mounted) return;
      NotificationUtils.showError(
        context,
        e is ApiException ? e.message : 'Ошибка подтверждения счёта',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDispute() async {
    Navigator.of(context).pop();
    await showDisputeScoreSheet(
      context: context,
      matchId: widget.matchId,
      participantsA: widget.participantsA,
      participantsB: widget.participantsB,
      onUpdated: widget.onUpdated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hostScoreLabel = _scoreToLabel(widget.hostTeamASets, widget.hostTeamBSets);
    final teamAIds = widget.participantsA.where((p) => p != null).map((p) => (p!).userId).toList(growable: false);
    final teamBIds = widget.participantsB.where((p) => p != null).map((p) => (p!).userId).toList(growable: false);
    final aWins = _calcWins(widget.hostTeamASets, widget.hostTeamBSets);
    final bWins = _calcWins(widget.hostTeamBSets, widget.hostTeamASets);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 10 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Результаты матча',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF222223),
                              letterSpacing: -0.8,
                              height: 1.25,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Подтвердите или оспорьте предложенный счёт',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF89867E),
                              letterSpacing: -0.32,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/images/close_button_bg.svg',
                                width: 30,
                                height: 30,
                              ),
                              SvgPicture.asset(
                                'assets/images/close_icon_x.svg',
                                width: 11,
                                height: 11,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              MatchScoreCard(
                teamAPlayerIds: teamAIds.length > 2 ? teamAIds.sublist(0, 2) : teamAIds,
                teamBPlayerIds: teamBIds.length > 2 ? teamBIds.sublist(0, 2) : teamBIds,
                matchDuration: _matchDuration,
                teamAScore: aWins,
                teamBScore: bWins,
              ),
              
              const SizedBox(height: 20),
              Row(
                children: [
                  if (!_hideDispute) ...[
                    Expanded(
                      child: TextButton(
                        onPressed: _loading ? null : _openDispute,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B6B),
                          padding: const EdgeInsets.symmetric(vertical: 14.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Осдорить',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: TextButton(
                      onPressed: _loading ? null : _confirm,
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        padding: const EdgeInsets.symmetric(vertical: 14.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: Colors.white,
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Подтвердить',
                              style: TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.32,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Показывает модальное окно для ввода оспариваемого счёта
Future<void> showDisputeScoreSheet({
  required BuildContext context,
  required String matchId,
  required List<MatchParticipant?> participantsA,
  required List<MatchParticipant?> participantsB,
  Duration matchDuration = Duration.zero,
  VoidCallback? onUpdated,
}) async {
  final teamAControllers = List.generate(3, (_) => TextEditingController(text: '0'));
  final teamBControllers = List.generate(3, (_) => TextEditingController(text: '0'));

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _DisputeScoreSheet(
        matchId: matchId,
        teamAControllers: teamAControllers,
        teamBControllers: teamBControllers,
        participantsA: participantsA,
        participantsB: participantsB,
        onUpdated: onUpdated,
      );
    },
  );
}

class _DisputeScoreSheet extends StatefulWidget {
  final String matchId;
  final List<TextEditingController> teamAControllers;
  final List<TextEditingController> teamBControllers;
  final List<MatchParticipant?> participantsA;
  final List<MatchParticipant?> participantsB;
  final VoidCallback? onUpdated;

  const _DisputeScoreSheet({
    required this.matchId,
    required this.teamAControllers,
    required this.teamBControllers,
    required this.participantsA,
    required this.participantsB,
    this.onUpdated,
  });

  @override
  State<_DisputeScoreSheet> createState() => _DisputeScoreSheetState();
}

class _DisputeScoreSheetState extends State<_DisputeScoreSheet> {
  bool _isSubmitting = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    for (final c in widget.teamAControllers) {
      c.addListener(_validate);
    }
    for (final c in widget.teamBControllers) {
      c.addListener(_validate);
    }
  }

  @override
  void dispose() {
    for (final c in widget.teamAControllers) {
      c.removeListener(_validate);
      c.dispose();
    }
    for (final c in widget.teamBControllers) {
      c.removeListener(_validate);
      c.dispose();
    }
    super.dispose();
  }

  void _validate() {
    bool ok = true;
    for (int i = 0; i < widget.teamAControllers.length; i++) {
      final a = widget.teamAControllers[i].text.trim();
      final b = i < widget.teamBControllers.length ? widget.teamBControllers[i].text.trim() : '';
      if (a.isEmpty || b.isEmpty) {
        ok = false;
        break;
      }
      final aa = int.tryParse(a) ?? 0;
      final bb = int.tryParse(b) ?? 0;
      if (aa == 0 && bb == 0) {
        ok = false;
        break;
      }
    }
    if (mounted && _isFormValid != ok) {
      setState(() => _isFormValid = ok);
    }
  }

  void _addSet() {
    setState(() {
      final ca = TextEditingController(text: '0');
      final cb = TextEditingController(text: '0');
      ca.addListener(_validate);
      cb.addListener(_validate);
      widget.teamAControllers.add(ca);
      widget.teamBControllers.add(cb);
    });
  }

  Future<void> _submit() async {
    final sets = <String>[];
    for (int i = 0; i < widget.teamAControllers.length; i++) {
      final a = int.tryParse(widget.teamAControllers[i].text.trim()) ?? 0;
      final b = int.tryParse(
        i < widget.teamBControllers.length ? widget.teamBControllers[i].text.trim() : '0',
      ) ?? 0;
      sets.add('$a-$b');
    }
    final score = sets.join(', ');

    setState(() => _isSubmitting = true);
    try {
      await ApiService.disputeHostScore(widget.matchId, score: score);
      if (!mounted) return;
      Navigator.of(context).pop();
      NotificationUtils.showSuccess(context, 'Ваш счёт отправлен');
      widget.onUpdated?.call();
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(
        context,
        e is ApiException ? e.message : 'Ошибка отправки счёта',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 11,
            bottom: 10 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Введите результаты матча',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF222223),
                              letterSpacing: -0.8,
                              height: 1.25,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Ваш вариант счёта будет отправлен',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF89867E),
                              letterSpacing: -0.32,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/images/close_button_bg.svg',
                                width: 30,
                                height: 30,
                              ),
                              SvgPicture.asset(
                                'assets/images/close_icon_x.svg',
                                width: 11,
                                height: 11,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              MatchScoreInput(
                teamAControllers: widget.teamAControllers,
                teamBControllers: widget.teamBControllers,
                participantsA: widget.participantsA,
                participantsB: widget.participantsB,
                duration: Duration.zero,
                isLocked: false,
                onAddSet: _addSet,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: (!_isFormValid || _isSubmitting) ? null : _submit,
                  style: TextButton.styleFrom(
                    backgroundColor: (_isFormValid && !_isSubmitting)
                        ? const Color(0xFF00897B)
                        : const Color(0xFF7F8AC0),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Отправить',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.32,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

