import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/booking.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';
import 'booking_details_screen.dart';

class AllBookingsScreen extends StatefulWidget {
  const AllBookingsScreen({super.key});

  @override
  State<AllBookingsScreen> createState() => _AllBookingsScreenState();
}

class _AllBookingsScreenState extends State<AllBookingsScreen> {
  List<Booking> _upcomingBookings = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Booking> allBookings;

      // Загружаем все будущие бронирования без ограничения по дате
      // Передаем только startDate (текущая дата), чтобы получить все будущие бронирования
      final now = DateTime.now();
      allBookings = await ApiService.getMyBookings(
        startDate: now,
      );
      final today = DateTime(now.year, now.month, now.day);

      setState(() {
        // Показываем только предстоящие бронирования (не отмененные, в будущем)
        // Без ограничения по времени - все будущие бронирования
        _upcomingBookings = allBookings.where((booking) {
          final bookingDate = DateTime(
            booking.bookingDate.year,
            booking.bookingDate.month,
            booking.bookingDate.day,
          );
          return booking.status != 'cancelled' && 
                 (bookingDate.isAfter(today) || bookingDate.isAtSameMomentAs(today));
        }).toList();

        _isLoading = false;
      });
    } catch (e, stackTrace) {
      Logger.error('Ошибка загрузки бронирований: $e', stackTrace);
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка загрузки бронирований')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/images/chevron_left.svg',
            width: 9,
            height: 16,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Мои бронирования',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2A2C36),
            height: 1.16,
            letterSpacing: -0.72,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBookingsList(_upcomingBookings, 'Нет предстоящих бронирований'),
    );
  }

  // Группируем бронирования по датам
  Map<String, List<Booking>> _groupBookingsByDate(List<Booking> bookings) {
    final Map<String, List<Booking>> grouped = {};
    
    for (var booking in bookings) {
      // Форматируем ключ даты с нулями для правильной сортировки (YYYY-MM-DD)
      final dateKey = '${booking.bookingDate.year}-'
          '${booking.bookingDate.month.toString().padLeft(2, '0')}-'
          '${booking.bookingDate.day.toString().padLeft(2, '0')}';
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(booking);
    }
    
    // Сортируем бронирования внутри каждой даты по времени начала
    for (var dateBookings in grouped.values) {
      dateBookings.sort((a, b) {
        // Сначала сравниваем по дате
        final dateCompare = a.bookingDate.compareTo(b.bookingDate);
        if (dateCompare != 0) return dateCompare;
        
        // Если даты одинаковые, сравниваем по времени начала
        final timeA = a.startTime.split(':');
        final timeB = b.startTime.split(':');
        final hourA = int.tryParse(timeA[0]) ?? 0;
        final minA = int.tryParse(timeA.length > 1 ? timeA[1] : '0') ?? 0;
        final hourB = int.tryParse(timeB[0]) ?? 0;
        final minB = int.tryParse(timeB.length > 1 ? timeB[1] : '0') ?? 0;
        
        if (hourA != hourB) return hourA.compareTo(hourB);
        return minA.compareTo(minB);
      });
    }
    
    return grouped;
  }
  
  String _formatDateHeader(DateTime date) {
    final weekdays = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    
    final weekday = weekdays[date.weekday - 1];
    final day = date.day;
    final month = months[date.month - 1];
    
    return '$weekday, $day $month';
  }

  Widget _buildBookingsList(List<Booking> bookings, String emptyMessage) {
    if (bookings.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF838A91),
            height: 1.25,
            letterSpacing: -0.32,
          ),
        ),
      );
    }

    // Группируем бронирования по датам
    final groupedBookings = _groupBookingsByDate(bookings);
    final sortedDates = groupedBookings.keys.toList()
      ..sort();

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: sortedDates.length * 2, // Дата + список бронирований для каждой даты
        itemBuilder: (context, index) {
          if (index.isEven) {
            // Заголовок даты
            final dateKey = sortedDates[index ~/ 2];
            final date = groupedBookings[dateKey]!.first.bookingDate;
            return Padding(
              padding: EdgeInsets.only(bottom: 12, top: index == 0 ? 0 : 24),
              child: Text(
                _formatDateHeader(date),
                style: const TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2A2C36),
                  height: 1.0,
                  letterSpacing: -0.80,
                ),
              ),
            );
          } else {
            // Список бронирований для этой даты
            final dateKey = sortedDates[index ~/ 2];
            final dateBookings = groupedBookings[dateKey]!;
            
            return Column(
              children: dateBookings.asMap().entries.map((entry) {
                final idx = entry.key;
                final booking = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: idx < dateBookings.length - 1 ? 8 : 0),
                  child: _buildBookingCard(booking),
                );
              }).toList(),
            );
          }
        },
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    // Форматируем дату
    final weekdays = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    
    final weekday = weekdays[booking.bookingDate.weekday - 1];
    final day = booking.bookingDate.day;
    final month = months[booking.bookingDate.month - 1];
    final formattedDate = '$weekday, $day $month';
    
    // Форматируем время (убираем секунды)
    final startTime = booking.startTime;
    final parts = startTime.split(':');
    final startHour = int.tryParse(parts.first) ?? 0;
    var minutes = parts.length > 1 ? parts[1] : '00';
    // Убираем секунды, если они есть
    if (minutes.length > 2) {
      minutes = minutes.substring(0, 2);
    }
    final endHour = (startHour + (booking.durationMin ~/ 60)) % 24;
    final formattedStart = '${startHour.toString().padLeft(2, '0')}:$minutes';
    final timeRange = '$formattedStart - ${endHour.toString().padLeft(2, '0')}:$minutes';
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BookingDetailsScreen(booking: booking),
          ),
        ).then((updated) {
          // Обновляем список при возврате, если было обновление
          if (updated == true) {
            _loadBookings();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF2A2C36),
                      height: 1.0,
                      letterSpacing: -0.80,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeRange,
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF2A2C36),
                      height: 1.0,
                      letterSpacing: -0.80,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    booking.clubName,
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF2A2C36),
                      height: 1.0,
                      letterSpacing: -0.64,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    booking.courtName ?? 'Корт не указан',
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF838A91),
                      height: 1.0,
                      letterSpacing: -0.56,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Вертикальный разделитель
            Container(
              width: 1,
              height: 110,
              color: const Color(0xFFD9D9D9),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 105,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/clock_icon.svg',
                    width: 21,
                    height: 21,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${booking.durationMin} мин',
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF2A2C36),
                      height: 1.0,
                      letterSpacing: -0.64,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

