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
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D1F1B2E), blurRadius: 18, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x1A1F1B2E), blurRadius: 28, offset: Offset(0, 12)),
  ];

  static const List<BoxShadow> primary = [
    BoxShadow(color: Color(0x405B6CF0), blurRadius: 22, offset: Offset(0, 10)),
  ];

  static const List<BoxShadow> nav = [
    BoxShadow(color: Color(0x141F1B2E), blurRadius: 30, offset: Offset(0, -8)),
  ];
}
