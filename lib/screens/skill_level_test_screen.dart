import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../utils/rating_utils.dart';
import '../services/deep_link_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'home_screen.dart';
import 'match_details_screen.dart';
import 'public_profile_screen.dart';
import 'courts/club_details_screen.dart';
import 'courts/booking_details_screen.dart';
import 'competition_details_screen.dart';
import 'training_detail_screen.dart';

// Экран 1: Интро
class SkillLevelTestScreen extends StatelessWidget {
  final Map<String, dynamic>? registrationData; // Может быть null, если запуск из профиля
  final String? yandexOauthToken;
  final String? vkAccessToken;
  final String? vkAuthCode;
  final String? vkRedirectUri;
  final String? vkCodeVerifier;
  final bool isRetestFlow; // запуск из повторного тестирования
  
  const SkillLevelTestScreen({super.key, this.registrationData, this.yandexOauthToken, this.vkAccessToken, this.vkAuthCode, this.vkRedirectUri, this.vkCodeVerifier, this.isRetestFlow = false});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: SvgPicture.asset('assets/images/back_icon.svg', width: 24, height: 24),
        ),
        title: const Text(
          'Определение уровня игры',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF222223),
            letterSpacing: -0.85,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24), // Отступ от AppBar
              const Text('Ответь на 7 вопросов — и мы подберём тебе уровень.', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 24, fontWeight: FontWeight.w500, color: Color(0xFF222223), height: 1.5, letterSpacing: -0.85)),
              const SizedBox(height: 16),
              const Text('Постарайся оценить свои навыки объективно. Лучше немного занизить уровень, чем переоценить.', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF222223), height: 1.2, letterSpacing: -0.85)),
              const SizedBox(height: 12),
              const Text('После первого матча рейтинг будет обновляться автоматически по результатам твоих игр.', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF222223), height: 1.2, letterSpacing: -0.85)),
              const SizedBox(height: 12),
              const Text('* Вопросы основаны на системе International Padel Rating (IPR)', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF7F8AC0), letterSpacing: -0.85)),
              const Spacer(),
              ElevatedButton(
                onPressed: () async {
                  final updated = await Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => SkillLevelQuestionScreen(
                      registrationData: registrationData,
                      yandexOauthToken: yandexOauthToken,
                      vkAccessToken: vkAccessToken,
                      vkAuthCode: vkAuthCode,
                      vkRedirectUri: vkRedirectUri,
                      vkCodeVerifier: vkCodeVerifier,
                      isRetestFlow: isRetestFlow,
                    ),
                  ));
                  if (updated == true && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF262F63),
                  minimumSize: const Size.fromHeight(50),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Начать', style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: -0.85)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

// Экран 2: Вопросы
class SkillLevelQuestionScreen extends StatefulWidget {
  final Map<String, dynamic>? registrationData;
  final String? yandexOauthToken;
  final String? vkAccessToken;
  final String? vkAuthCode;
  final String? vkRedirectUri;
  final VoidCallback? onRatingInitialized;
  final String? vkCodeVerifier;
  final bool isRetestFlow;

  const SkillLevelQuestionScreen({super.key, this.registrationData, this.yandexOauthToken, this.vkAccessToken, this.vkAuthCode, this.vkRedirectUri, this.onRatingInitialized, this.vkCodeVerifier, this.isRetestFlow = false});

  @override
  State<SkillLevelQuestionScreen> createState() => _SkillLevelQuestionScreenState();
}

class _SkillLevelQuestionScreenState extends State<SkillLevelQuestionScreen> {
  int _currentStep = 0;
  bool _showFinal = false;
  final List<int> _answers = [];
  String? _finalLetter;
  double? _finalNumericRating;
  String? _preferredHand;
  bool _isLoading = false;
  String? _error;

