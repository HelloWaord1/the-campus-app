String scoreToNtrpLetter(int score) {
  // Шкала на основе нормализованных 0-20 баллов из Figma
  if (score <= 7) return 'D';
  if (score <= 11) return 'D+';
  if (score <= 13) return 'C';
  if (score <= 15) return 'C+';
  if (score <= 17) return 'B';
  if (score <= 19) return 'B+';
  return 'A'; // score 20
}

double scoreToNumericRating(int score) {
  // Шкала на основе нормализованных 0-20 баллов из Figma
  // if (score <= 4) return 1.0;
  // if (score <= 7) return 1.5;
  // if (score <= 9) return 2.0;
  // if (score <= 11) return 2.5;
  // if (score <= 13) return 3.0;
  // if (score <= 15) return 3.5;
  // if (score <= 17) return 4.0;
  // if (score <= 19) return 4.5;
  return calculateRating((700 + ((score - 6) / 24) * 900).round());
}

/// Рассчитывает балл для конкретного ответа.
/// Для нового вопроса (index 3) используется кастомная шкала.
int mapAnswerToScore(int questionIndex, int answerIndex) {
  // Для вопроса про квадранты (индекс 3) с 3 вариантами
  if (questionIndex == 3) {
    switch (answerIndex) {
      case 0: // Да
        return 5;
      case 1: // Нет
        return 1;
      case 2: // Не до конца
        return 3;
      default:
        return 1;
    }
  }
  // Для всех остальных вопросов (5 вариантов)
  else {
    return answerIndex + 1; // 1-5 баллов
  }
}

/// Нормализует сырой балл (6-30) к шкале 0-20.
int normalizeScore(int rawScore) {
  // Вычитаем 6, чтобы сдвинуть диапазон к 0-24
  final shiftedScore = rawScore - 6;
  // Масштабируем 0-24 -> 0-20, умножая на 20/24 = 5/6
  final normalized = (shiftedScore * 5 / 6).round();
  return normalized;
}

/// Рассчитывает рейтинг по равномерной шкале
/// 600 -> 1.00, 2000 -> 5.00
double calculateRating(int score) {
  if (score < 600) return 1.0;
  if (score > 2000) return 5.0;
  
  // Равномерная шкала: 600 -> 1.00, 2000 -> 5.00
  return 1.0 + (score - 600) * 4.0 / (2000 - 600);
}

/// Преобразует числовой рейтинг (1.0-5.0) в буквенное обозначение
String ratingToLetter(double rating) {
  if (rating < 2.0) return 'D';
  if (rating < 3.0) return 'D+';
  if (rating < 3.5) return 'C';
  if (rating < 4.0) return 'C+';
  if (rating < 4.7) return 'B';
  if (rating < 5.0) return 'B+';
  return 'A';
}

double getReliability(int matches) {
  if (matches <= 0) {
    return 0;
  }
  if (matches >= 40) {
    return 100;
  }

  const reliabilityMap = {
    1: 10.0,
    2: 12.31,
    3: 14.62,
    4: 16.92,
    5: 19.23,
    6: 21.54,
    7: 23.85,
    8: 26.15,
    9: 28.46,
    10: 30.77,
    11: 33.08,
    12: 35.38,
    13: 37.69,
    14: 40.0,
    15: 42.31,
    16: 44.62,
    17: 46.92,
    18: 49.23,
    19: 51.54,
    20: 53.85,
    21: 56.15,
    22: 58.46,
    23: 60.77,
    24: 63.08,
    25: 65.38,
    26: 67.69,
    27: 70.0,
    28: 72.31,
    29: 74.62,
    30: 76.92,
    31: 79.23,
    32: 81.54,
    33: 83.85,
    34: 86.15,
    35: 88.46,
    36: 90.77,
    37: 93.08,
    38: 95.38,
    39: 97.69,
  };

  return reliabilityMap[matches] ?? 0;
} 