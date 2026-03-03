import 'package:flutter/material.dart';
import '../models/match.dart';
import 'user_avatar.dart';

class MatchScoreInput extends StatefulWidget {
  final List<TextEditingController> teamAControllers;
  final List<TextEditingController> teamBControllers;
  final List<MatchParticipant?> participantsA;
  final List<MatchParticipant?> participantsB;
  final Duration duration;
  final bool isLocked; // true = блокируем ввод (режим после "Завершить матч")
  final VoidCallback? onAddSet; // добавляет по одному контроллеру в обе команды
  final bool syncScroll; // по умолчанию true
  final EdgeInsets padding;
  final Widget? bottomAction; // опциональный настраиваемый виджет действия снизу

  const MatchScoreInput({
    super.key,
    required this.teamAControllers,
    required this.teamBControllers,
    required this.participantsA,
    required this.participantsB,
    required this.duration,
    required this.isLocked,
    this.onAddSet,
    this.syncScroll = true,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 14),
    this.bottomAction,
  });

  @override
  State<MatchScoreInput> createState() => _MatchScoreInputState();
}

class _MatchScoreInputState extends State<MatchScoreInput> {
  final _aScroll = ScrollController();
  final _bScroll = ScrollController();
  bool _syncing = false;

  // Храним FocusNode для каждого контроллера, чтобы ставить "0" при потере фокуса
  final Map<TextEditingController, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    _ensureFocusNodes();
  }

  @override
  void didUpdateWidget(covariant MatchScoreInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureFocusNodes();
  }

  void _ensureFocusNodes() {
    for (final c in widget.teamAControllers) {
      _focusNodes.putIfAbsent(c, () {
        final n = FocusNode();
        n.addListener(() {
          if (!n.hasFocus && c.text.trim().isEmpty) c.text = '0';
        });
        return n;
      });
    }
    for (final c in widget.teamBControllers) {
      _focusNodes.putIfAbsent(c, () {
        final n = FocusNode();
        n.addListener(() {
          if (!n.hasFocus && c.text.trim().isEmpty) c.text = '0';
        });
        return n;
      });
    }
    // чистим удалённые
    _focusNodes.keys
        .where((k) => !widget.teamAControllers.contains(k) && !widget.teamBControllers.contains(k))
        .toList()
        .forEach((k) {
      _focusNodes[k]?.dispose();
      _focusNodes.remove(k);
    });
  }

  @override
  void dispose() {
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    _aScroll.dispose();
    _bScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aWin = _calcSetsWon(widget.teamAControllers, widget.teamBControllers);
    final bWin = _calcSetsWon(widget.teamBControllers, widget.teamAControllers);

    final h = widget.duration.inHours.toString().padLeft(2, '0');
    final m = (widget.duration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (widget.duration.inSeconds % 60).toString().padLeft(2, '0');
    final timeString = '$h:$m:$s';

    return Container(
      width: double.infinity,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
      ),
      child: Column(
        children: [
          // Верхняя часть: Счет и Время
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Счет матча',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF89867E),
                        height: 1.0, // tighter
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 0),
                    Text(
                      '$aWin:$bWin',
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 32,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF222223),
                        letterSpacing: -1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 56,
                color: const Color(0xFFECECEC),
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Время матча',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF89867E),
                        height: 1.0, // tighter
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 0),
                    Text(
                      timeString,
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 32,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF222223),
                        letterSpacing: -1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Разделитель между счетом и полями ввода
          Container(
            width: double.infinity,
            height: 1,
            color: const Color(0xFFECECEC),
            margin: const EdgeInsets.only(top: 4, bottom: 16),
          ),
          const SizedBox(height: 2),
          
          // Команда A
          _teamRow(
            participants: widget.participantsA,
            controllers: widget.teamAControllers,
            isTeamA: true,
          ),
          const SizedBox(height: 12),
          
          // Команда B
          _teamRow(
            participants: widget.participantsB,
            controllers: widget.teamBControllers,
            isTeamA: false,
          ),
          if (widget.bottomAction != null) ...[
            const SizedBox(height: 32),
            widget.bottomAction!,
          ],
        ],
      ),
    );
  }

  int _calcSetsWon(List<TextEditingController> one, List<TextEditingController> other) {
    int won = 0;
    for (int i = 0; i < one.length; i++) {
      final a = int.tryParse(one[i].text) ?? 0;
      final b = i < other.length ? (int.tryParse(other[i].text) ?? 0) : 0;
      if (a > b) won++;
    }
    return won;
  }

  double _calculateContentWidth() {
    // Ширина одного поля ввода: 38px
    // Ширина отступа между полями: 6px
    // Ширина кнопки "+": 38px (если есть)
    // Ширина отступа перед кнопкой "+": 6px (если есть)
    
    double width = 0;
    
    // Ширина полей ввода
    for (int i = 0; i < widget.teamAControllers.length; i++) {
      width += 38; // ширина поля
      if (i < widget.teamAControllers.length - 1) {
        width += 6; // отступ между полями
      }
    }
    
    // Ширина кнопки "+" (только для команды A и если не заблокировано)
    if (widget.onAddSet != null && !widget.isLocked) {
      width += 6; // отступ перед кнопкой
      width += 38; // ширина кнопки
    }
    
    return width;
  }

  Widget _teamRow({
    required List<MatchParticipant?> participants,
    required List<TextEditingController> controllers,
    required bool isTeamA,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Аватары команды
        Row(
          children: [
            for (int i = 0; i < participants.length && participants[i] != null; i++)
              Transform.translate(
                offset: Offset(i * -8.0, 0),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: UserAvatar(
                    imageUrl: participants[i]!.avatarUrl,
                    userName: participants[i]!.name,
                    isDeleted: participants[i]!.isDeleted,
                    radius: 28,
                    backgroundColor: const Color(0xFFF7F7F7),
                    borderColor: null,
                    borderWidth: 0,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        
        // Инпуты с синхронизированным скроллом
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (!widget.syncScroll) return false;
              if (!_syncing && notification is ScrollUpdateNotification) {
                _syncing = true;
                if (isTeamA) {
                  _bScroll.jumpTo(_aScroll.position.pixels);
                } else {
                  _aScroll.jumpTo(_bScroll.position.pixels);
                }
                _syncing = false;
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: isTeamA ? _aScroll : _bScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _calculateContentWidth(),
                child: Row(
                  children: [
                    for (int i = 0; i < controllers.length; i++) ...[
                      Container(
                        width: 38,
                        height: 52,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: controllers[i],
                          builder: (context, value, child) {
                            final isZero = value.text == '0' || value.text.isEmpty;
                            return TextField(
                              controller: controllers[i],
                              focusNode: _focusNodes[controllers[i]],
                              enabled: !widget.isLocked,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              onTap: () {
                                if (controllers[i].text == '0') {
                                  controllers[i].clear();
                                }
                              },
                              style: TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: isZero ? const Color(0xFF89867E) : const Color(0xFF222223),
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            );
                          },
                        ),
                      ),
                      if (i < controllers.length - 1) const SizedBox(width: 6),
                    ],
                    // Кнопка добавить сет (только для команды A и если не заблокировано)
                    if (isTeamA && !widget.isLocked && widget.onAddSet != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: widget.onAddSet,
                        child: Container(
                          width: 38,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF262F63), width: 1),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Color(0xFF262F63),
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

