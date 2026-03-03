import 'package:flutter/material.dart';
import '../models/club.dart';
import '../services/api_service.dart';
import '../widgets/city_selection_modal.dart';
import '../widgets/close_button.dart';
import '../utils/date_utils.dart' as date_utils;
import '../utils/app_defaults.dart';

class MatchFiltersScreen extends StatefulWidget {
  final String? selectedCity;
  final List<String> selectedClubs;
  final List<DateTime> selectedDates;
  final String? selectedTimeRange;
  final bool lockClubSelection;
  final List<String> initialLockedClubs;

  const MatchFiltersScreen({
    super.key,
    this.selectedCity,
    this.selectedClubs = const [],
    this.selectedDates = const [],
    this.selectedTimeRange,
    this.lockClubSelection = false,
    this.initialLockedClubs = const [],
  });

  @override
  State<MatchFiltersScreen> createState() => _MatchFiltersScreenState();
}

class _MatchFiltersScreenState extends State<MatchFiltersScreen> {
  String? _selectedCity;
  List<String> _selectedClubs = [];
  List<DateTime> _selectedDates = [];
  String _selectedTimeRange = 'Весь день';
  
  List<Club> _clubs = [];
  bool _isLoadingClubs = false;

  final List<String> _timeRanges = ['Весь день', 'Утро с 8 до 12', 'День с 12 до 18', 'Вечер с 18 до 24'];

  @override
  void initState() {
    super.initState();
    print('🏢 [CLUBS] initState вызван');
    print('🏢 [CLUBS] widget.selectedCity: ${widget.selectedCity}');
    
    _selectedCity = widget.selectedCity ?? kDefaultCity; // Дефолт: Кемерово
    _selectedClubs = widget.lockClubSelection && widget.initialLockedClubs.isNotEmpty
        ? List.from(widget.initialLockedClubs)
        : List.from(widget.selectedClubs);
    _selectedDates = List.from(widget.selectedDates);
    _selectedTimeRange = widget.selectedTimeRange ?? 'Весь день';
    
    print('🏢 [CLUBS] После инициализации _selectedCity: $_selectedCity');
    print('🏢 [CLUBS] Вызываем _loadClubs()');
    _loadClubs(); // Загружаем клубы только если город выбран
  }

  Future<void> _loadClubs() async {
    print('🏢 [CLUBS] _loadClubs вызван. _selectedCity: $_selectedCity');
    
    if (_selectedCity == null) {
      print('🏢 [CLUBS] Город не выбран, выходим');
      return;
    }

    print('🏢 [CLUBS] Начинаем загрузку клубов для города: $_selectedCity');
    setState(() {
      _isLoadingClubs = true;
    });

    try {
      print('🏢 [CLUBS] Вызываем ApiService.getClubsByCity($_selectedCity)');
      final response = await ApiService.getClubsByCity(_selectedCity!);
      
      print('🏢 [CLUBS] Получен ответ. Количество клубов: ${response.clubs.length}');
      setState(() {
        _clubs = response.clubs;
        _isLoadingClubs = false;
      });
      print('🏢 [CLUBS] Состояние обновлено. _clubs.length: ${_clubs.length}');
    } catch (e) {
      print('🏢 [CLUBS] Ошибка загрузки клубов: $e');
      setState(() {
        _isLoadingClubs = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки клубов: $e')),
        );
      }
    }
  }

