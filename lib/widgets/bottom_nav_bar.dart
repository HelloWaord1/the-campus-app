import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/responsive_utils.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabTapped;
  final double? height;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabTapped,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final double contentHeight = height ?? ResponsiveUtils.scaleHeight(context, 80);
    final double topPadding = 6.0;
    
    // На Android используем viewPadding для учёта системной навигации
    // На iOS оставляем минимальный отступ как раньше
    final double bottomInset;
    final double bottomPadding;
    
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android: используем viewPadding для системной панели навигации
      bottomInset = MediaQuery.of(context).viewPadding.bottom;
      bottomPadding = bottomInset;
    } else {
      // iOS: используем старую логику с минимальным отступом
      final double iosBottomInset = MediaQuery.of(context).padding.bottom;
      bottomInset = 0; // Не добавляем к высоте
      bottomPadding = iosBottomInset > 0 ? 2.0 : 8.0; // Старый подход
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.black.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Container(
        height: contentHeight + bottomInset,
        padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
              _buildNavItem(
                index: 0,
                svgAsset: 'assets/images/nav_home.svg',
                label: 'Главная',
                isActive: currentIndex == 0,
              ),
              _buildNavItem(
                index: 1,
                svgAsset: 'assets/images/nav_community.svg',
                label: 'Комьюнити',
                isActive: currentIndex == 1,
                iconWidth: 24,
                iconHeight: 24,
              ),
              _buildNavItem(
                index: 2,
                svgAsset: 'assets/images/nav_notifications.svg',
                label: 'Уведомления',
                isActive: currentIndex == 2,
              ),
              _buildNavItem(
                index: 3,
                svgAsset: 'assets/images/nav_profile.svg',
                label: 'Профиль',
                isActive: currentIndex == 3,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String svgAsset,
    required String label,
    required bool isActive,
    double? iconWidth,
    double? iconHeight,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTabTapped(index),
        child: SizedBox(
          height: double.infinity,
          child: Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: SvgPicture.asset(
                    svgAsset,
                    width: iconWidth ?? 20,
                    height: iconHeight ?? 20,
                    colorFilter: ColorFilter.mode(
                      isActive ? const Color(0xFF00897B) : const Color(0xFF89867E),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: isActive ? const Color(0xFF00897B) : const Color(0xFF89867E),
                  letterSpacing: -0.24,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
