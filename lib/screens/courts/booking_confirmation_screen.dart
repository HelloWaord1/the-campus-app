import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/club.dart';
import '../../models/court.dart';
import '../../models/booking.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';
import '../../utils/notification_utils.dart';
import '../../services/auth_storage.dart';
import 'booking_details_screen.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final Club club;
  final DateTime bookingDate;
  /// Времена начала в формате 'HH:mm'
  final List<String> startTimes;
  final List<Court> selectedCourts;
  final bool onlinePayment;

  const BookingConfirmationScreen({
    super.key,
    required this.club,
    required this.bookingDate,
    required this.startTimes,
    required this.selectedCourts,
    this.onlinePayment = true,
  });

  @override
  State<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  bool _isProcessing = false;
  bool _isFormValid = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _nameController.addListener(_validateForm);
    _phoneController.addListener(_validateForm);
    _emailController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthStorage.getUser();
      if (!mounted || user == null) return;

      setState(() {
        _nameController.text = user.name;
        _emailController.text = user.email;
        _phoneController.text = user.phone ?? '';
      });
    } catch (e) {
      Logger.error('Ошибка загрузки данных пользователя: $e');
    } finally {
      _validateForm();
    }
  }

  void _validateForm() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    bool isValid = name.isNotEmpty && phone.isNotEmpty && email.isNotEmpty;

    // Простая валидация email
    if (isValid && !email.contains('@')) {
      isValid = false;
    }

    if (_isFormValid != isValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    
    final weekday = weekdays[date.weekday - 1];
    final day = date.day;
    final month = months[date.month - 1];
    
    return '$weekday, $day $month';
  }

  String _formatTimeRange(String time) {
    // Ожидаем формат 'HH:mm' или 'HH:mm:ss' и приводим к 'HH:mm'
    final parts = time.split(':');
    final startHour = int.tryParse(parts.first) ?? 0;
    var minutes = parts.length > 1 ? parts[1] : '00';

    if (minutes.length > 2) {
      minutes = minutes.substring(0, 2);
    }

    final endHour = (startHour + 1) % 24;

    final start = '${startHour.toString().padLeft(2, '0')}:$minutes';
    final end = '${endHour.toString().padLeft(2, '0')}:$minutes';
    return '$start - $end';
  }

  double _getTotalPrice() {
    final perHourSum = widget.selectedCourts.fold(0.0, (sum, court) => sum + court.pricePerHour);
    return perHourSum * widget.startTimes.length;
  }

  Future<void> _handlePayment(String paymentUrl, String? paymentId) async {
    try {
      final uri = Uri.parse(paymentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('После оплаты вы вернетесь в приложение'),
              duration: Duration(seconds: 3),
            ),
          );

          // Возвращаемся назад на экран клуба/списка кортов
          Navigator.of(context).pop(); // закрываем экран подтверждения
        }
      } else {
        throw Exception('Не удалось открыть ссылку на оплату');
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(
          context,
          'Ошибка при открытии страницы оплаты: $e',
        );
      }
    }
  }

  Future<void> _confirmBooking() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Берём имя из поля и режем на first/last для бэка (и YCLIENTS).
      final fullName = _nameController.text.trim();
      final parts = fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      final String? firstName = parts.isNotEmpty ? parts.first : null;
      final String? lastName = parts.length > 1 ? parts.sublist(1).join(' ') : null;

      // Подготавливаем данные: N таймслотов * M кортов
      final List<BookingCreate> bookingsData = [];
      final times = List<String>.from(widget.startTimes)..sort();
      for (final time in times) {
        for (final court in widget.selectedCourts) {
          bookingsData.add(
            BookingCreate(
              clubId: widget.club.id,
              courtId: court.id,
              bookingDate: widget.bookingDate,
              startTime: time,
              durationMin: 60,
              firstName: firstName,
              lastName: lastName,
              phone: _phoneController.text.trim(),
              email: _emailController.text.trim(),
            ),
          );
        }
      }

      // Создаем все бронирования с одной оплатой через batch-эндпоинт
      final result = await ApiService.createBookingsBatch(
        bookingsData,
        onlinePayment: widget.onlinePayment,
      );
      
      final List<Booking> bookings = result['bookings'] as List<Booking>;
      final String? paymentUrl = result['payment_url'] as String?;
      final String? paymentId = result['payment_id'] as String?;

      if (!mounted) return;

      // Если пришла ссылка на оплату — открываем Юкассу
      if (paymentUrl != null && paymentUrl.isNotEmpty && paymentId != null) {
        await _handlePayment(paymentUrl, paymentId);
      } else {
        // Бесплатное бронирование или оплата не требуется
        NotificationUtils.showSuccess(
          context,
          'Забронировано кортов: ${bookings.length}',
        );
        Navigator.of(context).pop(); // экран подтверждения
      }
    } catch (e) {
      Logger.error('Ошибка создания бронирования: $e');
      if (mounted) {
        NotificationUtils.showError(context, 'Ошибка создания бронирования: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/images/back_icon.svg',
            width: 24,
            height: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Оплата',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2A2C36),
            letterSpacing: -0.36,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
              child: Column(
                children: [
                    // Карточка с информацией о бронировании
                  Container(
                    width: double.infinity,
                      decoration: BoxDecoration(
                    color: Colors.white,
                        border: Border.all(color: const Color(0xFFD9D9D9), width: 0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                          Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(widget.bookingDate),
                              style: const TextStyle(
                                fontFamily: 'SF Pro Display',
                                        fontSize: 20,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF2A2C36),
                                        height: 1.3,
                                        letterSpacing: -0.40,
                              ),
                            ),
                            Text(
                              widget.startTimes.length == 1
                                  ? _formatTimeRange(widget.startTimes.first)
                                  : 'Слоты: ${(List<String>.from(widget.startTimes)..sort()).join(', ')}',
                              style: const TextStyle(
                                fontFamily: 'SF Pro Display',
                                        fontSize: 20,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF2A2C36),
                                        height: 1.3,
                                        letterSpacing: -0.40,
                              ),
                            ),
                          ],
                        ),
                                const SizedBox(height: 28),
                                Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                                      widget.club.name,
                                      style: const TextStyle(
                                        fontFamily: 'SF Pro Display',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF2A2C36),
                                        height: 1.125,
                                        letterSpacing: -0.32,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                  Text(
                                      widget.selectedCourts.map((c) => c.name).join(', '),
                                    style: const TextStyle(
                                      fontFamily: 'SF Pro Display',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF838A91),
                                        height: 1.285,
                                        letterSpacing: -0.28,
                                      ),
                                    ),
                                  ],
                                  ),
                                ],
                              ),
                          ),
                          const SizedBox(width: 12),
                        Container(
                            width: 1,
                            height: 120,
                            color: const Color(0xFFECECEC),
                        ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              const Icon(
                                Icons.access_time_outlined,
                                size: 24,
                                color: Color(0xFF2A2C36),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(widget.startTimes.isEmpty ? 0 : widget.startTimes.length) * 60} мин',
                                style: const TextStyle(
                                  fontFamily: 'SF Pro Display',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF2A2C36),
                                  height: 1.125,
                                  letterSpacing: -0.32,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                    const SizedBox(height: 32),
                    // Ваши данные
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ваши данные',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF2A2C36),
                            height: 1.0,
                            letterSpacing: -0.36,
                          ),
                        ),
                        const SizedBox(height: 15),
                        // Имя
                        const Text(
                          'Имя',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF838A91),
                            letterSpacing: -0.28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                          controller: _nameController,
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF2A2C36),
                              letterSpacing: -0.32,
                            ),
                          decoration: InputDecoration(
                            hintText: 'Введите имя',
                            hintStyle: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFFB3B3B3),
                                letterSpacing: -0.32,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                            ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Телефон
                        const Text(
                          'Номер телефона',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF838A91),
                            letterSpacing: -0.28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                              _PhoneInputFormatter(),
                            ],
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF2A2C36),
                              letterSpacing: -0.32,
                            ),
                          decoration: InputDecoration(
                            hintText: '+7',
                            hintStyle: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFFB3B3B3),
                                letterSpacing: -0.32,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                            ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Email
                        const Text(
                          'Ваша почта',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF838A91),
                            letterSpacing: -0.28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF2A2C36),
                              letterSpacing: -0.32,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Введите почту',
                              hintStyle: const TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFFB3B3B3),
                                letterSpacing: -0.32,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Итого — единственный блок, который отличается при onlinePayment=false
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFD9D9D9), width: 0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Итого',
                                style: TextStyle(
                                  fontFamily: 'SF Pro Display',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF2A2C36),
                                  height: 1.222,
                                  letterSpacing: -0.36,
                                ),
                              ),
                              Text(
                                '${_getTotalPrice().toStringAsFixed(0)} ₽',
                                style: const TextStyle(
                                  fontFamily: 'SF Pro Display',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF2A2C36),
                                  height: 1.182,
                                  letterSpacing: -0.44,
                                ),
                              ),
                            ],
                          ),
                          if (!widget.onlinePayment) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              height: 1,
                              color: Color(0xFFE6E6E6),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                SvgPicture.string(
                                  '''
<svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M6.1875 4.5C6.1875 4.2775 6.25348 4.05999 6.3771 3.87498C6.50072 3.68998 6.67642 3.54578 6.88198 3.46064C7.08755 3.37549 7.31375 3.35321 7.53198 3.39662C7.75021 3.44002 7.95066 3.54717 8.108 3.7045C8.26533 3.86184 8.37248 4.06229 8.41589 4.28052C8.4593 4.49875 8.43702 4.72495 8.35187 4.93052C8.26672 5.13609 8.12253 5.31179 7.93752 5.4354C7.75251 5.55902 7.53501 5.625 7.3125 5.625C7.01413 5.625 6.72799 5.50647 6.51701 5.2955C6.30603 5.08452 6.1875 4.79837 6.1875 4.5ZM15.1875 7.59375C15.1875 9.09565 14.7421 10.5638 13.9077 11.8126C13.0733 13.0614 11.8873 14.0347 10.4998 14.6095C9.11218 15.1842 7.58533 15.3346 6.11229 15.0416C4.63924 14.7486 3.28617 14.0253 2.22416 12.9633C1.16216 11.9013 0.438922 10.5483 0.145915 9.07522C-0.147091 7.60217 0.00329027 6.07532 0.578043 4.68775C1.1528 3.30017 2.12611 2.11419 3.37489 1.27978C4.62368 0.445366 6.09185 0 7.59375 0C9.60706 0.00223328 11.5373 0.803004 12.9609 2.22662C14.3845 3.65025 15.1853 5.58045 15.1875 7.59375ZM13.5 7.59375C13.5 6.4256 13.1536 5.28369 12.5046 4.31241C11.8556 3.34114 10.9332 2.58412 9.85398 2.13709C8.77475 1.69006 7.5872 1.57309 6.4415 1.80099C5.2958 2.02888 4.24341 2.5914 3.4174 3.4174C2.5914 4.2434 2.02888 5.2958 1.80099 6.4415C1.5731 7.5872 1.69006 8.77475 2.13709 9.85397C2.58412 10.9332 3.34114 11.8556 4.31242 12.5046C5.28369 13.1536 6.42561 13.5 7.59375 13.5C9.15967 13.4983 10.661 12.8755 11.7683 11.7682C12.8755 10.661 13.4983 9.15967 13.5 7.59375ZM8.4375 10.1728V7.875C8.4375 7.50204 8.28934 7.14435 8.02562 6.88063C7.7619 6.61691 7.40421 6.46875 7.03125 6.46875C6.83199 6.46845 6.63906 6.53869 6.48662 6.66701C6.33418 6.79533 6.23208 6.97347 6.19839 7.16986C6.1647 7.36625 6.20161 7.56822 6.30257 7.74001C6.40353 7.9118 6.56203 8.04232 6.75 8.10844V10.4062C6.75 10.7792 6.89816 11.1369 7.16188 11.4006C7.42561 11.6643 7.78329 11.8125 8.15625 11.8125C8.35551 11.8128 8.54845 11.7426 8.70089 11.6142C8.85332 11.4859 8.95543 11.3078 8.98912 11.1114C9.0228 10.915 8.9859 10.713 8.88493 10.5412C8.78397 10.3694 8.62547 10.2389 8.4375 10.1728Z" fill="#262F63"/>
</svg>
                                  ''',
                                  width: 16,
                                  height: 16,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Оплата на месте',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Display',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF00897B),
                                    letterSpacing: -0.28,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
                ),
              ),
            ),
          ),
          // Кнопка подтверждения
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing || !_isFormValid ? null : _confirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    disabledBackgroundColor: const Color(0xFF00897B).withOpacity(0.45),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          widget.onlinePayment ? 'Оплатить' : 'Забронировать',
                          style: const TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.32,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 11) {
      return oldValue;
    }

    final chars = digitsOnly.split('');
    var formatted = '';

    if (chars.isNotEmpty) {
      if (chars[0] == '8') {
        chars[0] = '7';
      }
      if (chars[0] != '7') {
        chars.insert(0, '7');
      }
    }

    final phone = chars.join();

    if (phone.isNotEmpty) {
      formatted += '+${phone.substring(0, 1)}';
    }
    if (phone.length > 1) {
      formatted += ' (${phone.substring(1, phone.length > 4 ? 4 : phone.length)}';
    }
    if (phone.length > 4) {
      formatted += ') ${phone.substring(4, phone.length > 7 ? 7 : phone.length)}';
    }
    if (phone.length > 7) {
      formatted += '-${phone.substring(7, phone.length > 9 ? 9 : phone.length)}';
    }
    if (phone.length > 9) {
      formatted += '-${phone.substring(9, phone.length > 11 ? 11 : phone.length)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
