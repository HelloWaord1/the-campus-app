import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/notification_utils.dart';
import '../services/api_service.dart';
import '../screens/courts/club_details_screen.dart';

/// Карточка клуба с информацией и кнопкой карты
class ClubCard extends StatelessWidget {
  final String? clubId;
  final String clubName;
  final String clubCity;
  final String? clubAddress;
  final String? backgroundImage;
  final VoidCallback? onTap;
  final VoidCallback? onContactsTap;

  const ClubCard({
    super.key,
    this.clubId,
    required this.clubName,
    required this.clubCity,
    this.clubAddress,
    this.backgroundImage,
    this.onTap,
    this.onContactsTap,
  });

  Future<void> _openClubDetails(BuildContext context) async {
    if (clubId == null) {
      if (context.mounted) {
        NotificationUtils.showError(context, 'Информация о клубе недоступна');
      }
      return;
    }

    try {
      // Загружаем полную информацию о клубе
      final club = await ApiService.getClubById(clubId!);
      
      if (!context.mounted) return;
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ClubDetailsScreen(club: club),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      NotificationUtils.showError(context, 'Не удалось загрузить информацию о клубе');
    }
  }

  Future<void> _openYandexMaps(BuildContext context) async {
    // Формируем адрес для поиска
    String? searchQuery;
    
    if (clubAddress != null && clubAddress!.isNotEmpty) {
      // Если есть адрес, используем его вместе с городом
      searchQuery = '$clubCity, $clubAddress';
    } else if (clubName.isNotEmpty) {
      // Если адреса нет, ищем по названию клуба и городу
      searchQuery = '$clubCity, $clubName';
    } else {
      NotificationUtils.showError(context, 'Адрес клуба недоступен');
      return;
    }

    // Открываем Яндекс.Карты с поиском по адресу
    final Uri webUri = Uri.https(
      'yandex.ru',
      '/maps/',
      {
        'text': searchQuery,
      },
    );
    
    try {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Фолбэк: та же ссылка через http(s) парсинг
      try {
        final Uri fallback = Uri.parse('https://yandex.ru/maps/?text=${Uri.encodeComponent(searchQuery)}');
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (context.mounted) {
          NotificationUtils.showError(context, 'Не удалось открыть карты');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? (clubId != null ? () => _openClubDetails(context) : null),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
        children: [
          // Изображение клуба
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(4),
              image: backgroundImage != null
                  ? DecorationImage(
                      image: NetworkImage(backgroundImage!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          
          // Информация о клубе
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clubName,
                      style: const TextStyle(
                        color: Color(0xFF222223),
                        fontSize: 12.6,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -0.54,
                        height: 1.286,
                      ),
                    ),
                    Text(
                      clubCity,
                      style: const TextStyle(
                        color: Color(0xFF89867E),
                        fontSize: 12.6,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -0.54,
                        height: 1.286,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Кнопка контактов
                InkWell(
                  onTap: onContactsTap,
                  child: Row(
                    children: [
                      const Text(
                        'Контакты',
                        style: TextStyle(
                          color: Color(0xFF00897B),
                          fontSize: 12.6,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'SF Pro Display',
                          letterSpacing: -0.54,
                          height: 1.286,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SvgPicture.asset(
                        'assets/images/caret_right.svg',
                        width: 5,
                        height: 9,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF00897B),
                          BlendMode.srcIn,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Кнопка карты
          InkWell(
            onTap: () => _openYandexMaps(context),
            borderRadius: BorderRadius.circular(48),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF00897B),
                borderRadius: BorderRadius.circular(48),
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/map_icon.svg',
                  width: 13,
                  height: 13,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

