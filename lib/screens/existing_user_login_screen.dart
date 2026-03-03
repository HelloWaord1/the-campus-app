import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../services/deep_link_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/notification_utils.dart';
import '../utils/logger.dart';
import '../utils/phone_utils.dart';
import '../models/user.dart';
import 'home_screen.dart';
import 'match_details_screen.dart';
import 'public_profile_screen.dart';
import 'courts/club_details_screen.dart';
import 'courts/booking_details_screen.dart';
import 'competition_details_screen.dart';
import 'training_detail_screen.dart';

class ExistingUserLoginScreen extends StatefulWidget {
  final String email;
  final String existingUserName;

  const ExistingUserLoginScreen({
    super.key,
    required this.email,
    required this.existingUserName,
  });

  @override
  State<ExistingUserLoginScreen> createState() => _ExistingUserLoginScreenState();
}

class _ExistingUserLoginScreenState extends State<ExistingUserLoginScreen> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    Logger.info('🔐 UI: Открываем экран ввода пароля для: ${widget.email} (${widget.existingUserName})');
    _passwordController.addListener(() {
      setState(() {}); // Обновляем состояние, чтобы перерисовать кнопку
    });
    super.initState();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_passwordController.text.trim().isEmpty) {
      NotificationUtils.showError(context, 'Введите пароль');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Нормализуем номер телефона если это телефон, иначе оставляем как есть  
      String loginIdentifier = widget.email;
      if (widget.email.startsWith('+') || widget.email.startsWith('7') || widget.email.startsWith('8')) {
        // Это телефон, нормализуем его
        loginIdentifier = PhoneUtils.normalizePhoneForApi(widget.email);
        Logger.info('🔐 UI: Нормализовали телефон: ${widget.email} -> $loginIdentifier');
      }
      
      final loginRequest = LoginRequest(
        email: loginIdentifier,
        password: _passwordController.text.trim(),
      );

      Logger.info('🔐 UI: Начинаем авторизацию по логину: ${loginRequest.email}');
      print('--- Login Attempt ---');
      print('Email: ${loginRequest.email}');
      print('Password: ${loginRequest.password}');

      final authResponse = await ApiService.login(loginRequest);
      Logger.success('🔐 UI: Успешная авторизация');

      // Сохраняем токен и данные пользователя
      await AuthStorage.saveAuthData(authResponse);
      try {
        await FirebaseMessaging.instance.requestPermission();
        await ApiService.registerPushToken();
      } catch (_) {}
      
      // Обрабатываем навигацию после авторизации
      final navigationInfo = await DeepLinkService().handlePostAuthNavigation();

      Navigator.of(context).pushNamedAndRemoveUntil(
            '/main',
            (route) => false,
          );

      if (mounted && navigationInfo != null) {
        switch (navigationInfo.type) {
          case NavigationType.match:
            // Переходим к матчу
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MatchDetailsScreen(matchId: navigationInfo.id),
              ),
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PublicProfileScreen(userId: navigationInfo.id),
                ),
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
      }
      
      NotificationUtils.showSuccess(
        context,
        'Добро пожаловать, ${widget.existingUserName}!',
      );
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        print('--- Login Failed ---');
        print('Error: $e');
        print('StackTrace: $stackTrace');
        
        String errorMessage = 'Ошибка входа';
        if (e is ApiException) {
          if (e.message.contains('password') || e.message.contains('пароль')) {
            errorMessage = 'Неверный пароль';
          } else {
            errorMessage = e.message;
          }
        }
        
        NotificationUtils.showError(context, errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            // Кнопка назад
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.chevron_left, size: 32, color: Color(0xFF262F63)),
              ),
            ),
            
            // Основной контент
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  // Заголовок
                  _buildWelcomeTitle(),
                  
                  const SizedBox(height: 32),
                  
                  // Форма ввода пароля
                  _buildPasswordForm(),
                ],
              ),
            ),
            const Spacer(),
            // Кнопка входа
            _buildLoginButton(),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.chevron_left,
              color: Color(0xFF262F63),
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              'Назад',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Color(0xFF262F63),
                letterSpacing: -0.85,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeTitle() {
    return Text(
      'Добро пожаловать, ${widget.existingUserName}!',
      style: const TextStyle(
        fontFamily: 'SF Pro Display',
        fontWeight: FontWeight.w500,
        fontSize: 24,
        color: Color(0xFF222223),
        height: 1.5, // 36px / 24px
        letterSpacing: -0.85,
      ),
    );
  }

  Widget _buildPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Лейбл "Пароль"
        const Text(
          'Пароль',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: Color(0xFF79766E),
            height: 1.286,
            letterSpacing: -0.85,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Поле ввода пароля
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w400,
            fontSize: 16,
            color: Color(0xFF222223),
            letterSpacing: -0.85,
          ),
          decoration: InputDecoration(
            hintText: 'Введите пароль',
            hintStyle: const TextStyle(
              fontFamily: 'SF Pro Display',
              fontWeight: FontWeight.w400,
              fontSize: 16,
              color: Color(0xFF79766E),
              letterSpacing: -0.85,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF79766E),
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              borderSide: const BorderSide(color: Color(0xFF262F63), width: 1),
            ),
          ),
          onFieldSubmitted: (_) => _login(),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    final bool isEnabled = _passwordController.text.length >= 8;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        height: 48, // Задаем высоту кнопки
        child: ElevatedButton(
          onPressed: _isLoading || !isEnabled ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF262F63),
            disabledBackgroundColor: const Color(0xFF7F8AC0),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
              : const Text(
                  'Войти',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    letterSpacing: -0.85,
                  ),
                ),
        ),
      ),
    );
  }
} 