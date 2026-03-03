import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class CustomDatePickerSheet extends StatefulWidget {
  final DateTime? initialDate;

  const CustomDatePickerSheet({super.key, this.initialDate});

  @override
  _CustomDatePickerSheetState createState() => _CustomDatePickerSheetState();
}

class _CustomDatePickerSheetState extends State<CustomDatePickerSheet> {
  late DateTime _selectedDate;
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ru');
    _selectedDate = widget.initialDate ?? DateTime.now();
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildCalendar(),
          const SizedBox(height: 24),
          _buildDoneButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Text(
          'Дата начала',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Color(0xFF79766E), size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    String monthName = DateFormat('LLLL', 'ru').format(_currentMonth);
    monthName = monthName[0].toUpperCase() + monthName.substring(1);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Color(0xFF222223)),
              onPressed: _previousMonth,
            ),
            Text(
              monthName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Color(0xFF222223)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Color(0xFF222223)),
              onPressed: _nextMonth,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildWeekdays(),
        const SizedBox(height: 8),
        _buildCalendarGrid(),
      ],
    );
  }

  Widget _buildWeekdays() {
    const weekdays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekdays.map((day) => Text(day, style: const TextStyle(color: Color(0xFF79766E), fontSize: 14, fontWeight: FontWeight.w400))).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final today = DateUtils.dateOnly(DateTime.now());
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final weekdayOfFirstDay = firstDayOfMonth.weekday;
    final int emptyCells = weekdayOfFirstDay - 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
        mainAxisSpacing: 4.0,
        crossAxisSpacing: 4.0,
      ),
      itemCount: daysInMonth + emptyCells,
      itemBuilder: (context, index) {
        if (index < emptyCells) {
          return Container(); // Empty cell
        }

        final dayNumber = index - emptyCells + 1;
        final date = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);

        final isSelected = DateUtils.isSameDay(_selectedDate, date);
        final isToday = DateUtils.isSameDay(today, date);
        final isPast = date.isBefore(today);

        BoxDecoration decoration = const BoxDecoration(shape: BoxShape.circle);
        TextStyle textStyle = TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: isPast ? const Color(0xFFD1D1D1) : const Color(0xFF222223),
        );
        
        if (isSelected) {
          decoration = const BoxDecoration(
            color: Color(0xFF00897B),
            shape: BoxShape.circle,
          );
          textStyle = const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500);
        } else if (isToday) {
          decoration = BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF00897B)),
          );
          textStyle = const TextStyle(fontSize: 16, color: Color(0xFF00897B), fontWeight: FontWeight.w500);
        }

        return GestureDetector(
          onTap: isPast ? null : () => setState(() => _selectedDate = date),
          child: Container(
            decoration: decoration,
            child: Center(
              child: Text(
                '$dayNumber',
                style: textStyle,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDoneButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00897B),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => Navigator.of(context).pop(_selectedDate),
      child: const Text('Готово', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }
} 