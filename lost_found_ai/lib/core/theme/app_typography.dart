import 'package:flutter/material.dart';

abstract final class AppText {
  static const String family = 'Nunito';

  static const TextStyle display = TextStyle(
    fontFamily: family,
    fontSize: 36,
    height: 1.2,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: family,
    fontSize: 32,
    height: 1.25,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: family,
    fontSize: 24,
    height: 1.3,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle body = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle eyebrow = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  static const TextStyle button = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const TextStyle score = TextStyle(
    fontFamily: family,
    fontSize: 34,
    height: 1.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle tiny = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );
}
