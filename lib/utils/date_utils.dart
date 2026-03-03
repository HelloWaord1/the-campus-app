/// Утилиты для работы с датами и их форматирования
class DateUtils {
  /// Названия дней недели (начиная с понедельника)
  static const List<String> weekdayNames = [
    'ПН',
    'ВТ',
    'СР',
    'ЧТ',
    'ПТ',
    'СБ',
    'ВС'
  ];

  /// Названия дней недели (начиная с воскресенья)
  static const List<String> weekdayNamesFromSunday = [
    'ВС',
    'ПН',
    'ВТ',
    'СР',
    'ЧТ',
    'ПТ',
    'СБ'
  ];

  /// Названия месяцев в сокращенной форме
  static const List<String> monthNames = [
    'Янв',
    'Февр',
    'Март',
    'Апр',
    'Май',
    'Июнь',
    'Июль',
    'Авг',
    'Сен',
    'Окт',
    'Нояб',
    'Дек'
  ];

  /// Названия месяцев в полной форме (именительный падеж)
  static const List<String> monthNamesFull = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь'
  ];

  /// Названия месяцев в короткой форме (для форматирования даты)
  static const List<String> monthNamesShort = [
    'янв',
    'фев',
    'мар',
    'апр',
    'май',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек'
  ];

  /// Названия дней недели в смешанном регистре (начиная с понедельника)
  static const List<String> weekdayNamesMixedCase = [
    'Пн',
    'Вт',
    'Ср',
    'Чт',
    'Пт',
    'Сб',
    'Вс'
  ];

  /// Получить название дня недели по индексу (1 = понедельник, 7 = воскресенье)
  static String getWeekdayName(int weekday) {
    if (weekday < 1 || weekday > 7) {
      throw ArgumentError('weekday must be between 1 and 7');
    }
    return weekdayNames[weekday - 1];
  }

  /// Получить название дня недели по индексу (0 = воскресенье, 6 = суббота)
  static String getWeekdayNameFromSunday(int weekday) {
    if (weekday < 0 || weekday > 6) {
      throw ArgumentError('weekday must be between 0 and 6');
    }
    return weekdayNamesFromSunday[weekday];
  }

  /// Получить название месяца по индексу (1-12)
  static String getMonthName(int month) {
    if (month < 1 || month > 12) {
      throw ArgumentError('month must be between 1 and 12');
    }
    return monthNames[month - 1];
  }

  /// Получить полное название месяца по индексу (1-12)
  static String getMonthNameFull(int month) {
    if (month < 1 || month > 12) {
      throw ArgumentError('month must be between 1 and 12');
    }
    return monthNamesFull[month - 1];
  }

  /// Форматирует дату в формат "Вт, 12 июн, 10:00"
  /// Возвращает "Дата не указана" в случае ошибки
  static String formatMatchDate(DateTime dateTime) {
    try {
      final local = dateTime.toLocal();
      final weekday = weekdayNamesMixedCase[local.weekday - 1];
      final day = local.day;
      final month = monthNamesShort[local.month - 1];
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '$weekday, $day $month, $hour:$minute';
    } catch (e) {
      return 'Дата не указана';
    }
  }

  /// Преобразует локальное время в UTC, интерпретируя локальное время как UTC
  /// 
  /// Например: если локальное время 10:00 (MSK, UTC+3), 
  /// результат будет 10:00 UTC (а не 07:00 UTC)
  /// 
  /// Это используется для корректного сравнения времени матчей,
  /// когда сервер работает в UTC, но время отображается локально
  static DateTime localTimeAsUtc(DateTime localTime) {
    final offset = localTime.timeZoneOffset;
    return localTime.toUtc().add(offset);
  }
}

