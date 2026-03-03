import 'package:flutter/material.dart';

enum NotificationType { success, error, info, warning }

class CustomNotificationBanner extends StatelessWidget {
  final String message;
  final NotificationType type;

  const CustomNotificationBanner({
    super.key,
    required this.message,
    required this.type,
  });

  IconData _getIcon() {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.cancel; // Иконка крестика в круге
      case NotificationType.info:
        return Icons.info;
      case NotificationType.warning:
        return Icons.warning;
    }
  }

  Color _getIconColor() {
    switch (type) {
      case NotificationType.success:
        return Colors.white;
      case NotificationType.error:
        return const Color(0xFFFF453A); // Красный цвет для ошибок, как в Figma
      case NotificationType.info:
        return Colors.white;
      case NotificationType.warning:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Темный фон, как в дизайне Figma
    const backgroundColor = Color(0xFF252525); 
    const textColor = Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(_getIcon(), color: _getIconColor(), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
} 