  final List<_LevelTestStepData> _steps = [
    _LevelTestStepData(
      questionNumber: 1,
      questionText: 'Как долго ты играешь в падел или похожие ракеточные виды спорта?',
      answers: [
        'Только взял ракетку',
        'Начинающие игрок (3 мес.)',
        'Продвинутый игрок (6-12 мес.)',
        'Уверенный игрок (1-3 лет)',
        'Полу-профессионал',
      ],
    ),
    _LevelTestStepData(
      questionNumber: 2,
      questionText: 'Как ты играешь от стекла?',
      answers: [
        'Пока не использую отскоки от стекла',
        'Иногда пробую, но не всегда получается',
        'Получается отбивать после прямого отскока',
        'Уверенно играю после отскока от заднего или бокового стекла',
        'Использую стекло как часть такики, могу перевести розыгрыш в свою пользу',
      ],
    ),
    _LevelTestStepData(
      questionNumber: 3,
      questionText: 'Что ты делаешь, когда мяч летит высоко на тебя?',
      answers: [
        'Просто подставляю ракетку',
        'Пробую смэш, иногда получается',
        'Бью смэш или бандеху, в зависимости от ситуации',
        'Могу выполнить и бандеху, и вибору, и атакующий смэш',
        'Владею всеми видами смэшей, варьирую силу и направление осознанно',
      ],
    ),
    _LevelTestStepData(
      questionNumber: 4,
      questionText: 'Понимаешь ли ты различия между первым и вторым квадрантом?',
      answers: ['Да', 'Нет', 'Не до конца'],
    ),
    _LevelTestStepData(
      questionNumber: 5,
      questionText: 'Как ты работаешь над своими навыками?',
      answers: [
        'Я не тренируюсь и играю как получается ради развлечения',
        'Сходил на 1-3 тренировки. Мне пока этого хватает',
        'Я иногда посещаю тренировки или работаю над определенными элементами игры',
        'Я регулярно тренируюсь и стараюсь развивать все аспекты своей игры',
        'Я систематически тренируюсь, анализирую свои матчи и работаю с тренером',
      ],
    ),
    _LevelTestStepData(
      questionNumber: 6,
      questionText: 'Принимал(а) ли ты участие в турнирах по паделу?',
      answers: [
        'Никогда не участвовал(а)',
        'Играл(а) в форматах типа "Американо" или внутренних матчах клуба',
        'Участвовал(а) в Pro-Am турнирах (любитель + профессионал)',
        'Играл(а) в турнирах Российского Падел Тура (РПТ)',
        'Участвовал(а) в официальных международных турнирах FIP (Federation Internacional de Padel)',
      ],
    ),
    _LevelTestStepData(
      questionNumber: 7,
      questionText: 'Ты правша/левша?',
      answers: ['Правша', 'Левша'],
    ),
  ];

  void _onAnswer(int answerIndex) {
    // Если это последний вопрос (о руке)
    if (_currentStep == _steps.length - 1) {
      setState(() {
        _preferredHand = ['right', 'left'][answerIndex];
        // Теперь считаем рейтинг, когда все ответы собраны
        final rawTotalScore = _answers.asMap().entries.fold<int>(0, (sum, entry) {
          return sum + mapAnswerToScore(entry.key, entry.value);
        });
        final normalizedScore = normalizeScore(rawTotalScore);
        // Буква и число теперь оба базируются на одном и том же Elo-рейтингe,
        // чтобы совпадать с тем, что пользователь потом видит в профиле.
        final calculatedRating = (700 + ((rawTotalScore - 6) / 24) * 900).round();
        _finalLetter = ratingToLetter(calculateRating(calculatedRating));
        _finalNumericRating = calculateRating(calculatedRating);
        _showFinal = true;
      });
      return;
    }

    // Для вопросов 1-6 просто сохраняем ответ
    if (_answers.length > _currentStep) {
      _answers[_currentStep] = answerIndex;
    } else {
      _answers.add(answerIndex);
    }
    setState(() => _currentStep++);
  }
  
  void _restartTest() => setState(() {
    _currentStep = 0;
    _showFinal = false;
    _answers.clear();
    _finalLetter = null;
    _finalNumericRating = null;
    _preferredHand = null;
    _error = null;
  });

