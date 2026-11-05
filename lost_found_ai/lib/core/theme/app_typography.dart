import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppText {
  static const String family = 'Manrope';
  static const String headingFamily = 'PlusJakartaSans';

  static const TextStyle display = TextStyle(
    fontFamily: headingFamily,
    fontSize: 34,
    height: 1.08,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    color: AppColors.textPrimary,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: headingFamily,
    fontSize: 28,
    height: 1.14,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.7,
    color: AppColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: headingFamily,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: headingFamily,
    fontSize: 17,
    height: 1.28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
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
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
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
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
  );

  static const TextStyle score = TextStyle(
    fontFamily: headingFamily,
    fontSize: 34,
    height: 1.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle tiny = TextStyle(
    fontFamily: family,
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: AppColors.textTertiary,
  );

  // Dark theme text styles
  static TextStyle get darkDisplay =>
      display.copyWith(color: AppColors.darkTextPrimary);
  static TextStyle get darkH1 => h1.copyWith(color: AppColors.darkTextPrimary);
  static TextStyle get darkH2 => h2.copyWith(color: AppColors.darkTextPrimary);
  static TextStyle get darkH3 => h3.copyWith(color: AppColors.darkTextPrimary);
  static TextStyle get darkBody =>
      body.copyWith(color: AppColors.darkTextSecondary);
  static TextStyle get darkBodyStrong =>
      bodyStrong.copyWith(color: AppColors.darkTextPrimary);
  static TextStyle get darkLabel =>
      label.copyWith(color: AppColors.darkTextSecondary);
  static TextStyle get darkCaption =>
      caption.copyWith(color: AppColors.darkTextTertiary);
  static TextStyle get darkButton => button.copyWith(color: Colors.white);
  static TextStyle get darkScore =>
      score.copyWith(color: AppColors.darkTextPrimary);
}
