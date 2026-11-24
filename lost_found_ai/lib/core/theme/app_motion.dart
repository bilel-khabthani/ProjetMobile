import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration short = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration long = Duration(milliseconds: 320);
  static const Duration sheet = Duration(milliseconds: 360);
  static const Duration skeleton = Duration(milliseconds: 1300);
  static const Duration counter = Duration(milliseconds: 650);
  static const Duration dialog = Duration(milliseconds: 200);
  static const Duration celebration = Duration(milliseconds: 4500);
  static const Duration illustration = Duration(milliseconds: 520);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeInOutCubic;
  static const Curve pop = Curves.easeOutBack;

  static const int staggerStepMs = 55;
  static const int maxStaggerItems = 6;
  static const double revealDistance = 14;

  static Duration stagger(int index, {int maxItems = maxStaggerItems}) {
    final bounded = index.clamp(0, maxItems - 1);
    return Duration(milliseconds: bounded * staggerStepMs);
  }
}

extension AppMotionContext on BuildContext {
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  Duration motion(Duration duration) => reduceMotion ? Duration.zero : duration;
}
