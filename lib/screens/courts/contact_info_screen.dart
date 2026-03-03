import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../models/booking.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../utils/logger.dart';
import '../../utils/booking_error_handler.dart';
import 'booking_success_screen.dart';

class ContactInfoScreen extends StatefulWidget {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final int selectedDuration;
  final Club club;

  const ContactInfoScreen({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedDuration,
    required this.club,
  });

  @override
  State<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends State<ContactInfoScreen> {
  final TextEditingController _phoneController = TextEditingController(text: '+7');
  final TextEditingController _whatsappController = TextEditingController(text: '+7');
  final TextEditingController _telegramController = TextEditingController(text: '@');
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _whatsappController.dispose();
    _telegramController.dispose();
    super.dispose();
  }

  bool _isPhoneValid(String phone) {
    // If only prefix is present (e.g., "+7" or "@"), consider it valid
    if (phone == '+7' || phone == '@') {
      return true;
    }
    
    // Remove all non-digit characters and check if exactly 10 digits (excluding +7 prefix)
    String digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    // Remove the +7 prefix (first 2 digits) and check if remaining is 10 digits
    if (digitsOnly.startsWith('7')) {
      digitsOnly = digitsOnly.substring(1);
    }
    return digitsOnly.length == 10;
  }

  bool _isAnyFieldValid() {
    return (_phoneController.text.length > 2) || // More than just "+7"
           (_whatsappController.text.length > 2) || // More than just "+7"
           (_telegramController.text.length > 1); // More than just "@"
  }

