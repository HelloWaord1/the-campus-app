import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/services.dart'; // portrtait
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/competitions_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/match_details_screen.dart';
import 'services/auth_storage.dart';
import 'services/deep_link_service.dart';
import 'package:app_links/app_links.dart';
import 'screens/public_profile_screen.dart';
import 'screens/clubs/clubs_list_screen.dart';
import 'screens/clubs/clubs_map_screen.dart';
import 'screens/clubs/clubs_search_screen.dart';
import 'services/api_service.dart';
import 'screens/courts/club_details_screen.dart';
import 'screens/courts/booking_details_screen.dart';
import 'screens/competition_details_screen.dart';
import 'screens/training_detail_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
// dart:io не доступен на web, импортируем условно через stub
import 'utils/platform_utils.dart';
// duplicate import removed
// FCM background handler должен быть топ-уровневой функцией
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    debugPrint('[FCM][background] message data=${message.data}');
  } catch (e) {
    // ignore
  }
}
// Обертка для определения типа профиля
// ProfileWrapper больше не нужен — переходим сразу на PublicProfileScreen

class _AppLinkHandler {
  static AppLinks? _appLinks;

  static Future<void> init() async {
    _appLinks ??= AppLinks();
    _appLinks!.uriLinkStream.listen((uri) async {
      if (uri.host == 'the-campus.app' && uri.path == '/vk_id_redirect') {
        final code = uri.queryParameters['code'];
        if (code != null) {
          try {
            final isLoggedIn = await AuthStorage.getToken() != null;
            if (!isLoggedIn) {
              // Code flow больше не используется. Авторизация идёт через VK ID SDK на клиенте
            }
          } catch (_) {}
        }
      }
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([ // portrait
    DeviceOrientation.portraitUp, // portrait
  ]); // portrait
  await initializeDateFormatting('ru', null);

  // Firebase и FCM только на мобильных платформах
  if (!kIsWeb) {
    if (Firebase.apps.isEmpty) {
      if (PlatformUtils.isIOS) {
        // iOS: уже есть конфигурация из AppDelegate (GoogleService-Info.plist)
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    }
    // Регистрируем обработчик фоновых сообщений FCM
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    try {
      print('[FCM] requesting notification permission...');
      final settings = await FirebaseMessaging.instance.requestPermission();
      print('[FCM] permission status: ${settings.authorizationStatus}');

      final String? fcmToken = await FirebaseMessaging.instance.getToken();
      print('[FCM] initial token: ${fcmToken == null ? 'null' : (fcmToken.length <= 10 ? '***' : '${fcmToken.substring(0,6)}...${fcmToken.substring(fcmToken.length-4)}')}');

      // Если пользователь уже авторизован, регистрируем токен на бэкенде при старте
      try {
        final bool isLoggedIn = await AuthStorage.isLoggedIn();
        if (isLoggedIn) {
          print('[FCM] user is logged in, registering token on backend...');
          await ApiService.registerPushToken(overrideToken: fcmToken);
          print('[FCM] backend registration completed');
        }
      } catch (e) {
        debugPrint('[FCM] register on startup failed: $e');
      }

      // Подписываемся на обновление FCM токена и пере-регистрируем на бэкенде
      FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
        final masked = newToken.length <= 10 ? '***' : '${newToken.substring(0,6)}...${newToken.substring(newToken.length-4)}';
        print('[FCM] token refreshed: $masked');
        try {
          final bool isLoggedIn = await AuthStorage.isLoggedIn();
          if (isLoggedIn) {
            print('[FCM] user is logged in, re-registering refreshed token...');
            await ApiService.registerPushToken(overrideToken: newToken);
            print('[FCM] backend re-registration completed');
          }
        } catch (e) {
          debugPrint('[FCM] register on refresh failed: $e');
        }
      });
    } catch (e) {
      print('[FCM] failed to get token: $e');
    }

    // Обработка пуш-диплинка при запуске (tap по уведомлению из "убитого" состояния)
    try {
      final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[Main] getInitialMessage data=${initialMessage.data}');
        DeepLinkService().handleDeeplinkFromPushData(initialMessage.data);
      }
    } catch (_) {}
  }

  await _AppLinkHandler.init();

  runApp(const MyApp());
  // Инициализируем сервис глубоких ссылок после запуска UI, чтобы навигатор уже существовал
  // и были назначены колбэки в MyApp.initState
  // Небольшая задержка, чтобы дать времени построиться дереву виджетов
  Future.delayed(const Duration(milliseconds: 50), () async {
    try {
      await DeepLinkService().initialize();
    } catch (e) {
      debugPrint('[Main] DeepLinkService.initialize error: $e');
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _isHandlingSessionExpiry = false;
  bool _isHandlingForceUpdate = false;

  @override
  void initState() {
    super.initState();
    _installSessionExpiredHandler();
    _installForceUpdateHandler();
    _setupDeepLinkHandlers();
    _setupPushOpenHandler();
  }

  void _installForceUpdateHandler() {
    // Запускаем один раз после построения первого кадра, когда navigator уже создан.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkAndShowForceUpdateIfNeeded();
    });
  }

  Future<void> _checkAndShowForceUpdateIfNeeded() async {
    if (_isHandlingForceUpdate) return;
    _isHandlingForceUpdate = true;
    try {
      if (!PlatformUtils.isMobile) {
        _isHandlingForceUpdate = false;
        return;
      }

      final policy = await ApiService.getAppVersionPolicy();
      final platformKey = PlatformUtils.isAndroid ? 'android' : 'ios';

      final dynamic platformPolicyRaw = policy[platformKey];
      if (platformPolicyRaw is! Map) {
        _isHandlingForceUpdate = false;
        return;
      }
      final platformPolicy = Map<String, dynamic>.from(platformPolicyRaw as Map);

      final int minBuild = (() {
        final v = platformPolicy['min_build'];
        if (v is int) return v;
        if (v is String) return int.tryParse(v) ?? 0;
        return 0;
      })();

      final info = await PackageInfo.fromPlatform();
      final int currentBuild = int.tryParse(info.buildNumber) ?? 0;
      debugPrint(
        '[FORCE_UPDATE] platform=$platformKey current=${info.version}+${info.buildNumber} (build=$currentBuild) minBuild=$minBuild',
      );
      if (currentBuild >= minBuild || minBuild <= 0) {
        debugPrint('[FORCE_UPDATE] ok: update not required');
        _isHandlingForceUpdate = false;
        return;
      }
      debugPrint('[FORCE_UPDATE] blocked: update required');

      final String title = (policy['title'] is String && (policy['title'] as String).trim().isNotEmpty)
          ? (policy['title'] as String).trim()
          : 'Нужно обновить приложение';
      final String message = (policy['message'] is String && (policy['message'] as String).trim().isNotEmpty)
          ? (policy['message'] as String).trim()
          : 'Чтобы продолжить пользоваться приложением, обновите его до последней версии.';

      final ctx = _navigatorKey.currentContext;
      if (ctx == null) return;

      await showGeneralDialog<void>(
        context: ctx,
        barrierDismissible: false,
        barrierLabel: 'force-update',
        barrierColor: const Color(0xFFF3F5F6), // непрозрачный серый фон, скрывает содержимое снизу
        pageBuilder: (dialogContext, _, __) {
          return SafeArea(
            child: PopScope(
              canPop: false, // блокируем back
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.system_update_alt, size: 48, color: Color(0xFFFF6B6B)),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF222223)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF89867E)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              // Непропускаемый экран: предлагаем обновиться вручную и перезапустить приложение.
                              // Ссылку на стор намеренно не используем.
                              try {
                                if (PlatformUtils.isIOS) {
                                  PlatformUtils.exitApp();
                                } else {
                                  SystemNavigator.pop();
                                }
                              } catch (_) {}
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B6B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text('Выйти'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (_) {
      // fail-open: если не удалось проверить — не блокируем вход
      _isHandlingForceUpdate = false;
    }
  }

  void _installSessionExpiredHandler() {
    AuthStorage.onSessionExpired = () async {
      if (_isHandlingSessionExpiry) return;
      _isHandlingSessionExpiry = true;
      try {
        final ctx = _navigatorKey.currentContext;
        if (ctx != null) {
          await showGeneralDialog<void>(
            context: ctx,
            barrierDismissible: false,
            barrierLabel: 'session-expired',
            barrierColor: const Color(0xFFF3F5F6), // непрозрачный серый фон, скрывает содержимое снизу
            pageBuilder: (dialogContext, _, __) {
              return SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text(
                            'Сессия истекла',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF222223)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Токен доступа истек. Перезайдите заново в профиль.',
                            style: TextStyle(fontSize: 14, color: Color(0xFF89867E)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                try {
                                  await AuthStorage.clearAuthData();
                                } catch (_) {}
                                final isOnboardingCompleted = await AuthStorage.isOnboardingCompleted();
                                final target = isOnboardingCompleted ? '/register' : '/onboarding';
                                Navigator.of(dialogContext, rootNavigator: true).pop();
                                _navigatorKey.currentState?.pushNamedAndRemoveUntil(target, (route) => false);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B6B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('Выйти'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }
      } catch (_) {
        // ignore
      }
      _isHandlingSessionExpiry = false;
    };
  }

  void _setupDeepLinkHandlers() {
    final deepLinkService = DeepLinkService();
    debugPrint('[MyApp] Setting up deep link handlers');
    
    // Обработчик для перехода к матчу
    deepLinkService.onMatchLinkReceived = (String matchId) {
      debugPrint('[MyApp] onMatchLinkReceived matchId=$matchId');
      _navigatorKey.currentState?.pushNamed(
        '/match_details',
        arguments: matchId,
      );
    };
    
    // Обработчик для перехода к профилю
    deepLinkService.onProfileLinkReceived = (String profileId, bool isOwnProfile) {
      debugPrint('[MyApp] onProfileLinkReceived profileId=$profileId isOwn=$isOwnProfile');
      if (isOwnProfile) {
        // Если это свой профиль, переходим на главный экран с вкладкой профиля
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/profile_tab',
          (route) => false,
        );
      } else {
        // Если это чужой профиль, переходим к PublicProfileScreen
        _navigatorKey.currentState?.pushNamed(
          '/profile',
          arguments: profileId,
        );
      }
    };

    // Обработчик для перехода к клубу — открываем список клубов с предзаполненным фильтром по id
    deepLinkService.onClubLinkReceived = (String clubId) async {
      debugPrint('[MyApp] onClubLinkReceived clubId=$clubId');
      _navigatorKey.currentState?.pushNamed(
        '/clubs',
        arguments: {
          'clubId': clubId, // будет использован в списке/карте для автофокуса, если поддерживается
        },
      );
    };

    // Обработчик для перехода к соревнованию
    deepLinkService.onCompetitionLinkReceived = (String competitionId) {
      debugPrint('[MyApp] onCompetitionLinkReceived competitionId=$competitionId');
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => CompetitionDetailsScreen(competitionId: competitionId),
        ),
      );
    };

    // Обработчик для перехода к тренировке
    deepLinkService.onTrainingLinkReceived = (String trainingId) {
      debugPrint('[MyApp] onTrainingLinkReceived trainingId=$trainingId');
      _navigatorKey.currentState?.pushNamed(
        '/training_details',
        arguments: trainingId,
      );
    };

    // Обработчик для перехода к успешному бронированию (после оплаты)
    deepLinkService.onBookingSuccessLinkReceived = (String bookingId) async {
      debugPrint('[MyApp] onBookingSuccessLinkReceived bookingId=$bookingId');
      try {
        // Загружаем бронирование по ID
        final booking = await ApiService.getBookingById(bookingId);
        
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => BookingDetailsScreen(booking: booking),
          ),
        );
      } catch (e) {
        debugPrint('[MyApp] Ошибка загрузки бронирования $bookingId: $e');
      }
    };

    // После регистрации колбэков пробуем обработать возможную отложенную навигацию
    // (например, если ссылка пришла до инициализации колбэков)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final pending = await deepLinkService.handlePostAuthNavigation();
        if (pending == null) return;
        switch (pending.type) {
          case NavigationType.match:
            _navigatorKey.currentState?.pushNamed(
              '/match_details',
              arguments: pending.id,
            );
            break;
          case NavigationType.profile:
            if (pending.isOwnProfile == true) {
              _navigatorKey.currentState?.pushNamedAndRemoveUntil(
                '/profile_tab',
                (route) => false,
              );
            } else {
              _navigatorKey.currentState?.pushNamed(
                '/profile',
                arguments: pending.id,
              );
            }
            break;
          case NavigationType.club:
            // Экран ещё не подключен; пока ничего не делаем
            break;
          case NavigationType.competition:
            _navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => CompetitionDetailsScreen(competitionId: pending.id),
              ),
            );
            break;
          case NavigationType.training:
            _navigatorKey.currentState?.pushNamed(
              '/training_details',
              arguments: pending.id,
            );
            break;
          case NavigationType.bookingSuccess:
            try {
              final booking = await ApiService.getBookingById(pending.id);
              _navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (context) => BookingDetailsScreen(booking: booking),
                ),
              );
            } catch (e) {
              debugPrint('[MyApp] Ошибка загрузки бронирования ${pending.id}: $e');
            }
            break;
        }
      } catch (e) {
        debugPrint('[MyApp] post-callback pending navigation error: $e');
      }
    });
  }

  void _setupPushOpenHandler() {
    if (kIsWeb) return; // FCM не используется на web
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      try {
        debugPrint('[MyApp] onMessageOpenedApp data=${message.data}');
        DeepLinkService().handleDeeplinkFromPushData(message.data);
      } catch (e) {
        debugPrint('[MyApp] onMessageOpenedApp error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Campus',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final m = MediaQuery.of(context);
        return MediaQuery(
          data: m.copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
        useMaterial3: true,
        //primarySwatch: const Color(0xFF00897B),
        primaryColor: const Color(0xFF00897B),
        focusColor: const Color(0xFF00897B),
        dividerColor: const Color(0xFF00897B).withOpacity(0.2),
        fontFamily: 'Inter',
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF00897B),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthChecker(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/main': (context) => const HomeScreen(), // Добавляем этот маршрут
        '/profile_tab': (context) => const HomeScreen(initialTabIndex: 3), // Добавляем маршрут для вкладки профиля
        '/onboarding': (context) => const OnboardingScreen(),
        '/match_details': (context) {
          final matchId = ModalRoute.of(context)!.settings.arguments as String;
          return MatchDetailsScreen(matchId: matchId);
        },
        '/training_details': (context) {
          final trainingId = ModalRoute.of(context)!.settings.arguments as String;
          return TrainingDetailScreen(trainingId: trainingId);
        },
        '/profile': (context) {
          final profileId = ModalRoute.of(context)!.settings.arguments as String;
          return PublicProfileScreen(userId: profileId);
        },
        // Клубы
        '/clubs': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          final String? deepLinkClubId = args?['clubId'] as String?;
          if (deepLinkClubId != null && deepLinkClubId.isNotEmpty) {
            // Если пришёл клуб по диплинку — грузим детали и открываем экран клуба
            return FutureBuilder(
              future: ApiService.getClubById(deepLinkClubId),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  // Фолбэк: открываем список клубов
                  return ClubsListScreen(
                    initialCity: args?['city'] as String?,
                    initialName: (args?['clubName'] ?? args?['name']) as String?,
                    initialCourtType: args?['courtType'] as String?,
                    initialCourtSize: args?['courtSize'] as String?,
                    initialDistanceKm: args?['distanceKm'] as int?,
                    initialNearMe: (args?['nearMe'] as bool?) ?? false,
                  );
                }
                return ClubDetailsScreen(club: snapshot.data!);
              },
            );
          }
          // Обычный маршрут списка клубов
          return ClubsListScreen(
            initialCity: args?['city'] as String?,
            initialName: (args?['clubName'] ?? args?['name']) as String?,
            initialCourtType: args?['courtType'] as String?,
            initialCourtSize: args?['courtSize'] as String?,
            initialDistanceKm: args?['distanceKm'] as int?,
            initialNearMe: (args?['nearMe'] as bool?) ?? false,
          );
        },
        '/clubs_map': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return ClubsMapScreen(
            nearMe: (args?['nearMe'] as bool?) ?? false,
            city: args?['city'] as String?,
            name: args?['name'] as String?,
            courtType: args?['courtType'] as String?,
            courtSize: args?['courtSize'] as String?,
            distanceKm: (args?['distanceKm'] as int?) ?? 50,
          );
        },
        '/clubs_search': (context) => const ClubsSearchScreen(),
        '/competitions': (context) => const CompetitionsScreen(),
      },
    );
  }
}

