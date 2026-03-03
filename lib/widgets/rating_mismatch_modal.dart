import 'package:flutter/material.dart';

class RatingMismatchModal extends StatelessWidget {
  const RatingMismatchModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              height: 76,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                children: [
                  // Заголовок (слева)
                  const Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Участие недоступно',
                        style: TextStyle(
                          color: Color(0xFF222223),
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'SF Pro Display',
                          letterSpacing: -2, // -2% от 24px
                          height: 1.5,
                        ),
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
                        onTap: () => Navigator.of(context).pop(),
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
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 0),
                  const Padding(
                    padding: EdgeInsets.only(right: 100),
                    child: Text(
                      'Вы не можете принять участие в этой тренировке, так как ваш уровень не соответствует требованиям.',
                      style: TextStyle(
                        color: Color(0xFF222223),
                        fontSize: 14.4,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -1.2, // -2% от 16px
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF262F63),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Готов',
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 14.4,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'SF Pro Display',
                          letterSpacing: -0.32,
                          height: 1.193359375,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const RatingMismatchModal(),
    );
  }
}

