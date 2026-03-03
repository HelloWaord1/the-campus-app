import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import '../models/match.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../models/user.dart';
import '../utils/notification_utils.dart';
import 'public_profile_screen.dart';
import 'invite_users_screen.dart';
import '../widgets/custom_confirmation_dialog.dart';
import 'match_requests_screen.dart'; // Импортируем новый экран
import '../utils/logger.dart';
import '../utils/date_utils.dart' as date_utils;
import '../widgets/user_avatar.dart';
import '../models/club.dart';
import '../widgets/rate_players_modal.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/match_score_input.dart';
import '../widgets/score_confirmation_sheet.dart';
import '../widgets/score_input_modal_content.dart';
import 'courts/club_details_screen.dart';
import 'create_match_screen.dart';

class MatchDetailsScreen extends StatefulWidget {
  final String matchId;
  final bool isTournament; // флаг, что матч относится к турниру

  const MatchDetailsScreen({
    super.key,
    required this.matchId,
    this.isTournament = false,
  });

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  Match? _match;
  bool _isLoading = false;
  String? _error;
  bool _isActionLoading = false;
  User? _currentUser;
  Set<String> _invitedUserIds = {};
  Club? _club; // Для адреса клуба
  
  // Состояние для режима ввода счета
  bool _isMatchStarted = false;
  bool _isMatchFinished = false;
  Timer? _matchTimer;
  Duration _matchDuration = Duration.zero;
  String? _finalScore;
  bool _organizerCanEdit = false;
  
  // Счет для каждой команды (до 3 сетов)
  List<TextEditingController> _teamAControllers = [];
  List<TextEditingController> _teamBControllers = [];
  // Вспомогательный метод: заполнить контроллеры из строки счёта "6-4, 5-2"
  void _fillControllersFromScore(String draft) {
    final sets = draft.split(',');
    final needed = sets.length;
    if (needed <= 0) return;

    setState(() {
      // Расширяем контроллеры до нужного количества сетов
      while (_teamAControllers.length < needed) {
        final cA = TextEditingController(text: '0');
        final cB = TextEditingController(text: '0');
        cA.addListener(_onScoreChanged);
        cB.addListener(_onScoreChanged);
        _teamAControllers.add(cA);
        _teamBControllers.add(cB);
      }

      for (int i = 0; i < sets.length; i++) {
        final setStr = sets[i].trim();
        final parts = setStr.split(RegExp(r'[:\-]'));
        if (parts.length != 2) continue;
        final a = int.tryParse(parts[0].trim());
        final b = int.tryParse(parts[1].trim());
        if (a != null) _teamAControllers[i].text = a.toString();
        if (b != null) _teamBControllers[i].text = b.toString();
      }
    });
  }
  
  // Индекс для нижней навигации (-1 = ни один таб не активен, так как мы на отдельном экране)
  int _currentNavIndex = -1;
  
  // Флаг для отслеживания изменений в счёте
  bool _hasUnsavedChanges = false;
  
