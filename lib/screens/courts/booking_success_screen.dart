import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../models/club.dart';
import '../../models/booking.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';
import '../../utils/booking_error_handler.dart';
import '../../utils/phone_utils.dart';
import '../../utils/notification_utils.dart';
import '../../utils/responsive_utils.dart';
import '../home_screen.dart';
import 'club_details_screen.dart';

class BookingSuccessScreen extends StatefulWidget {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final int selectedDuration;
  final Club club;
  final String? bookingId; // Добавляем ID бронирования для возможности отмены

  const BookingSuccessScreen({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedDuration,
    required this.club,
    this.bookingId,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> {
  final int _currentIndex = 0;
  bool _isCancelling = false;

  String _formatSelectedDate(DateTime date) {
    final weekday = date.weekday;
    final day = date.day;
    final month = date.month;

    String dayOfWeekStr;
    switch (weekday) {
      case 1: dayOfWeekStr = 'Понедельник'; break;
      case 2: dayOfWeekStr = 'Вторник'; break;
      case 3: dayOfWeekStr = 'Среда'; break;
      case 4: dayOfWeekStr = 'Четверг'; break;
      case 5: dayOfWeekStr = 'Пятница'; break;
      case 6: dayOfWeekStr = 'Суббота'; break;
      case 7: dayOfWeekStr = 'Воскресенье'; break;
      default: dayOfWeekStr = '';
    }

    String monthStr;
    switch (month) {
      case 1: monthStr = 'января'; break;
      case 2: monthStr = 'февраля'; break;
      case 3: monthStr = 'марта'; break;
      case 4: monthStr = 'апреля'; break;
      case 5: monthStr = 'мая'; break;
      case 6: monthStr = 'июня'; break;
      case 7: monthStr = 'июля'; break;
      case 8: monthStr = 'августа'; break;
      case 9: monthStr = 'сентября'; break;
      case 10: monthStr = 'октября'; break;
      case 11: monthStr = 'ноября'; break;
      case 12: monthStr = 'декабря'; break;
      default: monthStr = '';
    }
    return '$dayOfWeekStr, $day $monthStr';
  }

  Future<void> _cancelBooking() async {
    if (widget.bookingId == null) {
      Logger.warning('Попытка отмены бронирования без ID');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID бронирования не найден'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    try {
      Logger.info('Отмена бронирования: bookingId=${widget.bookingId}');
      
      final cancelData = BookingCancel(bookingId: widget.bookingId!);
      await ApiService.cancelBooking(cancelData);
      
      Logger.success('Бронирование успешно отменено: ID=${widget.bookingId}');
      
      if (mounted) {
        NotificationUtils.showSuccess(context, 'Бронирование успешно отменено');
        
        // Переходим на карточку клуба
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ClubDetailsScreen(club: widget.club),
          ),
        );
      }
    } catch (e, stackTrace) {
      Logger.bookingError('Отмена бронирования в BookingSuccessScreen', e, stackTrace);
      
      if (mounted) {
        final errorMessage = BookingErrorHandler.getUserFriendlyMessage(e);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отмены бронирования: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  Future<void> _showCancelConfirmationDialog() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCancelConfirmationModal(),
    );
    
    if (result == true) {
      _cancelBooking();
    }
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(initialTabIndex: index),
        ),
      );
    }
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: isActive ? const Color(0xFF262F63) : const Color(0xFF89867E),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? const Color(0xFF262F63) : const Color(0xFF89867E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            child: Column(
              children: [
                // Hero image
                Container(
                  width: double.infinity,
                  height: 239,
                  decoration: BoxDecoration(
                    image: widget.club.photoUrl != null && widget.club.photoUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(widget.club.photoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: widget.club.photoUrl == null || widget.club.photoUrl!.isEmpty
                        ? const Color(0xFFE0E0E0)
                        : null,
                  ),
                  child: widget.club.photoUrl == null || widget.club.photoUrl!.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.sports_tennis,
                            size: 64,
                            color: Color(0xFF9E9E9E),
                          ),
                        )
                      : null,
                ),
                
                // Content section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Club info section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.club.name,
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF222223),
                              letterSpacing: -0.36,
                            ),
                          ),
                          Text(
                            widget.club.address.isNotEmpty ? widget.club.address : (widget.club.city ?? 'Адрес не указан'),
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF222223),
                              letterSpacing: -0.28,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.club.description ?? 'Описание отсутствует',
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF79766E),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 18),
                      
                      // Divider
                      Container(
                        height: 1,
                        color: const Color(0xFFEBEBEB),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Booking success section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Заявка на игру',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF222223),
                              letterSpacing: -0.36,
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Success notification
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5F1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF262F63),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Заявка успешно отправлена',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro Display',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF222223),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(left: 32),
                                  child: Text(
                                    'В ближайшее время с вами свяжется администратор клуба.',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF222223),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Booking details
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Дата',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF79766E),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatSelectedDate(widget.selectedDate),
                                    style: const TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF222223),
                                      letterSpacing: -0.36,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Time
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Время начала',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF79766E),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.selectedTime.format(context),
                                    style: const TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF222223),
                                      letterSpacing: -0.36,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Duration
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Продолжительность',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF79766E),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${widget.selectedDuration} мин',
                                    style: const TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF222223),
                                      letterSpacing: -0.36,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Action buttons
                          Column(
                            children: [
                              // Call club button
                              GestureDetector(
                                onTap: widget.club.phone != null && widget.club.phone!.isNotEmpty
                                    ? () {
                                        PhoneUtils.showPhoneNumberDialog(
                                          context,
                                          widget.club.name,
                                          widget.club.phone!,
                                        );
                                      }
                                    : null,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: widget.club.phone != null && widget.club.phone!.isNotEmpty
                                        ? const Color(0xFFF0F0F0)
                                        : const Color(0xFFF0F0F0).withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    widget.club.phone != null && widget.club.phone!.isNotEmpty
                                        ? 'Позвонить в клуб'
                                        : 'Телефон не указан',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: widget.club.phone != null && widget.club.phone!.isNotEmpty
                                          ? const Color(0xFF222223)
                                          : const Color(0xFF222223).withOpacity(0.5),
                                      letterSpacing: -0.32,
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Cancel booking button
                              GestureDetector(
                                onTap: _isCancelling ? null : _showCancelConfirmationDialog,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F0F0),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _isCancelling ? 'Отмена...' : 'Отменить заявку',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: _isCancelling 
                                          ? const Color(0xFF79766E)
                                          : const Color(0xFFEC2D20),
                                      letterSpacing: -0.32,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Back button overlay
          Positioned(
            top: 54,
            left: 16,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
              child: IconButton(
                icon: SvgPicture.asset(
                  'assets/images/back_icon.svg',
                  width: 24,
                  height: 24,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.black.withOpacity(0.1),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Container(
            height: ResponsiveUtils.scaleHeight(context, 80), // Адаптивная высота
            padding: ResponsiveUtils.adaptivePadding(context, horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Главная
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Главная',
                  isActive: _currentIndex == 0,
                ),
                // Комьюнити  
                _buildNavItem(
                  index: 1,
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Комьюнити',
                  isActive: _currentIndex == 1,
                ),
                // Уведомления
                _buildNavItem(
                  index: 2,
                  icon: Icons.notifications_none_outlined,
                  activeIcon: Icons.notifications,
                  label: 'Уведомления',
                  isActive: _currentIndex == 2,
                ),
                // Профиль
                _buildNavItem(
                  index: 3,
                  icon: Icons.account_circle_outlined,
                  activeIcon: Icons.account_circle,
                  label: 'Профиль',
                  isActive: _currentIndex == 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Modal bottom sheet for cancel confirmation
  Widget _buildCancelConfirmationModal() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Title - aligned to left according to Figma
                const Text(
                  'Отменить заявку',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222223),
                    letterSpacing: -0.48,
                  ),
                ),
                const Spacer(),
                // Close button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFAEAEAE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4), // Reduced from 32 to 16
                
                // Confirmation message
                const Text(
                  'Вы уверены что хотите отменить заявку?',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222223),
                    letterSpacing: -0.32,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Action buttons with side padding
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
                  child: Column(
                    children: [
                      // Cancel button (red)
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(true),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEC2D20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Отменить',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              letterSpacing: -0.32,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Back button (gray)
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(false),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F3F3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Назад',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF222223),
                              letterSpacing: -0.32,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 