class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  bool _isLoading = true;
  // ignore: unused_field
  bool _isLoggedIn = false;
  // ignore: unused_field
  bool _isOnboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Перепроверяем статус при каждом возврате на этот экран
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final isLoggedIn = await AuthStorage.isLoggedIn();
      final isOnboardingCompleted = await AuthStorage.isOnboardingCompleted();
      
      // Если пользователь якобы авторизован, проверим валидность токена
      if (isLoggedIn) {
        final token = await AuthStorage.getToken();
        if (token == null || token.isEmpty) {
          // Токен отсутствует - очищаем данные
          await AuthStorage.clearAuthData();
          setState(() {
            _isLoggedIn = false;
            _isOnboardingCompleted = isOnboardingCompleted;
            _isLoading = false;
          });
          return;
        }
      }
      
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isOnboardingCompleted = isOnboardingCompleted;
        _isLoading = false;
      });
    } catch (e) {
      // При любой ошибке очищаем данные авторизации
      await AuthStorage.clearAuthData();
      final isOnboardingCompleted = await AuthStorage.isOnboardingCompleted();
      
      setState(() {
        _isLoggedIn = false;
        _isOnboardingCompleted = isOnboardingCompleted;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Если пользователь авторизован - показываем главный экран
    if (_isLoggedIn) {
      return const HomeScreen();
    }

    // Если онбординг не завершен - показываем онбординг
    if (!_isOnboardingCompleted) {
      return const OnboardingScreen();
    }

    // Иначе показываем экран регистрации
    return const RegisterScreen();
  }
}
