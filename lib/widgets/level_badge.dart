import 'package:flutter/material.dart';
import '../utils/rating_utils.dart';

class LevelBadge extends StatelessWidget {
  final String? ntrpLevel;
  final int? score; // Изменяем на score для расчета рейтинга
  final VoidCallback? onTap;
  final int? totalMatches;
  final int? wins;
  final int? losses;
  
  const LevelBadge({
    Key? key, 
    this.ntrpLevel, 
    this.score, 
    this.onTap, 
    this.totalMatches,
    this.wins,
    this.losses,
  }) : super(key: key);

  // Метод для получения отдельного блока статистики
  Widget? getStatsCard() {
    if (ntrpLevel != null && ntrpLevel!.isNotEmpty && score != null) {
      return null; // Статистика уже в основной карточке
    }
    return _buildStatsCard();
  }

  @override
  Widget build(BuildContext context) {
    final hasRating = ntrpLevel != null && ntrpLevel!.isNotEmpty && score != null;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: hasRating ? 210 : 190,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Фоновое изображение
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/rating_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
            // Градиент поверх изображения
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x0A000000),
                      Color(0x2A000000),
                      Color(0xAA000000),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            
            // Контент
            Positioned(
              left: 16,
              right: 16,
              bottom: 20, // Одинаковый отступ от низа для обеих карточек
              child: hasRating ? _buildWithRating() : _buildWithoutRating(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithRating() {
    final reliability = getReliability(totalMatches ?? 0);
    final reliabilityString = reliability.toStringAsFixed(2);
    
    String reliabilityLevel;
    Color reliabilityColor;
    
    if (reliability < 30) {
      reliabilityLevel = 'Низкий';
      reliabilityColor = const Color(0xFFFF6B6B); // Красный
    } else if (reliability >= 30 && reliability < 70) {
      reliabilityLevel = 'Средний';
      reliabilityColor = const Color(0xFFF98213); // Оранжевый
    } else {
      reliabilityLevel = 'Высокий';
      reliabilityColor = const Color(0xFF0BAB53); // Зеленый
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Уровень и рейтинг на одной строке (как в макете)
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Text(
                    'Уровень',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -0.56,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ntrpLevel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -0.56,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    calculateRating(score!).toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -0.56,
                    ),
                  ),
                ],
              ),
            ),
            // Стрелка справа
            Container(
              width: 24,
              height: 24,
              child: const Icon(
                Icons.keyboard_arrow_right,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 2),
        
        // Уровень надежности
        Row(
          children: [
            const Text(
              'Уровень надежности:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontFamily: 'SF Pro Display',
                letterSpacing: -0.28,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$reliabilityString%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'SF Pro Display',
                letterSpacing: -0.28,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: reliabilityColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                reliabilityLevel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'SF Pro Display',
                  letterSpacing: -0.28,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 10),
        
        // Разделитель
        Container(
          height: 1,
          color: Colors.white.withOpacity(0.3),
        ),
        
        const SizedBox(height: 10),
        
        // Статистика матчей с одинаковой шириной блоков
        Row(
          children: [
            Expanded(
              child: _buildStatItem('${totalMatches ?? 0} Матчей'),
            ),
            Container(
              width: 1,
              height: 24,
              color: Colors.white.withOpacity(0.3),
            ),
            Expanded(
              child: _buildStatItem('${wins ?? 0} Побед'),
            ),
            Container(
              width: 1,
              height: 24,
              color: Colors.white.withOpacity(0.3),
            ),
            Expanded(
              child: _buildStatItem('${losses ?? 0} Проигрыша'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWithoutRating() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Определить уровень',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'SF Pro Display',
                  letterSpacing: -0.56,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ответь на вопросы — и мы\nподберём тебе уровень.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'SF Pro Display',
                  letterSpacing: -0.28,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 24,
          height: 24,
          child: const Icon(
            Icons.keyboard_arrow_right,
            color: Colors.white,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        fontFamily: 'Basis Grotesque Arabic Pro',
        letterSpacing: -0.3,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStatsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE7E9EB),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  '${totalMatches ?? 0}',
                  style: const TextStyle(
                    color: Color(0xFF222223),
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.44,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Матчей',
                  style: TextStyle(
                    color: Color(0xFF222223),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: const Color(0xFFD9D9D9),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${wins ?? 0}',
                  style: const TextStyle(
                    color: Color(0xFF222223),
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.44,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Побед',
                  style: TextStyle(
                    color: Color(0xFF222223),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: const Color(0xFFD9D9D9),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${losses ?? 0}',
                  style: const TextStyle(
                    color: Color(0xFF222223),
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.44,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Проигрыша',
                  style: TextStyle(
                    color: Color(0xFF222223),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 