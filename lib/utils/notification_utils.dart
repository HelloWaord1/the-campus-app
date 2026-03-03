import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../widgets/custom_notification_banner.dart';
import 'responsive_utils.dart';

class NotificationUtils {
  static void _showNotification(BuildContext context, String message, NotificationType type) {
    // Пытаемся показать баннер через верхний Overlay, чтобы он был поверх модальных окон
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay.mounted) {
      final entry = OverlayEntry(
        builder: (ctx) {
          // Отступ снизу: системные инкрусты + высота кастомного BottomNavBar + небольшой зазор
          final media = MediaQuery.of(ctx);
          final double systemBottom = media.padding.bottom;
          final double keyboardInset = media.viewInsets.bottom; // > 0 при открытой клавиатуре
          // Высота нашего кастомного нижнего бара (как в BottomNavBar)
          final double navHeight = ResponsiveUtils.scaleHeight(ctx, 80);
          final double bottomGap = systemBottom > 0 ? 2.0 : 8.0; // как в BottomNavBar
          final double extraGap = 12.0;
          final double baseNavPadding = systemBottom + navHeight + bottomGap + extraGap;
          final double keyboardPadding = keyboardInset > 0 ? keyboardInset + 16.0 : 0.0;
          // Берём максимум, чтобы баннер располагался над баром и поднимался вместе с клавиатурой
          final double bottomPadding = math.max(baseNavPadding, keyboardPadding);
          return IgnorePointer(
            ignoring: true,
            child: SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Material(
                      color: Colors.transparent,
                      child: CustomNotificationBanner(message: message, type: type),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
      overlay.insert(entry);
      Future.delayed(const Duration(seconds: 3)).then((_) {
        try { entry.remove(); } catch (_) {}
      });
      return;
    }

    // Фоллбэк: обычный SnackBar, если Overlay недоступен
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    ScaffoldMessenger.of(rootContext).showSnackBar(
      SnackBar(
        content: CustomNotificationBanner(message: message, type: type),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Показывает уведомление об успешном действии (зеленое)
  static void showSuccess(BuildContext context, String message) {
    _showNotification(context, message, NotificationType.success);
  }

  /// Показывает уведомление об ошибке (красное)
  static void showError(BuildContext context, String message) {
    _showNotification(context, message, NotificationType.error);
  }

  /// Показывает информационное уведомление (синее)
  static void showInfo(BuildContext context, String message) {
    _showNotification(context, message, NotificationType.info);
  }

  /// Показывает предупреждающее уведомление (оранжевое)
  static void showWarning(BuildContext context, String message) {
    _showNotification(context, message, NotificationType.warning);
  }
} 