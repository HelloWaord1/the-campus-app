import 'package:flutter/material.dart';

Future<TimeOfDay?> showCustomTimePicker(BuildContext context) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CustomTimePickerDialog(),
  );
}

class _CustomTimePickerDialog extends StatefulWidget {
  @override
  State<_CustomTimePickerDialog> createState() => _CustomTimePickerDialogState();
}

class _CustomTimePickerDialogState extends State<_CustomTimePickerDialog> {
  TimeOfDay? _selectedTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 685,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          // Header
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
                  'Время начала',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222223),
                    letterSpacing: -0.48,
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
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Time grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTimeRow(['8:00', '8:30', '9:00', '9:30', '10:00']),
                  const SizedBox(height: 12),
                  _buildTimeRow(['10:30', '11:00', '11:30', '12:00', '12:30']),
                  const SizedBox(height: 12),
                  _buildTimeRow(['13:00', '13:30', '14:00', '14:30', '15:00']),
                  const SizedBox(height: 12),
                  _buildTimeRow(['15:30', '16:00', '16:30', '17:00', '17:30']),
                  const SizedBox(height: 12),
                  _buildTimeRow(['18:00', '18:30', '19:00', '19:30', '20:00']),
                  const SizedBox(height: 12),
                  _buildTimeRow(['20:30', '21:00', '21:30', '22:00', '22:30']),
                  const SizedBox(height: 12),
                  _buildTimeRow(['23:00', '23:30', '', '', '']),
                ],
              ),
            ),
          ),
          
          // Done button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedTime == null ? null : () => Navigator.of(context).pop(_selectedTime),
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
                    color: _selectedTime == null ? Colors.white.withOpacity(0.4) : Colors.white,
                    letterSpacing: -0.32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow(List<String> times) {
    return Row(
      children: times.map((time) {
        if (time.isEmpty) return const Expanded(child: SizedBox());
        
        final timeOfDay = _parseTimeString(time);
        final isSelected = _selectedTime != null && 
                          _selectedTime!.hour == timeOfDay.hour && 
                          _selectedTime!.minute == timeOfDay.minute;
        
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTime = timeOfDay),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00897B) : const Color(0xFFD9D9D9),
                    width: isSelected ? 2 : 1,
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
                      color: Color(0xFF222223),
                      letterSpacing: -0.32,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  TimeOfDay _parseTimeString(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
} 