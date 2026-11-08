import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppText {
  static const String family = 'Nunito';

  static const TextStyle display = TextStyle(
    fontFamily: family,
    fontSize: 32,
    height: 1.18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: AppColors.textPrimary,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: family,
    fontSize: 26,
    height: 1.22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 1.28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1.32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.textTertiary,
  );

  static const TextStyle eyebrow = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: AppColors.textTertiary,
  );

  static const TextStyle button = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.1,
  );

  static const TextStyle score = TextStyle(
    fontFamily: family,
    fontSize: 34,
    height: 1.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    color: AppColors.textPrimary,
  );

  /// Style le plus petit, reserve aux badges et metadonnees compactes.
  static const TextStyle tiny = TextStyle(
    fontFamily: family,
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: AppColors.textTertiary,
  );
}
