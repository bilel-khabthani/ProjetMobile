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
    BoxShadow(color: Color(0x0A1B1B1F), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x1A1B1B1F), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> primary = [
    BoxShadow(color: Color(0x296C5CE7), blurRadius: 20, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> nav = [
    BoxShadow(color: Color(0x141B1B1F), blurRadius: 18, offset: Offset(0, -4)),
  ];
}