  // Таймер для автосохранения
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadMatchDetails();
    _initializeScoreControllers();
  }
  
  void _initializeScoreControllers() {
    // Инициализируем с 3 сетами
    for (int i = 0; i < 3; i++) {
      final controllerA = TextEditingController(text: '0');
      final controllerB = TextEditingController(text: '0');
      
      // Добавляем слушателей для отслеживания изменений
      controllerA.addListener(_onScoreChanged);
      controllerB.addListener(_onScoreChanged);
      
      _teamAControllers.add(controllerA);
      _teamBControllers.add(controllerB);
    }
  }
  
  void _onScoreChanged() {
    // Перезапускаем таймер автосохранения с минимальной задержкой для debounce
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 300), () {
      _saveDraftScore();
    });
  }
  
  Future<void> _saveDraftScore() async {
    if (_match == null || !_isMatchStarted) return;
    
    try {
      // Собираем счёт из контроллеров
      List<String> sets = [];
      
      for (int i = 0; i < _teamAControllers.length; i++) {
        final aText = _teamAControllers[i].text.trim();
        final bText = _teamBControllers[i].text.trim();
        
        // Если оба поля пустые - пропускаем
        if (aText.isEmpty && bText.isEmpty) continue;
        
        // Формируем строку сета в формате "A-B"
        final a = int.tryParse(aText) ?? 0;
        final b = int.tryParse(bText) ?? 0;
        sets.add('$a-$b');
      }
      
      // Если нет ни одного введённого значения - не отправляем
      if (sets.isEmpty) return;
      
      // Формируем строку счёта: "6-4, 5-2, 3-7"
      final draftScore = sets.join(', ');
      
      await ApiService.saveDraftScore(
        widget.matchId,
        draftScore: draftScore,
      );
      
      Logger.info('Черновик счёта сохранён: $draftScore');
    } catch (e) {
      Logger.error('Ошибка сохранения черновика счёта', e);
      // Не показываем ошибку пользователю, чтобы не мешать вводу
    }
  }
  
  @override
  void dispose() {
    _matchTimer?.cancel();
    _autoSaveTimer?.cancel();
    for (var controller in _teamAControllers) {
      controller.removeListener(_onScoreChanged);
      controller.dispose();
    }
    for (var controller in _teamBControllers) {
      controller.removeListener(_onScoreChanged);
      controller.dispose();
    }
    super.dispose();
  }

  void _loadCurrentUser() async {
    try {
      final user = await AuthStorage.getUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      // Ошибка получения текущего пользователя
    }
  }

  Future<void> _loadMatchDetails() async {
    Logger.info('Начинаем загрузку деталей матча. ID: ${widget.matchId}');
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final match = await ApiService.getMatchDetails(widget.matchId);

      // Синхронно пытаемся получить клуб (для адреса), чтобы избежать мигания города
      Club? club;
      if (match.clubId != null) {
        try {
          club = await ApiService.getClubById(match.clubId!);
        } catch (_) {
          club = null; // игнорируем ошибку
        }
      }

      Logger.success('Детали матча успешно загружены. ID: ${widget.matchId}');

      if (mounted) {
        setState(() {
          _match = match;
          _club = club;
          _isLoading = false;

          // Сбрасываем флаги
          _isMatchStarted = false;
          _isMatchFinished = (match.status.toLowerCase() == 'completed');

          // Если матч завершён — показываем фиксированную длительность (finished_at - started_at) и не запускаем таймер
          if (_isMatchFinished && match.startedAt != null) {
            _matchTimer?.cancel();
            _matchTimer = null;
            if (match.finishedAt != null) {
              _matchDuration = match.finishedAt!.difference(match.startedAt!).abs();
            } else {
              // Фоллбэк на заявленную длительность матча в минутах
              _matchDuration = Duration(minutes: match.duration);
            }
          } else if (match.startedAt != null) {
            // Матч начат, но не завершён — показываем таймер
            _isMatchStarted = true;
            final now = DateTime.now();
            _matchDuration = now.difference(match.startedAt!);
            _matchTimer?.cancel();
            _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (mounted) {
                setState(() {
                  _matchDuration = DateTime.now().difference(match.startedAt!);
                });
              }
            });

            // Подтягиваем ранее сохранённый draft_score и заполняем поля
            _prefillDraftScore();
          }
          // Обновляем флаг возможности редактирования организатором
          _refreshOrganizerCanEdit();
        });
      }

      // Если матч завершён и нет финального результата — подгружаем черновик host для отображения в инпуте
      if (mounted && _match != null && _match!.status.toLowerCase() == 'completed') {
        final hasFinalSets = ((_match!.teamASets?.isNotEmpty) ?? false) || ((_match!.teamBSets?.isNotEmpty) ?? false);
        if (!hasFinalSets) {
          try {
            final draft = await ApiService.getHostDraftScore(widget.matchId);
            if (draft != null && draft.trim().isNotEmpty) {
              setState(() {
                _fillControllersFromScore(draft);
              });
            }
          } catch (_) {
            // ignore
          }
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Ошибка при загрузке деталей матча. ID: ${widget.matchId}', e, stackTrace);
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshOrganizerCanEdit() async {
    if (!mounted || _match == null) return;
    final isOrganizer = _isCurrentUserOrganizer();
    final isCompleted = _match!.status.toLowerCase() == 'completed';
    if (!isOrganizer || !isCompleted) {
      setState(() { _organizerCanEdit = false; });
      return;
    }
    try {
      final res = await ApiService.organizerCanEdit(widget.matchId);
      final can = (res['can_edit'] == true);
      if (mounted) setState(() { _organizerCanEdit = can; });
    } catch (_) {
      if (mounted) setState(() { _organizerCanEdit = false; });
    }
  }

  void _openOrganizerEditModal() {
    if (_match == null) return;
    final isSingleFormat = _match!.format.toLowerCase() == 'single';
    final participantsA = isSingleFormat 
        ? [_getParticipantForTeamAndPosition('A', 0)]
        : [_getParticipantForTeamAndPosition('A', 0), _getParticipantForTeamAndPosition('A', 1)];
    final participantsB = isSingleFormat
        ? [_getParticipantForTeamAndPosition('B', 0)]
        : [_getParticipantForTeamAndPosition('B', 0), _getParticipantForTeamAndPosition('B', 1)];

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> onSubmit() async {
              // Сбор и валидация счёта
              final List<String> sets = [];
              for (int i = 0; i < _teamAControllers.length; i++) {
                final aText = _teamAControllers[i].text.trim();
                final bText = _teamBControllers[i].text.trim();
                if (aText.isEmpty && bText.isEmpty) continue;
                if (aText.isEmpty || bText.isEmpty) {
                  NotificationUtils.showError(context, 'Заполните оба значения для каждого сета');
                  return;
                }
                final a = int.tryParse(aText) ?? 0;
                final b = int.tryParse(bText) ?? 0;
                sets.add('$a-$b');
              }
              if (sets.isEmpty) {
                NotificationUtils.showError(context, 'Укажите хотя бы один сет');
                return;
              }
              final score = sets.join(', ');

              try {
                setModalState(() { isSubmitting = true; });
                await ApiService.organizerEditResult(widget.matchId, score: score);
                if (mounted) {
                  Navigator.of(context).pop();
                  NotificationUtils.showSuccess(context, 'Черновик обновлён');
                  await _loadMatchDetails();
                  await _refreshOrganizerCanEdit();
                }
              } on ApiException catch (e) {
                NotificationUtils.showError(context, e.message);
              } catch (e) {
                NotificationUtils.showError(context, 'Ошибка сохранения результата');
              } finally {
                setModalState(() { isSubmitting = false; });
              }
            }

            return ScoreInputModalContent(
              teamAControllers: _teamAControllers,
              teamBControllers: _teamBControllers,
              participantsA: participantsA,
              participantsB: participantsB,
              duration: _matchDuration,
              isLocked: false,
              onAddSet: _addSet,
              onSubmit: onSubmit,
              isFormValid: true,
              isSubmitting: isSubmitting,
              titleText: 'Изменить результаты матча',
              subtitleText: 'Результаты можно изменить один раз. После подтверждения значение станет окончательным',
              submitButtonText: 'Сохранить',
              onClose: () => Navigator.of(context).pop(),
            );
          },
        );
      },
    );
  }

  Future<void> _prefillDraftScore() async {
    try {
      final draft = await ApiService.getMyDraftScore(widget.matchId);
      if (draft == null || draft.trim().isEmpty) return;
      _fillControllersFromScore(draft);
      Logger.info('Черновик счёта загружен и применён: $draft');
    } catch (e) {
      // Тихо игнорируем, чтобы не мешать UX
      Logger.error('Не удалось загрузить черновик счёта', e);
    }
  }

  bool _isCurrentUserParticipant() {
    if (_currentUser == null || _match == null) return false;
    
    return _match!.participants.any((participant) => 
      participant.userId == _currentUser!.id
    );
  }

  bool _isCurrentUserOrganizer() {
    if (_currentUser == null || _match == null) return false;
    return _match!.organizerId == _currentUser!.id;
  }

  bool _shouldShowRatePlayersCard() {
    if (_match == null || _currentUser == null) return false;
    if (widget.isTournament || (_match?.isTournament == true)) return false;
    
    final statusLower = _match!.status.toLowerCase();
    final isParticipant = _isCurrentUserParticipant();
    
    return statusLower == 'completed' && isParticipant;
  }
  
  bool _hasFinalResult() {
    if (_match == null) return false;
    final statusLower = _match!.status.toLowerCase();
    final hasSets = ((_match!.teamASets?.isNotEmpty) ?? false) || ((_match!.teamBSets?.isNotEmpty) ?? false);
    final hasWinner = (_match!.winnerTeam != null) || (_match!.winnerUserId != null);
    return statusLower == 'completed' && (hasSets || hasWinner);
  }
  
  void _startMatch() async {
    setState(() => _isActionLoading = true);
    
    try {
      // Вызываем API для начала матча
      await ApiService.startMatch(widget.matchId);

      // Гарантированно обновляем детали и запускаем таймер через единый путь
      if (mounted) {
        _matchTimer?.cancel();
        NotificationUtils.showSuccess(context, 'Матч начат');
        await _loadMatchDetails();
        if (mounted) setState(() => _isActionLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        
        String errorMessage = 'Ошибка при начале матча';
        if (e is ApiException) {
          errorMessage = e.message;
        }
        
        NotificationUtils.showError(context, errorMessage);
      }
    }
  }
  
  Future<void> _finishMatch() async {
    // По текущим правилам результат может фиксировать только хост (организатор)
    if (!_isCurrentUserOrganizer()) {
      NotificationUtils.showError(context, 'Только организатор матча может выставить результат');
      return;
    }

    // Собираем счет из контроллеров
    List<String> sets = [];
    List<int> teamAScores = [];
    List<int> teamBScores = [];
    
    for (int i = 0; i < _teamAControllers.length; i++) {
      final aText = _teamAControllers[i].text.trim();
      final bText = _teamBControllers[i].text.trim();
      
      if (aText.isEmpty && bText.isEmpty) continue;
      
      if (aText.isEmpty || bText.isEmpty) {
        NotificationUtils.showError(context, 'Заполните оба значения для каждого сета');
        return;
      }
      
      final a = int.tryParse(aText) ?? 0;
      final b = int.tryParse(bText) ?? 0;
      
      teamAScores.add(a);
      teamBScores.add(b);
      sets.add('$a-$b');
    }
    
    if (sets.isEmpty) {
      NotificationUtils.showError(context, 'Укажите хотя бы один сет');
      return;
    }
    
    // Определяем победителя
    int winsA = 0, winsB = 0;
    for (int i = 0; i < teamAScores.length; i++) {
      if (teamAScores[i] > teamBScores[i]) winsA++;
      else if (teamBScores[i] > teamAScores[i]) winsB++;
    }
    
    if (winsA == winsB) {
      NotificationUtils.showError(context, 'Нельзя завершить матч с ничьей. Укажите победителя по сетам');
      return;
    }
    
    // Останавливаем таймер
    _matchTimer?.cancel();
    
    setState(() => _isActionLoading = true);
    
    // Формируем строку счёта: "6-4, 5-2, 3-7"
    final score = sets.join(', ');
    
    try {
      // Только организатор (host) фиксирует финальный результат
      final response = await ApiService.finishMatchAsHost(
        widget.matchId,
        score: score,
      );

      if (mounted) {
        setState(() {
          _isMatchFinished = true;
          _finalScore = score;
          _isActionLoading = false;
        });

        NotificationUtils.showSuccess(context, 'Результат матча зафиксирован');

        // Перезагружаем детали матча
        await _loadMatchDetails();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionLoading = false);
        
        String errorMessage = 'Ошибка при завершении матча';
        if (e is ApiException) {
          errorMessage = e.message;
        }
        
        NotificationUtils.showError(context, errorMessage);
      }
    }
  }
  
  void _editMatch() {
    // Перезапускаем таймер
    // _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    //   setState(() {
    //     _matchDuration += const Duration(seconds: 1);
    //   });
    // });
    
    // Возвращаемся в режим редактирования
    setState(() {
      _isMatchFinished = false;
    });
  }
  
  Future<void> _submitMatchResult(String score, String winnerTeamId) async {
    setState(() => _isActionLoading = true);
    
    try {
      String? winnerUserId;
      if (_match!.format.toLowerCase() == 'single') {
        final winner = _match!.participants.firstWhere(
          (p) => p.teamId == winnerTeamId,
          orElse: () => _match!.participants.first,
        );
        winnerUserId = winner.userId;
      }
      
      final updated = await ApiService.finishMatch(
        widget.matchId,
        score: score,
        winnerTeamId: _match!.format.toLowerCase() == 'double' ? winnerTeamId : null,
        winnerUserId: _match!.format.toLowerCase() == 'single' ? winnerUserId : null,
        matchDuration: _matchDuration.inMinutes,
        isDraw: false,
        notes: null,
      );
      
      if (mounted) {
        NotificationUtils.showSuccess(context, 'Матч завершен');
        setState(() {
          _match = updated;
          _isMatchStarted = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        NotificationUtils.showError(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(context, 'Ошибка завершения матча');
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _joinMatch({String? teamId}) async {
    if (_match == null) return;

    // Проверяем, не участвует ли пользователь уже в матче
    if (_isCurrentUserParticipant()) {
      if (mounted) {
        NotificationUtils.showError(context, 'Вы уже участвуете в этом матче');
      }
      return;
    }

    setState(() {
      _isActionLoading = true;
    });

    try {
      await ApiService.joinMatch(widget.matchId, teamId: teamId);
      
      if (mounted) {
        NotificationUtils.showSuccess(context, 'Вы присоединились к матчу!');
      }
      
      await _loadMatchDetails();
      
    } catch (e) {
      String errorMessage = 'Ошибка при присоединении к матчу';
      
      if (e is ApiException) {
        switch (e.statusCode) {
          case 400:
            // Проверяем, содержит ли сообщение об ошибке информацию об участии
            if (e.message.toLowerCase().contains('уже') || 
                e.message.toLowerCase().contains('already') ||
                e.message.toLowerCase().contains('участвует') ||
                e.message.toLowerCase().contains('участник')) {
              errorMessage = 'Вы уже участвуете в этом матче';
            } else {
              errorMessage = e.message.isNotEmpty ? e.message : 'Невозможно присоединиться к матчу';
            }
            break;
          case 401:
            errorMessage = 'Необходимо войти в систему';
            break;
          case 404:
            errorMessage = 'Матч не найден';
            break;
          case 500:
            errorMessage = 'Ошибка сервера. Попробуйте позже или обратитесь к администратору';
            break;
          default:
            errorMessage = e.message.isNotEmpty ? e.message : 'Ошибка при присоединении к матчу';
        }
      }
      
      if (mounted) {
        NotificationUtils.showError(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _leaveMatch() async {
    if (_match == null) return;

    final shouldLeave = await showCustomConfirmationDialog(
      context: context,
      title: 'Выйти из матча',
      content: 'Вы уверены, что хотите покинуть этот матч?',
      confirmButtonText: 'Выйти',
    );

    if (shouldLeave != true) return;

    setState(() {
      _isActionLoading = true;
    });

    try {
      await ApiService.leaveMatch(widget.matchId);
      
      if (mounted) {
        NotificationUtils.showSuccess(context, 'Вы покинули матч');
      }
      
      await _loadMatchDetails();
      
    } catch (e) {
      String errorMessage = 'Ошибка при выходе из матча';
      
      if (e is ApiException) {
        switch (e.statusCode) {
          case 400:
            errorMessage = 'Невозможно покинуть матч';
            break;
          case 401:
            errorMessage = 'Необходимо войти в систему';
            break;
          case 404:
            errorMessage = 'Матч не найден';
            break;
          default:
            errorMessage = e.message;
        }
      }
      
      if (mounted) {
        NotificationUtils.showError(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _sendMatchRequest(String team) async {
    if (_match == null) return;

    setState(() {
      _isActionLoading = true;
    });

    try {
      // Для одиночных матчей команда не указывается
      if (_match!.format.toLowerCase() == 'single') {
        await ApiService.createMatchRequest(
          widget.matchId,
          message: 'Привет! Хочу присоединиться к вашему матчу.',
        );
      } else {
        final preferredTeamId = team == 'А' ? 'A' : 'B';
        await ApiService.createMatchRequest(
          widget.matchId,
          message: 'Привет! Хочу присоединиться к вашему матчу.',
          preferredTeamId: preferredTeamId,
        );
      }
      
      if (mounted) {
        NotificationUtils.showSuccess(context, 'Заявка на участие отправлена!');
      }
      
    } catch (e) {
      String errorMessage = 'Ошибка при отправке заявки';
      
      if (e is ApiException) {
        switch (e.statusCode) {
          case 400:
            errorMessage = 'Нельзя отправить заявку на этот матч';
            break;
          case 401:
            errorMessage = 'Необходимо войти в систему';
            break;
          case 404:
            errorMessage = 'Матч не найден';
            break;
          case 409:
            errorMessage = 'Заявка уже отправлена';
            break;
          default:
            errorMessage = e.message;
        }
      }
      
      if (mounted) {
        NotificationUtils.showError(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _inviteUsers() async {
    if (_match == null) return;
    
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InviteUsersScreen(
        matchId: widget.matchId,
        invitedUserIds: _invitedUserIds,
      ),
    );
    
    if (result != null) {
      setState(() {
        _invitedUserIds.addAll(result['invitedUserIds'] ?? <String>[]);
      });
    }
  }

  Future<void> _shareMatch() async {
    final matchUrl = 'https://the-campus.app/match/${widget.matchId}';
    
    try {
      await Clipboard.setData(ClipboardData(text: matchUrl));
      
      if (mounted) {
        NotificationUtils.showSuccess(
          context, 
          'Ссылка на матч скопирована в буфер обмена',
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(
          context, 
          'Ошибка при копировании ссылки',
        );
      }
    }
  }

  bool _canEditMatchSettings() {
    if (_match == null) return false;
    if (!_isCurrentUserOrganizer()) return false;
    // Редактирование доступно только до начала матча
    return _match!.startedAt == null && _match!.status.toLowerCase() == 'active';
  }

  Future<void> _openEditMatchScreen() async {
    if (!_canEditMatchSettings()) return;
    if (_match == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateMatchScreen(
          initialClub: _club,
          initialMatch: _match,
        ),
      ),
    );
  }

  Future<void> _openRatePlayersModal() async {
    if (_match == null || _currentUser == null) return;
    
    // Проверяем, может ли пользователь оценивать участников
    if (!_match!.canRatePlayers) {
      if (mounted) {
        NotificationUtils.showError(
          context, 
          'Оценка недоступна. Возможные причины: вы уже оценили участников, прошло более 24 часов с момента окончания матча, или это турнирный матч.'
        );
      }
      return;
    }
    
    // Получаем список участников для оценки (все кроме текущего пользователя)
    final participantsToRate = _match!.participants
        .where((p) => p.userId != _currentUser!.id)
        .toList();
    
    if (participantsToRate.isEmpty) {
      if (mounted) {
        NotificationUtils.showError(context, 'Нет игроков для оценки');
      }
      return;
    }
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.665,
        minChildSize: 0.5,
        maxChildSize: 0.665,
        builder: (context, scrollController) => RatePlayersModal(
          participantsToRate: participantsToRate,
          onSubmit: _submitPlayerRatings,
        ),
      ),
    );
  }

  Future<void> _submitPlayerRatings(List<Map<String, dynamic>> reviews) async {
    setState(() => _isActionLoading = true);
    
    try {
      await ApiService.reviewPlayers(widget.matchId, reviews);
      
      if (mounted) {
        NotificationUtils.showSuccess(
          context, 
          'Спасибо за оценку! Ваше мнение учтено.',
        );
      }
      
      // Перезагружаем детали матча
      await _loadMatchDetails();
    } catch (e) {
      String errorMessage = 'Ошибка при отправке оценок';
      
      if (e is ApiException) {
        errorMessage = e.message.isNotEmpty ? e.message : errorMessage;
      }
      
      if (mounted) {
        NotificationUtils.showError(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  // Удалены неиспользуемые вспомогательные методы

  MatchParticipant? _getParticipantForTeamAndPosition(String team, int position) {
    if (_match == null) return null;
    final String normalizedTeam = team.toUpperCase(); // ожидаем 'A' или 'B'

    // 1) Сначала берем участников с явным teamId
    final List<MatchParticipant> withExplicitTeam = _match!.participants
        .where((p) => (p.teamId != null && p.teamId!.toUpperCase() == normalizedTeam))
        .toList();

    if (position < withExplicitTeam.length) {
      return withExplicitTeam[position];
    }

    // Специальная логика для одиночного формата 1v1:
    // Если у одного игрока есть команда (A или B), а у второго teamId == null,
    // то второму присваиваем противоположную команду, чтобы корректно отрисовать слоты.
    final bool isSingleFormat = _match!.format.toLowerCase() == 'single';
    if (isSingleFormat && position == 0) {
      final List<MatchParticipant> teamAExplicit = _match!.participants
          .where((p) => p.teamId != null && p.teamId!.toUpperCase() == 'A')
          .toList();
      final List<MatchParticipant> teamBExplicit = _match!.participants
          .where((p) => p.teamId != null && p.teamId!.toUpperCase() == 'B')
          .toList();
      final List<MatchParticipant> withoutTeamAll = _match!.participants
          .where((p) => p.teamId == null)
          .toList();

      // Если, например, есть участник с B, а для A пусто — отдаем безкомандного для A (и наоборот)
      if (withoutTeamAll.isNotEmpty) {
        if (normalizedTeam == 'A' && teamAExplicit.isEmpty && teamBExplicit.isNotEmpty) {
          return withoutTeamAll.first;
        }
        if (normalizedTeam == 'B' && teamBExplicit.isEmpty && teamAExplicit.isNotEmpty) {
          return withoutTeamAll.first;
        }
      }
    }

    // 2) Fallback: участники без teamId — распределяем детерминированно по индексу
    final List<MatchParticipant> withoutTeam = _match!.participants
        .where((p) => p.teamId == null)
        .toList();

    final List<MatchParticipant> inferredForTeam = withoutTeam.where((p) {
      final idx = _match!.participants.indexOf(p);
      final inferred = (idx % 2 == 0) ? 'A' : 'B';
      return inferred == normalizedTeam;
    }).toList();

    final int fallbackIndex = position - withExplicitTeam.length;
    if (fallbackIndex >= 0 && fallbackIndex < inferredForTeam.length) {
      return inferredForTeam[fallbackIndex];
    }

    return null;
  }

  Widget _buildMatchInfoCard() {
    if (_match == null) return const SizedBox.shrink();

    // Форматирование времени начала и конца (локальное время)
    final localDateTime = _match!.dateTime.toLocal();
    final startTime = TimeOfDay.fromDateTime(localDateTime);
    final endTime = TimeOfDay.fromDateTime(localDateTime.add(Duration(minutes: _match!.duration)));
    final timeRange = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}-${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    
    // Форматирование даты
    const weekdays = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    const months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    final weekday = weekdays[localDateTime.weekday - 1];
    final day = localDateTime.day;
    final month = months[localDateTime.month - 1];
    final dateText = '$weekday, $day $month, $timeRange';

    return Container(
      width: MediaQuery.of(context).size.width * 0.96,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00897B), width: 2),
      ),
      child: Builder(
        builder: (context) {
          // Проверяем, осталось ли меньше часа до матча
          final now = DateTime.now();
          final matchStart = _match!.dateTime.toLocal();
          final oneHourBeforeMatch = matchStart.subtract(const Duration(hours: 1));
          final bool isLessThanOneHourBefore = now.isAfter(oneHourBeforeMatch) || now.isAtSameMomentAs(oneHourBeforeMatch);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/tennis_ball_icon.svg',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      dateText,
                      style: const TextStyle(fontFamily: 'SF Pro Display', fontSize: 18, fontWeight: FontWeight.w400, color: Color(0xFF222223), letterSpacing: -1.2),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              if (!isLessThanOneHourBefore) ...[
                const SizedBox(height: 10),
                _buildBookingStatus(),
              ],
            ],
          );
        },
      ),
    );
  }

  // Возвращает участника по команде/позиции — одиночный формат использует ту же логику

  Widget _buildBookingStatus() {
    if (_match == null) return const SizedBox.shrink();

    if (_match!.isBooked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF00897B), size: 24),
          const SizedBox(width: 6),
          const Text(
            'Корт забронирован',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              color: Color(0xFF00897B),
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.32,
            ),
          ),
          const SizedBox(width: 6),
          Container(height: 14, width: 1, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            '${_match!.price?.toStringAsFixed(0) ?? '0'} ₽',
            style: const TextStyle(
              fontFamily: 'SF Pro Display',
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 6),
          Text(
            'Корт не забронирован',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              color: Color(0xFF79766E),
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.32,
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00897B)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Детали матча',
            style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Ошибка загрузки', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMatchDetails,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_match == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Матч не найден')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40.0),
            child: Column(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 287,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Stack(
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage('assets/images/match_details.png'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            // Затемнение фона для лучшей читаемости
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withOpacity(0.25),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 95,
                        child: SizedBox(
                          height: 105,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgPicture.asset(
                                  'assets/images/match_header_logo_new.svg',
                                  height: 105,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Builder(
                    builder: (context) {
                      // Проверяем, осталось ли меньше часа до матча
                      final now = DateTime.now();
                      final matchStart = _match!.dateTime.toLocal();
                      final oneHourBeforeMatch = matchStart.subtract(const Duration(hours: 1));
                      final bool isLessThanOneHourBefore = now.isAfter(oneHourBeforeMatch) || now.isAtSameMomentAs(oneHourBeforeMatch);
                      
                      // Если меньше часа до матча, смещаем блок меньше (чтобы он был ниже)
                      final double matchCardOffset = isLessThanOneHourBefore ? -30 : -50;
                      
                      return Column(
                        children: [
                          Transform.translate(
                            offset: Offset(0, matchCardOffset),
                            child: _buildMatchInfoCard(),
                          ),
                          const SizedBox(height: 16),
                          Transform.translate(
                            offset: const Offset(0, -20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Проверяем, нужно ли показывать таймер/счет
                                if (((_isMatchStarted && !_hasFinalResult() && _isCurrentUserOrganizer())
                                  || (_match?.status.toLowerCase() == 'completed' && !_hasFinalResult() && _isCurrentUserOrganizer()))
                                  && _match?.status.toLowerCase() != 'cancelled' 
                                  && _match?.status.toLowerCase() != 'canceled') ...[
                                  const SizedBox(height: 0),
                                  _buildMatchScoreInput()
                                ]
                                else ...[
                                  // Показываем надпись "Участники" когда НЕ показываем таймер
                                  const Text(
                                    'Участники',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontWeight: FontWeight.w400,
                                      fontSize: 16,
                                      letterSpacing: -0.52,
                                      color: Color(0xFF79766E),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Показываем список участников
                                  if (_match!.format.toLowerCase() == 'single')
                              InkWell(
                                onTap: _shouldShowRatePlayersCard() ? _openRatePlayersModal : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      height: 152,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 26),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  _buildParticipantSlot(
                                                    _getParticipantForTeamAndPosition('A', 0),
                                                    'А',
                                                    _getParticipantForTeamAndPosition('A', 0) == null,
                                                  ),
                                                ],
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
                                                children: [
                                                  _buildParticipantSlot(
                                                    _getParticipantForTeamAndPosition('B', 0),
                                                    'Б',
                                                    _getParticipantForTeamAndPosition('B', 0) == null,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Буквы А и Б внизу карточки для одиночных матчей
                                    const Positioned(
                                      left: 12,
                                      bottom: 8,
                                      child: Text(
                                        'А',
                                        style: TextStyle(
                                          fontFamily: 'Basis Grotesque Arabic Pro',
                                          fontWeight: FontWeight.w500,
                                          fontSize: 24,
                                          height: 1.0,
                                          letterSpacing: -0.32,
                                          color: Color(0xFF00897B),
                                        ),
                                      ),
                                    ),
                                    const Positioned(
                                      right: 12,
                                      bottom: 8,
                                      child: Text(
                                        'Б',
                                        style: TextStyle(
                                          fontFamily: 'Basis Grotesque Arabic Pro',
                                          fontWeight: FontWeight.w500,
                                          fontSize: 24,
                                          height: 1.0,
                                          letterSpacing: -0.32,
                                          color: Color(0xFF00897B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
              LayoutBuilder(
                builder: (context, constraints) {
                  // Доступная ширина для обеих команд внутри контейнера:
                  // минус горизонтальные паддинги (24), минус отступы вокруг разделителя (24), минус сам разделитель (1)
                  final double teamWidth = (constraints.maxWidth - 50) / 2; // даём +1px запас
                  final double slotWidth = [
                    80.0,
                    ((teamWidth - 13) / 2).clamp(60.0, 80.0), // -1px запас внутри команды
                  ].reduce((a, b) => a < b ? a : b);

                  return InkWell(
                    onTap: _shouldShowRatePlayersCard() ? _openRatePlayersModal : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 152,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 16, 12, 26),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _buildParticipantSlot(
                                          _getParticipantForTeamAndPosition('A', 0),
                                          'А',
                                          _getParticipantForTeamAndPosition('A', 0) == null,
                                          slotWidth: slotWidth,
                                        ),
                                        const SizedBox(width: 12),
                                        _buildParticipantSlot(
                                          _getParticipantForTeamAndPosition('A', 1),
                                          'А',
                                          _getParticipantForTeamAndPosition('A', 1) == null,
                                          slotWidth: slotWidth,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(width: 1, height: 79, color: const Color(0xFFECECEC)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _buildParticipantSlot(
                                          _getParticipantForTeamAndPosition('B', 0),
                                          'Б',
                                          _getParticipantForTeamAndPosition('B', 0) == null,
                                          slotWidth: slotWidth,
                                        ),
                                        const SizedBox(width: 12),
                                        _buildParticipantSlot(
                                          _getParticipantForTeamAndPosition('B', 1),
                                          'Б',
                                          _getParticipantForTeamAndPosition('B', 1) == null,
                                          slotWidth: slotWidth,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          bottom: 8,
                          child: const Text(
                            'А',
                            style: TextStyle(
                              fontFamily: 'Basis Grotesque Arabic Pro',
                              fontWeight: FontWeight.w500,
                              fontSize: 24,
                              height: 1.0,
                              letterSpacing: -0.32,
                              color: Color(0xFF00897B),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 8,
                          child: const Text(
                            'Б',
                            style: TextStyle(
                              fontFamily: 'Basis Grotesque Arabic Pro',
                              fontWeight: FontWeight.w500,
                              fontSize: 24,
                              height: 1.0,
                              letterSpacing: -0.32,
                              color: Color(0xFF00897B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
                                ],
                                // Плашка для отмененного матча
                                if (_match!.status.toLowerCase() == 'cancelled' || _match!.status.toLowerCase() == 'canceled')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16.0),
                                    child: _buildCancelledMatchBanner(),
                                  ),
                                if (!(widget.isTournament || (_match?.isTournament == true)) && _isCurrentUserOrganizer() && _match!.isPrivate)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16.0),
                                    child: _buildMatchRequestsButton(),
                                  ),
                              ],
                            ),
                          ),
      Transform.translate(
        offset: const Offset(0, -23),
        child: _buildMatchDetailsSection(),
      ),
      const SizedBox(height: 0),

      _buildActionButton(), // Добавляем новую кнопку
                ],
              );
            },
          ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            top: MediaQuery.of(context).padding.top,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/images/back_icon.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_canEditMatchSettings()) ...[
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openEditMatchScreen,
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/edit_match_button.png',
                        width: 40,
                        height: 40,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _shareMatch();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/images/share_logo.svg',
                          width: 18,
                          height: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isActionLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.1),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00897B)),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        onTabTapped: (index) {
          // Навигация по табам
          switch (index) {
            case 0: // Главная
              Navigator.of(context).popUntil((route) => route.isFirst);
              break;
            case 1: // Комьюнити
              // Возвращаемся на главный экран и переключаемся на таб Комьюнити
              Navigator.of(context).popUntil((route) => route.isFirst);
              break;
            case 2: // Уведомления
              // Возвращаемся на главный экран и переключаемся на таб Уведомления
              Navigator.of(context).popUntil((route) => route.isFirst);
              break;
            case 3: // Профиль
              // Возвращаемся на главный экран и переключаемся на таб Профиль
              Navigator.of(context).popUntil((route) => route.isFirst);
              break;
          }
        },
      ),
    );
  }

  Widget _buildActionButton() {
    if (_match == null || _currentUser == null) return const SizedBox.shrink();

    // Для турнирных матчей скрываем любые действия (по параметру экрана или по данным с сервера)
    if (widget.isTournament || (_match?.isTournament == true)) {
      return const SizedBox.shrink();
    }

    final isOrganizer = _isCurrentUserOrganizer();
    final isParticipant = _isCurrentUserParticipant();

    // Если матч отменён – не показываем кнопку (плашка отображается под участниками)
    final statusLower = _match!.status.toLowerCase();
    if (statusLower == 'cancelled' || statusLower == 'canceled') {
      return const SizedBox.shrink();
    }

    // Если матч завершён и пользователь - участник, не показываем кнопку (оценка через карточку)
    if (statusLower == 'completed' && isParticipant) {
      return const SizedBox.shrink();
    }

    // Проверяем, осталось ли меньше часа до начала матча
    final now = DateTime.now();
    final matchStart = _match!.dateTime.toLocal();
    
    final oneHourBeforeMatch = matchStart.subtract(const Duration(hours: 1));
    final bool isLessThanOneHourBefore = now.isAfter(oneHourBeforeMatch) || now.isAtSameMomentAs(oneHourBeforeMatch);

    // Если меньше часа до начала или матч уже начался (но не завершен)
    // Показываем кнопку "Начать матч" ТОЛЬКО организатору
    if (isLessThanOneHourBefore && statusLower != 'completed' && isOrganizer) {
      // Если матч уже начат (started_at != null) или завершен, кнопка не нужна
      if (_match!.startedAt != null || _isMatchStarted || _isMatchFinished) {
        return const SizedBox.shrink();
      }
      
      // Показываем зеленую кнопку "Начать матч"
      return _buildGreenButton(
        text: 'Начать матч',
        onPressed: () {
          _startMatch();
        },
      );
    }

    if (isOrganizer) {
      // Если организатор, но не меньше часа до начала - показываем кнопку удаления
      if (!isLessThanOneHourBefore || statusLower == 'completed') {
        final List<Widget> children = [];
        children.add(
          _buildRedButton(
            text: 'Удалить матч',
            onPressed: () async {
              final shouldDelete = await showCustomConfirmationDialog(
                context: context,
                title: 'Удалить матч',
                content: 'Вы уверены, что хотите удалить этот матч? Это действие необратимо.',
                confirmButtonText: 'Удалить',
              );

              if (shouldDelete == true) {
                try {
                  setState(() => _isActionLoading = true);
                  await ApiService.deleteMatch(widget.matchId);
                  if (mounted) {
                    Navigator.of(context).pop();
                    NotificationUtils.showSuccess(context, 'Матч успешно удален');
                  }
                } on ApiException catch (e) {
                  if (mounted) NotificationUtils.showError(context, e.message);
                } catch (e) {
                  if (mounted) NotificationUtils.showError(context, 'Ошибка удаления матча');
                } finally {
                  if (mounted) setState(() => _isActionLoading = false);
                }
              }
            },
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      }
    } else if (isParticipant) {
      // Кнопка для участника (если не меньше часа до начала)
      if (!isLessThanOneHourBefore) {
        return _buildRedButton(
          text: 'Выйти из матча',
          onPressed: _leaveMatch,
        );
      }
    }

    return const SizedBox.shrink(); // Не показывать кнопку для остальных
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

  Widget _buildGreenButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFF00897B),
          padding: const EdgeInsets.symmetric(vertical: 14.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.32,
          ),
        ),
      ),
    );
  }

  Widget _buildDisabledStatusButton({required String text}) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: null,
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFF7F7F7),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF89867E),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showFinishMatchSheet() {
    if (_match == null) return;
    final TextEditingController a1 = TextEditingController();
    final TextEditingController b1 = TextEditingController();
    final TextEditingController a2 = TextEditingController();
    final TextEditingController b2 = TextEditingController();
    final TextEditingController a3 = TextEditingController();
    final TextEditingController b3 = TextEditingController();

    final FocusNode fa1 = FocusNode(debugLabel: 'fa1');
    final FocusNode fb1 = FocusNode(debugLabel: 'fb1');
    final FocusNode fa2 = FocusNode(debugLabel: 'fa2');
    final FocusNode fb2 = FocusNode(debugLabel: 'fb2');
    final FocusNode fa3 = FocusNode(debugLabel: 'fa3');
    final FocusNode fb3 = FocusNode(debugLabel: 'fb3');

    void _next(FocusNode node) {
      // Сначала снимаем фокус, затем переводим на нужное поле после кадра
      final scope = FocusScope.of(context);
      scope.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        node.requestFocus();
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isSubmitting = false;
        String? errorText;

        Future<void> submit() async {
          FocusScope.of(context).unfocus();
          List<int> sa = [];
          List<int> sb = [];

          List<(TextEditingController, TextEditingController)> pairs = [
            (a1, b1),
            (a2, b2),
            (a3, b3),
          ];

          for (final pair in pairs) {
            final sA = pair.$1.text.trim();
            final sB = pair.$2.text.trim();
            if (sA.isEmpty && sB.isEmpty) {
              continue;
            }
            if (sA.isEmpty || sB.isEmpty) {
              errorText = 'Заполните оба значения для каждого сета';
              NotificationUtils.showError(context, 'Заполните оба значения для каждого сета');
              // ignore: invalid_use_of_protected_member
              (context as Element).markNeedsBuild();
              return;
            }
            sa.add(int.tryParse(sA) ?? 0);
            sb.add(int.tryParse(sB) ?? 0);
          }

          if (sa.isEmpty || sb.isEmpty) {
            errorText = 'Укажите хотя бы один сет';
            NotificationUtils.showError(context, 'Укажите хотя бы один сет');
            // ignore: invalid_use_of_protected_member
            (context as Element).markNeedsBuild();
            return;
          }

          int winsA = 0, winsB = 0;
          for (int i = 0; i < sa.length; i++) {
            if (sa[i] > sb[i]) winsA++; else if (sb[i] > sa[i]) winsB++;
          }
          if (winsA == winsB) {
            errorText = 'Нельзя завершить матч с ничьей. Укажите победителя по сетам';
            NotificationUtils.showError(context, 'Нельзя завершить матч с ничьей. Укажите победителя по сетам');
            // ignore: invalid_use_of_protected_member
            (context as Element).markNeedsBuild();
            return;
          }

          final winnerTeamId = winsA > winsB ? 'A' : 'B';

          String? winnerUserId;
          if ((_match!.format).toLowerCase() == 'single') {
            final String targetTeam = winnerTeamId;
            final winner = _match!.participants.firstWhere(
              (p) => (p.teamId == targetTeam),
              orElse: () => _match!.participants.first,
            );
            winnerUserId = winner.userId;
          }

          final score = List.generate(sa.length, (i) => '${sa[i]}-${sb[i]}').join(',');

          try {
            isSubmitting = true;
            // ignore: invalid_use_of_protected_member
            (context as Element).markNeedsBuild();

            final updated = await ApiService.finishMatch(
              widget.matchId,
              score: score,
              winnerTeamId: (_match!.format).toLowerCase() == 'double' ? winnerTeamId : null,
              winnerUserId: (_match!.format).toLowerCase() == 'single' ? winnerUserId : null,
              matchDuration: _match!.duration,
              isDraw: false,
              notes: null,
            );

            if (mounted) {
              Navigator.of(context).pop();
              NotificationUtils.showSuccess(context, 'Матч завершен');
              setState(() {
                _match = updated;
              });
            }
          } on ApiException catch (e) {
            errorText = e.message;
            NotificationUtils.showError(context, e.message);
            isSubmitting = false;
            // ignore: invalid_use_of_protected_member
            (context as Element).markNeedsBuild();
          } catch (e) {
            errorText = 'Ошибка завершения матча';
            NotificationUtils.showError(context, 'Ошибка завершения матча');
            isSubmitting = false;
            // ignore: invalid_use_of_protected_member
            (context as Element).markNeedsBuild();
          }
        }

        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            builder: (_, controller) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Завершить матч',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Укажите счет по сетам (до 3-х сетов)',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6E6B65)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      child: Column(
                        children: [
                          Row(
                            children: const [
                              SizedBox(width: 32),
                              Expanded(child: Center(child: Text('Сет-1'))),
                              Expanded(child: Center(child: Text('Сет-2'))),
                              Expanded(child: Center(child: Text('Сет-3'))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(width: 32, child: Text('А', style: TextStyle(fontSize: 16))),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: TextField(
                                    controller: a1,
                                    focusNode: fa1,
                                    autofocus: true,
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(2),
                                    ],
                                    onChanged: (v) {
                                      if (v.length >= 2 || (v.length == 1 && v != '1')) _next(fb1);
                                    },
                                    onSubmitted: (_) => _next(fb1),
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      counterText: '',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: TextField(
                                    controller: a2,
                                    focusNode: fa2,
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(2),
                                    ],
                                    onChanged: (v) {
                                      if (v.length >= 2 || (v.length == 1 && v != '1')) _next(fb2);
                                    },
                                    onSubmitted: (_) => _next(fb2),
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      counterText: '',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: TextField(
                                    controller: a3,
                                    focusNode: fa3,
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(2),
                                    ],
                                    onChanged: (v) {
                                      if (v.length >= 2 || (v.length == 1 && v != '1')) _next(fb3);
                                    },
                                    onSubmitted: (_) => _next(fb3),
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      counterText: '',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(width: 32, child: Text('Б', style: TextStyle(fontSize: 16))),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: TextField(
                                    controller: b1,
                                    focusNode: fb1,
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(2),
                                    ],
                                    onChanged: (v) {
                                      if (v.length >= 2 || (v.length == 1 && v != '1')) _next(fa2);
                                    },
                                    onSubmitted: (_) => _next(fa2),
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      counterText: '',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: TextField(
                                    controller: b2,
                                    focusNode: fb2,
                                    textInputAction: TextInputAction.next,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(2),
                                    ],
                                    onChanged: (v) {
                                      if (v.length >= 2 || (v.length == 1 && v != '1')) _next(fa3);
                                    },
                                    onSubmitted: (_) => _next(fa3),
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      counterText: '',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: TextField(
                                    controller: b3,
                                    focusNode: fb3,
                                    textInputAction: TextInputAction.done,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(2),
                                    ],
                                    onChanged: (v) {
                                      if (v.length >= 2 || (v.length == 1 && v != '1')) FocusScope.of(context).unfocus();
                                    },
                                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      counterText: '',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: isSubmitting ? null : submit,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text(
                                'Сохранить результат',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),);
        },
      );
    }

  Widget _buildMatchDetailsSection() {
    if (_match == null) return const SizedBox.shrink();

    // Debug prints for match status and sets
    // Показываем статус матча и очки по сетам для команд A и B
    Logger.info('[MatchDetails] status: ${_match!.status}');
    Logger.info('[MatchDetails] teamASets: ${_match!.teamASets}');
    Logger.info('[MatchDetails] teamBSets: ${_match!.teamBSets}');

    return Container(
      width: double.infinity, // Растягиваем на всю ширину
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Добавляем вертикальные отступы
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_match!.status.toLowerCase() == 'completed' &&
              (((_match!.teamASets?.isNotEmpty) ?? false) || ((_match!.teamBSets?.isNotEmpty) ?? false))) 
            _buildResultSection(),
          const SizedBox(height: 10,),
          _buildDetailItem(
            'Клуб', 
            _match!.clubName ?? 'Не указан',
            subtitle: (() {
              final String? city = _match!.clubCity?.trim().isNotEmpty == true
                  ? _match!.clubCity!.trim()
                  : (_club?.city?.trim().isNotEmpty == true ? _club!.city!.trim() : null);
              final String? address = _club?.address.trim().isNotEmpty == true ? _club!.address.trim() : null;
              if (city != null && address != null) return '$city, $address';
              if (address != null) return address;
              return city ?? '';
            })(),
            onTap: () async {
              // Если клуб уже загружен, сразу открываем его страницу
              if (_club != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ClubDetailsScreen(club: _club!),
                  ),
                );
                return;
              }

              // Иначе пытаемся загрузить клуб по его ID из матча
              final clubId = _match!.clubId;
              if (clubId == null) {
                NotificationUtils.showError(context, 'Информация о клубе недоступна');
                return;
              }

              try {
                final club = await ApiService.getClubById(clubId);
                if (!mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ClubDetailsScreen(club: club),
                  ),
                );
              } catch (_) {
                if (!mounted) return;
                NotificationUtils.showError(context, 'Не удалось загрузить информацию о клубе');
              }
            },
          ),
          const SizedBox(height: 8),

          if (_match!.isBooked) ...[
            _buildDetailItem(
              'Номер корта',
              (() {
                final int? n = _match!.courtNumber ?? int.tryParse(_match!.courtName ?? '');
                if (n != null) return '$n';
                if (_match!.courtName != null && _match!.courtName!.isNotEmpty) return _match!.courtName!;
                return 'Не указан';
              })(),
            ),
            const SizedBox(height: 8),
            _buildDetailItem('На чье имя забронирован', _match!.bookedByName ?? _match!.organizerName),
            const SizedBox(height: 8),
          ],
          
          _buildDetailItem('Матч', _match!.isPrivate ? 'Приватный' : 'Публичный'),
          const SizedBox(height: 7),

          _buildDetailItem(
            'Тип матча',
            (() {
              final mt = (_match!.matchType ?? '').toLowerCase().trim();
              final isTournamentMatch = widget.isTournament || (_match?.isTournament == true) || mt == 'competitive';
              return isTournamentMatch ? 'Турнир' : 'Дружеский';
            })(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String title, String value, {String? subtitle, VoidCallback? onTap}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF79766E),
            letterSpacing: -0.48,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF222223),
            letterSpacing: -0.36,
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 0),
            child: Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF222223),
                letterSpacing: -0.28,
              ),
            ),
          ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: content,
      ),
    );
  }

  Widget _buildResultSection() {
    final List<int> a = _match!.teamASets ?? const [];
    final List<int> b = _match!.teamBSets ?? const [];
    final int setsCount = a.length > b.length ? a.length : b.length;

    // Определяем победителя по количеству выигранных сетов
    int winsA = 0, winsB = 0;
    for (int i = 0; i < setsCount; i++) {
      final int va = i < a.length ? a[i] : 0;
      final int vb = i < b.length ? b[i] : 0;
      if (va > vb) winsA++; else if (vb > va) winsB++;
    }
    final String? winnerTeam = winsA > winsB ? 'A' : (winsB > winsA ? 'B' : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Результат',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF79766E),
            letterSpacing: -0.48,
          ),
        ),
      const SizedBox(height: 8),
      // Подписи сетов вне таблицы (сверху), с тем же распределением колонок
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Table(
          columnWidths: {
            0: const FixedColumnWidth(48),
            1: const FixedColumnWidth(48),
            for (int i = 0; i < setsCount; i++) i + 2: const FlexColumnWidth(),
          },
          children: [
            TableRow(
              children: [
                const SizedBox.shrink(), // Пустая ячейка для команды
                const SizedBox.shrink(), // Пустая ячейка для кубка
                for (int i = 0; i < setsCount; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Center(
                      child: Text(
                        'Сет-${i + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 14,
                          color: Color(0xFF79766E),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Table(
              border: const TableBorder(
                horizontalInside: BorderSide(color: Color(0xFFECECEC), width: 1),
              ),
              columnWidths: {
                0: const FixedColumnWidth(48),
                1: const FixedColumnWidth(48),
                for (int i = 0; i < setsCount; i++) i + 2: const FlexColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                // Team A row
                TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    child: Text(
                      'А',
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 24,
                        color: Color(0xFF222223),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    child: Center(
                      child: winnerTeam == 'A'
                          ? Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00897B),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  'assets/images/cup.svg',
                                  width: 24,
                                  height: 24,
                                  // colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                ),
                              ),
                            )
                          : const SizedBox(width: 32, height: 32),
                    ),
                  ),
                for (int i = 0; i < setsCount; i++)
                  Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 16,
                        bottom: 0,
                        child: Container(width: 1, color: const Color(0xFFECECEC)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            '${i < a.length ? a[i] : 0}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 32,
                              color: Color(0xFF222223),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),

                // Team B row
                TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    child: Text(
                      'Б',
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 24,
                        color: Color(0xFF222223),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    child: Center(
                      child: winnerTeam == 'B'
                          ? Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00897B),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  'assets/images/cup.svg',
                                  width: 24,
                                  height: 24,
                                  // colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                ),
                              ),
                            )
                          : const SizedBox(width: 32, height: 32),
                    ),
                  ),
                for (int i = 0; i < setsCount; i++)
                  Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 16,
                        child: Container(width: 1, color: const Color(0xFFECECEC)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            '${i < b.length ? b[i] : 0}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 32,
                              color: Color(0xFF222223),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCancelledMatchBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Результат',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w400,
            fontSize: 16,
            letterSpacing: -0.52,
            color: Color(0xFF79766E),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 34),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/match_cancelled_icon.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF89867E),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Матч аннулирован',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF89867E),
                  letterSpacing: -1,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchRequestsButton() {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.8,  // 80% экрана изначально
            minChildSize: 0.3,      // Минимум 30% экрана
            maxChildSize: 0.9,      // Максимум 90% экрана
            builder: (context, scrollController) => MatchRequestsScreen(matchId: widget.matchId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(8),
          // border: Border.all(color: const Color(0xFFD9D9D9)),

        ),
        child: const Row(
          children: [
            Icon(Icons.people_outline, color: Color(0xFF79766E)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Заявки на матч',
                style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: -0.48),
              ),
            ),
            Icon(Icons.chevron_right, color: Color(0xFF79766E)),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchScoreInput() {
    if (_match == null) return const SizedBox.shrink();
    
    // Для одиночных матчей показываем по одному участнику
    final isSingleFormat = _match!.format.toLowerCase() == 'single';
    
    final participantsA = isSingleFormat 
        ? [_getParticipantForTeamAndPosition('A', 0)]
        : [_getParticipantForTeamAndPosition('A', 0), _getParticipantForTeamAndPosition('A', 1)];
    
    final participantsB = isSingleFormat
        ? [_getParticipantForTeamAndPosition('B', 0)]
        : [_getParticipantForTeamAndPosition('B', 0), _getParticipantForTeamAndPosition('B', 1)];
    
    return MatchScoreInput(
      teamAControllers: _teamAControllers,
      teamBControllers: _teamBControllers,
      participantsA: participantsA,
      participantsB: participantsB,
      duration: _matchDuration,
      isLocked: _isMatchFinished || (_match?.status.toLowerCase() == 'completed'),
      onAddSet: _addSet,
      bottomAction: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        child: SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _isMatchFinished
                ? (_organizerCanEdit ? _openOrganizerEditModal : null)
                : (_isCurrentUserOrganizer() ? _finishMatch : null),
            style: TextButton.styleFrom(
              backgroundColor: _isMatchFinished
                  ? const Color(0xFFF7F7F7)
                  : const Color(0xFFFF6B6B),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide.none,
              ),
            ),
            child: Text(
              _isMatchFinished ? 'Результат зафиксирован' : 'Завершить матч',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                color: _isMatchFinished ? const Color(0xFF222223) : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.32,
              ),
            ),
          ),
        ),
      ),
    );
    
  }
  
  void _addSet() {
    setState(() {
      final controllerA = TextEditingController(text: '0');
      final controllerB = TextEditingController(text: '0');
      
      controllerA.addListener(_onScoreChanged);
      controllerB.addListener(_onScoreChanged);
      
      _teamAControllers.add(controllerA);
      _teamBControllers.add(controllerB);
    });
  }

  // Модальное окно подтверждения счёта от host
  void _showConfirmScoreModal() {
    if (_match == null) return;
    
    final isSingleFormat = _match!.format.toLowerCase() == 'single';
    
    final participantsA = isSingleFormat 
        ? [_getParticipantForTeamAndPosition('A', 0)]
        : [_getParticipantForTeamAndPosition('A', 0), _getParticipantForTeamAndPosition('A', 1)];
    
    final participantsB = isSingleFormat
        ? [_getParticipantForTeamAndPosition('B', 0)]
        : [_getParticipantForTeamAndPosition('B', 0), _getParticipantForTeamAndPosition('B', 1)];
    
    showMatchResultConfirmationSheet(
      context: context,
      matchId: widget.matchId,
      participantsA: participantsA,
      participantsB: participantsB,
      hostTeamASets: _match!.teamASets,
      hostTeamBSets: _match!.teamBSets,
      onUpdated: _loadMatchDetails,
    );
  }

  Widget _buildParticipantSlot(MatchParticipant? participant, String team, bool isAddSlot, {double slotWidth = 80}) {
    if (isAddSlot) {
      // Для турнирных матчей показываем неактивное состояние "Ожидание"
      if (widget.isTournament) {
        return Container(
          width: slotWidth,
          child: Column(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFF7F7F7), width: 2),
                  ),
                  child: Center(
                    child: SvgPicture.asset('assets/images/waiting.svg', width: 24, height: 24),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ожидание',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  height: 1.286,
                  letterSpacing: -0.28,
                  color: Color(0xFF89867E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              SizedBox(width: slotWidth, height: 10),
            ],
          ),
        );
      }
      return GestureDetector(
        onTap: () {
          if (_isCurrentUserOrganizer()) {
            _inviteUsers();
          } else {
            // Для приватных матчей отправляем заявку, для публичных - присоединяемся напрямую
            if (_match!.isPrivate) {
              _sendMatchRequest(team);
            } else {
              // Для одиночных матчей teamId не передаем
              if (_match!.format.toLowerCase() == 'single') {
                _joinMatch();
              } else {
                final teamId = team == 'А' ? 'A' : 'B';
                _joinMatch(teamId: teamId);
              }
            }
          }
        },
        child: Container(
          width: slotWidth, // адаптируемая ширина
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(0xFF00897B), width: 1),
                  color: Colors.white,
                ),
                child: Icon(
                  Icons.add,
                  color: Color(0xFF00897B),
                  size: 24,
                ),
              ),
              SizedBox(height: 6), // Точно по Figma
              Text(
                'Добавить',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  height: 1.286,
                  letterSpacing: -0.28,
                  color: Color(0xFF00897B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              // Добавляем пустой контейнер рейтинга для выравнивания с участниками
              Container(
                width: slotWidth,
                height: 10,
                // Пустой контейнер для выравнивания
              ),
            ],
          ),
        ),
      );
    }

    if (participant == null) {
      return Container(
        width: slotWidth, // адаптируемая ширина
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF7F7F7),
              ),
              child: Center(
                child: Text(
                  'АС',
                  style: TextStyle(
                    fontFamily: 'Basis Grotesque Arabic Pro',
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    height: 1.286,
                    letterSpacing: -0.28,
                    color: Color(0xFF7F8AC0),
                  ),
                ),
              ),
            ),
            SizedBox(height: 6), // Точно по Figma
            Text(
              'Алексей',
              style: TextStyle(
                fontFamily: 'Basis Grotesque Arabic Pro',
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.1,
                letterSpacing: -0.28,
                color: Color(0xFF222223),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            // Рейтинг пользователя - точно по Figma (убираем дополнительный SizedBox)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'D 2.5',
                style: TextStyle(
                  fontFamily: 'Basis Grotesque Arabic Pro',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  height: 1.1,
                  letterSpacing: -0.28,
                  color: Color(0xFF00897B),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    final isCurrentUser = _currentUser != null && participant.userId == _currentUser!.id;

    // Получаем только первое слово из имени, или "(Вы)" для текущего пользователя
    String displayName = isCurrentUser ? '(Вы)' : participant.name.split(' ').first;

    return GestureDetector(
      onTap: () {
        if (isCurrentUser) {
          _leaveMatch();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PublicProfileScreen(
                userId: participant.userId,
              ),
            ),
          );
        }
      },
      child: Container(
        width: slotWidth, // адаптируемая ширина
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  // Убрана рамка для организатора
                  color: Colors.transparent, 
                  width: 0,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.zero, // Отступ для рамки убран
                child: UserAvatar(
                  imageUrl: participant.avatarUrl,
                  userName: participant.name,
                  isDeleted: participant.isDeleted,
                  radius: 24,
                ),
              ),
            ),
            const SizedBox(height: 6), // Точно по Figma
            Text(
              displayName, // Показываем "(Вы)" или первое слово
              style: const TextStyle(
                fontFamily: 'Basis Grotesque Arabic Pro',
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.1,
                letterSpacing: -0.28,
                color: Color(0xFF222223),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            // Рейтинг пользователя - точно по Figma (убираем дополнительный SizedBox)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                participant.formattedRating,
                style: const TextStyle(
                  fontFamily: 'Basis Grotesque Arabic Pro',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  height: 1.1,
                  letterSpacing: -0.28,
                  color: Color(0xFF00897B),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

