import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
}

abstract final class AppRadius {
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 30;
  static const double pill = 999;
}

abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0D141B3D),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x14141B3D),
      blurRadius: 34,
      offset: Offset(0, 16),
    ),
  ];

  static const List<BoxShadow> primary = [
    BoxShadow(
      color: Color(0x4D4338E8),
      blurRadius: 26,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> nav = [
    BoxShadow(
      color: Color(0x14141B3D),
      blurRadius: 30,
      offset: Offset(0, -8),
    ),
  ];
}
