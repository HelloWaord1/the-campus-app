import 'package:flutter/material.dart';

// Отдельный виджет для кнопки закрытия, используется во всех модальных окнах
class CustomCloseButton extends StatelessWidget {
  final VoidCallback onPressed;
  
  const CustomCloseButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFFAEAEAE),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.close,
          color: Color.fromARGB(255, 255, 255, 255),
          size: 20,
        ),
      ),
    );
  }
} 