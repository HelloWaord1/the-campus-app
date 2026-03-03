import 'package:flutter/material.dart';

class ResponsiveUtils {
  // Базовая ширина экрана для дизайна (iPhone 14)
  static const double baseWidth = 390;
  // Базовая высота экрана для дизайна (iPhone 14)
  static const double baseHeight = 844;
  
  // Минимальные и максимальные масштабы для предотвращения чрезмерного масштабирования
  static const double minScale = 0.8;
  static const double maxScale = 1.3;
  
  // Более консервативное масштабирование шрифтов
  static const double minFontScale = 0.9;
  static const double maxFontScale = 1.1;

  /// Получает коэффициент масштабирования ширины
  static double _getWidthScale(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = screenWidth / baseWidth;
    return scale.clamp(minScale, maxScale);
  }

  /// Получает коэффициент масштабирования высоты
  static double _getHeightScale(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final scale = screenHeight / baseHeight;
    return scale.clamp(minScale, maxScale);
  }

  /// Получает консервативный коэффициент масштабирования для шрифтов
  static double _getFontScale(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = screenWidth / baseWidth;
    return scale.clamp(minFontScale, maxFontScale);
  }

  /// Масштабирует ширину относительно базового дизайна
  static double scaleWidth(BuildContext context, double width) {
    return width * _getWidthScale(context);
  }

  /// Масштабирует высоту относительно базового дизайна
  static double scaleHeight(BuildContext context, double height) {
    return height * _getHeightScale(context);
  }

  /// Консервативное масштабирование размера шрифта
  static double scaleFontSize(BuildContext context, double fontSize) {
    return fontSize * _getFontScale(context);
  }

  /// Создает адаптивные отступы
  static EdgeInsets adaptivePadding(
    BuildContext context, {
    double top = 0,
    double bottom = 0,
    double left = 0,
    double right = 0,
    double horizontal = 0,
    double vertical = 0,
  }) {
    return EdgeInsets.only(
      top: scaleHeight(context, top + vertical),
      bottom: scaleHeight(context, bottom + vertical),
      left: scaleWidth(context, left + horizontal),
      right: scaleWidth(context, right + horizontal),
    );
  }

  /// Создает адаптивный SizedBox
  static SizedBox adaptiveSizedBox(
    BuildContext context, {
    double? width,
    double? height,
  }) {
    return SizedBox(
      width: width != null ? scaleWidth(context, width) : null,
      height: height != null ? scaleHeight(context, height) : null,
    );
  }

  /// Определяет, является ли экран очень большим
  static bool isExtraLargeScreen(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth > 428; // iPhone 14 Pro Max ширина
  }

  /// Определяет, является ли экран маленьким
  static bool isSmallScreen(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth < 375; // iPhone SE ширина
  }
} 