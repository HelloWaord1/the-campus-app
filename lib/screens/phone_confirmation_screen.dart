import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../utils/phone_utils.dart';
import '../utils/notification_utils.dart';
import '../utils/logger.dart';

class PhoneConfirmationScreen extends StatefulWidget {
  final String phoneNumber;

  const PhoneConfirmationScreen({super.key, required this.phoneNumber});

  @override
  _PhoneConfirmationScreenState createState() =>
      _PhoneConfirmationScreenState();
}

class _PhoneConfirmationScreenState extends State<PhoneConfirmationScreen> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late Timer _timer;
  int _start = 59;
  bool _isTimerActive = true;
  bool _hasError = false;
  bool _isFillingFromPaste = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (index) => TextEditingController());
    _focusNodes = List.generate(4, (index) => FocusNode());
    startTimer();
    _sendInitialCode();
  }
  
  void startTimer() {
    _isTimerActive = true;
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

  @override
  void dispose() {
    _timer.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String _formatPhoneNumber(String phone) {
    // Убираем все нецифровые символы, кроме начального '+'
    String digitsOnly = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digitsOnly.startsWith('+')) {
      digitsOnly = digitsOnly.substring(1);
    }
    // Убедимся, что номер начинается с 7, если это российский номер
    if (digitsOnly.length == 11 && (digitsOnly.startsWith('7') || digitsOnly.startsWith('8'))) {
        digitsOnly = digitsOnly.substring(1);
    }
    if (digitsOnly.length != 10) return phone; // Возвращаем как есть, если длина некорректна

    String areaCode = digitsOnly.substring(0, 3);
    String firstPart = digitsOnly.substring(3, 6);
    String secondPart = digitsOnly.substring(6, 8);
    String thirdPart = digitsOnly.substring(8, 10);
    return "+7 $areaCode $firstPart-$secondPart-$thirdPart";
  }

  void _onCodeChanged(String value, int index) {
    // Обработка вставки нескольких символов в первую ячейку
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
    // Когда все поля заполнены, пытаемся подтвердить
    if (_controllers.every((controller) => controller.text.isNotEmpty)) {
      _confirmCode();
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
              // Очищаем предыдущую ячейку, т.к. backspace на пустой
              _controllers[i - 1].clear();
            }
            break;
          }
        }
      }
    }
  }
  
  Future<void> _sendInitialCode() async {
    final normalizedPhone = PhoneUtils.normalizePhoneForApi(widget.phoneNumber);
    Logger.info('📱 UI: Отправка первичного SMS-кода на $normalizedPhone');
    try {
      await ApiService.sendSmsVerificationCode(normalizedPhone);
    } on ApiException catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(
        context,
        e.message.isNotEmpty ? e.message : 'Не удалось отправить SMS-код',
      );
      setState(() {
        _isTimerActive = false;
      });
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(
        context,
        'Не удалось отправить SMS-код: $e',
      );
      setState(() {
        _isTimerActive = false;
      });
    }
  }

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
    // Сбрасываем ошибку при новой попытке ввода
    if (_hasError) {
      setState(() {
        _hasError = false;
      });
    }
    // Наводим фокус на первую пустую ячейку или подтверждаем, если все заполнены
    if (_controllers.every((c) => c.text.isNotEmpty)) {
      _confirmCode();
    } else {
      final firstEmpty = _controllers.indexWhere((c) => c.text.isEmpty);
      if (firstEmpty != -1) {
        _focusNodes[firstEmpty].requestFocus();
      }
    }
  }
  
  Future<void> _confirmCode() async {
    if (_isLoading) return;
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 4) {
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final normalizedPhone = PhoneUtils.normalizePhoneForApi(widget.phoneNumber);
    Logger.info(
        '📱 UI: Проверка SMS-кода для телефона $normalizedPhone, код=$code');
    try {
      await ApiService.verifySmsCode(phone: normalizedPhone, code: code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
      NotificationUtils.showError(
        context,
        e.message.isNotEmpty ? e.message : 'Неверный или истекший код',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
      NotificationUtils.showError(
        context,
        'Ошибка проверки кода: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (_isTimerActive || _isLoading) return;
    final normalizedPhone = PhoneUtils.normalizePhoneForApi(widget.phoneNumber);
    Logger.info('📱 UI: Повторная отправка SMS-кода на $normalizedPhone');
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      await ApiService.sendSmsVerificationCode(normalizedPhone);
      if (!mounted) return;
      NotificationUtils.showSuccess(context, 'Новый код отправлен!');
      setState(() {
        _start = 59;
        startTimer();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(
        context,
        e.message.isNotEmpty ? e.message : 'Не удалось отправить SMS-код',
      );
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(
        context,
        'Не удалось отправить SMS-код: $e',
      );
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
                  _buildBackButton(),
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
                  _buildCodeInputFields(),
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
                  _buildResendCodeText(),
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

  Widget _buildBackButton() {
     return GestureDetector(
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
    );
  }

  Widget _buildResendCodeText() {
    if (_isTimerActive) {
      return Center(
        child: Text(
          "Запросить новый код через 00:${_start.toString().padLeft(2, '0')}",
          style: const TextStyle(fontSize: 16, color: Color(0xFF7F8AC0), letterSpacing: -0.5),
        ),
      );
    } else {
      return Center(
        child: GestureDetector(
          onTap: _resendCode,
          child: const Text(
            "Запросить новый код",
            style: TextStyle(fontSize: 16, color: Color(0xFF7F8AC0), fontWeight: FontWeight.w500, letterSpacing: -0.5),
          ),
        ),
      );
    }
  }

  Widget _buildCodeInputFields() {
    return Row(
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
    );
  }
} 