import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfileMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? labelWidget; // Кастомная разметка заголовка (RichText и т.п.)
  final VoidCallback onTap;
  final int? counter;
  final Color iconColor;
  final Widget? customIcon; // Позволяет передать SVG или любой виджет вместо Icon
  final BorderRadius? borderRadius; // Кастомный радиус скругления

  const ProfileMenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelWidget,
    this.counter,
    this.iconColor = const Color(0xFF89867E),
    this.customIcon,
    this.borderRadius,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F6F6),
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            customIcon != null
                ? SizedBox(width: 22, height: 22, child: Center(child: customIcon))
                : Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: labelWidget ?? Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF222223),
                    letterSpacing: -0.32,
                    height: 1.25,
                  ),
                ),
            ),
            if (counter != null) ...[
              Text(
                '$counter',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF89867E),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 4),
            ],
            SvgPicture.asset('assets/images/chevron_right.svg', width: 20, height: 20, color: const Color(0xFF89867E)),
          ],
        ),
      ),
    );
  }
} 