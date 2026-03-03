import 'package:flutter/material.dart';

/// Виджет, отображающий сообщение об отсутствии свободного времени
class NoTimeAvailableWidget extends StatelessWidget {
  const NoTimeAvailableWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFD9D9D9),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Иконка часов
          SizedBox(
            width: 24,
            height: 24,
            child: Icon(
              Icons.access_time,
              size: 24,
              color: const Color(0xFF222223),
            ),
          ),
          const SizedBox(height: 12),
          // Текстовый блок с заголовком и подзаголовком
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              const Text(
                'Свободного времени нет',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF222223),
                  height: 1.222, // 22/18
                ),
              ),
              const SizedBox(height: 6),
              // Подзаголовок
              const Text(
                'Попробуйте выбрать другой день или время',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF222223),
                  height: 1.25, // 20/16
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

