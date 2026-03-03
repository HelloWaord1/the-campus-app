import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/training.dart';
import '../models/club.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/rating_mismatch_modal.dart';
import '../widgets/club_card.dart';
import '../widgets/user_avatar.dart';
import '../utils/rating_utils.dart';
import '../utils/notification_utils.dart';
import '../utils/calendar_utils.dart';
import 'public_profile_screen.dart';
import 'participants_list_screen.dart';

class TrainingDetailScreen extends StatefulWidget {
  final String trainingId;
  final bool isMyTraining;

  const TrainingDetailScreen({
    super.key,
    required this.trainingId,
    this.isMyTraining = true,
  });

  @override
  _TrainingDetailScreenState createState() => _TrainingDetailScreenState();
}

class _TrainingDetailScreenState extends State<TrainingDetailScreen> {
  Training? _training;
  bool _isLoading = true;
  bool _isDescriptionExpanded = false;
  String? _error;
  String? _currentUserId;
  double? _currentUserRating;
  bool _paymentSuccessShown = false; // Чтобы не показывать success повторно на одном экране

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadTrainingDetails();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthStorage.getUser();
    if (user != null) {
      setState(() {
        _currentUserId = user.id;
      });
      // Загружаем рейтинг пользователя
      await _loadUserRating();
    }
  }

  Future<void> _loadUserRating() async {
    try {
      final rating = await ApiService.getCurrentUserRating();
      if (rating != null && rating.rating != null) {
        setState(() {
          _currentUserRating = calculateRating(rating.rating!.toInt());
        });
      }
    } catch (e) {
      debugPrint('Не удалось загрузить рейтинг пользователя: $e');
    }
  }

  Future<void> _loadTrainingDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final training = await ApiService.getTrainingDetails(widget.trainingId);
      setState(() {
        _training = training;
        _isLoading = false;
      });

      // Показать уведомление в зависимости от статуса оплаты текущего пользователя
      if (!_paymentSuccessShown && training.myPaymentStatus != null) {
        if (training.myPaymentStatus == 'succeeded') {
          _paymentSuccessShown = true;
          if (mounted) {
            NotificationUtils.showSuccess(context, 'Оплата тренировки прошла успешно');
          }
        } else if (training.myPaymentStatus == 'canceled') {
          _paymentSuccessShown = true;
          if (mounted) {
            NotificationUtils.showError(
              context,
              'Вы не успели оплатить бронь, средства будут возвращены на ваш счёт, попробуйте записаться ещё раз',
            );
          }
        }
      }
    } catch (e) {
      String errorMessage = 'Ошибка при загрузке деталей тренировки';
      
      if (e is ApiException) {
        switch (e.statusCode) {
          case 400:
            errorMessage = e.message.isNotEmpty ? e.message : 'Неверные параметры запроса';
            break;
          case 401:
            errorMessage = 'Необходимо войти в систему';
            break;
          case 404:
            errorMessage = 'Тренировка не найдена';
            break;
          case 500:
            errorMessage = e.message.isNotEmpty ? e.message : 'Ошибка сервера';
            break;
          default:
            errorMessage = e.message.isNotEmpty ? e.message : 'Ошибка при загрузке деталей тренировки';
        }
      }
      
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelTraining() async {
    if (_training == null) return;

    try {
      await ApiService.cancelTraining(_training!.id);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вы отменили участие')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      String errorMessage = 'Ошибка при отмене участия';
      
      if (e is ApiException) {
        switch (e.statusCode) {
          case 400:
            errorMessage = e.message.isNotEmpty ? e.message : 'Невозможно отменить участие';
            break;
          case 401:
            errorMessage = 'Необходимо войти в систему';
            break;
          case 404:
            errorMessage = 'Тренировка не найдена';
            break;
          case 500:
            errorMessage = e.message.isNotEmpty ? e.message : 'Ошибка сервера';
            break;
          default:
            errorMessage = e.message.isNotEmpty ? e.message : 'Ошибка при отмене участия';
        }
      }
      
      if (mounted) {
        NotificationUtils.showError(context, errorMessage);
      }
    }
  }

  Future<void> _joinTraining() async {
    if (_training == null) return;

    try {
      final response = await ApiService.joinTraining(_training!.id);
      
      if (!mounted) return;
      
      // Если требуется оплата, открываем ссылку на оплату
      if (response.paymentRequired && response.paymentUrl != null) {
        await _handlePayment(response.paymentUrl!, response.paymentId);
      } else {
        // Бесплатная тренировка - просто показываем успех
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вы записались на тренировку')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      String errorMessage = 'Ошибка при записи на тренировку';
      
      if (e is ApiException) {
        switch (e.statusCode) {
          case 400:
            // Проверяем конкретные случаи ошибок
            if (e.message.toLowerCase().contains('уже') || 
                e.message.toLowerCase().contains('already') ||
                e.message.toLowerCase().contains('записан')) {
              errorMessage = 'Вы уже записаны на эту тренировку';
            } else if (e.message.toLowerCase().contains('нет свободных мест') ||
                       e.message.toLowerCase().contains('no spots') ||
                       e.message.toLowerCase().contains('переполнен')) {
              errorMessage = 'В тренировке нет свободных мест';
            } else if (e.message.toLowerCase().contains('рейтинг') ||
                       e.message.toLowerCase().contains('уровень') ||
                       e.message.toLowerCase().contains('rating') ||
                       e.message.toLowerCase().contains('level')) {
              errorMessage = e.message.isNotEmpty ? e.message : 'Ваш уровень не соответствует требованиям тренировки';
            } else {
              errorMessage = e.message.isNotEmpty ? e.message : 'Невозможно записаться на тренировку';
            }
            break;
          case 401:
            errorMessage = 'Необходимо войти в систему';
            break;
          case 404:
            errorMessage = 'Тренировка не найдена';
            break;
          case 500:
            errorMessage = e.message.isNotEmpty ? e.message : 'Ошибка сервера';
            break;
          default:
            errorMessage = e.message.isNotEmpty ? e.message : 'Ошибка при записи на тренировку';
        }
      }
      
      if (mounted) {
        NotificationUtils.showError(context, errorMessage);
      }
    }
  }

  Future<void> _handlePayment(String paymentUrl, String? paymentId) async {
    // Мгновенно открываем ссылку на оплату без дополнительного подтверждения
    try {
      final uri = Uri.parse(paymentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        // Показываем информационное сообщение
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('После оплаты вы вернетесь в приложение'),
              duration: Duration(seconds: 3),
            ),
          );
          
          // Закрываем экран деталей тренировки
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Не удалось открыть ссылку на оплату');
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(
          context,
          'Ошибка при открытии страницы оплаты: $e',
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final weekdays = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    
    final weekday = weekdays[dateTime.weekday - 1];
    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final time = DateFormat('HH:mm').format(dateTime);
    
    return '$weekday, $day $month, $time';
  }

  int _getDurationInMinutes() {
    if (_training == null) return 60;
    final duration = _training!.endTime.difference(_training!.startTime);
    return duration.inMinutes;
  }

  // Проверка, является ли текущий пользователь участником тренировки
  bool _isCurrentUserParticipant() {
    if (_training == null || _currentUserId == null) return false;
    return _training!.participants.any((p) => p.userId == _currentUserId);
  }

  // Проверка соответствия рейтинга пользователя требованиям тренировки
  bool _isRatingMatching() {
    if (_training == null || _currentUserRating == null) return true; // Разрешаем если рейтинг не загружен
    
    // minLevel и maxLevel в тренировке уже в формате уровней (1.0-5.0), не нужно конвертировать
    final minLevel = _training!.minLevel;
    final maxLevel = _training!.maxLevel;
    
    debugPrint('Training level range: $minLevel - $maxLevel');
    debugPrint('User rating level: $_currentUserRating');
    
    return _currentUserRating! >= minLevel && _currentUserRating! <= maxLevel;
  }

  Future<void> _shareTraining() async {
    final trainingUrl = 'https://the-campus.app/training/${widget.trainingId}';
    
    try {
      await Clipboard.setData(ClipboardData(text: trainingUrl));
      
      if (mounted) {
        NotificationUtils.showSuccess(
          context, 
          'Ссылка на тренировку скопирована в буфер обмена',
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(
          context, 
          'Ошибка при копировании ссылки',
        );
      }
    }
  }

  Future<void> _addToCalendar() async {
    if (_training == null) return;
    
    try {
      final success = await CalendarUtils.addTrainingToCalendar(_training!);
      
      if (mounted) {
        if (success) {
          _showSuccessAlert();
        } else {
          NotificationUtils.showError(
            context,
            'Не удалось добавить тренировку в календарь',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(
          context,
          'Ошибка при добавлении в календарь',
        );
      }
    }
  }

  void _showSuccessAlert() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Успешно добавлено',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222223),
            ),
          ),
          content: const Text(
            'Тренировка добавлена в ваш календарь',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF222223),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Ок',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF00897B),
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Белый фон
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Ошибка: $_error'))
              : _buildContent(),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_training != null) _buildBottomButton(),
          BottomNavBar(
            currentIndex: 3, // Профиль
            onTabTapped: (index) {
              // Навигация по табам
              Navigator.of(context).popUntil((route) => route.isFirst);
              
              // Переход на нужную вкладку в HomeScreen
              if (index == 0) {
                // Главная
                Navigator.of(context).pushReplacementNamed('/home');
              } else if (index == 1) {
                // Комьюнити
                Navigator.of(context).pushReplacementNamed('/home', arguments: {'initialTab': 1});
              } else if (index == 2) {
                // Уведомления
                Navigator.of(context).pushReplacementNamed('/home', arguments: {'initialTab': 2});
              }
            },
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFFFFFFF),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF89867E)),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'О тренировке',
        style: TextStyle(
          color: Color(0xFF222223),
          fontSize: 16.2, // Уменьшено на 10% (18 * 0.9)
          fontWeight: FontWeight.w500,
          fontFamily: 'SF Pro Display',
          letterSpacing: -0.945, // Уменьшено на 10%
        ),
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(32),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: SvgPicture.asset(
              'assets/images/share_icon.svg',
              width: 17,
              height: 18,
              colorFilter: const ColorFilter.mode(
                Color(0xFF89867E), // Серый цвет
                BlendMode.srcIn,
              ),
            ),
            onPressed: _shareTraining,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_training == null) return const SizedBox();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Название тренировки
            const SizedBox(height: 1),
            _buildTitleSection(),
            const SizedBox(height: 13),
            
            // Блок с количеством оставшихся мест
            _buildSpotsLeftBadge(),
            // Отступ если блок отображается
            if ((_training!.isGroup && (_training!.maxParticipants - _training!.currentParticipants) > 0) ||
                (_training!.isIndividual && _training!.currentParticipants > 0))
              const SizedBox(height: 22),
            
            // Описание и тип тренировки
            _buildDescriptionSection(),
            const SizedBox(height: 32),
            
            // Карточка с деталями (цена, дата, уровень, длительность)
            _buildDetailsCard(),
            const SizedBox(height: 32),
            
            // Информация о тренере
            _buildTrainerSection(),
            const SizedBox(height: 41),
            
            // Участники (только для групповых)
            if (_training!.isGroup) ...[
              _buildParticipantsSection(),
              const SizedBox(height: 32),
            ],
            
            // Карточка клуба
            _buildClubCard(),
            const SizedBox(height: 100), // Space for bottom button
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Row(
          children: [
            SvgPicture.asset(
              'assets/images/academic_cap_large.svg',
              width: 44,
              height: 44,
              colorFilter: const ColorFilter.mode(
                Color(0xFFC4C4C4),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _training!.title,
                style: const TextStyle(
                  color: Color(0xFF222223),
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'SF Pro Display',
                  letterSpacing: -0.81,
                  height: 1.2,
                ),
              ),
            ),
          ],
    );
  }

  // Блок с количеством оставшихся мест (из Figma)
  Widget _buildSpotsLeftBadge() {
    final spotsLeft = _training!.maxParticipants - _training!.currentParticipants;
    
    // Для индивидуальной тренировки: показываем "Нет мест!" если есть участник
    // if (_training!.isIndividual && _training!.currentParticipants > 0) {
    //   return Container(
    //     padding: const EdgeInsets.fromLTRB(12, 7.5, 16, 8),
    //     decoration: BoxDecoration(
    //       color: const Color(0xFFFF6B6B).withOpacity(0.05),
    //       border: Border.all(
    //         color: const Color(0xFFFF6B6B).withOpacity(0.2),
    //         width: 1,
    //       ),
    //       borderRadius: BorderRadius.circular(20),
    //     ),
    //     child: Row(
    //       mainAxisSize: MainAxisSize.min,
    //       children: [
    //         Container(
    //           width: 8,
    //           height: 8,
    //           decoration: const BoxDecoration(
    //             color: Color(0xFFFF6B6B),
    //             shape: BoxShape.circle,
    //           ),
    //         ),
    //         const SizedBox(width: 8),
    //         const Text(
    //           'Нет мест',
    //           style: TextStyle(
    //             color: Color(0xFF222223),
    //             fontSize: 16,
    //             fontWeight: FontWeight.w400,
    //             fontFamily: 'SF Pro Display',
    //             letterSpacing: -0.32,
    //             height: 1.125,
    //           ),
    //         ),
    //       ],
    //     ),
    //   );
    // }
    
    // Для групповой тренировки: показываем "Осталось n мест!" если есть места
    if (_training!.isGroup && spotsLeft > 0) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 7.5, 16, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withOpacity(0.05),
          border: Border.all(
            color: const Color(0xFFFF6B6B).withOpacity(0.2),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B6B),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Осталось $spotsLeft ${_getSpotsWord(spotsLeft)}!',
              style: const TextStyle(
                color: Color(0xFF222223),
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontFamily: 'SF Pro Display',
                letterSpacing: -0.32,
                height: 1.125,
              ),
            ),
          ],
        ),
      );
    }
    
    // В остальных случаях не показываем блок
    return const SizedBox.shrink();
  }

  String _getSpotsWord(int spots) {
    if (spots == 1) return 'место';
    if (spots >= 2 && spots <= 4) return 'места';
    return 'мест';
  }

  // Форматирование числа с пробелами между тысячами
  String _formatPrice(double price) {
    final intPrice = price.toInt();
    final priceString = intPrice.toString();
    final buffer = StringBuffer();
    
    for (int i = 0; i < priceString.length; i++) {
      if (i > 0 && (priceString.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(priceString[i]);
    }
    
    return buffer.toString();
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Описание',
          style: TextStyle(
            color: Color(0xFF222223),
            fontSize: 17,
            fontWeight: FontWeight.w400,
            fontFamily: 'SF Pro Display',
            letterSpacing: -0.675,
            height: 1.11,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          _training!.description,
          maxLines: _isDescriptionExpanded ? null : 3,
          overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF89867E),
            fontSize: 16, // Уменьшено на 10%
            fontWeight: FontWeight.w400,
            fontFamily: 'SF Pro Display',
            letterSpacing: -0.675,
            height: 1.25,
          ),
        ),
        if (!_isDescriptionExpanded && _training!.description.length > 100) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isDescriptionExpanded = true;
                });
              },
              child: const Text(
                'Показать',
                style: TextStyle(
                  color: Color(0xFF222223),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'SF Pro Display',
                  letterSpacing: -0.675,
                  height: 1.25,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Тип тренировки ',
              style: TextStyle(
                color: Color(0xFF79766E),
                fontSize: 12.6,
                fontWeight: FontWeight.w400,
                fontFamily: 'SF Pro Display',
                letterSpacing: -0.54,
                height: 1.286,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _training!.typeDisplayName,
              style: const TextStyle(
                color: Color(0xFF222223),
                fontSize: 16.2,
                fontWeight: FontWeight.w400,
                fontFamily: 'SF Pro Display',
                letterSpacing: -0.675,
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(11.2, 12, 11.2, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Выравнивание по левому краю
        children: [
          Text(
            '${_formatPrice(_training!.price)}₽ за место',
            style: const TextStyle(
              color: Color(0xFF222223),
              fontSize: 15.4,
              fontWeight: FontWeight.w400,
              fontFamily: 'SF Pro Display',
              letterSpacing: -0.81,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 5), // Уменьшено на 40% (24 * 0.6)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateTime(_training!.startTime),
                      style: const TextStyle(
                        color: Color(0xFF222223),
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -1.2,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3), // Уменьшено на 40% (12 * 0.6)
                    GestureDetector(
                      onTap: _addToCalendar,
                      child: const Text(
                      'Добавить в календарь',
                      style: TextStyle(
                        color: Color(0xFF00897B),
                          fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -0.54,
                        height: 1.286,
                      ),
                    ),
                    ),
                    const SizedBox(height: 17), // Уменьшено на 40% (24 * 0.6)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Уровень',
                          style: TextStyle(
                            color: Color(0xFF89867E),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'SF Pro Display',
                            letterSpacing: -1,
                            height: 1.286,
                          ),
                        ),
                        const SizedBox(height: 6), // Уменьшено на 40% (12 * 0.6)
                        Text(
                          '${_training!.minLevel.toStringAsFixed(2)}-${_training!.maxLevel.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF222223),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'SF Pro Display',
                            letterSpacing: -1.2,
                            height: 1.125,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 120,
                color: const Color(0xFFECECEC),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/clock_icon.svg',
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF222223),
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_getDurationInMinutes()} мин',
                    style: const TextStyle(
                      color: Color(0xFF222223),
                      fontSize: 14.4,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'SF Pro Display',
                      letterSpacing: -0.81,
                      height: 1.125,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerSection() {
    return GestureDetector(
      onTap: () {
        // Переход на профиль тренера, если есть trainerId
        if (_training!.trainerId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PublicProfileScreen(
                userId: _training!.trainerId!,
              ),
            ),
          );
        }
      },
      child: Row(
        children: [
          Stack(
            children: [
              UserAvatar(
                imageUrl: _training!.trainerAvatar,
                userName: _training!.trainerName,
                radius: 27,
                backgroundColor: const Color(0xFFE0E0E0),
                borderColor: null,
                borderWidth: 0,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B),
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SvgPicture.asset(
                    'assets/images/training_icon.svg',
                    width: 12,
                    height: 12,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _training!.trainerName,
                  style: const TextStyle(
                    color: Color(0xFF222223),
                    fontSize: 16.2,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.81,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Проверенный тренер',
                  style: TextStyle(
                    color: Color(0xFF222223),
                    fontSize: 12.6,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.54,
                    height: 1.286,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Участники (${_training!.currentParticipants}/${_training!.maxParticipants})',
              style: const TextStyle(
                color: Color(0xFF222223),
                fontSize: 17,
                fontWeight: FontWeight.w400,
                fontFamily: 'SF Pro Display',
                letterSpacing: -0.675,
                height: 1.0,
              ),
            ),
            if (_training!.participants.isNotEmpty)
              TextButton(
                onPressed: () {
                  // Получаем список ID всех участников
                  final userIds = _training!.participants
                      .map((p) => p.userId)
                      .toList();
                  
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ParticipantsListScreen(
                        userIds: userIds,
                        title: 'Участники',
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
              'Смотреть все',
              style: TextStyle(
                color: Color(0xFF00897B),
                    fontSize: 16,
                fontWeight: FontWeight.w400,
                fontFamily: 'SF Pro Display',
                letterSpacing: -0.81,
                height: 1.25,
                  ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        
        // Список участников - горизонтальный скролл
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _training!.participantAvatars.length > 6 ? 6 : _training!.participantAvatars.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: index < 5 ? 8 : 0),
                child: _buildParticipantCard(index),
              );
            },
          ),
        ),
        
        const SizedBox(height: 10),
        
        // Прогресс заполнения
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Требуется ${_training!.maxParticipants - _training!.currentParticipants} ${_training!.maxParticipants - _training!.currentParticipants == 1 ? "участник" : "участника"}',
                  style: const TextStyle(
                    color: Color(0xFF222223),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.8,
                    height: 1.286,
                  ),
                ),
                Text(
                  '${_training!.currentParticipants}/${_training!.maxParticipants}',
                  style: const TextStyle(
                    color: Color(0xFF222223),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.8,
                    height: 1.286,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 358,
              height: 4,
              child: Stack(
                children: [
                  Container(
                    width: 358,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    width: 358 * (_training!.currentParticipants / _training!.maxParticipants),
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildParticipantCard(int index) {
  // Получаем данные участника
     final participant = _training!.participants.isNotEmpty && index < _training!.participants.length
         ? _training!.participants[index]
         : null;
     
     return GestureDetector(
       onTap: () {
         // Переход на профиль участника
         if (participant != null) {
           Navigator.push(
             context,
             MaterialPageRoute(
               builder: (context) => PublicProfileScreen(
                 userId: participant.userId,
               ),
             ),
           );
         }
       },
       child: SizedBox(
         width: 80,
         child: Column(
           children: [
             UserAvatar(
               imageUrl: participant?.avatarUrl,
               userName: participant != null
                   ? '${participant.firstName} ${participant.lastName}'
                   : 'Участник',
               radius: 24,
               backgroundColor: const Color(0xFFE0E0E0),
               borderColor: null,
               borderWidth: 0,
             ),
             const SizedBox(height: 3),
             Text(
               participant?.firstName ?? 'Участник',
               style: const TextStyle(
                 color: Color(0xFF222223),
                 fontSize: 15,
                 fontWeight: FontWeight.w400,
                 fontFamily: 'SF Pro Display',
                 letterSpacing: -0.8,
                 height: 1.286,
               ),
               textAlign: TextAlign.center,
               maxLines: 1,
               overflow: TextOverflow.ellipsis,
             ),
             const SizedBox(height: 0),
             Container(
               padding: const EdgeInsets.symmetric(vertical: 0),
               width: 80,
               height: 24,
               child: Text(
                 participant?.rating != null
                     ? 'С ${calculateRating(participant!.rating!).toStringAsFixed(2)}'
                     : '',
                 style: const TextStyle(
                   color: Color(0xFF00897B),
                   fontSize: 14,
                   fontWeight: FontWeight.w500,
                   fontFamily: 'SF Pro Display',
                   letterSpacing: -0.8,
                   height: 1.286,
                 ),
                 textAlign: TextAlign.center,
               ),
             ),
           ],
         ),
       ),
     );
  }

  Widget _buildClubCard() {
    return ClubCard(
      clubId: _training!.clubId,
      clubName: _training!.clubName,
      clubCity: _training!.clubCity,
      clubAddress: _training!.clubAddress,
      backgroundImage: _training!.backgroundImage,
      onContactsTap: () {
        // TODO: Реализовать переход к контактам клуба
      },
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(
          top: BorderSide(color: Color(0xFFD9D9D9), width: 0.5),
        ),
      ),
      child: _isCurrentUserParticipant()
          ? _buildCancelButton()
          : _buildJoinButton(),
    );
  }

  void _showRatingMismatchModal() {
    RatingMismatchModal.show(context);
  }

  Widget _buildJoinButton() {
    final isRatingMatch = _isRatingMatching();
    final canJoin = _training!.hasSpots && isRatingMatch;
    
    // Определяем цвет кнопки и текста
    Color buttonColor;
    Color textColor;
    String buttonText;
    VoidCallback? onPressed;
    
    if (!_training!.hasSpots) {
      // Нет мест
      buttonColor = const Color(0xFF00897B);
      textColor = const Color(0xFFFFFFFF);
      buttonText = 'Участвовать ${_formatPrice(_training!.price)}₽';
      onPressed = null;
    } else if (!isRatingMatch) {
      // Не подходит по уровню - показываем модальное окно
      buttonColor = const Color(0xFF7F8AC0);
      textColor = const Color(0xFFFFFFFF);
      buttonText = 'Участвовать ${_formatPrice(_training!.price)}₽';
      onPressed = _showRatingMismatchModal;
    } else {
      // Можно участвовать
      buttonColor = const Color(0xFF00897B);
      textColor = const Color(0xFFFFFFFF);
      buttonText = 'Участвовать ${_formatPrice(_training!.price)}₽';
      onPressed = _joinTraining;
    }
    
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          disabledBackgroundColor: buttonColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          buttonText,
          style: TextStyle(
            color: textColor,
            fontSize: 14.4,
            fontWeight: FontWeight.w500,
            fontFamily: 'SF Pro Display',
            letterSpacing: -0.81,
            height: 1.193359375,
          ),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _cancelTraining,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF0F0F0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Отменить участие',
          style: TextStyle(
            color: Color(0xFFFF6B6B),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'SF Pro Display',
            letterSpacing: -0.32, // -2% от 16
            height: 1.25,
          ),
        ),
      ),
    );
  }
}
