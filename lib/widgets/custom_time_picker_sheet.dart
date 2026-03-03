import 'package:flutter/material.dart';

class CustomTimePickerSheet extends StatefulWidget {
  final TimeOfDay? initialTime;
  final int? initialDuration;

  const CustomTimePickerSheet(
      {super.key, this.initialTime, this.initialDuration});

  @override
  _CustomTimePickerSheetState createState() => _CustomTimePickerSheetState();
}

class _CustomTimePickerSheetState extends State<CustomTimePickerSheet> {
  late int _selectedHour;
  late int _selectedMinute;
  late int _selectedDuration;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  final List<int> _durations = [60, 90, 120];

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime?.hour ?? TimeOfDay.now().hour;
    _selectedMinute = widget.initialTime?.minute ?? TimeOfDay.now().minute;
    _selectedDuration = widget.initialDuration ?? 90;

    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
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
          const SizedBox(height: 6),
          _buildHeader(),
          const SizedBox(height: 23),
          Container(height: 1, color: const Color(0xFFD9D9D9)),
          _buildTimePicker(),
          // const SizedBox(height: 12),
          _buildDurationSelector(),
          const SizedBox(height: 30),
          _buildDoneButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Text('Время начала', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, letterSpacing: -0.48)),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFFF2F2F2), shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Color(0xFF79766E), size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker() {
    return SizedBox(
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 36, // Matches itemExtent
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              _buildPickerColumn(
                controller: _hourController,
                itemCount: 24,
                onSelectedItemChanged: (index) =>
                    setState(() => _selectedHour = index),
              ),
              _buildPickerColumn(
                controller: _minuteController,
                itemCount: 60,
                onSelectedItemChanged: (index) =>
                    setState(() => _selectedMinute = index),
              ),
            ],
          ),
         ),
        ],
      ),
    );
  }

  Widget _buildPickerColumn({
    required FixedExtentScrollController controller,
    required int itemCount,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    return Expanded(
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 32,
        perspective: 0.005,
        diameterRatio: 1.2,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onSelectedItemChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) => Center(
            child: Text(
              index.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 25,
                fontWeight: FontWeight.w400,
                color: Color(0xFF222223),
              ),
            ),
          ),
          childCount: itemCount,
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Продолжительность', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 16, color: Color(0xFF79766E), fontWeight: FontWeight.w400, letterSpacing: -0.32)),
        const SizedBox(height: 12),
        Row(
              children: _durations
              .map((duration) => Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: _buildDurationButton(duration),
                    ),
                  )
              .toList(),
            ),
        ],
    );
  }

  Widget _buildDurationButton(int duration) {
    final isSelected = _selectedDuration == duration;
    return GestureDetector(
      onTap: () => setState(() => _selectedDuration = duration),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF262F63) : const Color(0xFFD9D9D9),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            '$duration мин',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 16,
              color: const Color(0xFF222223),
              fontWeight: FontWeight.w400,
              letterSpacing: -0.32,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoneButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF262F63),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        final result = {
          'time': TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
          'duration': _selectedDuration,
        };
        Navigator.of(context).pop(result);
      },
      child: const Text('Готово', style: TextStyle(fontFamily: 'SF Pro Display', color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: -0.32)),
    );
  }
} 