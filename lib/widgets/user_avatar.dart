import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String userName;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final Color backgroundColor;
  /// Если профиль пользователя удалён — показываем специальную заглушку.
  final bool isDeleted;
  /// Опциональный обработчик нажатия — можно навигировать на профиль.
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.imageUrl,
    required this.userName,
    this.radius = 24, // По умолчанию радиус 24 (размер 48x48)
    this.borderColor,
    this.borderWidth = 2.0,
    // Делаем фон таким же, как в MatchScoreInput (0xFFF7F7F7)
    this.backgroundColor = const Color(0xFFF7F7F7),
    this.isDeleted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final bool showDeletedPlaceholder = isDeleted || !hasImage;

    final Widget placeholder = ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Image.asset(
          'assets/images/deleted_avatar.png',
          fit: BoxFit.cover,
        ),
      ),
    );

    // Если передан borderColor и ширина больше 0 — рисуем обводку
    Widget avatar;

    if (borderColor != null && borderWidth > 0) {
      final double innerRadius = (radius - borderWidth).clamp(0.0, radius);

      avatar = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: borderWidth),
        ),
        alignment: Alignment.center,
        child: showDeletedPlaceholder
            ? ClipOval(
                child: SizedBox(
                  width: innerRadius * 2,
                  height: innerRadius * 2,
                  child: Image.asset(
                    'assets/images/deleted_avatar.png',
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : CircleAvatar(
                radius: innerRadius,
                backgroundColor: backgroundColor,
                backgroundImage: NetworkImage(imageUrl!),
              ),
      );
    } else {
      avatar = showDeletedPlaceholder
          ? placeholder
          : CircleAvatar(
              radius: radius,
              backgroundColor: backgroundColor,
              backgroundImage: NetworkImage(imageUrl!),
            );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.translucent,
        child: avatar,
      );
    }

    return avatar;
  }
}