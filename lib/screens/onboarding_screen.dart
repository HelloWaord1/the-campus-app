import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_storage.dart';
import 'register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Ваш рейтинг',
      description: 'Создай профиль, узнай свой уровень\nи отслеживай прогресс',
      imagePath: 'assets/images/your_rating_onboarding.png',
    ),
    OnboardingData(
      title: 'Бронь кортов',
      description: 'Находи корты в любом городе\nи бронируй в удобное время',
      imagePath: 'assets/images/booking_onboarding.jpg',
    ),
    OnboardingData(
      title: 'Партнеры для игр\nв любом городе',
      description: 'Добавляй друзей, находи партнеров\nи вызывай на матчи',
      imagePath: 'assets/images/friends_onboarding.png',
    ),
    OnboardingData(
      title: 'Соревнования',
      description: 'Создавай турниры и участвуй\n в соревнованиях для повышения\n рейтинга',
      imagePath: 'assets/images/competition_onboarding.png',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() async {
    // Сохраняем флаг что онбординг пройден
    await AuthStorage.setOnboardingCompleted();
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const RegisterScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemCount: _pages.length,
          itemBuilder: (context, index) {
            return _buildOnboardingPage(_pages[index]);
          },
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingData data) {
    return Stack(
      children: [
        // Background image with gradient overlay (full screen)
        _buildBackgroundImage(data.imagePath),
        
        // Content overlay with safe area
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: _buildSkipButton(),
                      ),
                    ),
              // сonst SizedBox(height: 32),
              // Top section with logo and skip button using a Stack for alignment
              const SizedBox(height: 24),
              Center(child: _buildLogo()),
              
              const Spacer(),
              
              // Title
              _buildTitle(data.title),
              
              const SizedBox(height: 16),
              
              // Description
              _buildDescription(data.description),
              
              const SizedBox(height: 24),
              
              // Page indicators
              _buildPageIndicators(),
              
              const SizedBox(height: 24),
              
              // Continue button
              _buildContinueButton(),
              
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundImage(String imagePath) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.5, 5.0],
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.black.withOpacity(0.0),
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return SvgPicture.asset(
      'assets/images/the_campus_white_label.svg',
      height: 110,
      width: 110,
    );
  }

  Widget _buildSkipButton() {
    return GestureDetector(
      onTap: _finishOnboarding,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          'Пропустить',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.6),
            letterSpacing: -0.32,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'SF Pro Display',
          fontSize: 32,
          fontWeight: FontWeight.w500,
          color: Colors.white,
          height: 1.125,
          letterSpacing: -0.64,
        ),
      ),
    );
  }

  Widget _buildDescription(String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        description,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'SF Pro Display',
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: Colors.white,
          height: 1.2,
          letterSpacing: -0.4,
        ),
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 20,
          height: 4,
          decoration: BoxDecoration(
            color: index == _currentPage 
                ? Colors.white 
                : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF222223),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text(
            'Продолжить',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.32,
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final String imagePath;

  OnboardingData({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}