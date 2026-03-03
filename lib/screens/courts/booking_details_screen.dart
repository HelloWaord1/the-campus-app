import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/booking.dart';
import '../../models/club.dart';
import '../../services/api_service.dart';
import '../../utils/notification_utils.dart';
import '../../utils/date_utils.dart' as date_utils;
import 'package:share_plus/share_plus.dart';
import '../../widgets/bottom_nav_bar.dart';

class BookingDetailsScreen extends StatefulWidget {
  final Booking booking;
  
  const BookingDetailsScreen({
    super.key,
    required this.booking,
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  bool _isCancelling = false;
  bool _isCancelled = false;
  Club? _club;
  bool _isClubLoading = false;

  @override
  void initState() {
    super.initState();
    // Если бронирование уже отменено, устанавливаем флаг
    _isCancelled = widget.booking.status == 'cancelled';
    _loadClub();
  }

  Future<void> _loadClub() async {
    setState(() {
      _isClubLoading = true;
    });

    try {
      final club = await ApiService.getClubById(widget.booking.clubId);
      if (!mounted) return;
      setState(() {
        _club = club;
        _isClubLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isClubLoading = false;
      });
    }
  }

  String _formatDate() {
    final weekdays = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    
    final weekday = weekdays[widget.booking.bookingDate.weekday - 1];
    final day = widget.booking.bookingDate.day;
    final month = months[widget.booking.bookingDate.month - 1];
    
    return '$weekday, $day $month';
  }

  String _formatTimeRange() {
    final startTime = widget.booking.startTime;
    final parts = startTime.split(':');
    final startHour = int.tryParse(parts.first) ?? 0;
    var minutes = parts.length > 1 ? parts[1] : '00';

    // Убираем секунды, если они есть (если формат HH:MM:SS, берем только HH:MM)
    if (minutes.length > 2) {
      minutes = minutes.substring(0, 2);
    }

    final endHour = (startHour + (widget.booking.durationMin ~/ 60)) % 24;

    final formattedStart = '${startHour.toString().padLeft(2, '0')}:$minutes';
    final formattedEnd = '${endHour.toString().padLeft(2, '0')}:$minutes';

    return '$formattedStart - $formattedEnd';
  }

  void _shareBooking() {
    final text = '''
Бронирование в ${widget.booking.clubName}
Корт: ${widget.booking.courtName ?? 'не указан'}
Дата: ${_formatDate()}
Время: ${_formatTimeRange()}
Продолжительность: ${widget.booking.durationMin} мин
''';
    Share.share(text);
  }

  Future<void> _cancelBooking() async {
    // Показываем нижнее меню подтверждения
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок с кнопкой закрытия
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Отменить бронирование?',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222223),
                      letterSpacing: -0.48,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0E0E0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFF89867E),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Вы уверены, что хотите отменить это бронирование?',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF222223),
                  height: 1.25,
                  letterSpacing: -0.32,
                ),
              ),
              const SizedBox(height: 32),
              // Кнопка "Отменить бронирование"
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC2D20),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Отменить бронирование',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Кнопка "Назад"
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F3F3),
                    foregroundColor: const Color(0xFF222223),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
            ),
                  child: const Text(
                    'Назад',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.32,
                    ),
                  ),
                ),
          ),
        ],
          ),
        ),
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    setState(() {
      _isCancelling = true;
    });
    
    try {
      final cancelRequest = BookingCancel(bookingId: widget.booking.id);
      await ApiService.cancelBooking(cancelRequest);
      
      if (!mounted) return;
      
      setState(() {
        _isCancelling = false;
        _isCancelled = true;
      });
    } catch (e) {
      if (!mounted) return;
      
        setState(() {
          _isCancelling = false;
        });
      
      NotificationUtils.showError(context, 'Ошибка отмены бронирования: $e');
  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Изображение клуба
                          Stack(
                            children: [
                      // Изображение
                              Container(
                                width: double.infinity,
                        height: 244,
                                decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          image: widget.booking.clubPhotoUrl != null
                                      ? DecorationImage(
                                  image: NetworkImage(widget.booking.clubPhotoUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                        child: widget.booking.clubPhotoUrl == null
                                    ? const Center(
                                        child: Icon(
                                          Icons.image,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                      )
                                    : null,
                              ),
                              
                      // Статус бар и кнопки навигации
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top,
                            left: 16,
                            right: 16,
                            bottom: 16,
                          ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Кнопка назад
                                      GestureDetector(
                                        onTap: () => Navigator.of(context).pop(),
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(32),
                                          ),
                                  child: const Center(
                                    child: Icon(
                                            Icons.chevron_left,
                                            size: 24,
                                            color: Color(0xFF838A91),
                                    ),
                                          ),
                                        ),
                                      ),
                                      
                                      // Кнопка поделиться
                                      GestureDetector(
                                        onTap: _shareBooking,
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(32),
                                          ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.share_outlined,
                                            size: 20,
                                            color: Color(0xFF838A91),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  // Информация о бронировании
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                        // Красный овал "Бронирование отменено"
                        if (_isCancelled)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEC2D20).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  'assets/images/booking_cancelled_icon.svg',
                                  width: 15,
                                  height: 15,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Бронирование отменено',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Display',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF000000),
                                    letterSpacing: -0.32,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Название клуба, адрес и описание
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                              widget.booking.clubName,
                                      style: const TextStyle(
                                        fontFamily: 'SF Pro Display',
                                        fontSize: 22,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF2A2C36),
                                        height: 1.18,
                                        letterSpacing: -0.44,
                                      ),
                                    ),
                            const SizedBox(height: 4),
                            if (widget.booking.clubCity != null)
                                      Text(
                                widget.booking.clubCity!,
                                        style: const TextStyle(
                                          fontFamily: 'SF Pro Display',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF2A2C36),
                                          height: 1.125,
                                          letterSpacing: -0.32,
                                        ),
                                      ),
                            if (_club?.description != null &&
                                _club!.description!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                _club!.description!.trim(),
                                style: const TextStyle(
                                  fontFamily: 'SF Pro Display',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF838A91),
                                  height: 1.3,
                                  letterSpacing: -0.28,
                                ),
                              ),
                            ],
                                  ],
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Разделитель
                                Container(
                                  height: 1,
                                  color: const Color(0xFFEBEBEB),
                                ),
                                
                        const SizedBox(height: 21),
                                
                                // Корт
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Корт',
                                      style: TextStyle(
                                        fontFamily: 'SF Pro Display',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF838A91),
                                height: 1.29,
                                      ),
                                    ),
                            const SizedBox(height: 6),
                                    Text(
                              widget.booking.courtName ?? 'Корт не указан',
                                      style: const TextStyle(
                                        fontFamily: 'SF Pro Display',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF2A2C36),
                                        height: 1.0,
                                        letterSpacing: -0.36,
                                      ),
                                    ),
                                  ],
                                ),
                                
                        const SizedBox(height: 19),
                                
                                // Разделитель
                                Container(
                                  height: 1,
                                  color: const Color(0xFFEBEBEB),
                                ),
                                
                        const SizedBox(height: 21.5),
                                
                        // Дата, время, продолжительность
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Дата
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Дата',
                                          style: TextStyle(
                                            fontFamily: 'SF Pro Display',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF838A91),
                                    height: 1.29,
                                          ),
                                        ),
                                const SizedBox(height: 7),
                                        Text(
                                          _formatDate(),
                                          style: const TextStyle(
                                            fontFamily: 'SF Pro Display',
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF2A2C36),
                                            height: 1.0,
                                            letterSpacing: -0.36,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                            const SizedBox(height: 17.5),
                                    
                                    // Время начала
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Время начала',
                                          style: TextStyle(
                                            fontFamily: 'SF Pro Display',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF838A91),
                                    height: 1.29,
                                          ),
                                        ),
                                const SizedBox(height: 7),
                                        Text(
                                          _formatTimeRange(),
                                          style: const TextStyle(
                                            fontFamily: 'SF Pro Display',
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF2A2C36),
                                            height: 1.0,
                                            letterSpacing: -0.36,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                            const SizedBox(height: 18.5),
                                    
                                    // Продолжительность
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Продолжительность',
                                          style: TextStyle(
                                            fontFamily: 'SF Pro Display',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF838A91),
                                    height: 1.29,
                                          ),
                                        ),
                                const SizedBox(height: 7),
                                        Text(
                                  '${widget.booking.durationMin} мин',
                                          style: const TextStyle(
                                            fontFamily: 'SF Pro Display',
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF2A2C36),
                                            height: 1.0,
                                            letterSpacing: -0.36,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                
                        const SizedBox(height: 32),
                        
                        // Кнопка "Отменить бронирование" (только если не отменено)
                        if (!_isCancelled)
                          SizedBox(
                              width: double.infinity,
                            height: 48,
                              child: ElevatedButton(
                                onPressed: _isCancelling ? null : _cancelBooking,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF0F0F0),
                                  foregroundColor: const Color(0xFFEC2D20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                elevation: 0,
                                disabledBackgroundColor: const Color(0xFFF0F0F0).withOpacity(0.5),
                                ),
                                child: _isCancelling
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFEC2D20),
                                        ),
                                      )
                                    : const Text(
                                        'Отменить бронирование',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro Display',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: -0.32,
                                        ),
                                      ),
                              ),
                            ),
                        
                        const SizedBox(height: 100), // Отступ для нижней панели
                      ],
                        ),
                      ),
                  ],
              ),
            ),
          ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTabTapped: (index) {
          // Возвращаемся на главную и переключаем на нужную вкладку
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
                ),
    );
  }
}
