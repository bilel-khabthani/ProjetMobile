import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/app_colors.dart';

/// Icone du set Solar (Iconify), teintee via [color].
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.color = AppColors.textPrimary,
    this.semanticLabel,
  });

  final String name;
  final double size;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/solar/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      theme: SvgTheme(currentColor: color),
      semanticsLabel: semanticLabel,
    );
  }
}
