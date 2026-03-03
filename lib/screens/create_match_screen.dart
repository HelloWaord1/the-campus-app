import 'package:flutter/material.dart';
import '../models/match.dart';
import '../models/user.dart';
import '../models/club.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../utils/notification_utils.dart';
import 'invite_users_screen.dart';
import 'club_selection_screen.dart';
import 'match_details_screen.dart';
import '../widgets/custom_date_picker_sheet.dart';
import '../widgets/custom_time_picker_sheet.dart';
import '../widgets/user_avatar.dart';
import '../utils/app_defaults.dart';
import '../utils/rating_utils.dart';

class CreateMatchScreen extends StatefulWidget {
  final Club? initialClub;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final Match? initialMatch; // если задан — экран работает в режиме редактирования
  const CreateMatchScreen({
    super.key,
    this.initialClub,
    this.initialDate,
    this.initialTime,
    this.initialMatch,
  });

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  bool _isDoubles = true;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _duration = 90;

  Club? _selectedClub;
  User? _currentUser;
  String? _currentUserRatingLabel;
  bool _isCourtBooked = false;
  final _courtNumberController = TextEditingController();
  final _bookedByNameController = TextEditingController();
  final _costPerPlayerController = TextEditingController();
  bool _isPrivate = false;
  String _matchType = 'турнир';
  bool _isLoading = false;
  List<Map<String, dynamic>> _invitedUsers = [];
  bool get _isEditMode => widget.initialMatch != null;
  bool get _canChangeFormatInEdit {
    final m = widget.initialMatch;
    if (m == null) return true;
    final organizerId = m.organizerId;
    // Разрешаем менять формат только если нет участников кроме организатора
    return !m.participants.any((p) {
      final st = (p.status ?? '').toLowerCase();
      return p.userId != organizerId && (st == 'joined' || st == 'pending');
    });
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    // Проставляем клуб, если передан из вызывающего экрана
    _selectedClub = widget.initialClub;
    // Проставляем дату и время, если переданы
    _selectedDate = widget.initialDate ?? _selectedDate;
    _selectedTime = widget.initialTime ?? _selectedTime;

    // Режим редактирования: префилл полей из матча
    final m = widget.initialMatch;
    if (m != null) {
      _isDoubles = (m.format.toLowerCase() == 'double');
      // На бэке дата/время чаще всего хранится/приходит в UTC.
      // В редакторе показываем локальное время клиента (как и в остальных местах приложения).
      final localDt = m.dateTime.toLocal();
      _selectedDate = DateTime(localDt.year, localDt.month, localDt.day);
      _selectedTime = TimeOfDay(hour: localDt.hour, minute: localDt.minute);
      _duration = m.duration;
      _isPrivate = m.isPrivate;
      _isCourtBooked = m.isBooked;
      if (_isCourtBooked) {
        if (m.courtNumber != null) _courtNumberController.text = '${m.courtNumber}';
        if (m.bookedByName != null) _bookedByNameController.text = m.bookedByName!;
        if (m.price != null) _costPerPlayerController.text = m.price!.toStringAsFixed(0);
      }
      // matchType: competitive -> "турнир", friendly -> "дружеский"
      final mt = (m.matchType ?? 'friendly').toLowerCase();
      _matchType = (mt == 'competitive') ? 'турнир' : 'дружеский';

      // Показываем уже добавленных участников матча (кроме организатора).
      // Экран использует _invitedUsers для отображения слотов, поэтому в режиме редактирования
      // префиллим её реальными участниками.
      final organizerId = m.organizerId;
      final others = m.participants.where((p) {
        final st = (p.status ?? '').toLowerCase();
        return p.userId != organizerId && (st == 'joined' || st == 'pending');
      }).toList();

      // В UI CreateMatchScreen слоты фиксированы:
      // - слева команда A: [организатор, invitedUsers[0]]
      // - справа команда B: [invitedUsers[1], invitedUsers[2]]
      // Поэтому при редактировании раскладываем участников по teamId.
      final List<MatchParticipant> teamA = [];
      final List<MatchParticipant> teamB = [];
      final List<MatchParticipant> noTeam = [];
      for (final p in others) {
        final t = (p.teamId ?? '').toUpperCase().trim();
        if (t == 'A') {
          teamA.add(p);
        } else if (t == 'B') {
          teamB.add(p);
        } else {
          noTeam.add(p);
        }
      }

      List<MatchParticipant> ordered;
      if (_isDoubles) {
        // Парный: сначала напарник A, затем два соперника B
        ordered = [
          ...teamA.take(1),
          ...teamB.take(2),
          ...noTeam, // запасной fallback, если teamId не проставлены
          ...teamA.skip(1),
          ...teamB.skip(2),
        ];
      } else {
        // Дуэль: предпочитаем соперника из B, иначе первого попавшегося
        ordered = [
          ...teamB.take(1),
          ...teamA.take(1),
          ...noTeam,
        ];
      }

      final int limit = _isDoubles ? 3 : 1;
      _invitedUsers = ordered.take(limit).map((p) => {
            'id': p.userId,
            'name': p.name,
            'avatar_url': p.avatarUrl,
            'user_rating': p.userRating,
            'status': p.status,
            'team_id': p.teamId,
          }).toList(growable: true);
    }
  }

