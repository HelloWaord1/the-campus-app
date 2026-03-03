import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/filters_search_section.dart';
import '../utils/date_utils.dart' as date_utils;

const double _kEdgePad = 0.30;

class _FullWidthSliderTrackShape extends RoundedRectSliderTrackShape {
  const _FullWidthSliderTrackShape();
  
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final h = sliderTheme.trackHeight ?? 2;
    final left = offset.dx;
    final top = offset.dy + (parentBox.size.height - h) / 2;
    final w = parentBox.size.width;
    return Rect.fromLTWH(left, top, w, h);
  }
}

class _DistanceScale extends StatelessWidget {
  const _DistanceScale();
  
  @override
  Widget build(BuildContext context) {
    const labels = [1, 5, 10, 15, 20, 30, 50];
    const n = 7;
    return SizedBox(
      height: 20,
      child: LayoutBuilder(
        builder: (context, c) {
          final usable = c.maxWidth;
          return Stack(
            children: List.generate(n, (i) {
              final frac = (i + _kEdgePad) / ((n - 1) + 2 * _kEdgePad);
              final x = usable * frac;
              const w = 32.0;
              final left = (x - w / 2).clamp(0.0, c.maxWidth - w);
              return Positioned(
                left: left, 
                bottom: 0, 
                width: w,
                child: Text(
                  '${labels[i]}', 
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display', 
                    fontSize: 12, 
                    color: Color(0xFF79766E), 
                    letterSpacing: -0.24,
                    fontWeight: FontWeight.w400,
                    height: 1.667,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _DistanceSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _DistanceSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const steps = [1, 5, 10, 15, 20, 30, 50];
    const n = 7;
    int idx = 0; 
    double best = 1e9;
    for (int i = 0; i < n; i++) {
      final d = (value - steps[i]).abs();
      if (d < best) { 
        best = d; 
        idx = i; 
      }
    }
    final double uiMin = -_kEdgePad;
    final double uiMax = (n - 1) + _kEdgePad;
    final double uiValue = idx.toDouble();
    
    return SizedBox(
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: LayoutBuilder(
              builder: (context, c) {
                final usable = c.maxWidth;
                return Stack(
                  children: List.generate(n, (i) {
                    final frac = (i + _kEdgePad) / ((n - 1) + 2 * _kEdgePad);
                    final left = usable * frac;
                    return Positioned(
                      left: left - 0.25,
                      top: (28 - 16) / 2,
                      child: Container(
                        width: 1, 
                        height: 16, 
                        color: const Color(0xFFD9D9D9),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: const Color(0xFF00897B),
              inactiveTrackColor: const Color(0xFFD9D9D9),
              thumbColor: const Color(0xFF00897B),
              overlayColor: Colors.transparent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackShape: const _FullWidthSliderTrackShape(),
            ),
            child: Slider(
              min: uiMin,
              max: uiMax,
              value: uiValue,
              onChanged: (raw) {
                final t = ((raw).clamp(0.0, (n - 1).toDouble())).round();
                onChanged(steps[t].toDouble());
              },
            ),
          ),
        ],
      ),
    );
  }
}

const _undefined = Object();

class TrainingFilters {
  String? city;
  String? type; // 'group' или 'individual'
  DateTime? startDate;
  DateTime? endDate;
  List<DateTime>? selectedDates; // Список выбранных дат
  int? maxPrice;
  List<String>? selectedTimes;
  double? distanceKm;
  String? difficulty; // 'all', 'beginner', 'intermediate', 'advanced'

  TrainingFilters({
    this.city,
    this.type,
    this.startDate,
    this.endDate,
    this.selectedDates,
    this.maxPrice,
    this.selectedTimes,
    this.distanceKm,
    this.difficulty,
  });

  TrainingFilters copyWith({
    Object? city = _undefined,
    Object? type = _undefined,
    Object? startDate = _undefined,
    Object? endDate = _undefined,
    Object? selectedDates = _undefined,
    Object? maxPrice = _undefined,
    Object? selectedTimes = _undefined,
    Object? distanceKm = _undefined,
    Object? difficulty = _undefined,
  }) {
    return TrainingFilters(
      city: city == _undefined ? this.city : city as String?,
      type: type == _undefined ? this.type : type as String?,
      startDate: startDate == _undefined ? this.startDate : startDate as DateTime?,
      endDate: endDate == _undefined ? this.endDate : endDate as DateTime?,
      selectedDates: selectedDates == _undefined ? this.selectedDates : selectedDates as List<DateTime>?,
      maxPrice: maxPrice == _undefined ? this.maxPrice : maxPrice as int?,
      selectedTimes: selectedTimes == _undefined ? this.selectedTimes : selectedTimes as List<String>?,
      distanceKm: distanceKm == _undefined ? this.distanceKm : distanceKm as double?,
      difficulty: difficulty == _undefined ? this.difficulty : difficulty as String?,
    );
  }

  bool get hasFilters {
    return city != null || 
           type != null || 
           startDate != null || 
           endDate != null || 
           (selectedDates != null && selectedDates!.isNotEmpty) ||
           maxPrice != null || 
           (selectedTimes != null && selectedTimes!.isNotEmpty) || 
           (distanceKm != null) || 
           (difficulty != null && difficulty != 'all');
  }

  void clear() {
    city = null;
    type = null;
    startDate = null;
    endDate = null;
    selectedDates = null;
    maxPrice = null;
    selectedTimes = null;
    distanceKm = null;
    difficulty = 'all';
  }
}

class TrainingFiltersScreen extends StatefulWidget {
  final TrainingFilters initialFilters;
  final Function(TrainingFilters) onFiltersChanged;

  const TrainingFiltersScreen({
    super.key,
    required this.initialFilters,
    required this.onFiltersChanged,
  });

  @override
  State<TrainingFiltersScreen> createState() => _TrainingFiltersScreenState();

  static void show(BuildContext context, {
    required TrainingFilters initialFilters,
    required Function(TrainingFilters) onFiltersChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TrainingFiltersScreen(
        initialFilters: initialFilters,
        onFiltersChanged: onFiltersChanged,
      ),
    );
  }
}

class _TrainingFiltersScreenState extends State<TrainingFiltersScreen> {
  late TrainingFilters _filters;
  late ScrollController _scrollController;
  late ScrollController _calendarScrollController;
  late TextEditingController _searchController;
  final List<String> _times = ['8:00', '9:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00', '17:00'];
  final List<DateTime> _weekDates = [];

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters.copyWith();
    _filters.difficulty ??= 'all';
    _scrollController = ScrollController();
    _calendarScrollController = ScrollController();
    _searchController = TextEditingController(text: _filters.city ?? '');
    _generateWeekDates();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _calendarScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _generateWeekDates() {
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      _weekDates.add(now.add(Duration(days: i)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black26,
      ),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: DraggableScrollableSheet(
          initialChildSize: 0.87,
          minChildSize: 0.87,
          maxChildSize: 0.87,
          builder: (context, scrollController) {
            return GestureDetector(
              onTap: () {}, // Prevents closing when tapping inside
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        children: [
                          _buildCalendarSection(),
                          const SizedBox(height: 14),
                          _buildTimeSection(),
                          const SizedBox(height: 27),
                          _buildDistanceSection(),
                          const SizedBox(height: 20),
                          _buildSearchSection(),
                          const SizedBox(height: 28),
                          _buildDifficultySection(),
                          const SizedBox(height: 28),
                          _buildTypeSection(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    _buildBottomButton(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          // Сбросить (слева)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _filters.clear();
                  });
                },
                child: const Text(
                  'Сбросить',
                  style: TextStyle(
                    color: Color(0xFF7F8AC0),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.33,
                  ),
                ),
              ),
            ),
          ),
          // Заголовок (центр)
          Center(
            child: const Text(
              'Фильтры',
              style: TextStyle(
                color: Color(0xFF222223),
                fontSize: 24,
                fontWeight: FontWeight.w500,
                fontFamily: 'SF Pro Display',
                letterSpacing: -2,
                height: 1.5,
              ),
            ),
          ),
          // Кнопка закрытия (справа)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFAEAEAE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        controller: _calendarScrollController,
        itemCount: _weekDates.length,
        itemBuilder: (context, index) {
          final date = _weekDates[index];
          final selectedDates = _filters.selectedDates ?? [];
          final isSelected = selectedDates.any((selectedDate) => 
                             date.year == selectedDate.year &&
                             date.month == selectedDate.month &&
                             date.day == selectedDate.day);
          
          return GestureDetector(
            onTap: () {
              setState(() {
                List<DateTime> newSelectedDates = List.from(selectedDates);
                if (isSelected) {
                  // Убираем дату из выбранных
                  newSelectedDates.removeWhere((selectedDate) =>
                      date.year == selectedDate.year &&
                      date.month == selectedDate.month &&
                      date.day == selectedDate.day);
                  // Используем явное значение null для пустого списка
                  _filters = _filters.copyWith(
                    selectedDates: newSelectedDates.isEmpty ? null : newSelectedDates
                  );
                } else {
                  // Добавляем дату к выбранным
                  newSelectedDates.add(date);
                  _filters = _filters.copyWith(selectedDates: newSelectedDates);
                }
              });
            },
            child: Container(
              width: 48,
              margin: EdgeInsets.only(right: index < _weekDates.length - 1 ? 8 : 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    date_utils.DateUtils.weekdayNamesFromSunday[date.weekday % 7],
                    style: const TextStyle(
                      color: Color(0xFF222223),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -1.4,
                      height: 1.125,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF00897B) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF222223),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -0.32,
                        height: 1.125,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date_utils.DateUtils.monthNames[date.month - 1],
                    style: const TextStyle(
                      color: Color(0xFF222223),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -1.2,
                      height: 1.286,
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

  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Время',
          style: TextStyle(
            color: Color(0xFF79766E),
            fontSize: 16,
            fontWeight: FontWeight.w400,
            fontFamily: 'SF Pro Display',
            letterSpacing: -1.2,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            // Первая строка: 8:00-12:00
            Row(
              children: _times.take(5).map((time) {
                final isSelected = _filters.selectedTimes?.contains(time) ?? false;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildTimeChip(time, isSelected),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            // Вторая строка: 13:00-17:00
            Row(
              children: _times.skip(5).map((time) {
                final isSelected = _filters.selectedTimes?.contains(time) ?? false;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildTimeChip(time, isSelected),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeChip(String time, bool isSelected) {
    // выбор времени на две строки
    return GestureDetector(
      onTap: () {
        setState(() {
          final times = _filters.selectedTimes ?? [];
          if (times.contains(time)) {
            times.remove(time);
          } else {
            times.add(time);
          }
          _filters = _filters.copyWith(selectedTimes: times.isEmpty ? null : times);
        });
      },
      child: Container(
        height: 44,
        padding: EdgeInsets.all(isSelected ? 0 : 1),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF00897B) : const Color(0xFFD9D9D9),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          time,
          style: const TextStyle(
            color: Color(0xFF222223),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'SF Pro Display',
            letterSpacing: -1.2,
            height: 1.125,
          ),
        ),
      ),
    );
  }

  Widget _buildDistanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Дистанция (0-50 км)',
          style: TextStyle(
            color: Color(0xFF79766E),
            fontSize: 16,
            fontWeight: FontWeight.w400,
            fontFamily: 'SF Pro Display',
            letterSpacing: -1.2,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 20),
        _DistanceSlider(
          value: _filters.distanceKm ?? 50,
          onChanged: (v) => setState(() {
            _filters = _filters.copyWith(distanceKm: v);
          }),
        ),
        const SizedBox(height: 3),
        const _DistanceScale(),
      ],
    );
  }

  Widget _buildSearchSection() {
    return Column(
      children: [
        // Поиск/город → открываем отдельный экран, как в списке клубов
        FiltersSearchSection(
          currentValue: _filters.city,
          secondaryValue: null,
          onSearchResult: (value, {bool isCity = false}) {
            debugPrint('🔍 Результат поиска: value=$value, isCity=$isCity');
            setState(() {
              if (value == null || value.isEmpty) {
                _filters = _filters.copyWith(city: null);
                _searchController.text = '';
              } else {
                _filters = _filters.copyWith(city: value);
                _searchController.text = value;
              }
            });
          },
        ),
        const SizedBox(height: 16),
        // Рядом со мной
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/navigation_arrow.svg',
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Рядом со мной',
                  style: TextStyle(
                    color: Color(0xFF89867E),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -1,
                    height: 1.286,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Сложность',
          style: TextStyle(
            color: Color(0xFF79766E),
            fontSize: 16,
            fontWeight: FontWeight.w400,
            fontFamily: 'SF Pro Display',
            letterSpacing: -1.2,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Все',
                isSelected: _filters.difficulty == 'all' || _filters.difficulty == null,
                onTap: () => setState(() => _filters = _filters.copyWith(difficulty: 'all')),
              ),
              const SizedBox(width: 12),
              _buildFilterChip(
                label: 'Начинающий (1.00-2.00)  ',
                isSelected: _filters.difficulty == 'beginner',
                onTap: () => setState(() => _filters = _filters.copyWith(difficulty: 'beginner')),
              ),
              const SizedBox(width: 12),
              _buildFilterChip(
                label: 'Средний (2.50-3.50)',
                isSelected: _filters.difficulty == 'intermediate',
                onTap: () => setState(() => _filters = _filters.copyWith(difficulty: 'intermediate')),
              ),
              const SizedBox(width: 12),
              _buildFilterChip(
                label: 'Продвинутый (3.50-5.00)',
                isSelected: _filters.difficulty == 'advanced',
                onTap: () => setState(() => _filters = _filters.copyWith(difficulty: 'advanced')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Тип тренировки ',
          style: TextStyle(
            color: Color(0xFF79766E),
            fontSize: 16,
            fontWeight: FontWeight.w400,
            fontFamily: 'SF Pro Display',
            letterSpacing: -1,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Все',
                isSelected: _filters.type == null,
                onTap: () => setState(() => _filters = _filters.copyWith(type: null)),
              ),
              const SizedBox(width: 12),
              _buildFilterChip(
                label: 'Групповая ',
                isSelected: _filters.type == 'group',
                onTap: () => setState(() => _filters = _filters.copyWith(type: 'group')),
              ),
              const SizedBox(width: 12),
              _buildFilterChip(
                label: 'Индивидуальная ',
                isSelected: _filters.type == 'individual',
                onTap: () => setState(() => _filters = _filters.copyWith(type: 'individual')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 37),
      child: ElevatedButton(
        onPressed: () {
          widget.onFiltersChanged(_filters);
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00897B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 0),
        ),
        child: const Text(
          'Смотреть результаты',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'SF Pro Display',
            letterSpacing: -1,
            height: 1.194,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 37,
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: isSelected ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF00897B) : const Color(0xFFD9D9D9),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF222223),
            fontSize: 16,
            fontWeight: FontWeight.w400,
            fontFamily: 'SF Pro Display',
            letterSpacing: -1,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}
