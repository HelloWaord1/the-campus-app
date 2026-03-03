import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../services/deep_link_service.dart';
import '../utils/logger.dart';
import '../utils/phone_utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import 'phone_login_verification_screen.dart';
import 'match_details_screen.dart';
import 'public_profile_screen.dart';
import 'courts/club_details_screen.dart';
import 'competition_details_screen.dart';
import 'training_detail_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;
  bool _isEmailSelected = true; // true для почты, false для телефона

  // Защита от частых попыток входа
  int _failedAttempts = 0;
  Timer? _lockoutTimer;
  int _lockoutTimeLeft = 0;
  bool get _isLockedOut => _lockoutTimeLeft > 0;

  @override
  void initState() {
    super.initState();
    _loadFailedAttemptsFromStorage();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFailedAttemptsFromStorage() async {
    // Загружаем данные о попытках входа из локального хранилища
    // В реальном приложении лучше использовать SharedPreferences
    // Здесь используем простую логику без постоянного хранения
  }

  void _startLockoutTimer() {
    _lockoutTimeLeft = 60; // 60 секунд
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _lockoutTimeLeft--;
        if (_lockoutTimeLeft <= 0) {
          timer.cancel();
          _failedAttempts = 0; // Сбрасываем счетчик после окончания блокировки
        }
      });
    });
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return _isEmailSelected ? 'Введите email' : 'Введите номер телефона';
    }
    if (_isEmailSelected) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(value)) {
        return 'Введите корректный email';
      }
    } else {
      // Простая валидация для номера телефона (только цифры, минимум 10 символов)
      final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
      if (!phoneRegex.hasMatch(value.replaceAll(RegExp(r'[\s\-\(\)]'), ''))) {
        return 'Введите корректный номер телефона';
      }
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите пароль';
    }
    return null;
  }

  Future<void> _login() async {
    if (_isLockedOut) {
      setState(() {
        _errorMessage = 'Слишком много неудачных попыток. Попробуйте через $_lockoutTimeLeft сек.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isEmailSelected) {
      // Вход по email с паролем
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final loginRequest = LoginRequest(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        final authResponse = await ApiService.login(loginRequest);
        
        // Сохраняем токен и данные пользователя
        await AuthStorage.saveAuthData(authResponse);
        try {
          await FirebaseMessaging.instance.requestPermission();
          await ApiService.registerPushToken();
        } catch (_) {}
        
        // Сбрасываем счетчик неудачных попыток при успешном входе
        _failedAttempts = 0;
        
        // Обрабатываем навигацию после авторизации
        final navigationInfo = await DeepLinkService().handlePostAuthNavigation();
        
        // Переходим на главный экран или к матчу/профилю
        Navigator.of(context).pushNamedAndRemoveUntil(
            '/main',
            (route) => false,
          );

        if (mounted && navigationInfo != null) {
          debugPrint('[LoginScreen] post-auth navigation: ${navigationInfo.type} id=${navigationInfo.id}');
          switch (navigationInfo.type) {
            case NavigationType.match:
              // Переходим к матчу
              debugPrint('[LoginScreen] navigate to match ${navigationInfo.id}');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MatchDetailsScreen(matchId: navigationInfo.id),
                ),
              );
              break;
            case NavigationType.profile:
              if (navigationInfo.isOwnProfile == true) {
                // Если это свой профиль, переходим на главный экран с вкладкой профиля
                debugPrint('[LoginScreen] navigate to own profile tab');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const HomeScreen(initialTabIndex: 3),
                  ),
                  (route) => false,
                );
              } else {
                // Если это чужой профиль, переходим к PublicProfileScreen
                debugPrint('[LoginScreen] navigate to public profile ${navigationInfo.id}');
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PublicProfileScreen(userId: navigationInfo.id),
                  ),
                );
              }
              break;
            case NavigationType.club:
              // Загружаем клуб и открываем экран
              try {
                debugPrint('[LoginScreen] loading club ${navigationInfo.id}');
                final club = await ApiService.getClubById(navigationInfo.id);
                if (!mounted) break;
                debugPrint('[LoginScreen] navigate to club ${club.id}');
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ClubDetailsScreen(club: club),
                  ),
                );
              } catch (_) {}
              break;
            case NavigationType.competition:
              // Переходим к соревнованию
              debugPrint('[LoginScreen] navigate to competition ${navigationInfo.id}');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CompetitionDetailsScreen(competitionId: navigationInfo.id),
                ),
              );
              break;
            case NavigationType.training:
              // Переходим к тренировке
              debugPrint('[LoginScreen] navigate to training ${navigationInfo.id}');
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TrainingDetailScreen(trainingId: navigationInfo.id),
                ),
              );
              break;
          }
        }
      } catch (e) {
        // Увеличиваем счетчик неудачных попыток
        _failedAttempts++;
        
        if (_failedAttempts >= 3) {
          _startLockoutTimer();
          setState(() {
            _errorMessage = 'Слишком много неудачных попыток. Попробуйте через 1 минуту.';
          });
        } else {
          setState(() {
            _errorMessage = '${e.toString()} (Попытка $_failedAttempts/3)';
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // Вход по телефону - отправляем SMS код
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final phone = _emailController.text.trim();
        final normalizedPhone = PhoneUtils.normalizePhoneForApi(phone);
        Logger.info('🔐 UI: Нормализовали телефон: $phone -> $normalizedPhone');
        
        final phoneInitRequest = PhoneInitRequest(
          phone: normalizedPhone,
        );

        Logger.info('🔐 UI: Инициализируем вход по телефону для номера: $normalizedPhone');
        await ApiService.initPhoneLogin(phoneInitRequest);
        Logger.success('🔐 UI: Успешно инициализировали вход по телефону');
        
        if (mounted) {
          // Переходим на экран подтверждения SMS кода для входа
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PhoneLoginVerificationScreen(
                phoneNumber: normalizedPhone, // Передаем нормализованный номер
              ),
            ),
          );
        }
      } catch (e) {
        Logger.error('🔐 UI: Ошибка при инициализации входа по телефону', e);
        setState(() {
          _errorMessage = e.toString();
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  
                  // Кнопка "Назад"
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.arrow_back, color: Colors.green),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Назад',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Логотип
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 3),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo.jpg',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Text(
                                'AN\n4',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  height: 1.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Заголовок
                  const Text(
                    'Добро пожаловать!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  const Text(
                    'Войдите в свой аккаунт',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Переключатели Почта/Телефон
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              setState(() {
                                _isEmailSelected = true;
                                _emailController.clear(); // Очищаем поле при смене типа
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isEmailSelected ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Почта',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: _isEmailSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: _isEmailSelected ? Colors.black : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              setState(() {
                                _isEmailSelected = false;
                                _emailController.clear(); // Очищаем поле при смене типа
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_isEmailSelected ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Телефон',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: !_isEmailSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: !_isEmailSelected ? Colors.black : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Поле логина (email или телефон)
                  TextFormField(
                    key: ValueKey(_isEmailSelected ? 'email' : 'phone'),
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: _isEmailSelected ? 'Email' : 'Телефон',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: _isEmailSelected ? TextInputType.emailAddress : TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: _isEmailSelected ? const [AutofillHints.email] : const [AutofillHints.telephoneNumber],
                    inputFormatters: _isEmailSelected
                        ? const []
                        : <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(RegExp(r"[0-9+ ()-]")),
                          ],
                    validator: _validateEmail,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).nextFocus();
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Поле ввода пароля
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                    textInputAction: TextInputAction.done,
                    validator: _validatePassword,
                    onFieldSubmitted: (_) => _login(),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Кнопка "Забыли пароль?"
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Забыли пароль?',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Сообщение об ошибке
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  // Кнопка входа
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _isLockedOut) ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLockedOut ? Colors.grey : Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : Text(
                              _isLockedOut 
                                  ? 'Заблокировано ($_lockoutTimeLeft сек)' 
                                  : _isEmailSelected 
                                      ? 'Войти' 
                                      : 'Отправить SMS',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 