  void _loadCurrentUser() async {
    try {
      final user = await AuthStorage.getUser();
      if (mounted && user != null) {
        setState(() {
          _currentUser = user;
          _currentUserRatingLabel = _formatRatingLabelFromUnknown(user.currentRating);
        });
      }
    } catch (e) {
      // Handle user loading error
    }
    try {
      final rating = await ApiService.getCurrentUserRating();
      if (!mounted) return;
      if (rating != null) {
        String? formatted;
        if (rating.rating != null) {
          formatted = _formatRatingLabelFromNumeric(rating.rating!);
        } else if (rating.ntrpLevel != null && rating.ntrpLevel!.trim().isNotEmpty) {
          // Фоллбэк: иногда бэкенд отдает строку уровня — пытаемся извлечь число и отформатировать единообразно
          formatted = _formatRatingLabelFromUnknown(rating.ntrpLevel);
        }
        if (formatted != null && formatted.isNotEmpty) {
          setState(() => _currentUserRatingLabel = formatted);
        }
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _courtNumberController.dispose();
    _bookedByNameController.dispose();
    _costPerPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00897B)),
          onPressed: () => Navigator.of(context).pop(),
            ),
        title: Text(
          _isEditMode ? 'Редактирование матча' : 'Создание матча',
          style: TextStyle(
            color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
            ),
          ),
        centerTitle: true,
      ),
      body: Stack( // Используем Stack для наложения кнопки
            children: [
          SingleChildScrollView(
            // Добавляем отступ снизу, равный высоте кнопки + отступы
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMatchTypeSwitcher(),
                const SizedBox(height: 24),
                _buildParticipantsSection(),
                const SizedBox(height: 24),
                _buildClubSection(),
                const SizedBox(height: 24),
                _buildCourtBookedSwitch(),
                if (_isCourtBooked) ...[
                  const SizedBox(height: 24),
                  _buildBookingDetailsFields(),
                ],
                const SizedBox(height: 24),
                _buildDateTimeSection(),
                const SizedBox(height: 24),
                _buildPrivacySection(),
                const SizedBox(height: 24),
                _buildMatchTypeSection(),
              ],
                ),
          ),
          // Позиционируем кнопку внизу
          Positioned(
            left: 16,
            right: 16,
            bottom: 32, // Отступ от нижнего края
            child: _buildCreateButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchTypeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(10),
              ),
      child: Row(
        children: [
          Expanded(child: _buildSwitcherButton('Дуэль', false)),
          Expanded(child: _buildSwitcherButton('Парный', true)),
        ],
      ),
    );
  }

  Widget _buildSwitcherButton(String text, bool isDoublesButton) {
    final bool isSelected = (isDoublesButton && _isDoubles) || (!isDoublesButton && !_isDoubles);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (_isEditMode && !_canChangeFormatInEdit) {
            NotificationUtils.showError(
              context,
              'Нельзя изменить формат матча (дуэль/парный), если в матче уже есть участники',
            );
            return;
          }
          if (_isDoubles != isDoublesButton) {
            setState(() {
              _isDoubles = isDoublesButton;
              _invitedUsers.clear();
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: isSelected
              ? BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEFEEEC), width: 0.5),
                  boxShadow: const [
                    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.04), blurRadius: 1),
                    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.04), blurRadius: 8, offset: Offset(0, 4)),
                    BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.04), blurRadius: 16, offset: Offset(0, 12)),
                  ],
                )
              : null,
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w400 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  

  // _getWeekday больше не используется

  

  Widget _buildParticipantsSection() {
    // Формируем список виджетов слотов: первый — текущий пользователь, далее приглашённые/плейсхолдеры
    final List<Widget> slots = <Widget>[_buildCurrentUserAvatar()];

    if (_isDoubles) {
      for (int i = 0; i < 3; i++) {
        if (_invitedUsers.length > i) {
          slots.add(_buildInvitedUserAvatar(_invitedUsers[i]));
        } else {
          slots.add(_buildAddParticipantButton());
        }
      }
    } else {
      if (_invitedUsers.isNotEmpty) {
        slots.add(_buildInvitedUserAvatar(_invitedUsers.first));
      } else {
        slots.add(_buildAddParticipantButton());
      }
    }

    // Готовим дочерние элементы строки с вертикальным разделителем между командами/игроками
    final List<Widget> rowChildren = <Widget>[];
    if (_isDoubles) {
      rowChildren.addAll([
        Expanded(child: Center(child: slots[0])),
        const SizedBox(width: 12),
        Expanded(child: Center(child: slots[1])),
        const SizedBox(width: 12),
        Container(width: 1, height: 79, color: const Color(0xFFECECEC)),
        const SizedBox(width: 12),
        Expanded(child: Center(child: slots[2])),
        const SizedBox(width: 12),
        Expanded(child: Center(child: slots[3])),
      ]);
    } else {
      rowChildren.addAll([
        Expanded(child: Center(child: slots[0])),
        const SizedBox(width: 12),
        Container(width: 1, height: 79, color: const Color(0xFFECECEC)),
        const SizedBox(width: 12),
        Expanded(child: Center(child: slots[1])),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Участники', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFF79766E))),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: 130,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD9D9D9)),
          ),
          child: Row(children: rowChildren),
        ),
      ],
    );
  }

  Widget _buildClubSection() {
    return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
        const Text('Клуб', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFF79766E))),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _selectClub,
          child: Container(
            width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFD9D9D9)),
                                ),
                                child: _selectedClub != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _selectedClub!.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF222223)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_selectedClub!.city != null && _selectedClub!.city!.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                _selectedClub!.city!,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF89867E)),
                                                  ),
                            ],
                                                ],
                                              ),
                                            ),
                      const SizedBox(width: 8),
                                            const Text(
                                              'Изменить',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF00897B)),
                                            ),
                                          ],
                                      )
                                    : Row(
                    children: const [
                      Icon(Icons.add, color: Color(0xFF00897B)),
                      SizedBox(width: 12),
                      Text(
                        'Выбрать клуб',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF00897B)),
                                          ),
                                        ],
                                      ),
                              ),
        ),
                            ],
    );
  }

  Widget _buildCourtBookedSwitch() {
    return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
        const Text('Корт забронирован', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isCourtBooked = !_isCourtBooked;
                                            if (!_isCourtBooked) {
                                              _courtNumberController.clear();
                                              _bookedByNameController.clear();
                                              _costPerPlayerController.clear();
                                            }
                                          });
                                        },
                                        child: Container(
                                          width: 51,
                                          height: 31,
                                          decoration: BoxDecoration(
              color: _isCourtBooked ? const Color(0xFF00897B) : const Color(0xFFE0E0E0),
                                            borderRadius: BorderRadius.circular(15.5),
                                          ),
                                          child: AnimatedAlign(
                                            alignment: _isCourtBooked ? Alignment.centerRight : Alignment.centerLeft,
                                            duration: const Duration(milliseconds: 200),
                                            child: Container(
                                              margin: const EdgeInsets.all(2),
                                              width: 27,
                                              height: 27,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Color.fromRGBO(0, 0, 0, 0.06),
                                                    offset: Offset(0, 3),
                                                    blurRadius: 1,
                                                  ),
                                                  BoxShadow(
                                                    color: Color.fromRGBO(0, 0, 0, 0.15),
                                                    offset: Offset(0, 3),
                                                    blurRadius: 8,
                                                  ),
                                                ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
    );
  }

  Widget _buildBookingDetailsFields() {
    return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
        _buildTextField(
            label: 'Номер корта*',
            hint: 'Введите номер',
            controller: _courtNumberController),
        const SizedBox(height: 24),
        _buildTextField(
            label: 'На чье имя забронирован*',
            hint: 'Введите имя',
            controller: _bookedByNameController),
        const SizedBox(height: 24),
        _buildTextField(
            label: 'Стоимость на каждого игрока*',
            hint: '₽',
            controller: _costPerPlayerController,
            keyboardType: TextInputType.number),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
              color: Color(0xFF79766E)),
                                    ),
                                    const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
              color: Color(0xFF222223)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF79766E)),
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      ),
                                    ),
                                  ],
    );
  }

  Widget _buildDateTimeSection() {
    String dateText = _selectedDate != null
        ? "${_selectedDate!.day.toString().padLeft(2, '0')}.${_selectedDate!.month.toString().padLeft(2, '0')}.${_selectedDate!.year}"
        : "Выбрать дату начала";

    String timeText =
        _selectedTime != null ? _selectedTime!.format(context) : "Выбрать время начала";

    return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
          "Дата",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
              color: Color(0xFF79766E)),
                                    ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7F7F7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                Text(
                  dateText,
                                            style: TextStyle(
                                              fontSize: 16,
                                          fontWeight: FontWeight.w400,
                      color: _selectedDate != null
                          ? const Color(0xFF222223)
                          : const Color(0xFF79766E)),
                                            ),
                const Icon(Icons.chevron_right, color: Color(0xFF79766E)),
                                        ],
                                      ),
                                    ),
                                ),
                          const SizedBox(height: 24),
                              const Text(
          "Время начала",
                                style: TextStyle(
              fontSize: 14,
                                  fontWeight: FontWeight.w400,
              color: Color(0xFF79766E)),
                              ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _selectTime(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
                                ),
                                  child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                Text(
                  timeText,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                    color: _selectedTime != null
                        ? const Color(0xFF222223)
                        : const Color(0xFF79766E)),
                                ),
                const Icon(Icons.chevron_right, color: Color(0xFF79766E)),
                                        ],
                                      ),
                                        ),
                                      ),
                                    ],
    );
  }

  String _getMonthName(int month) {
    const months = ['янв.', 'февр.', 'марта', 'апр.', 'мая', 'июня', 'июля', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];
    return months[month - 1];
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomDatePickerSheet(initialDate: _selectedDate),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomTimePickerSheet(
        initialTime: _selectedTime,
        initialDuration: _duration,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedTime = result['time'] as TimeOfDay;
        _duration = result['duration'] as int;
      });
    }
  }

  Widget _buildPrivacySection() {
    return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
        const Text('Матч', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFF79766E))),
        const SizedBox(height: 6),
        _buildOptionTile(
          title: 'Публичный',
          subtitle: 'Виден всем',
          isSelected: !_isPrivate,
                                  onTap: () => setState(() => _isPrivate = false),
                              ),
                              const SizedBox(height: 12),
        _buildOptionTile(
          title: 'Приватный',
          subtitle: 'По приглашениям',
          isSelected: _isPrivate,
          onTap: () => setState(() {
            _isPrivate = true;
            // Для приватных матчей автоматически выбираем дружеский тип
            _matchType = 'дружеский';
          }),
        ),
      ],
    );
  }

  Widget _buildMatchTypeSection() {
    return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
        const Text('Выберите тип матча', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFF79766E))),
        const SizedBox(height: 6),
        _buildOptionTile(
          title: 'Турнир',
          subtitle: 'Влияет на статистику',
          isSelected: _matchType == 'турнир',
          onTap: () => setState(() => _matchType = 'турнир'),
          isEnabled: !_isPrivate,
                              ),
                              const SizedBox(height: 12),
        _buildOptionTile(
          title: 'Дружеский',
          subtitle: 'Не влияет на статистику',
          isSelected: _matchType == 'дружеский',
          onTap: () => setState(() => _matchType = 'дружеский'),
          isEnabled: true,
                                      ),
                                    ],
    );
  }
  
  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
            color: !isEnabled
                ? const Color(0xFFD9D9D9)
                : (isSelected ? const Color(0xFF00897B) : const Color(0xFFD9D9D9)),
            width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                  child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isEnabled ? const Color(0xFF222223) : const Color(0xFFBDBDBD),
              ),
                                      ),
                                      const SizedBox(width: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isEnabled ? const Color(0xFF79766E) : const Color(0xFFBDBDBD),
              ),
                                      ),
                                    ],
                                  ),
                                ),
    );
  }

  Widget _buildCreateButton() {
    // Убираем внешний контейнер с белым фоном
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitMatch,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00897B),
          disabledBackgroundColor: const Color(0xFF7F8AC0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const SizedBox(
                                              width: 24,
                                              height: 24,
                child: CircularProgressIndicator(color: Colors.white))
            : Text(_isEditMode ? 'Сохранить' : 'Создать матч',
                                              style: TextStyle(
                    color: Colors.white,
                                                fontSize: 16,
                    fontWeight: FontWeight.w500)),
      ),
    );
  }

  // Helper methods for participants
  Widget _buildCurrentUserAvatar() {
    if (_currentUser == null) return const SizedBox.shrink();
    return Column(
                                          children: [
        UserAvatar(
          imageUrl: _currentUser!.avatarUrl, 
          userName: _currentUser!.name,
                                      ),
        const SizedBox(height: 6),
        Text(
          _currentUser!.name.split(' ').first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF222223),
            fontFamily: 'Basis Grotesque Arabic Pro',
            letterSpacing: -0.28,
          ),
        ),
        if (_currentUserRatingLabel != null && _currentUserRatingLabel!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            _currentUserRatingLabel!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF00897B),
              fontFamily: 'Basis Grotesque Arabic Pro',
              letterSpacing: -0.28,
            ),
          ),
        ],
                                          ],
    );
  }
  
  Widget _buildInvitedUserAvatar(Map<String, dynamic> userData) {
    final name = userData['name'] as String;
    final avatarUrl = userData['avatar_url'] as String?;
    final userId = userData['id'] as String;
    final String? invitedUserRating = _extractInvitedUserRating(userData);
  
    return Column(
                                          children: [
        Stack(
          clipBehavior: Clip.none,
                                    children: [
            UserAvatar(
              imageUrl: avatarUrl, 
              userName: name,
            ),
            Positioned(
              top: -4,
              right: -4,
                                child: GestureDetector(
                onTap: () => _removeInvitedUser(userId),
                child: const CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Icon(Icons.close, size: 12, color: Colors.white),
                ),
                                              ),
                                            ),
                                          ],
                                        ),
        const SizedBox(height: 6),
        Text(
          name.split(' ').first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF222223),
            fontFamily: 'Basis Grotesque Arabic Pro',
            letterSpacing: -0.28,
          ),
        ),
        if (invitedUserRating != null && invitedUserRating.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            invitedUserRating,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF00897B),
              fontFamily: 'Basis Grotesque Arabic Pro',
              letterSpacing: -0.28,
            ),
          ),
        ],
                        ],
    );
  }

  String? _extractInvitedUserRating(Map<String, dynamic> userData) {
    // Используем ту же логику форматирования, что и на экране деталей матча:
    // score/int (ELO) -> calculateRating + ratingToLetter; numeric (1-5) -> ratingToLetter напрямую.
    final dynamic raw = userData['user_rating'] ??
        userData['current_rating'] ??
        userData['rating'] ??
        userData['elo'] ??
        userData['ntrp_level'] ??
        userData['currentRating'];
    return _formatRatingLabelFromUnknown(raw);
  }

  String _formatRatingLabelFromScore(int score) {
    final r = calculateRating(score);
    final letter = ratingToLetter(r);
    return '$letter ${r.toStringAsFixed(2)}';
  }

  String _formatRatingLabelFromNumeric(double rating) {
    // Если приходит ELO/score (обычно 700-2000) — конвертируем через calculateRating().
    if (rating >= 100) {
      return _formatRatingLabelFromScore(rating.toInt());
    }
    // Иначе предполагаем, что это уже нормализованный рейтинг 1.0-5.0.
    final letter = ratingToLetter(rating);
    return '$letter ${rating.toStringAsFixed(2)}';
  }

  String? _formatRatingLabelFromUnknown(dynamic raw) {
    if (raw == null) return null;

    if (raw is int) return _formatRatingLabelFromScore(raw);
    if (raw is num) return _formatRatingLabelFromNumeric(raw.toDouble());

    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return null;

      // Пытаемся извлечь число из строк вида "D 2.5", "2.5", "1200", "1200.0"
      final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(s);
      if (m == null) {
        // Если число не нашли — возвращаем как есть, чтобы не потерять данные
        return s;
      }
      final parsed = double.tryParse(m.group(1)!.replaceAll(',', '.'));
      if (parsed == null) return s;
      return _formatRatingLabelFromNumeric(parsed);
    }

    return null;
  }
  
  Widget _buildAddParticipantButton() {
    return GestureDetector(
      onTap: _inviteUsers,
              child: Column(
                                          children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
                                                      child: Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00897B), width: 1.5),
                                              ),
              child: const Center(child: Icon(Icons.add, color: Color(0xFF00897B))),
            ),
                                            ),
          const SizedBox(height: 6),
          const Text('Добавить', style: TextStyle(color: Color(0xFF00897B))),
        ],
      ),
    );
  }

  // Logic methods
  Future<void> _inviteUsers() async {
    final maxParticipants = _isDoubles ? 4 : 2;
    final maxInvitations = maxParticipants - 1;
    if (_invitedUsers.length >= maxInvitations) {
      NotificationUtils.showError(context, 'Достигнуто максимальное количество участников');
      return;
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InviteUsersScreen(
        matchId: 'create',
        invitedUserIds: _invitedUsers.map((u) => u['id'] as String).toSet(),
                                  ),
    );

    if (result != null) {
      final newInvitedUsersData = result['invitedUsersData'] as List<Map<String, dynamic>>? ?? [];
      setState(() {
        for (final userData in newInvitedUsersData) {
          if (!_invitedUsers.any((user) => user['id'] == userData['id']) && _invitedUsers.length < maxInvitations) {
            _invitedUsers.add(userData);
          }
        }
      });
    }
  }

  void _removeInvitedUser(String userId) {
    setState(() {
      _invitedUsers.removeWhere((user) => user['id'] == userId);
    });
  }

  Future<void> _selectClub() async {
    final result = await showModalBottomSheet<Club>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClubSelectionScreen(
        selectedCity: kDefaultCity,
        selectedClubId: _selectedClub?.id,
      ),
    );

    if (result != null) {
      setState(() => _selectedClub = result);
    }
  }

  Future<void> _submitMatch() async {
    if (_selectedClub == null) {
      NotificationUtils.showError(context, 'Пожалуйста, выберите клуб');
      return;
    }
    if (_selectedDate == null) {
      NotificationUtils.showError(context, 'Пожалуйста, выберите дату');
      return;
    }
    if (_selectedTime == null) {
      NotificationUtils.showError(context, 'Пожалуйста, выберите время');
      return;
    }

    // Проверяем данные бронирования, если корт забронирован
    if (_isCourtBooked) {
      if (_courtNumberController.text.isEmpty) {
        NotificationUtils.showError(context, 'Пожалуйста, укажите номер корта');
        return;
      }
      if (_bookedByNameController.text.isEmpty) {
        NotificationUtils.showError(context, 'Пожалуйста, укажите имя для бронирования');
        return;
      }
      if (_costPerPlayerController.text.isEmpty) {
        NotificationUtils.showError(context, 'Пожалуйста, укажите стоимость');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final dateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Создаем объект с информацией о бронировании корта, если нужно
      CourtBookingInfo? courtBookingInfo;
      if (_isCourtBooked) {
        courtBookingInfo = CourtBookingInfo(
          courtNumber: int.tryParse(_courtNumberController.text) ?? 1,
          bookedByName: _bookedByNameController.text,
          bookingCost: double.tryParse(_costPerPlayerController.text) ?? 0.0,
        );
      }

      // Конвертируем русские названия в английские для API
      String apiMatchType = _matchType == 'турнир' ? 'competitive' : 'friendly';
      String apiFormat = _isDoubles ? 'double' : 'single';

      if (_isEditMode) {
        final matchId = widget.initialMatch!.id;
        final update = MatchUpdate(
          dateTime: dateTime,
          duration: _duration,
          clubId: _selectedClub!.id,
          format: apiFormat,
          isPrivate: _isPrivate,
          // description пока не редактируется в UI — не отправляем
          maxParticipants: _isDoubles ? 4 : 2,
          matchType: apiMatchType,
          isBooked: _isCourtBooked,
          courtBookingInfo: courtBookingInfo,
        );
        await ApiService.updateMatch(matchId, update);
        if (!mounted) return;
        NotificationUtils.showSuccess(context, 'Изменения сохранены');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MatchDetailsScreen(matchId: matchId)),
        );
      } else {
        final matchCreate = MatchCreate(
          dateTime: dateTime,
          duration: _duration,
          clubId: _selectedClub!.id, // Добавляем обязательный clubId
          format: apiFormat,
          matchType: apiMatchType,
          isPrivate: _isPrivate,
          description: null, // Можно добавить поле для описания в UI позже
          maxParticipants: _isDoubles ? 4 : 2,
          isBooked: _isCourtBooked,
          courtBookingInfo: courtBookingInfo,
        );

        final match = await ApiService.createMatch(matchCreate);

        // Отправляем приглашения, если есть приглашенные пользователи
        if (_invitedUsers.isNotEmpty) {
          for (final userData in _invitedUsers) {
            await ApiService.inviteUserToMatch(match.id, userData['id'] as String, message: 'Приглашаю на матч!');
          }
        }

        if (mounted) {
          NotificationUtils.showSuccess(context, 'Матч успешно создан!');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MatchDetailsScreen(matchId: match.id)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(context, _isEditMode ? 'Ошибка сохранения: ${e.toString()}' : 'Ошибка создания матча: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
} 