import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'complete_registration_screen.dart';
import 'phone_complete_registration_screen.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../utils/notification_utils.dart';
import '../utils/phone_utils.dart';
import '../utils/logger.dart';
import '../services/deep_link_service.dart';
import 'email_confirmation_screen.dart';
import 'existing_user_login_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'phone_confirmation_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:oauth2_client/oauth2_client.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert' show utf8;
import 'package:crypto/crypto.dart' as crypto;
import 'home_screen.dart';
import 'match_details_screen.dart';
import 'skill_level_test_screen.dart';
import 'public_profile_screen.dart';
import 'courts/club_details_screen.dart';
import 'courts/booking_details_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'competition_details_screen.dart';
import 'training_detail_screen.dart';
import 'phone_login_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cityController = TextEditingController();
  
  String _selectedSkillLevel = 'любитель';
  bool _isLoading = false;
  String? _errorMessage;
  bool _isEmailSelected = true; // true для почты, false для телефона

  final List<String> _skillLevels = [
    'начинающий',
    'средний',
    'продвинутый',
  ];

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _cityController.dispose();
    super.dispose();
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
      if (value.length < 18) {
        return 'Введите номер телефона полностью';
      }
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите пароль';
    }
    if (value.length < 8) {
      return 'Пароль должен содержать минимум 8 символов';
    }
    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Введите $fieldName';
    }
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isLoading) return;

      setState(() {
        _isLoading = true;
      });

      try {
      if (_isEmailSelected) {
        final email = _emailController.text;
        final result = await ApiService.checkEmailAvailability(email);
        if (result.isAvailable) {
          // Email доступен - переходим на экран подтверждения почты
          if (mounted) {
            final confirmed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (context) => EmailConfirmationScreen(
                  email: email,
                ),
              ),
        );
            if (confirmed == true && mounted) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) =>
                    CompleteRegistrationScreen(email: email, isEmailConfirmed: true),
              ));
            }
          }
        } else {
          // Email уже зарегистрирован - переходим на экран входа
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (context) => ExistingUserLoginScreen(
                  email: email,
                  existingUserName: result.existingUserName ?? 'Пользователь',
                ),
              ),
            );
          }
        }
      } else {
        // Логика для телефона
        final phone = _emailController.text;
        final normalizedPhone = PhoneUtils.normalizePhoneForApi(phone);
        Logger.info('🔐 UI: Нормализовали телефон для проверки: $phone -> $normalizedPhone');
        
        final result = await ApiService.checkPhoneAvailability(normalizedPhone);
        if (result.isAvailable) {
          // Пользователь новый, переходим на экран подтверждения телефона
          final confirmed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => PhoneConfirmationScreen(phoneNumber: phone),
            ),
          );
          if (confirmed == true && mounted) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) =>
                  CompleteRegistrationScreen(phone: phone, isPhoneConfirmed: true),
            ));
          }
        } else {
          // Пользователь существует, запускаем вход по коду SMS
          Logger.info('🔐 UI: Пользователь с телефоном $normalizedPhone уже существует, отправляем код для входа');
          await ApiService.initPhoneLogin(PhoneInitRequest(phone: normalizedPhone));
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PhoneLoginVerificationScreen(
                  phoneNumber: normalizedPhone,
                ),
              ),
            );
          }
        }
        }
      } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: ${e.toString()}')));
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Некорректная ссылка')),
      );
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть ссылку')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка открытия ссылки: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                const SizedBox(height: 32),
                  
                // Логотип
                _buildLogo(),
                
                const SizedBox(height: 32),
                
                // Заголовки
                _buildHeader(),
                
                const SizedBox(height: 32),
                
                // Переключатель Почта/Телефон
                _buildAuthTypeSwitcher(),

                const SizedBox(height: 24),
                
                // Поле ввода email/телефона
                _buildInputField(),
                
                const SizedBox(height: 24),
                
                // Кнопка "Продолжить"
                _buildContinueButton(),
                
                // Отображение сообщения об ошибке
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                              child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                  ),
                  
                const SizedBox(height: 24),
                  
                // Разделитель "или"
                _buildDivider(),
                  
                const SizedBox(height: 24),

                // Кнопка Yandex
                _buildSocialButtonsRow(),
                  
                const SizedBox(height: 32),
                  
                // Условия использования
                _buildTermsText(),
                
                const SizedBox(height: 24),
              ],
                                ),
                              ),
          ),),
                          ),
    );
  }

  Widget _buildLogo() {
    return SvgPicture.asset(
      'assets/images/the_campus_icon.svg',
      height: 72,
    );
  }

  Widget _buildHeader() {
    return Column(
      children: const [
        Text(
          'Хочешь играть в падел\nс удовольствием?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 32,
            fontWeight: FontWeight.w500,
            height: 1.125,
            letterSpacing: -0.85,
          ),
        ),
        SizedBox(height: 21), // Изменено с 21 на 32
        Text(
          'Войти или создать профиль',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF222223),
            letterSpacing: -0.85,
                          ),
                        ),
                      ],
    );
  }

  Widget _buildAuthTypeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(2), // Внешний отступ
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: _buildSwitcherButton('Почта', true)),
          Expanded(child: _buildSwitcherButton('Телефон', false)),
        ],
      ),
    );
  }

  Widget _buildSwitcherButton(String text, bool isEmailButton) {
    final bool isSelected = (isEmailButton && _isEmailSelected) || (!isEmailButton && !_isEmailSelected);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_isEmailSelected != isEmailButton) {
          // FocusScope.of(context).unfocus();
          setState(() {
            _isEmailSelected = isEmailButton;
            _emailController.clear();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4), // Уменьшаем высоту до 5
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEFEEEC), width: 0.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.04),
                    blurRadius: 1,
                  ),
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.04),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.04),
                    blurRadius: 16,
                    offset: Offset(0, 12),
                    ),
                ],
              )
            : null,
        child: Center( // Центрируем текст
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 16,
              color: const Color(0xFF222223),
              fontWeight: isSelected ? FontWeight.w400 : FontWeight.w400,
              letterSpacing: -0.85,
                        ),
                      ),
                    ),
                  ),
    );
  }

  Widget _buildInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEmailSelected ? 'Почта' : 'Телефон',
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF79766E),
            letterSpacing: -0.85,
                          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey(_isEmailSelected ? 'email' : 'phone'),
          controller: _emailController,
          keyboardType: _isEmailSelected ? TextInputType.emailAddress : TextInputType.phone,
          inputFormatters: !_isEmailSelected ? [_PhoneInputFormatter()] : [],
          autofillHints: _isEmailSelected ? const [AutofillHints.email] : const [AutofillHints.telephoneNumber],
          decoration: InputDecoration(
            hintText: _isEmailSelected ? 'Введите вашу почту' : '+7 (999) 999-99-99',
            hintStyle: const TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 16,
              color: Color(0xFF79766E),
              letterSpacing: -0.85,
                      ),
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00897B), width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13), // Изменено с 14 на 13
          ),
          validator: _validateEmail,
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    bool isEnabled;
    final text = _emailController.text.trim();
    
    if (_isEmailSelected) {
      // Для email кнопка активна, если есть '@', '.' после него и минимум 2 символа после точки
      final atIndex = text.indexOf('@');
      if (atIndex != -1) {
        final dotIndex = text.indexOf('.', atIndex);
        if (dotIndex != -1 && text.length > dotIndex + 2) {
          isEnabled = true;
        } else {
          isEnabled = false;
        }
      } else {
        isEnabled = false;
      }
    } else {
      // Для телефона кнопка активна, если введен полный номер
      isEnabled = text.length == 18;
    }

    return SizedBox(
      height: 50, // Изменено с 48 на 50
                    child: ElevatedButton(
        onPressed: _isLoading || !isEnabled ? null : _register,
                      style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: const Color(0xFF00897B), 
          disabledBackgroundColor: const Color(0xFF7F8AC0),
                        foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          splashFactory: NoSplash.splashFactory, // Убираем анимацию нажатия
                        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
              height: 20.0,
              width: 20.0,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                strokeWidth: 3.0,
                              ),
                            )
                          : const Text(
                              'Продолжить',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.85,
                            ),
                    ),
                  ),
    );
  }

  Widget _buildDivider() {
    return Row(
                    children: [
        const Expanded(child: Divider(color: Color(0xFFEFEEEC))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24), // Изменено с 7 на 24
          child: Text(
            'или',
                        style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 16,
              color: Color(0xFF79766E),
              letterSpacing: -0.85,
                        ),
                      ),
        ),
        const Expanded(child: Divider(color: Color(0xFFEFEEEC))),
      ],
    );
  }

  Widget _buildSocialButtonsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAppleButton(),
        const SizedBox(height: 12),
        _buildYandexButton(),
      ],
    );
  }

  Widget _buildAppleButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () async {
          try {
            // Generate raw nonce and its SHA-256 hash (Apple expects the hashed nonce)
            final rawNonce = DateTime.now().millisecondsSinceEpoch.toString();
            final hashedNonce = crypto.sha256.convert(utf8.encode(rawNonce)).toString();

            // Use sign_in_with_apple to get credentials (pass hashed nonce)
            final credential = await SignInWithApple.getAppleIDCredential(
              scopes: [
                AppleIDAuthorizationScopes.email,
                AppleIDAuthorizationScopes.fullName,
              ],
              nonce: hashedNonce,
            );

            final idToken = credential.identityToken;
            if (idToken == null) {
              NotificationUtils.showError(context, 'Apple не вернул idToken');
              Logger.error('Apple Sign-In: idToken is null');
              return;
            }

            Logger.info('Apple Sign-In: got credentials. hasAuthCode=${credential.authorizationCode != null}, givenName=${credential.givenName}, familyName=${credential.familyName}');

            final appleResp = await ApiService.appleSignIn(
              idToken: idToken,
              authorizationCode: credential.authorizationCode,
              rawNonce: rawNonce,
              givenName: credential.givenName,
              familyName: credential.familyName,
            );

            if (appleResp.firstTime) {
              // первый вход: ведём на тест уровня, можно передать имя
              if (!mounted) return;
              final String firstName = (credential.givenName != null && credential.givenName!.isNotEmpty)
                  ? credential.givenName!
                  : 'Пользователь';
              final String lastName = (credential.familyName != null && credential.familyName!.isNotEmpty)
                  ? credential.familyName!
                  : 'User';
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SkillLevelTestScreen(
                    registrationData: {
                      'firstName': firstName,
                      'lastName': lastName,
                      'apple_id_token': idToken,
                      'apple_raw_nonce': rawNonce,
                      'apple_email': credential.email,
                    },
                  ),
                ),
              );
            } else if (appleResp.auth != null) {
              await AuthStorage.saveAuthData(appleResp.auth!);
              try {
                await FirebaseMessaging.instance.requestPermission();
                await ApiService.registerPushToken();
              } catch (_) {}
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
            } else {
              Logger.error('Apple Sign-In: неизвестный ответ бэка: без first_time и без auth');
              if (!mounted) return;
              NotificationUtils.showError(context, 'Не удалось завершить вход через Apple');
            }
          } catch (e) {
            if (!mounted) return;
            // Детализируем логи по типам исключений
            if (e is SignInWithAppleAuthorizationException) {
              Logger.error('Apple Sign-In failed: code=${e.code} message=${e.message}', e);
            } else if (e is PlatformException) {
              Logger.error('Apple Sign-In platform error: code=${e.code} message=${e.message}', e);
            } else {
              Logger.error('Apple Sign-In unknown error', e);
            }
            NotificationUtils.showError(context, 'Ошибка Apple Sign-In: $e');
          }
        },
        icon: Transform.translate(
          offset: const Offset(0, -5),
          child: const Icon(Icons.apple, size: 30, color: Color(0xFF222223)),
        ),
        label: const Text(
          'продолжить с Apple',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF222223),
            letterSpacing: -0.85,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: const Color(0xFFF2F2F2),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildYandexButton() {
    return SizedBox(
      height: 50, // Изменено с 48 на 50
      child: OutlinedButton.icon(
        onPressed: () async {
          // Вход через Яндекс OAuth
          try {
            final clientId = 'a9cf957086714d118ba498e0bbaaa430';
            final redirectUri = 'ru.thecampus.app://oauth-callback';

            final oauth2Client = OAuth2Client(
              authorizeUrl: 'https://oauth.yandex.ru/authorize',
              tokenUrl: 'https://oauth.yandex.ru/token',
              redirectUri: redirectUri,
              customUriScheme: 'ru.thecampus.app',
            );

            final tokenResponse = await oauth2Client.getTokenWithAuthCodeFlow(
              clientId: clientId,
              authCodeParams: {'force_confirm': 'yes'},
              webAuthOpts: {'preferEphemeral': true},
            );

            if (tokenResponse != null && tokenResponse.isValid()) {
              final oauthToken = tokenResponse.accessToken!;
              // 1. Отправляем токен на backend
              final callbackResp = await ApiService.yandexCallback(oauthToken);
              if (callbackResp.firstTime) {
                // 2. Новый пользователь — открываем экран теста
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SkillLevelTestScreen(
                        yandexOauthToken: oauthToken,
                      ),
                    ),
                  );
                }
              } else if (callbackResp.auth != null) {
                // 3. Уже зарегистрирован — сохраняем токен и профиль, переходим на главную
                await AuthStorage.saveAuthData(callbackResp.auth!);
                try {
                  await FirebaseMessaging.instance.requestPermission();
                  await ApiService.registerPushToken();
                } catch (_) {}
                
                // Обрабатываем навигацию после авторизации
                final navigationInfo = await DeepLinkService().handlePostAuthNavigation();
                
                if (context.mounted && navigationInfo != null) {
                  switch (navigationInfo.type) {
                    case NavigationType.match:
                      // Переходим к матчу
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => MatchDetailsScreen(matchId: navigationInfo.id),
                        ),
                        (route) => false,
                      );
                      break;
                    case NavigationType.profile:
                      if (navigationInfo.isOwnProfile == true) {
                        // Если это свой профиль, переходим на главный экран с вкладкой профиля
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(initialTabIndex: 3),
                          ),
                          (route) => false,
                        );
                      } else {
                        // Если это чужой профиль, переходим к PublicProfileScreen
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => PublicProfileScreen(userId: navigationInfo.id),
                          ),
                          (route) => false,
                        );
                      }
                      case NavigationType.club:
                        // Загружаем клуб и открываем экран
                        try {
                          final club = await ApiService.getClubById(navigationInfo.id);
                          if (!mounted) break;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ClubDetailsScreen(club: club),
                            ),
                          );
                        } catch (_) {}
                      break;
                    case NavigationType.competition:
                      // Переходим к соревнованию
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CompetitionDetailsScreen(competitionId: navigationInfo.id),
                        ),
                      );
                      break;
                    case NavigationType.training:
                      // Переходим к тренировке
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => TrainingDetailScreen(trainingId: navigationInfo.id),
                        ),
                      );
                      break;
                    case NavigationType.bookingSuccess:
                      // Переходим к успешному бронированию
                      try {
                        final booking = await ApiService.getBookingById(navigationInfo.id);
                        if (!mounted) break;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => BookingDetailsScreen(booking: booking),
                          ),
                        );
                      } catch (_) {}
                      break;
                  }
                } else {
                  // Иначе переходим на главный экран
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                }
              } else {
                print('Ошибка: не удалось авторизовать через Яндекс');
              }
            } else {
              print('Ошибка авторизации через Яндекс: ${tokenResponse?.errorDescription ?? 'Unknown error'}');
            }
          } catch (e) {
            print('Ошибка входа через Яндекс: ${e.toString()}');
            if (context.mounted) {
              final msg = e.toString().contains('ApiException') ? e.toString() : 'Не удалось войти через Яндекс';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg)),
              );
            }
          }
        },
        icon: SvgPicture.asset('assets/images/yandex_icon.svg', height: 20),
        label: const Text(
          'продолжить с Yandex',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF222223),
            letterSpacing: -0.85,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: const Color(0xFFF2F2F2),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTermsText() {
    return RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
          fontFamily: 'SF Pro Display',
          fontSize: 14,
          color: Color(0xFF222223),
                        height: 1.4,
          letterSpacing: -0.85,
                      ),
                      children: [
                        const TextSpan(text: 'Регистрируясь, вы принимаете наши '),
                        TextSpan(
            text: 'Условия\nиспользования',
            style: const TextStyle(color: Color(0xFF00897B), letterSpacing: -0.85),
            // recognizer: TapGestureRecognizer()..onTap = () => _launchURL('...'),
                        ),
          const TextSpan(text: ' и '),
                        TextSpan(
                          text: 'Политику конфиденциальности',
            style: const TextStyle(color: Color(0xFF00897B), letterSpacing: -0.85),
            recognizer: TapGestureRecognizer()..onTap = () => _launchURL('https://the-campus.app/privacy-policy.pdf'),
                        ),
                        const TextSpan(text: '.'),
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