  Future<void> _selectCity() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (context) => CitySelectionModal(selectedCity: _selectedCity),
    );

    if (result != null) {
      setState(() {
        _selectedCity = result;
        _selectedClubs.clear();
      });
      _loadClubs();
    }
  }

  void _toggleDate(DateTime date) {
    setState(() {
      if (_selectedDates.any((d) => _isSameDay(d, date))) {
        _selectedDates.removeWhere((d) => _isSameDay(d, date));
      } else {
        if (_selectedDates.length < 7) {
          _selectedDates.add(date);
        }
      }
    });
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  void _resetFilters() {
    setState(() {
      // Сброс возвращает дефолтный город
      _selectedCity = kDefaultCity;
      _selectedClubs.clear();
      _selectedDates.clear();
      _selectedTimeRange = 'Весь день';
      _clubs.clear();
    });
    // Перезагружаем клубы под дефолтный город
    _loadClubs();
  }

  void _applyFilters() {
    final result = {
      'city': _selectedCity,
      'clubs': _selectedClubs,
      'dates': _selectedDates,
      'timeRange': _selectedTimeRange,
    };
    
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final double initialSize = widget.lockClubSelection ? 0.72 : 0.87;
    final double maxSize = widget.lockClubSelection ? 0.87 : 0.95;
    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: 0.5,
      maxChildSize: maxSize,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Column(
            children: [
              // Заголовок с кнопками
              Container(
                height: 76,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Кнопка "Сбросить"
                    SizedBox(
                      width: 90, // Увеличили ширину для размещения текста
                      child: TextButton(
                        onPressed: _resetFilters,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero, // Убираем внутренние отступы
                        ),
                        child: const Text(
                          'Сбросить',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF7F8AC0),
                            fontFamily: 'Basis Grotesque Arabic Pro',
                            letterSpacing: -0.28,
                          ),
                        ),
                      ),
                    ),
                    
                    // Заголовок "Фильтры" по центру
                    const Expanded(
                      child: Text(
                        'Фильтры',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF222223),
                          fontFamily: 'Basis Grotesque Arabic Pro',
                          letterSpacing: -0.48,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    // Кнопка закрытия
                    SizedBox(
                      width: 90,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: CustomCloseButton(onPressed: () => Navigator.pop(context)),
                      ),
                    ),
                  ],
                ),
              ),

              // Основной контент
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      
                      // Выбор города
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Выберете город',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF79766E),
                              fontFamily: 'Basis Grotesque Arabic Pro',
                              letterSpacing: -0.28,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _selectCity,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F7F7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedCity ?? 'Выберите город',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF22211E),
                                      fontFamily: 'Basis Grotesque Arabic Pro',
                                      letterSpacing: -0.32,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Color(0xFF7F8AC0),
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Где будете играть? — не показываем, если клуб зафиксирован
                      if (!widget.lockClubSelection)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Где будете играть ?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF79766E),
                                fontFamily: 'Basis Grotesque Arabic Pro',
                                letterSpacing: -0.28,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_selectedCity == null)
                              Container(
                                height: 160,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F7F7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Выберите город для отображения клубов',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF222223),
                                      fontFamily: 'SF Pro Display',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else if (_isLoadingClubs)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(color: Color(0xFF00897B)),
                                ),
                              )
                            else
                              SizedBox(
                                height: 160,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _clubs.length,
                                  itemBuilder: (context, index) {
                                    final club = _clubs[index];
                                    final isSelected = _selectedClubs.contains(club.id);
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedClubs.remove(club.id);
                                          } else {
                                            if (_selectedClubs.length < 3) {
                                              _selectedClubs.add(club.id);
                                            }
                                          }
                                        });
                                      },
                                      child: Container(
                                        width: 148,
                                        height: 160,
                                        margin: EdgeInsets.only(right: index < _clubs.length - 1 ? 8 : 0),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF00897B) : const Color(0xFFD9D9D9),
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              height: 88,
                                              decoration: BoxDecoration(
                                                borderRadius: const BorderRadius.only(
                                                  topLeft: Radius.circular(8),
                                                  topRight: Radius.circular(8),
                                                ),
                                                image: club.photoUrl != null
                                                    ? DecorationImage(image: NetworkImage(club.photoUrl!), fit: BoxFit.cover)
                                                    : null,
                                                color: club.photoUrl == null ? const Color(0xFFE0E0E0) : null,
                                              ),
                                              child: club.photoUrl == null
                                                  ? const Center(child: Icon(Icons.sports_tennis, size: 32, color: Color(0xFF9E9E9E)))
                                                  : null,
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Text(
                                                  club.name,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w400,
                                                    color: Color(0xFF222223),
                                                    fontFamily: 'Basis Grotesque Arabic Pro',
                                                    letterSpacing: -0.28,
                                                  ),
                                                  maxLines: 3,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),

                      if (!widget.lockClubSelection) const SizedBox(height: 15),

                      // Выберите дни недели
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Выберите дни недели (Макс. 7)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF79766E),
                              fontFamily: 'Basis Grotesque Arabic Pro',
                              letterSpacing: -0.32,
                            ),
                          ),
                          const SizedBox(height: 18),
                          
                          // Календарь дней
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 7, // Неделя
                              itemBuilder: (context, index) {
                                final date = DateTime.now().add(Duration(days: index));
                                final isSelected = _selectedDates.any((d) => _isSameDay(d, date));
                                
                                return GestureDetector(
                                  onTap: () => _toggleDate(date),
                                  child: Container(
                                    width: 52,
                                    margin: EdgeInsets.only(
                                      right: index < 6 ? 16 : 0,
                                    ),
                                    child: Column(
                                      children: [
                                        // День недели
                                        Text(
                                          date_utils.DateUtils.weekdayNames[date.weekday - 1],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF222223),
                                            fontFamily: 'Basis Grotesque Arabic Pro',
                                            letterSpacing: -0.32,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        
                                        // Число
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFF00897B) : const Color(0xFFF5F5F5),
                                            borderRadius: BorderRadius.circular(32),
                                          ),
                                          child: Center(
                                            child: Text(
                                              date.day.toString(),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: isSelected ? Colors.white : const Color(0xFF222223),
                                                fontFamily: 'Basis Grotesque Arabic Pro',
                                                letterSpacing: -0.32,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        
                                        // Месяц
                                        Text(
                                          date_utils.DateUtils.monthNames[date.month - 1],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF222223),
                                            fontFamily: 'Basis Grotesque Arabic Pro',
                                            letterSpacing: -0.28,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 0),

                      // Выберите время
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Выберете время',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF79766E),
                              fontFamily: 'Basis Grotesque Arabic Pro',
                              letterSpacing: -0.32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Радио-кнопки времени
                          Column(
                            children: _timeRanges.map((timeRange) {
                              final isSelected = _selectedTimeRange == timeRange;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedTimeRange = timeRange;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    children: [
                                      // Радио-кнопка
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF00897B) : const Color(0xFF89867E),
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? Center(
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF00897B),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 4),
                                      
                                      // Текст времени
                                      Text(
                                        timeRange,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF222223),
                                          fontFamily: 'Basis Grotesque Arabic Pro',
                                          letterSpacing: -0.32,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Кнопка "Смотреть результаты"
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Смотреть результаты',
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
            ],
          ),
        );
      },
    );
  }
} 