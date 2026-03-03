/*import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../models/court.dart';
import '../../models/booking.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';
import '../../widgets/app_switch.dart';
import '../../utils/notification_utils.dart';
import 'package:intl/intl.dart';

class BookingScreen extends StatefulWidget {
  final Club club;

  const BookingScreen({super.key, required this.club});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedHour;
  bool _showUnavailableSlots = false;
  bool _isLoadingCourts = false;
  bool _isCheckingAvailability = false;
  List<Court> _courts = [];
  List<Court?> _selectedCourts = [null]; // Список выбранных кортов
  Map<String, List<String>> _availableCourts = {}; // time -> list of court IDs
  final List<GlobalKey> _courtSelectorKeys = [GlobalKey()];
  
  final List<String> _timeSlots = [
    '08:00', '09:00', '10:00', '11:00', 
    '12:00', '13:00', '14:00', '15:00',
    '16:00', '17:00', '18:00', '19:00', 
    '20:00'
  ];

  @override
  void initState() {
    super.initState();
    _loadCourts();
  }

  Future<void> _loadCourts() async {
    if (_isLoadingCourts) return;
    
    setState(() {
      _isLoadingCourts = true;
    });

    try {
      final response = await ApiService.getCourts(widget.club.id);
      setState(() {
        _courts = response.courts;
        _isLoadingCourts = false;
      });
    } catch (e) {
      Logger.error('Ошибка загрузки кортов: $e');
      setState(() {
        _isLoadingCourts = false;
      });
      if (mounted) {
        NotificationUtils.showError(context, 'Ошибка загрузки кортов');
      }
    }
  }

  Future<void> _checkAvailabilityForTime(String time) async {
    if (_isCheckingAvailability) return;

    setState(() {
      _isCheckingAvailability = true;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final availability = await ApiService.checkBookingAvailability(
        clubId: widget.club.id,
        bookingDate: dateStr,
        startTime: time,
        durationMin: 60,
      );

      final availableCourts = availability['available_courts'] as List? ?? [];
      final List<String> courtIds = availableCourts
          .map((c) => c['court_id'] as String)
          .toList();

      setState(() {
        _availableCourts[time] = courtIds;
        _isCheckingAvailability = false;
      });
    } catch (e) {
      Logger.error('Ошибка проверки доступности для времени $time: $e');
      setState(() {
        _isCheckingAvailability = false;
      });
    }
  }

  void _onSelectHour(String hour) {
    setState(() {
      if (_selectedHour == hour) {
        _selectedHour = null;
        _selectedCourts = [null];
        _courtSelectorKeys.clear();
        _courtSelectorKeys.add(GlobalKey());
      } else {
        _selectedHour = hour;
        _selectedCourts = [null];
        _courtSelectorKeys.clear();
        _courtSelectorKeys.add(GlobalKey());
        // Проверяем доступность для выбранного времени
        if (!_availableCourts.containsKey(hour)) {
          _checkAvailabilityForTime(hour);
        }
      }
    });
  }

  Future<void> _proceedToPayment() async {
    if (_selectedHour == null || !_selectedCourts.any((court) => court != null)) {
      NotificationUtils.showError(context, 'Выберите время и хотя бы один корт');
      return;
    }

    try {
      // Создаем бронирования для всех выбранных кортов
      final selectedCourts = _selectedCourts.where((court) => court != null).toList();
      
      for (final court in selectedCourts) {
        final bookingData = BookingCreate(
          clubId: widget.club.id,
          courtId: court!.id,
          bookingDate: _selectedDate,
          startTime: _selectedHour!,
          durationMin: 60,
        );

        await ApiService.createBooking(bookingData);
      }
      
      if (mounted) {
        NotificationUtils.showSuccess(
          context, 
          'Забронировано кортов: ${selectedCourts.length}'
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      Logger.error('Ошибка создания бронирования: $e');
      if (mounted) {
        NotificationUtils.showError(context, 'Ошибка создания бронирования: $e');
      }
    }
  }

  bool get _canProceed => _selectedHour != null && _selectedCourts.any((court) => court != null);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF838A91)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.club.name,
              style: const TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2A2C36),
                letterSpacing: -0.40,
              ),
            ),
            Text(
              widget.club.address.isNotEmpty ? widget.club.address : (widget.club.city ?? ''),
              style: const TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Color(0xFF2A2C36),
                letterSpacing: -0.32,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF838A91)),
            onPressed: () {
              // Share functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок месяца
            Text(
              _getMonthName(_selectedDate.month),
              style: const TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2A2C36),
                letterSpacing: -0.36,
              ),
            ),
            const SizedBox(height: 12),
            
            // Календарь-полоска (неделя)
            _buildWeekStrip(startOfWeek),
            
            const SizedBox(height: 16),
            
            // Переключатель недоступных слотов
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Показывать недоступные слоты',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2A2C36),
                    letterSpacing: -0.32,
                  ),
                ),
                AppSwitch(
                  value: _showUnavailableSlots,
                  onChanged: (value) => setState(() => _showUnavailableSlots = value),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Сетка временных слотов
            _buildTimeSlots(),
            
            const SizedBox(height: 16),
            
            // Выбор кортов
            if (_selectedHour != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Выберите корт',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF838A91),
                      letterSpacing: -0.32,
                    ),
                  ),
                  GestureDetector(
                    onTap: _addCourtSelector,
                    child: const Text(
                      'Добавить корт',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF00897B),
                        letterSpacing: -0.32,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._buildCourtSelectors(),
            ],
            
            const SizedBox(height: 24),
            
            // Кнопка "Перейти к оплате"
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canProceed ? _proceedToPayment : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  disabledBackgroundColor: const Color(0xFF00897B).withOpacity(0.45),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: const Text(
                  'Перейти к оплате',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.32,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekStrip(DateTime startOfWeek) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = startOfWeek.add(Duration(days: index));
          final isSelected = date.day == _selectedDate.day &&
              date.month == _selectedDate.month &&
              date.year == _selectedDate.year;
          
          return GestureDetector(
            onTap: () => setState(() {
              _selectedDate = date;
              _selectedHour = null;
              _selectedCourts = [null];
              _courtSelectorKeys.clear();
              _courtSelectorKeys.add(GlobalKey());
              _availableCourts.clear();
            }),
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00897B) : Colors.white,
                border: Border.all(
                  color: isSelected ? const Color(0xFF00897B) : const Color(0xFFD9D9D9),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    days[index],
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF838A91),
                      letterSpacing: -0.28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF2A2C36),
                      letterSpacing: -0.40,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSlots() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _timeSlots.map((time) {
        final isSelected = _selectedHour == time;
        final isAvailable = _availableCourts[time]?.isNotEmpty ?? false;
        final shouldShow = _showUnavailableSlots || isAvailable;
        
        if (!shouldShow) return const SizedBox.shrink();
        
        return GestureDetector(
          onTap: () => _onSelectHour(time),
          child: Container(
            width: 80,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: isSelected ? const Color(0xFF00897B) : const Color(0xFFD9D9D9),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                time,
                style: const TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2A2C36),
                  letterSpacing: -0.32,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _addCourtSelector() {
    setState(() {
      _selectedCourts.add(null);
      _courtSelectorKeys.add(GlobalKey());
    });
  }

  void _removeLastCourtSelector() {
    if (_selectedCourts.length > 1) {
      setState(() {
        _selectedCourts.removeLast();
        _courtSelectorKeys.removeLast();
      });
    }
  }

  List<Widget> _buildCourtSelectors() {
    final List<Widget> selectors = [];
    
    for (int i = 0; i < _selectedCourts.length; i++) {
      if (i > 0) {
        selectors.add(const SizedBox(height: 12));
      }
      
      selectors.add(_buildCourtSelector(i));
    }
    
    // Добавляем кнопку "Удалить корт" если полей больше 1
    if (_selectedCourts.length > 1) {
      selectors.add(const SizedBox(height: 12));
      selectors.add(
        GestureDetector(
          onTap: _removeLastCourtSelector,
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Удалить корт',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFFFF6B6B),
                letterSpacing: -0.32,
              ),
            ),
          ),
        ),
      );
    }
    
    return selectors;
  }

  Widget _buildCourtSelector(int index) {
    if (_isLoadingCourts) {
      return Container(
        width: double.infinity,
        height: 60,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_courts.isEmpty) {
      return Container(
        width: double.infinity,
        height: 60,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Корты не найдены',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF838A91),
              letterSpacing: -0.32,
            ),
          ),
        ),
      );
    }

    // Фильтруем корты, доступные для выбранного времени
    final availableCourtIds = _availableCourts[_selectedHour] ?? [];
    final availableCourtsForTime = _courts.where(
      (court) => availableCourtIds.contains(court.id)
    ).toList();
    
    final displayCourts = availableCourtsForTime.isEmpty ? _courts : availableCourtsForTime;
    final selectedCourt = _selectedCourts[index];

    return GestureDetector(
      key: _courtSelectorKeys[index],
      onTap: () => _showCourtSelectionBottomSheet(displayCourts, index),
      child: Container(
        width: double.infinity,
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD9D9D9)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                selectedCourt != null 
                    ? '${selectedCourt.name} — ${selectedCourt.pricePerHour.toStringAsFixed(0)} ₽/час'
                    : 'Выберите корт',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: selectedCourt != null ? const Color(0xFF2A2C36) : const Color(0xFF838A91),
                  letterSpacing: -0.32,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Color(0xFF838A91)),
          ],
        ),
      ),
    );
  }

  void _showCourtSelectionBottomSheet(List<Court> courts, int index) {
    final RenderBox? renderBox = _courtSelectorKeys[index].currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Вычисляем высоту меню
    final menuHeight = courts.length * 56.0 + (courts.length - 1); // высота элементов + разделители
    final gap = 4.0; // отступ между кнопкой и меню
    final upshift = 70.0; // поднимаем меню на 70 пикселей выше
    
    // Позиция сразу под кнопкой
    final topPosition = position.dy + size.height + gap - upshift;
    final bottomSpace = screenHeight - topPosition;
    
    // Определяем финальную позицию
    double finalTop;
    double maxHeight;
    
    if (bottomSpace >= menuHeight) {
      // Меню полностью помещается снизу
      finalTop = topPosition;
      maxHeight = bottomSpace - 16; // 16 - отступ от низа экрана
    } else {
      // Меню не помещается снизу, поднимаем его
      finalTop = screenHeight - menuHeight - 16 - upshift;
      maxHeight = menuHeight;
      
      // Если меню все равно не помещается, уменьшаем его высоту
      if (finalTop < 16) {
        finalTop = 16;
        maxHeight = screenHeight - 32; // отступы сверху и снизу
      }
    }
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          // Прозрачный фон для закрытия меню при клике вне его
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Меню
          Positioned(
            left: 16,
            right: 16,
            top: finalTop,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: maxHeight,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      courts.length * 2 - 1,
                      (index) {
                        if (index.isOdd) {
                          // Разделитель
                          return Container(
                            height: 1,
                            color: const Color(0xFF2A2C36).withOpacity(0.1),
                          );
                        }
                        
                        final courtIndex = index ~/ 2;
                        final court = courts[courtIndex];
                        
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCourts[index] = court;
                            });
                            Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.vertical(
                            top: courtIndex == 0 ? const Radius.circular(12) : Radius.zero,
                            bottom: courtIndex == courts.length - 1 ? const Radius.circular(12) : Radius.zero,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  court.name,
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    fontFamily: 'SF Pro Display',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF2A2C36),
                                    letterSpacing: -0.32,
                                    height: 1.125,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${court.pricePerHour.toStringAsFixed(0)}₽',
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    fontFamily: 'SF Pro Display',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF00897B),
                                    letterSpacing: -0.28,
                                    height: 1.14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return months[month - 1];
  }
}

