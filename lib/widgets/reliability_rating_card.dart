import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../utils/rating_utils.dart';

class ReliabilityRatingCard extends StatelessWidget {
  final String? ntrpLevel;
  final double? rating;
  final int? reliability; // 0-100
  final int? pendingReviewCount;
  final int totalMatches;
  final int wins;
  final int losses;
  final VoidCallback? onTap;

  const ReliabilityRatingCard({
    super.key,
    this.ntrpLevel,
    this.rating,
    this.reliability,
    this.pendingReviewCount,
    required this.totalMatches,
    required this.wins,
    required this.losses,
    this.onTap,
  });

  String _getReliabilityText() {
    if (reliability == null) return 'Нет данных';
    if (reliability! >= 75) return 'Высокий';
    if (reliability! >= 50) return 'Средний';
    return 'Низкий';
  }

  Color _getReliabilityColor() {
    if (reliability == null) return const Color(0xFF89867E);
    if (reliability! >= 75) return const Color(0xFF0BAB53);
    if (reliability! >= 50) return const Color(0xFFFFA500);
    return const Color(0xFFFF6B6B);
  }

  // Русская плюрализация: 1 матч, 2 матча, 5 матчей
  String _pluralize(int value, String form1, String form2, String form5) {
    final n = value.abs() % 100;
    final n1 = n % 10;
    if (n > 10 && n < 20) return form5;
    if (n1 == 1) return form1;
    if (n1 >= 2 && n1 <= 4) return form2;
    return form5;
  }

  String _matchesText(int value) => _pluralize(value, 'матч', 'матча', 'матчей');
  String _winsText(int value) => _pluralize(value, 'победа', 'победы', 'побед');
  String _lossesText(int value) => _pluralize(value, 'поражение', 'поражения', 'поражений');

  @override
  Widget build(BuildContext context) {
    final reliabilityText = _getReliabilityText();
    final reliabilityColor = _getReliabilityColor();
    final reviewCount = pendingReviewCount ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 370,
        height: 245,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFFF7F7F7),
        ),
        child: Stack(
          children: [
            // Background image with gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/level_card_background-4d94d8.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.5),
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.31, 0.51, 0.75],
                    ),
                  ),
                ),
              ),
            ),

            // Content
            Positioned(
              left: 16,
              right: 16,
              top: 102,
              child: SizedBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Level and rating
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Уровень',
                              style: const TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 28,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                letterSpacing: -0.56,
                                height: 1.143,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              rating != null ? ratingToLetter(rating!) : '-',
                              style: const TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 28,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                letterSpacing: -0.56,
                                height: 1.143,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating != null ? rating!.toStringAsFixed(2) : '0.00',
                              style: const TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 28,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                letterSpacing: -0.56,
                                height: 1.143,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        // Reliability info and percentage circle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Reliability info
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Рейтинг надежности:',
                                      style: const TextStyle(
                                        fontFamily: 'SF Pro Display',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                        letterSpacing: -0.32,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: reliabilityColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        reliabilityText,
                                        style: const TextStyle(
                                          fontFamily: 'SF Pro Display',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                          letterSpacing: -0.28,
                                          height: 1.429,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 0),
                                Opacity(
                                  opacity: 0.7,
                                  child: Text(
                                    'На основе $reviewCount оценок',
                                    style: const TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white,
                                      letterSpacing: -0.28,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            // Percentage circle
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: CustomPaint(
                                painter: _ReliabilityCirclePainter(
                                  reliability: reliability ?? 0,
                                ),
                                child: Center(
                                  child: Text(
                                    '${reliability ?? 0}%',
                                    style: const TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: -0.24,
                                      height: 1.333,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Divider
                    Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                              '$totalMatches ${_matchesText(totalMatches)}',
                                style: const TextStyle(
                                  fontFamily: 'Basis Grotesque Arabic Pro',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$wins ${_winsText(wins)}',
                                style: const TextStyle(
                                  fontFamily: 'Basis Grotesque Arabic Pro',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$losses ${_lossesText(losses)}',
                                style: const TextStyle(
                                  fontFamily: 'Basis Grotesque Arabic Pro',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReliabilityCirclePainter extends CustomPainter {
  final int reliability;

  _ReliabilityCirclePainter({required this.reliability});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle (stroke only, transparent center)
    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius - 2, backgroundPaint);

    // Progress circle
    final progressPaint = Paint()
      ..color = const Color(0xFF0BAB53)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * (reliability / 100);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

