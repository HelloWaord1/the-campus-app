import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import '../models/training.dart';

class CalendarUtils {
  /// Добавить тренировку в календарь
  /// 
  /// Открывает нативный диалог календаря iOS/Android для добавления события
  static Future<bool> addTrainingToCalendar(Training training) async {
    try {
      // Время тренировки уже московское, конвертируем в локальное время устройства
      // без применения дополнительной timezone конвертации
      final localStartTime = DateTime(
        training.startTime.year,
        training.startTime.month,
        training.startTime.day,
        training.startTime.hour,
        training.startTime.minute,
      );
      
      final localEndTime = DateTime(
        training.endTime.year,
        training.endTime.month,
        training.endTime.day,
        training.endTime.hour,
        training.endTime.minute,
      );

      final Event event = Event(
        title: training.title,
        description: _buildEventDescription(training),
        location: '${training.clubName}, ${training.clubCity}${training.clubAddress != null ? ', ${training.clubAddress}' : ''}',
        startDate: localStartTime,
        endDate: localEndTime,
        iosParams: const IOSParams(
          reminder: Duration(hours: 1), // Напоминание за 1 час
          url: null,
        ),
        androidParams: const AndroidParams(
          emailInvites: [],
        ),
      );

      final result = await Add2Calendar.addEvent2Cal(event);
      return result;
    } catch (e) {
      debugPrint('Ошибка добавления тренировки в календарь: $e');
      return false;
    }
  }

  /// Построить описание события для календаря
  static String _buildEventDescription(Training training) {
    final buffer = StringBuffer();
    
    // Описание тренировки
    buffer.writeln(training.description);
    buffer.writeln();
    
    // Тип тренировки
    buffer.writeln('Тип: ${training.typeDisplayName}');
    
    // Тренер
    buffer.writeln('Тренер: ${training.trainerName}');
    
    // Уровень
    buffer.writeln('Уровень: ${training.minLevel.toStringAsFixed(1)}-${training.maxLevel.toStringAsFixed(1)}');
    
    // Цена
    buffer.writeln('Стоимость: ${training.price.toInt()}₽');
    
    // Участники (для групповых)
    if (training.isGroup) {
      buffer.writeln('Участников: ${training.currentParticipants}/${training.maxParticipants}');
    }
    
    return buffer.toString();
  }

  /// Форматировать дату для отображения
  static String formatEventDate(DateTime dateTime) {
    final weekdays = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    
    final weekday = weekdays[dateTime.weekday - 1];
    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$weekday, $day $month, $hour:$minute';
  }
}

