import 'package:flutter/material.dart';

class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final double trackWidth;
  final double trackHeight;
  final double thumbSize;
  final Color activeTrackColor;
  final Color inactiveTrackColor;
  final Color inactiveOutlineColor;
  final Duration animationDuration;

  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.trackWidth = 50,
    this.trackHeight = 30,
    this.thumbSize = 26,
    this.activeTrackColor = const Color(0xFF262F63),
    this.inactiveTrackColor = const Color(0xFFEDEDED),
    this.inactiveOutlineColor = const Color(0xFFE0E0E0),
    this.animationDuration = const Duration(milliseconds: 180),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: trackWidth,
        height: trackHeight,
        child: AnimatedContainer(
          duration: animationDuration,
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: value ? activeTrackColor : inactiveTrackColor,
            borderRadius: BorderRadius.circular(trackHeight / 2),
            border: Border.all(
              color: value ? activeTrackColor : inactiveOutlineColor,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(1),
          child: AnimatedAlign(
            duration: animationDuration,
            curve: Curves.easeInOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: thumbSize,
              height: thumbSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: value
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 1,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