  void _onBack() {
    if (_showFinal) {
      setState(() {
        _showFinal = false;
        _currentStep = _steps.length - 1;
      });
      return;
    }
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onSave() async {
    if (_finalLetter == null) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final rawTotalScore = _answers.asMap().entries.fold<int>(0, (sum, entry) {
        return sum + mapAnswerToScore(entry.key, entry.value);
      });
      final calculatedRating = (700 + ((rawTotalScore - 6) / 24) * 900).round();

      // Если это регистрация через Яндекс
      if (widget.yandexOauthToken != null) {
        final authResponse = await ApiService.completeYandexRegistration(
          oauthToken: widget.yandexOauthToken!,
          city: 'Москва', // Город по умолчанию
          currentRating: calculatedRating,
          preferredHand: _preferredHand,
        );
        await AuthStorage.saveAuthData(authResponse);
        try {
          await FirebaseMessaging.instance.requestPermission();
          await ApiService.registerPushToken();
        } catch (_) {}
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } else if (widget.vkAccessToken != null) {
        // Регистрация стандартным путём через /api/register/email с данными профиля VK
        final firstName = widget.registrationData?['vk_first_name'] as String? ?? 'Пользователь';
        final lastName = widget.registrationData?['vk_last_name'] as String? ?? '';
        final email = widget.registrationData?['vk_email'] as String? ?? 'user_${DateTime.now().millisecondsSinceEpoch}@paddle-app.ru';
        final phone = widget.registrationData?['vk_phone'] as String?;
        // final avatarUrl = widget.registrationData?['vk_avatar_url'] as String?; // пока не используется на бэке
        final password = 'vk_${DateTime.now().millisecondsSinceEpoch}';

        final req = RegisterRequest(
          firstName: firstName,
          lastName: lastName,
          email: email,
          password: password,
          phone: phone,
          city: 'Москва',
          skillLevel: 'любитель',
          currentRating: calculatedRating,
          preferredHand: _preferredHand,
        );
        final authResponse = await ApiService.register(req);
        await AuthStorage.saveAuthData(authResponse);
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } else if (widget.registrationData != null && widget.registrationData!.containsKey('vk_first_name')) {
        // Регистрация по переданному профилю VK через /api/register/email
        final firstName = widget.registrationData?['vk_first_name'] as String? ?? 'Пользователь';
        final lastName = widget.registrationData?['vk_last_name'] as String? ?? '';
        final email = widget.registrationData?['vk_email'] as String? ?? 'user_${DateTime.now().millisecondsSinceEpoch}@paddle-app.ru';
        final phone = widget.registrationData?['vk_phone'] as String?;
        final password = 'vk_${DateTime.now().millisecondsSinceEpoch}';

        final req = RegisterRequest(
          firstName: firstName,
          lastName: lastName,
          email: email,
          password: password,
          phone: phone,
          city: 'Москва',
          skillLevel: 'любитель',
          currentRating: calculatedRating,
          preferredHand: _preferredHand,
        );
        final authResponse = await ApiService.register(req);
        await AuthStorage.saveAuthData(authResponse);
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } else if (widget.registrationData != null && widget.registrationData!.containsKey('firstName') && widget.registrationData!.containsKey('lastName') && widget.registrationData!.containsKey('apple_id_token') && widget.registrationData!.containsKey('apple_raw_nonce')) {
        // Регистрация через Apple после теста уровня
        final firstName = (widget.registrationData!['firstName'] as String?)?.trim();
        final lastName = (widget.registrationData!['lastName'] as String?)?.trim();
        final safeFirst = (firstName != null && firstName.isNotEmpty) ? firstName : 'Пользователь';
        final safeLast = (lastName != null && lastName.isNotEmpty) ? lastName : 'User';
        final idToken = widget.registrationData!['apple_id_token'] as String;
        final rawNonce = widget.registrationData!['apple_raw_nonce'] as String;
        final appleEmail = widget.registrationData!['apple_email'] as String?;
        final String effectiveEmail = (appleEmail != null && appleEmail.isNotEmpty)
            ? appleEmail
            : 'user_${DateTime.now().millisecondsSinceEpoch}@paddle-app.ru';

        final authResponse = await ApiService.appleRegister(
          idToken: idToken,
          rawNonce: rawNonce,
          firstName: safeFirst,
          lastName: safeLast,
          email: effectiveEmail,
          phone: null,
          city: 'Москва',
          currentRating: calculatedRating,
          skillLevel: 'любитель',
          preferredHand: _preferredHand,
        );
        await AuthStorage.saveAuthData(authResponse);
        try {
          await FirebaseMessaging.instance.requestPermission();
          await ApiService.registerPushToken();
        } catch (_) {}
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } else if (widget.registrationData != null) {
        // Если это обычная регистрация
        final request = RegisterRequest(
          firstName: widget.registrationData!['firstName'],
          lastName: widget.registrationData!['lastName'],
          email: widget.registrationData!['email'],
          password: widget.registrationData!['password'],
          city: widget.registrationData!['city'],
          phone: widget.registrationData!['phone'],
          skillLevel: 'профессионал',
          currentRating: calculatedRating,
          preferredHand: _preferredHand,
        );
        final authResponse = await ApiService.register(request);
        await AuthStorage.saveAuthData(authResponse);
        try {
          await FirebaseMessaging.instance.requestPermission();
          await ApiService.registerPushToken();
        } catch (_) {}
        
        // Обрабатываем навигацию после авторизации
        final navigationInfo = await DeepLinkService().handlePostAuthNavigation();
        
        if (mounted && navigationInfo != null) {
          switch (navigationInfo.type) {
            case NavigationType.match:
              // Переходим к матчу
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => MatchDetailsScreen(matchId: navigationInfo.id),
                ),
                (Route<dynamic> route) => false,
              );
              break;
            case NavigationType.profile:
              if (navigationInfo.isOwnProfile == true) {
                // Если это свой профиль, переходим на главный экран с вкладкой профиля
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const HomeScreen(initialTabIndex: 3),
                  ),
                  (Route<dynamic> route) => false,
                );
              } else {
                // Если это чужой профиль, переходим к PublicProfileScreen
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => PublicProfileScreen(userId: navigationInfo.id),
                  ),
                  (Route<dynamic> route) => false,
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
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } else {
        // Инициализация/переинициализация рейтинга для существующего пользователя
        if (widget.isRetestFlow) {
          await ApiService.reinitializeUserRating(_finalLetter!);
        } else {
          await ApiService.initializeUserRating(_finalLetter!);
        }
        if (mounted) {
          widget.onRatingInitialized?.call();
          Navigator.of(context).pop(true); 
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _showFinal
            ? _LevelTestFinalView(
                onRestart: _restartTest,
                onSave: _onSave,
                letter: _finalLetter ?? 'D',
                numericRating: _finalNumericRating ?? 1.0,
                isLoading: _isLoading,
                error: _error,
                onBack: _onBack,
              )
            : _LevelTestQuestionView(
                currentStep: _currentStep,
                totalSteps: _steps.length,
                step: _steps[_currentStep],
                onAnswer: _onAnswer,
                onBack: _onBack,
              ),
      ),
    );
  }
}

