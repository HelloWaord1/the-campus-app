import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/modal_close_button.dart';
import '../models/match.dart';
import '../services/api_service.dart';
import '../utils/notification_utils.dart';
import '../widgets/user_avatar.dart';
import '../utils/logger.dart'; // Импортируем логгер

class MatchRequestsScreen extends StatefulWidget {
  final String matchId;

  const MatchRequestsScreen({super.key, required this.matchId});

  @override
  State<MatchRequestsScreen> createState() => _MatchRequestsScreenState();
}

class _MatchRequestsScreenState extends State<MatchRequestsScreen> {
  late Future<List<MatchRequest>> _requestsFuture;
  Set<String> _pressedAcceptButtons = {}; // Добавьте эту строку
  Set<String> _pressedRejectButtons = {}; 

  @override
  void initState() {
    super.initState();
    _requestsFuture = ApiService.getMatchRequests(widget.matchId);
  }

  // lib/screens/match_requests_screen.dart

void _handleRequest(String requestId, bool accept) async {
  // 1. Немедленно обновляем UI, чтобы показать нажатое состояние
  setState(() {
    if (accept) {
      _pressedAcceptButtons.add(requestId);
      _pressedRejectButtons.remove(requestId); // Убедимся, что только одна кнопка активна
    } else {
      _pressedRejectButtons.add(requestId);
      _pressedAcceptButtons.remove(requestId); // Убедимся, что только одна кнопка активна
    }
  });

  // 2. Добавляем небольшую задержку для визуального эффекта
  await Future.delayed(const Duration(milliseconds: 300));

  try {
    final status = accept ? 'approved' : 'declined';
    await ApiService.respondToMatchRequest(requestId, status);
    
    // Логируем успешный факт отправки запроса
    Logger.info('Запрос на изменение статуса заявки ($status) успешно отправлен.');

    if (mounted) {
      final message = accept ? 'Заявка принята' : 'Заявка отклонена';
      NotificationUtils.showSuccess(context, message);
    }
    
    // 3. После успеха обновляем список (обработанная заявка исчезнет)
    if (mounted) {
      setState(() {
        _requestsFuture = ApiService.getMatchRequests(widget.matchId);
      });
    }

  } catch (e, stackTrace) {
    // Логируем ошибку
    Logger.error('Ошибка при обработке заявки на матч', e, stackTrace);

    if (mounted) {
      NotificationUtils.showError(context, 'Ошибка: ${e.toString()}');
      // 4. При ошибке возвращаем иконку в исходное состояние
      setState(() {
        _pressedAcceptButtons.remove(requestId);
        _pressedRejectButtons.remove(requestId);
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          _buildRequestsList(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Stack(
      alignment: Alignment.center,
      children: [
        // Заголовок по центру
        const Text(
          'Заявки на матч',
          style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 24, fontWeight: FontWeight.w500, letterSpacing: -0.48),
        ),
        // Кнопка закрытия справа по центру
        Align(
          alignment: Alignment.centerRight,
          child: ModalCloseButton(
            onPressed: () => Navigator.of(context).pop(),
            size: 31,
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildRequestsList() {
    return FutureBuilder<List<MatchRequest>>(
      future: _requestsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Заявок на матч пока нет.'),
          ));
        }

        final requests = snapshot.data!;
        return ListView.separated(
          shrinkWrap: true,
          itemCount: requests.length,
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFE0E0E0)),
          itemBuilder: (context, index) {
            final request = requests[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              visualDensity: VisualDensity.compact,
              leading: UserAvatar(
                imageUrl: request.userAvatarUrl,
                userName: request.userName,
              ),
              title: Text(request.userName, style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: -0.32),),
              subtitle: Row(
              children: [
                Text(
                  'Уровень ', // Добавил пробел для разделения
                  style: TextStyle(
                    fontFamily: 'SF Pro Display', 
                    fontSize: 16, 
                    fontWeight: FontWeight.w400, 
                    letterSpacing: -0.28, 
                    color: Color(0xFF262F63),
                  ),
                ),
                Text(
                  request.formattedRating, 
                  style: TextStyle(
                    fontFamily: 'SF Pro Display', 
                    fontSize: 14, 
                    fontWeight: FontWeight.w500, 
                    letterSpacing: -0.24, 
                    color: Color(0xFF262F63),
                  ),
                ),
              ],
            ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: SvgPicture.asset(
                      _pressedAcceptButtons.contains(request.id)
                          ? 'assets/images/checkmark_blue.svg' // Закрашенная иконка
                          : 'assets/images/checkmark_grey.svg', // Обычная иконка
                      width: 42,
                      height: 42,
                    ),
                    padding: EdgeInsets.zero,
                    splashRadius: 1,
                    onPressed: () => _handleRequest(request.id, true),
                  ),
                  IconButton(
                    icon: SvgPicture.asset(
                      _pressedRejectButtons.contains(request.id)
                          ? 'assets/images/cross_red.svg'  // Закрашенная иконка
                          : 'assets/images/cross_grey.svg', // Обычная иконка
                      width: 42,
                      height: 42,
                    ),
                    padding: EdgeInsets.zero,
                    splashRadius: 1,
                    onPressed: () => _handleRequest(request.id, false),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
