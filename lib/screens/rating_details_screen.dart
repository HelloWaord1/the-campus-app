import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'skill_level_test_screen.dart';

class RatingDetailsScreen extends StatelessWidget {
  final bool showRetestButton; // показывать кнопку "Пройти тест"

  const RatingDetailsScreen({super.key, this.showRetestButton = false});

  // Data for the rating levels
  final List<Map<String, String>> ratingLevels = const [
    {
      'level': 'A (5.00+)',
      'description':
          'Опытный профессионал, обладаю большим игровым опытом. Регулярно участвую в турнирах и занимаю призовые места.',
    },
    {
      'level': 'B+ (4.00 - 5.00)',
      'description':
          'Играю уверенно и агрессивно, хорошо ориентируюсь на корте, умею строить розыгрыши и провоцировать соперника на ошибки.',
    },
    {
      'level': 'B (3.50 - 4.00)',
      'description':
          'Уверенный игрок, понимаю тактику розыгрышей, владею основными ударами. Имею опыт участия хотя бы в одном официальном турнире.',
    },
    {
      'level': 'C+ (3.00 - 3.50)',
      'description':
          'Играю точно, контролирую удары. Стараюсь ускорять темп и взаимодействовать с партнёром на площадке.',
    },
    {
      'level': 'C (2.50 - 3.00)',
      'description':
          'Средний темп игры. Мяч, как правило, летит в нужном направлении. Стабильно подаю и играю с лёта.',
    },
    {
      'level': 'D+ (2.00 - 2.50)',
      'description':
          'Темп средний, не хватает точности. Периодически пытаюсь выходить к сетке, иногда отбиваю мячи от стекла.',
    },
    {
      'level': 'D (1.00 – 2.00)',
      'description':
          'Новичок, только начинаю играть. Предпочитаю оставаться у задней линии, тяжело отбивать отбивать мяч от стекла.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Уровни игры в падел',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF222223),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF89867E), size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: ratingLevels.length,
        itemBuilder: (context, index) {
          final item = ratingLevels[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: RatingLevelCard(
              level: item['level']!,
              description: item['description']!,
            ),
          );
        },
      ),
      bottomNavigationBar: showRetestButton
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final updated = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SkillLevelTestScreen(isRetestFlow: true),
                        ),
                      );
                      if (updated == true && Navigator.of(context).canPop()) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF262F63),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Пройти тест',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class RatingLevelCard extends StatelessWidget {
  final String level;
  final String description;

  const RatingLevelCard({
    super.key,
    required this.level,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          level,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Color(0xFF222223),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF222223),
            height: 1.25,
          ),
        ),
      ],
    );
  }
} 