// Вспомогательные виджеты и классы данных

class _LevelTestStepData {
  final int questionNumber;
  final String questionText;
  final List<String> answers;
  _LevelTestStepData({required this.questionNumber, required this.questionText, required this.answers});
}

class _LevelTestQuestionView extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final _LevelTestStepData step;
  final void Function(int answerIndex) onAnswer;
  final VoidCallback onBack;

  const _LevelTestQuestionView({
    required this.currentStep,
    required this.totalSteps,
    required this.step,
    required this.onAnswer,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Убираем общий Padding, чтобы управлять отступами для каждого элемента
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Выравнивание по левому краю
        children: [
          const SizedBox(height: 22), // Отступ от статус-бара
          // Новая шапка
          _buildHeader(context),
          const SizedBox(height: 20), // Уменьшен до 16
          // Вопрос и ответы с нужными отступами
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${currentStep + 1}/${totalSteps}',
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF89867E),
                    letterSpacing: -0.85,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  step.questionText,
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222223),
                    height: 1.2,
                    letterSpacing: -0.85,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Условное отображение заметки для последнего вопроса
          if (currentStep == totalSteps - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Text(
                    '*Ответ на этот вопрос не влияет на ваш уровень',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      color: const Color(0xFF7F8AC0).withOpacity(0.8),
                      letterSpacing: -0.85,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          // Ответы
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: step.answers.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LevelTestAnswerButton(
                  text: step.answers[i],
                  onTap: () => onAnswer(i),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: GestureDetector(
        onTap: onBack,
        child: Row(
          children: [
            SvgPicture.asset('assets/images/green_back_icon.svg', height: 24, width: 24),
            const SizedBox(width: 8),
            const Text(
              'Назад',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF262F63),
                letterSpacing: -0.85,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelTestAnswerButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const _LevelTestAnswerButton({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        constraints: const BoxConstraints(minHeight: 68),
        decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.centerLeft,
        child: Text(text,
            // textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 16,
              color: Color(0xFF222223),
              height: 1.25, // Уменьшенный межстрочный интервал
              letterSpacing: -0.8,
            )),
      ),
    );
  }
}

class _LevelTestFinalView extends StatelessWidget {
  final VoidCallback onRestart;
  final Future<void> Function() onSave;
  final String letter;
  final bool isLoading;
  final String? error;
  final double numericRating; // Добавляем числовой рейтинг
  final VoidCallback onBack;

  const _LevelTestFinalView({
    required this.onRestart,
    required this.onSave,
    required this.letter,
    required this.numericRating,
    this.isLoading = false,
    this.error,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        _buildHeader(context),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Твой рейтинг',
                style: const TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF222223),
                  height: 1.5, // 36px / 24px
                  letterSpacing: -0.85,
                ),
              ),
              const SizedBox(height: 16), // Уменьшаем отступ
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    letter,
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 64,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF262F63),
                      height: 0.5, // Визуальная коррекция для выравнивания
                      letterSpacing: -0.85,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    numericRating.toStringAsFixed(2),
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 64,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF262F63),
                      height: 0.5, // Визуальная коррекция для выравнивания
                      letterSpacing: -0.85,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32), // Уменьшаем отступ
              _buildInfoText(
                  'Первые 15 матчей формируют приблизительный рейтинг. Чем больше сыгранных матчей — тем точнее он становится.'),
              const SizedBox(height: 16), // Уменьшаем отступ
              _buildInfoText('После 40+ матчей рейтинг считается достоверным.'),
              const SizedBox(height: 16), // Уменьшаем отступ
              _buildClickableInfoText('Пройти тест повторно можно в профиле'),
              const SizedBox(height: 16), // Уменьшаем отступ
              _buildInfoText(
                  'Также ты сможешь перепройти его из профиля — но только до того, как запишешь первый матч.'),
            ],
          ),
        ),
        const Spacer(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Text(error!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center),
          ),
        _buildContinueButton(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: GestureDetector(
        onTap: onBack,
        child: Row(
          children: [
            SvgPicture.asset('assets/images/green_back_icon.svg', height: 24, width: 24),
            const SizedBox(width: 8),
            const Text(
              'Назад',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF262F63),
                letterSpacing: -0.85,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'SF Pro Display',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Color(0xFF222223),
        height: 1.25,
        letterSpacing: -0.85,
      ),
    );
  }

  Widget _buildClickableInfoText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'SF Pro Display',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Color(0xFF262F63),
        height: 1.25,
        letterSpacing: -0.85,
      ),
    );
  }

  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: isLoading ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF262F63),
            disabledBackgroundColor: const Color(0xFF7F8AC0),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: isLoading
              ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
      ),
    );
  }
} 