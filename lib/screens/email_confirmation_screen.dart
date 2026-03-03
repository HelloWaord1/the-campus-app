import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'complete_registration_screen.dart';
import '../services/api_service.dart';

class EmailConfirmationScreen extends StatefulWidget {
  final String email;

  const EmailConfirmationScreen({super.key, required this.email});

  @override
  State<EmailConfirmationScreen> createState() => _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends State<EmailConfirmationScreen> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  Timer? _timer;
  int _start = 59;
  bool _isTimerActive = true;
  bool _hasError = false;
  bool _isFillingFromPaste = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (_) => TextEditingController());
    _focusNodes = List.generate(4, (_) => FocusNode());
    startTimer();
    // Автоотправка кода при открытии экрана
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ApiService.emailRegisterInit(widget.email);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки кода: ${e.toString()}')),
        );
      }
    });
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
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
  
  void _onCodeChanged(String raw, int index) {
    final value = raw.replaceAll(RegExp(r'\\D'), '');
    if (value.length > 1) {
      _controllers[index].text = value.substring(0, 1);
      _controllers[index].selection = const TextSelection.collapsed(offset: 1);
    }
    // Обработка вставки нескольких символов в первую ячейку
    if (index == 0 && value.length > 1 && !_isFillingFromPaste) {
      _handlePaste(value);
      return;
    }
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    // Логика Backspace обрабатывается в _handleKeyEvent
    if (_hasError) {
      setState(() {
        _hasError = false;
      });
    }
    if (_controllers.every((c) => c.text.isNotEmpty)) {
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
               // После очистки остаемся на том же поле,
               // чтобы можно было ввести новое значение
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
    if (_hasError) {
      setState(() {
        _hasError = false;
      });
    }
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
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    // Небольшая пауза, чтобы была видна загрузка при моке
    await Future.delayed(const Duration(milliseconds: 800));

    final code = _controllers.map((c) => c.text).join();
    try {
      await ApiService.emailRegisterVerify(widget.email, code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _hasError = true;
      });
      for (var controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendEmail() async {
    try {
      await ApiService.emailRegisterInit(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Письмо отправлено повторно.')));
      setState(() {
        _start = 59;
        startTimer();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString()}')));
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
                    'Мы отправили код на почту:',
                    style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF222223),
                        letterSpacing: -0.85),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.email,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF222223),
                        letterSpacing: -0.85),
                  ),
                  const SizedBox(height: 30),
                  const Center(
                      child: Text("Введите код",
                          style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF222223),
                              letterSpacing: -0.85))),
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
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 24.0),
                    child: CircularProgressIndicator(color: Color(0xFF262F63)),
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
                color: Color(0xFF262F63),
                letterSpacing: -0.85),
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
          style: const TextStyle(
              fontSize: 16, color: Color(0xFF7F8AC0), letterSpacing: -0.85),
        ),
      );
    } else {
      return Center(
        child: GestureDetector(
          onTap: _resendEmail,
          child: const Text(
            "Запросить новый код",
            style: TextStyle(
                fontSize: 16,
                color: Color(0xFF262F63),
                fontWeight: FontWeight.w500,
                letterSpacing: -0.85),
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
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
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
                LengthLimitingTextInputFormatter(1),
              ],
              onChanged: (value) => _onCodeChanged(value, index),
            ),
          ),
        );
      }),
    );
  }
} 