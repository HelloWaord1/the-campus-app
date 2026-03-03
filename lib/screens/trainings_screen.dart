import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import '../models/training.dart';
import '../services/api_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/training_filters_modal.dart';
import 'training_detail_screen.dart';
import '../utils/notification_utils.dart';

class TrainingsScreen extends StatefulWidget {
  const TrainingsScreen({super.key});

  @override
  State<TrainingsScreen> createState() => _TrainingsScreenState();
}

class _TrainingsScreenState extends State<TrainingsScreen> {
  List<Training> _trainings = [];
  bool _isLoading = true;
  String _selectedTab = 'available'; // 'available' или 'my_trainings'
  TrainingFilters _filters = TrainingFilters();
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _loadTrainings();
  }

  /// Получить текущие координаты пользователя
  Future<Position?> _getUserPosition() async {
    try {
      // Проверяем, включены ли сервисы геолокации
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Проверяем разрешения
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Получаем позицию
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (e) {
      debugPrint('Ошибка получения координат: $e');
      return null;
    }
  }

  Future<void> _loadTrainings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_selectedTab == 'available') {
        // Конвертируем уровень сложности в min/max level
        double? minLevel;
        double? maxLevel;
        
        if (_filters.difficulty != null && _filters.difficulty != 'all') {
          switch (_filters.difficulty) {
            case 'beginner':
              minLevel = 1.0;
              maxLevel = 2.0;
              break;
            case 'intermediate':
              minLevel = 2.5;
              maxLevel = 3.5;
              break;
            case 'advanced':
              minLevel = 3.5;
              maxLevel = 5.0;
              break;
          }
        }
        
        // Получаем координаты пользователя (если нужен фильтр по расстоянию)
        double? userLat;
        double? userLon;
        double? maxDistanceKm;
        
        if (_filters.distanceKm != null && _filters.distanceKm! > 0) {
          // Пытаемся получить реальные координаты пользователя
          if (_userPosition == null) {
            _userPosition = await _getUserPosition();
          }
          
          if (_userPosition != null) {
            // Проверяем, находится ли пользователь в разумной близости от России
            // Примерные границы: широта 41-82°N, долгота 19-180°E
            final isInRussia = _userPosition!.latitude >= 41 && 
                               _userPosition!.latitude <= 82 && 
                               _userPosition!.longitude >= 19 && 
                               _userPosition!.longitude <= 180;
            
            if (isInRussia) {
              userLat = _userPosition!.latitude;
              userLon = _userPosition!.longitude;
              maxDistanceKm = _filters.distanceKm;
              
              debugPrint('📍 Фильтр по расстоянию (реальная геопозиция):');
              debugPrint('   Координаты: $userLat, $userLon');
              debugPrint('   Радиус: $maxDistanceKm км');
            } else {
              // Пользователь за пределами России, используем Москву
              userLat = 55.7558;
              userLon = 37.6173;
              maxDistanceKm = _filters.distanceKm;
              
              debugPrint('📍 Фильтр по расстоянию (пользователь за пределами РФ, fallback к Москве):');
              debugPrint('   Реальные координаты: ${_userPosition!.latitude}, ${_userPosition!.longitude}');
              debugPrint('   Используем: $userLat, $userLon');
              debugPrint('   Радиус: $maxDistanceKm км');
              
              // Показываем уведомление пользователю
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Вы находитесь за пределами зоны обслуживания. Показываем тренировки в Москве.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          } else {
            // Если не удалось получить координаты, используем координаты Москвы по умолчанию
            userLat = 55.7558;
            userLon = 37.6173;
            maxDistanceKm = _filters.distanceKm;
            
            debugPrint('📍 Фильтр по расстоянию (не удалось получить геопозицию, fallback к Москве):');
            debugPrint('   Координаты: $userLat, $userLon');
            debugPrint('   Радиус: $maxDistanceKm км');
          }
        }
        
        debugPrint('🔍 Параметры запроса тренировок:');
        debugPrint('   search: ${_filters.city}');
        debugPrint('   type: ${_filters.type}');
        debugPrint('   minLevel: $minLevel');
        debugPrint('   maxLevel: $maxLevel');
        debugPrint('   userLatitude: $userLat');
        debugPrint('   userLongitude: $userLon');
        debugPrint('   maxDistanceKm: $maxDistanceKm');
        
        _trainings = await ApiService.getTrainings(
          search: _filters.city, // Используем city как search параметр
          type: _filters.type,
          startDate: _filters.startDate,
          endDate: _filters.endDate,
          selectedDates: _filters.selectedDates,
          selectedTimes: _filters.selectedTimes,
          minLevel: minLevel,
          maxLevel: maxLevel,
          userLatitude: userLat,
          userLongitude: userLon,
          maxDistanceKm: maxDistanceKm,
        );
      } else {
        _trainings = await ApiService.getMyTrainings();
      }
    } catch (e, stackTrace) {
      // Подробное логирование ошибки
      debugPrint('❌ Ошибка загрузки тренировок:');
      debugPrint('Тип ошибки: ${e.runtimeType}');
      debugPrint('Сообщение: $e');
      debugPrint('Stack trace: $stackTrace');
      
      String errorMessage = 'Ошибка при загрузке тренировок';
      
      if (e is ApiException) {
        debugPrint('Статус код: ${e.statusCode}');
        debugPrint('Сообщение API: ${e.message}');
        
        switch (e.statusCode) {
          case 400:
            errorMessage = e.message.isNotEmpty ? e.message : 'Неверные параметры запроса';
            break;
          case 401:
            errorMessage = 'Необходимо войти в систему';
            break;
          case 404:
            errorMessage = 'Тренировки не найдены';
            break;
          case 500:
            errorMessage = 'Ошибка сервера. Попробуйте позже или обратитесь к администратору';
            break;
          default:
            errorMessage = e.message.isNotEmpty ? e.message : 'Ошибка при загрузке тренировок';
        }
      }
      
      if (mounted) {
        NotificationUtils.showError(context, errorMessage);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F6), // Фон из Figma
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF89867E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Тренировки',
          style: TextStyle(
            color: Color(0xFF222223),
            fontSize: 18,
            fontWeight: FontWeight.w500,
            fontFamily: 'SF Pro Display',
            letterSpacing: -0.36, // -2% от 18
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.asset(
                  'assets/images/filter_icon.svg',
                  width: 20.4, // Уменьшено на 15% от 24
                  height: 20.4,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF00897B),
                    BlendMode.srcIn,
                  ),
                ),
                if (_filters.hasFilters)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE14856),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              TrainingFiltersScreen.show(
                context,
                initialFilters: _filters,
                onFiltersChanged: (filters) {
                  setState(() {
                    _filters = filters;
                  });
                  _loadTrainings();
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Табы
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedTab = 'available');
                      _loadTrainings();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == 'available' 
                                ? const Color(0xFF00897B) 
                                : const Color(0xFFD9D9D9),
                            width: _selectedTab == 'available' ? 2 : 1,
                          ),
                        ),
                      ),
                      child: Text(
                        'Доступные',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 'available' 
                              ? const Color(0xFF222223) 
                              : const Color(0xFF89867E),
                          fontSize: 16,
                          fontWeight: _selectedTab == 'available' 
                              ? FontWeight.w500 
                              : FontWeight.w400,
                          fontFamily: 'SF Pro Display',
                          letterSpacing: -0.32, // -2% от 16
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedTab = 'my_trainings');
                      _loadTrainings();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == 'my_trainings' 
                                ? const Color(0xFF00897B) 
                                : const Color(0xFFD9D9D9),
                            width: _selectedTab == 'my_trainings' ? 2 : 1,
                          ),
                        ),
                      ),
                      child: Text(
                        'Ваши тренировки',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 'my_trainings' 
                              ? const Color(0xFF222223) 
                              : const Color(0xFF89867E),
                          fontSize: 16,
                          fontWeight: _selectedTab == 'my_trainings' 
                              ? FontWeight.w500 
                              : FontWeight.w400,
                          fontFamily: 'SF Pro Display',
                          letterSpacing: -0.32, // -2% от 16
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Основной контент
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _buildTrainingsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingsList() {
    if (_trainings.isEmpty) {
      return const Center(
        child: Text(
          'Нет доступных тренировок',
          style: TextStyle(
            color: Color(0xFF89867E),
            fontSize: 16,
            fontFamily: 'SF Pro Display',
          ),
        ),
      );
    }

    // Группируем тренировки по датам
    final Map<String, List<Training>> groupedTrainings = {};
    for (final training in _trainings) {
      final dateKey = training.formattedDate;
      groupedTrainings[dateKey] ??= [];
      groupedTrainings[dateKey]!.add(training);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: groupedTrainings.entries.toList().asMap().entries.map((mapEntry) {
        final index = mapEntry.key;
        final entry = mapEntry.value;
        final isFirst = index == 0;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок даты
            Padding(
              padding: EdgeInsets.only(top: isFirst ? 8 : 0, bottom: 14), // +2 для первой, одинаковый bottom
              child: Text(
                entry.key,
                style: const TextStyle(
                  color: Color(0xFF222223),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'SF Pro Display',
                  letterSpacing: -0.45, // -2% от 18
                  height: 1.0, // lineHeight из Figma
                ),
              ),
            ),
            
            // Список тренировок на эту дату
            ...entry.value.asMap().entries.map((trainingEntry) {
              final isLast = trainingEntry.key == entry.value.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: _buildTrainingCard(trainingEntry.value),
              );
            }),
            
            const SizedBox(height: 24), // Отступ между группами
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTrainingCard(Training training) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrainingDetailScreen(
              trainingId: training.id,
              isMyTraining: training.isMyTraining,
            ),
          ),
        );
        
        // Обновляем список после возвращения, если были изменения
        if (result == true) {
          _loadTrainings();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD9D9D9)),
        ),
        child: Column(
        children: [
          // Основная часть карточки
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок с иконкой и временем
                Row(
                  children: [
                    // Иконка академической шапки
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SvgPicture.asset(
                        'assets/images/training_icon.svg',
                        width: 64,
                        height: 64,
                        fit: BoxFit.contain,
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Разделитель
                    Container(
                      width: 1,
                      height: 32,
                      color: const Color(0xFFECECEC),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Время и название
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            training.formattedTime,
                            style: const TextStyle(
                              color: Color(0xFF222223),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'SF Pro Display',
                              letterSpacing: -0.45, // -2% от 16
                              height: 1.125, // lineHeight из Figma
                            ),
                          ),
                          const SizedBox(height: 7), // Уменьшено на 20% (с 12 до 9.6)
                          Text(
                            training.title,
                            style: const TextStyle(
                              color: Color(0xFF222223),
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'SF Pro Display',
                              letterSpacing: -0.45, // -2% от 18
                              height: 1.222, // lineHeight из Figma
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Информация о типе тренировки
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/images/chart_bar_icon.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF222223),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      training.levelRange,
                      style: const TextStyle(
                        color: Color(0xFF222223),
                        fontSize: 14,
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -0.33, // -2% от 14
                        height: 1.286, // lineHeight из Figma
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '·',
                      style: TextStyle(
                        color: Color(0xFF222223),
                        fontSize: 14,
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -0.33,
                        height: 1.286,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      training.typeDisplayName,
                      style: const TextStyle(
                        color: Color(0xFF222223),
                        fontSize: 14,
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -0.33,
                        height: 1.286,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Участники и тренер
                if (training.isGroup)
                  // Групповая тренировка: участники слева, тренер справа
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildParticipantsAvatars(training),
                          const SizedBox(width: 8),
                          Text(
                            '${training.currentParticipants}/${training.maxParticipants}',
                            style: const TextStyle(
                              color: Color(0xFF89867E),
                              fontSize: 14,
                              fontFamily: 'SF Pro Display',
                              letterSpacing: -0.33,
                              height: 1.286,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          UserAvatar(
                            imageUrl: training.trainerAvatar,
                            userName: training.trainerName,
                            radius: 12,
                            backgroundColor: const Color(0xFFE0E0E0),
                            borderColor: null,
                            borderWidth: 0,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            training.trainerName,
                            style: const TextStyle(
                              color: Color(0xFF222223),
                              fontSize: 14,
                              fontFamily: 'SF Pro Display',
                              letterSpacing: -0.33,
                              height: 1.286,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  // Индивидуальная тренировка: тренер слева
                  Row(
                    children: [
                      UserAvatar(
                        imageUrl: training.trainerAvatar,
                        userName: training.trainerName,
                        radius: 12,
                        backgroundColor: const Color(0xFFE0E0E0),
                        borderColor: null,
                        borderWidth: 0,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        training.trainerName,
                        style: const TextStyle(
                          color: Color(0xFF222223),
                          fontSize: 14,
                          fontFamily: 'SF Pro Display',
                          letterSpacing: -0.33,
                          height: 1.286,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Разделитель
          Container(
            height: 1,
            color: const Color(0xFFD9D9D9),
          ),
          
          // Нижняя часть с клубом и ценой (высота уменьшена на 25%)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 11), // Уменьшено с 16 до 12 (25%)
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        training.clubName,
                        style: const TextStyle(
                          color: Color(0xFF222223),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'SF Pro Display',
                          letterSpacing: -0.33,
                          height: 1.286,
                        ),
                      ),
                      const SizedBox(height: 4), // Отступ между названием клуба и городом
                      Text(
                        training.clubCity,
                        style: const TextStyle(
                          color: Color(0xFF89867E),
                          fontSize: 14,
                          fontFamily: 'SF Pro Display',
                          letterSpacing: -0.33,
                          height: 1.286,
                        ),
                      ),
                    ],
                  ),
                ),
                // Показываем цену только для вкладки "Доступные"
                if (_selectedTab == 'available')
                  Text(
                    '${training.price.toInt()}₽',
                    style: const TextStyle(
                      color: Color(0xFF00897B),
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -0.45,
                      height: 1.222,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildParticipantsAvatars(Training training) {
    // Берём до 3 участников. Если пришёл полный список участников — используем его,
    // иначе fallback на список URL-ов аватарок.
    final hasParticipants = training.participants.isNotEmpty;
    final participantList = hasParticipants
        ? training.participants.take(3).toList()
        : <TrainingParticipant>[];
    final avatarUrls = !hasParticipants
        ? training.participantAvatars.take(3).toList()
        : <String>[];
    final count = hasParticipants ? participantList.length : avatarUrls.length;
    final remainingCount = training.currentParticipants - count;
    
    // Используем Stack для создания эффекта наложения
    List<Widget> avatarWidgets = [];
    
    // Добавляем аватары участников
    for (int index = 0; index < count; index++) {
      avatarWidgets.add(
        Positioned(
          left: index * 20.0, // Смещение на 20 пикселей
          child: UserAvatar(
            imageUrl: hasParticipants
                ? participantList[index].avatarUrl
                : (avatarUrls[index].isNotEmpty ? avatarUrls[index] : null),
            userName: hasParticipants
                ? participantList[index].fullName
                : 'Участник',
            radius: 12,
            backgroundColor: const Color(0xFFF7F7F7),
            borderColor: Colors.white,
            borderWidth: 1,
          ),
        ),
      );
    }
    
    // Добавляем кнопку добавления, если есть свободные места
    if (training.hasSpots) {
      avatarWidgets.add(
        Positioned(
          left: count * 20.0,
          child: CircleAvatar(
            radius: 12,
            backgroundColor: Colors.white,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF7F8AC0)),
              ),
              child: const Icon(
                Icons.add,
                size: 16,
                color: Color(0xFF00897B),
              ),
            ),
          ),
        ),
      );
    }
    
    final totalWidth = (count + (training.hasSpots ? 1 : 0)) * 20.0 + 4.0;
    
    return SizedBox(
      width: totalWidth,
      height: 24,
      child: Stack(
        children: avatarWidgets,
      ),
    );
  }

}