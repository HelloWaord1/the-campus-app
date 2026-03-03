import 'package:flutter/material.dart';

Future<DateTime?> showCustomDatePicker(BuildContext context) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CustomDatePickerDialog(),
  );
}

class _CustomDatePickerDialog extends StatefulWidget {
  @override
  State<_CustomDatePickerDialog> createState() => _CustomDatePickerDialogState();
}

class _CustomDatePickerDialogState extends State<_CustomDatePickerDialog> {
  DateTime? _selectedDate;
  late DateTime _currentMonth;
  
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 510,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          // Header - 76px height with exact spacing from Figma
          Container(
            height: 76,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFCCCCCC), width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 66),
                const Text(
                  'Дата начала',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222223),
                    letterSpacing: -0.48,
                    height: 1.5,
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(right: 16),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFAEAEAE),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Month name - exact positioning from Figma
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Text(
                  _getMonthName(_currentMonth),
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222223),
                    letterSpacing: -0.48,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Calendar grid with exact spacing from Figma
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                children: [
                  // Weekday headers - exact styling from Figma
                  Row(
                    children: ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'].map((day) =>
                      Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF222223),
                              letterSpacing: 0.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      )
                    ).toList(),
                  ),
                  
                  // Calendar with exact spacing
                  Expanded(child: _buildCalendarGrid()),
                ],
              ),
            ),
          ),
          
          // Done button with exact spacing from Figma
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedDate == null ? null : () => Navigator.of(context).pop(_selectedDate),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.disabled)) {
                      return const Color(0xFF7F8AC0);
                    }
                    return const Color(0xFF00897B);
                  }),
                  shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  elevation: MaterialStateProperty.all(0),
                ),
                child: Text(
                  'Готово',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _selectedDate == null ? Colors.white.withOpacity(0.4) : Colors.white,
                    letterSpacing: -0.32,
                    height: 1.193359375,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday;
    
    // Calculate start date (previous month days)
    final startDate = firstDayOfMonth.subtract(Duration(days: firstWeekday - 1));
    
    List<Widget> weeks = [];
    
    for (int week = 0; week < 6; week++) {
      List<Widget> days = [];
      
      for (int day = 0; day < 7; day++) {
        final currentDate = startDate.add(Duration(days: week * 7 + day));
        final isCurrentMonth = currentDate.month == _currentMonth.month;
        final isSelected = _selectedDate != null &&
                          currentDate.year == _selectedDate!.year &&
                          currentDate.month == _selectedDate!.month &&
                          currentDate.day == _selectedDate!.day;
        final isToday = currentDate.year == DateTime.now().year &&
                       currentDate.month == DateTime.now().month &&
                       currentDate.day == DateTime.now().day;
        
        days.add(
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
                });
              },
              child: Container(
                height: 40,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF00897B) : Colors.transparent,
                      borderRadius: BorderRadius.circular(isSelected ? 8 : 20),
                      border: isToday && !isSelected
                          ? Border.all(color: const Color(0xFF6750A4), width: 1)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        currentDate.day.toString(),
                        style: TextStyle(
                          fontFamily: isSelected ? 'Roboto' : 'SF Pro Display',
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.w400 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : isToday && !isSelected
                                  ? const Color(0xFF6750A4)
                                  : isCurrentMonth
                                      ? const Color(0xFF222223)
                                      : const Color(0xFFBCBCBE),
                          letterSpacing: 0.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      
      weeks.add(Row(children: days));
    }
    
    return Column(
      children: weeks.map((week) => 
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 0),
          child: week,
        )
      ).toList(),
    );
  }

  String _getMonthName(DateTime date) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return months[date.month - 1];
  }
}
