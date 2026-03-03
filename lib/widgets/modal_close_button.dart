import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Кнопка закрытия модального окна с единым стилем
/// По умолчанию использует иконку `assets/images/close_icon.svg` размером 44
class ModalCloseButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double size;
  final EdgeInsetsGeometry padding;
  final double? splashRadius;

  const ModalCloseButton({
    super.key,
    required this.onPressed,
    this.size = 44,
    this.padding = EdgeInsets.zero,
    this.splashRadius,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: SvgPicture.asset(
        'assets/images/close_icon.svg',
        width: size,
        height: size,
      ),
      onPressed: onPressed,
      padding: padding,
      splashRadius: splashRadius ?? size / 2,
    );
  }
}