  Future<void> _createBooking() async {
    if (!_isAnyFieldValid()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Подготавливаем контактную информацию
      String? phone = _phoneController.text.length > 2 ? _phoneController.text : null;
      String? whatsapp = _whatsappController.text.length > 2 ? _whatsappController.text : null;
      String? telegram = _telegramController.text.length > 1 ? _telegramController.text : null;

      Logger.info('Создание бронирования: clubId=${widget.club.id}, date=${widget.selectedDate}, time=${widget.selectedTime}, duration=${widget.selectedDuration}');

      // Получаем текущего пользователя
      final currentUser = await AuthStorage.getUser();
      
      // Если пользователь авторизован, сохраняем контактные данные через API
      if (currentUser != null) {
        try {
          final contactUpdateRequest = ContactUpdateRequest(
            contactPhone: phone,
            whatsapp: whatsapp,
            telegram: telegram,
          );
          
          await ApiService.updateContacts(contactUpdateRequest);
          Logger.info('Контактные данные успешно обновлены через API');
        } catch (e) {
          Logger.warning('Ошибка обновления контактных данных через API: $e');
          // Продолжаем создание бронирования даже при ошибке обновления контактов
        }
      }

      // Создаем объект для отправки на сервер
      final bookingData = BookingCreate(
        clubId: widget.club.id,
        bookingDate: widget.selectedDate,
        startTime: '${widget.selectedTime.hour.toString().padLeft(2, '0')}:${widget.selectedTime.minute.toString().padLeft(2, '0')}',
        durationMin: widget.selectedDuration,
        phone: phone,
        whatsapp: whatsapp,
        telegram: telegram,
      );
      
      // Отправляем запрос на сервер
      final booking = await ApiService.createBooking(bookingData);
      
      Logger.success('Бронирование успешно создано: ID=${booking.id}');
      
      if (mounted) {
        // Переходим на экран успешного бронирования
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => BookingSuccessScreen(
              selectedDate: widget.selectedDate,
              selectedTime: widget.selectedTime,
              selectedDuration: widget.selectedDuration,
              club: widget.club,
              bookingId: booking.id,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      Logger.bookingError('Создание бронирования в ContactInfoScreen', e, stackTrace);
      
      if (mounted) {
        final errorMessage = BookingErrorHandler.getUserFriendlyMessage(e);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate dynamic height based on error messages
    int errorCount = 0;
    if (_phoneController.text.length > 2 && !_isPhoneValid(_phoneController.text)) errorCount++;
    if (_whatsappController.text.length > 2 && !_isPhoneValid(_whatsappController.text)) errorCount++;
    
    // Base height is 500, add 21px for each error message
    double dynamicHeight = 500 + (errorCount * 21);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          const Spacer(),
          Container(
            height: dynamicHeight,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                // Header - 76px height
                Container(
                  width: double.infinity,
                  height: 76,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFCCCCCC),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                    child: Row(
                      children: [
                        const Text(
                          'Как со мной связаться',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF222223),
                            letterSpacing: -0.48,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 44,
                            height: 44,
                            margin: const EdgeInsets.only(right: 16),
                            child: IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFAEAEAE),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content with exact spacing from Figma
                Expanded(
                  child: Column(
                    children: [
                      // Description text - 24px gap from header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: const Text(
                          'Укажите хотя бы один способ связи для бронирования игры.',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF222223),
                            letterSpacing: -0.32,
                            height: 1.25,
                          ),
                        ),
                      ),

                      // Contact fields container - 24px gap from description
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            children: [
                              // Phone field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Телефон',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF79766E),
                                      height: 1.2857142857142858,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F7F7),
                                      borderRadius: BorderRadius.circular(10),
                                      border: _phoneController.text.length > 2 && !_isPhoneValid(_phoneController.text)
                                          ? Border.all(color: Colors.red, width: 1)
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _phoneController,
                                            keyboardType: TextInputType.phone,
                                            decoration: const InputDecoration(
                                              hintText: '',
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.only(bottom: 12),
                                            ),
                                            style: const TextStyle(
                                              fontFamily: 'SF Pro Display',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                              color: Color(0xFF22211E),
                                              height: 1.125,
                                            ),
                                            onChanged: (value) {
                                              setState(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_phoneController.text.length > 2 && !_isPhoneValid(_phoneController.text))
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Номер должен содержать 10 цифр',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro Display',
                                          fontSize: 12,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // WhatsApp field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'WhatsApp',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF79766E),
                                      height: 1.2857142857142858,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F7F7),
                                      borderRadius: BorderRadius.circular(10),
                                      border: _whatsappController.text.length > 2 && !_isPhoneValid(_whatsappController.text)
                                          ? Border.all(color: Colors.red, width: 1)
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _whatsappController,
                                            keyboardType: TextInputType.phone,
                                            decoration: const InputDecoration(
                                              hintText: '',
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.only(bottom: 12),
                                            ),
                                            style: const TextStyle(
                                              fontFamily: 'SF Pro Display',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                              color: Color(0xFF22211E),
                                              height: 1.125,
                                            ),
                                            onChanged: (value) {
                                              setState(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_whatsappController.text.length > 2 && !_isPhoneValid(_whatsappController.text))
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Номер должен содержать 10 цифр',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro Display',
                                          fontSize: 12,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Telegram field
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Telegram',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF79766E),
                                      height: 1.2857142857142858,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F7F7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _telegramController,
                                            decoration: const InputDecoration(
                                              hintText: '',
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.only(bottom: 12),
                                            ),
                                            style: const TextStyle(
                                              fontFamily: 'SF Pro Display',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                              color: Color(0xFF22211E),
                                              height: 1.125,
                                            ),
                                            onChanged: (value) {
                                              setState(() {});
                                            },
                                          ),
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
                      
                      // Save button with exact spacing from Figma
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 45),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : (_isAnyFieldValid() ? () {
                              _createBooking();
                            } : null),
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                                if (states.contains(MaterialState.disabled)) {
                                  return const Color(0xFF7F8AC0);
                                }
                                return const Color(0xFF00897B);
                              }),
                              padding: MaterialStateProperty.all(
                                const EdgeInsets.symmetric(vertical: 16),
                              ),
                              shape: MaterialStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              elevation: MaterialStateProperty.all(0),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Сохранить',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: _isAnyFieldValid() 
                                          ? Colors.white 
                                          : Colors.white.withOpacity(0.4),
                                      letterSpacing: -0.32,
                                      height: 1.193359375,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 