import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../services/deep_link_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/notification_utils.dart';
import '../utils/logger.dart';
import '../utils/phone_utils.dart';
import 'home_screen.dart';
import 'match_details_screen.dart';
import 'public_profile_screen.dart';
import 'courts/club_details_screen.dart';
import 'courts/booking_details_screen.dart';
import 'competition_details_screen.dart';
import 'training_detail_screen.dart';

class PhoneLoginVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const PhoneLoginVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<PhoneLoginVerificationScreen> createState() => _PhoneLoginVerificationScreenState();
}

class _PhoneLoginVerificationScreenState extends State<PhoneLoginVerificationScreen> {
  // Перерисовано под экран регистрации по телефону: 4 поля ввода, таймер, стили
  final List<TextEditingController> _controllers = List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  
  Timer? _timer;
  int _start = 59;
  bool _isTimerActive = true;
  bool _hasError = false;
  bool _isFillingFromPaste = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _isTimerActive = true;
    _start = 59;
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_start == 0) {
      setState(() {
          _isTimerActive = false;
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  void _onCodeChanged(String value, int index) {
    // Обработка вставки в первое поле
    if (index == 0 && value.length > 1 && !_isFillingFromPaste) {
      _handlePaste(value);
      return;
    }
    // Для всех остальных ячеек жёстко ограничиваем ввод одной цифрой
    if (index != 0 && value.length > 1) {
      final lastChar = value[value.length - 1];
      _controllers[index].text = lastChar;
      value = lastChar;
    }

    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_hasError) {
      setState(() {
        _hasError = false;
      });
    }
    if (_controllers.every((c) => c.text.isNotEmpty)) {
      _verifyCode();
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        for (int i = 3; i >= 0; i--) {
          if (_focusNodes[i].hasFocus) {
            if (_controllers[i].text.isNotEmpty) {
              _controllers[i].clear();
            } else if (i > 0) {
              _focusNodes[i - 1].requestFocus();
              // Очищаем предыдущее поле, так как Backspace был нажат на пустом
              _controllers[i - 1].clear();
            }
            break;
          }
        }
      }
    }
  }

  String _getCode() => _controllers.map((c) => c.text).join();

  void _handlePaste(String pasted) {
    final digitsOnly = pasted.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) return;
    _isFillingFromPaste = true;
    try {
      for (var i = 0; i < _controllers.length; i++) {
        _controllers[i].text = i < digitsOnly.length ? digitsOnly[i] : '';
      }
    } finally {
      _isFillingFromPaste = false;
    }
    if (_controllers.every((c) => c.text.isNotEmpty)) {
      _verifyCode();
    } else {
      final firstEmpty = _controllers.indexWhere((c) => c.text.isEmpty);
      if (firstEmpty != -1) {
        _focusNodes[firstEmpty].requestFocus();
      }
    }
  }

  String _formatPhoneNumber(String phone) {
    String digitsOnly = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digitsOnly.startsWith('+')) {
      digitsOnly = digitsOnly.substring(1);
    }
    if (digitsOnly.length == 11 && (digitsOnly.startsWith('7') || digitsOnly.startsWith('8'))) {
      digitsOnly = digitsOnly.substring(1);
    }
    if (digitsOnly.length != 10) return phone;
    final areaCode = digitsOnly.substring(0, 3);
    final firstPart = digitsOnly.substring(3, 6);
    final secondPart = digitsOnly.substring(6, 8);
    final thirdPart = digitsOnly.substring(8, 10);
    return "+7 $areaCode $firstPart-$secondPart-$thirdPart";
  }

  Future<void> _verifyCode() async {
    final code = _getCode();
    if (code.length != 4) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final normalizedPhone = PhoneUtils.normalizePhoneForApi(widget.phoneNumber);
      final phoneLoginRequest = PhoneLoginRequest(phone: normalizedPhone, code: code);
      Logger.info('🔐 UI: Верификация кода для ${normalizedPhone}');
      final authResponse = await ApiService.loginWithPhone(phoneLoginRequest);
      await AuthStorage.saveAuthData(authResponse);
      try {
        await FirebaseMessaging.instance.requestPermission();
        await ApiService.registerPushToken();
      } catch (_) {}
      final navigationInfo = await DeepLinkService().handlePostAuthNavigation();
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
      if (mounted && navigationInfo != null) {
        switch (navigationInfo.type) {
          case NavigationType.match:
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => MatchDetailsScreen(matchId: navigationInfo.id)));
            break;
          case NavigationType.profile:
            if (navigationInfo.isOwnProfile == true) {
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 3)), (route) => false);
            } else {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => PublicProfileScreen(userId: navigationInfo.id)));
            }
            break;
            case NavigationType.club:
              try {
                final club = await ApiService.getClubById(navigationInfo.id);
                if (!mounted) break;
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => ClubDetailsScreen(club: club)));
              } catch (_) {}
            break;
          case NavigationType.competition:
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => CompetitionDetailsScreen(competitionId: navigationInfo.id)));
            break;
          case NavigationType.training:
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => TrainingDetailScreen(trainingId: navigationInfo.id)));
            break;
          case NavigationType.bookingSuccess:
            try {
              final booking = await ApiService.getBookingById(navigationInfo.id);
              if (!mounted) break;
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => BookingDetailsScreen(booking: booking)));
            } catch (_) {}
            break;
        }
      }
    } on ApiException catch (_) {
      setState(() {
        _hasError = true;
        for (var c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
      });
    } catch (e) {
      Logger.error('🔐 UI: Ошибка при авторизации по телефону', e);
      setState(() {
        _hasError = true;
        for (var c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (_isTimerActive) return;
    try {
      final normalizedPhone = PhoneUtils.normalizePhoneForApi(widget.phoneNumber);
      await ApiService.initPhoneLogin(PhoneInitRequest(phone: normalizedPhone));
      if (!mounted) return;
      NotificationUtils.showSuccess(context, 'Новый код отправлен!');
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(context, 'Ошибка отправки кода: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Stack(
              children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const SizedBox(height: 10),
                  // Кнопка Назад
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_left, color: Color(0xFF262F63)),
                        SizedBox(width: 8),
                        Text(
                        'Назад',
                        style: TextStyle(
                          fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF262F63)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                const Text(
                    'Мы отправили код на номер:',
                    style: TextStyle(fontSize: 16, color: Color(0xFF222223), letterSpacing: -0.85),
                  ),
                const SizedBox(height: 12),
                Text(
                    _formatPhoneNumber(widget.phoneNumber),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Color(0xFF222223)),
                  ),
                  const SizedBox(height: 30),
                  const Center(child: Text("Введите код", style: TextStyle(fontSize: 16, color: Color(0xFF222223)))),
                  const SizedBox(height: 10),
                  // Поля ввода кода (4 клетки)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return Container(
                        width: 60,
                        height: 84,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      child: RawKeyboardListener(
                        focusNode: FocusNode(debugLabel: 'KeyListener_$index', skipTraversal: true),
                        onKey: _handleKeyEvent,
                          child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                            maxLength: 1,
                            maxLengthEnforcement: MaxLengthEnforcement.none,
                            enabled: !_isLoading,
                            textAlignVertical: TextAlignVertical.center,
                            textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 28, letterSpacing: -0.85),
                          decoration: InputDecoration(
                            counterText: '',
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFFF7F7F7),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: _hasError ? const Color(0xFFEC2D20) : Colors.transparent,
                                    width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: _hasError ? const Color(0xFFEC2D20) : const Color(0xFF262F63),
                                    width: 1),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 23),
                            ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) => _onCodeChanged(value, index),
                        ),
                      ),
                    );
                  }),
                ),
                  if (_hasError)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(
                        child: Text(
                          'Код неверный. Отправьте код и повторите попытку.',
                          style: TextStyle(color: Color(0xFFEC2D20), fontSize: 12, letterSpacing: -0.85),
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  // Повторная отправка
                  if (_isTimerActive)
                    Center(
                    child: Text(
                        "Запросить новый код через 00:${_start.toString().padLeft(2, '0')}",
                        style: const TextStyle(fontSize: 16, color: Color(0xFF7F8AC0), letterSpacing: -0.5),
                      ),
                    )
                  else
                    Center(
                      child: GestureDetector(
                        onTap: _resendCode,
                        child: const Text(
                          "Запросить новый код",
                          style: TextStyle(fontSize: 16, color: Color(0xFF7F8AC0), fontWeight: FontWeight.w500, letterSpacing: -0.5),
                            ),
                          ),
                  ),
                ],
              ),
              if (_isLoading)
                const IgnorePointer(
                  ignoring: true,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 24.0),
                      child: CircularProgressIndicator(color: Color(0xFF262F63)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 