import 'package:flutter/material.dart';

/// Palette "papier chaud, encre profonde" issue du design system Sleek.
///
/// Les noms historiques sont conserves pour ne pas casser les ecrans : ils
/// pointent maintenant vers les jetons du nouveau systeme.
abstract final class AppColors {
  static const Color primary = Color(0xFF4338E8);
  static const Color primaryDark = Color(0xFF2E2A8F);
  static const Color primarySoft = Color(0xFFECEAFB);

  static const Color lost = Color(0xFFF2705F);
  static const Color lostSoft = Color(0xFFFDEDEA);

  static const Color found = Color(0xFF12A07A);
  static const Color foundSoft = Color(0xFFDDF5EC);

  /// Ambre de signalement (score moyen, avertissements).
  static const Color accent = Color(0xFFE9A23B);
  static const Color accentSoft = Color(0xFFFDF3E2);

  /// Vert menthe du design (accent-foreground).
  static const Color mint = Color(0xFFDDF5EC);
  static const Color mintDark = Color(0xFF0B6B4F);
  static const Color lavender = Color(0xFFECEAFB);

  static const Color background = Color(0xFFFBF7F0);
  static const Color surface = Color(0xFFFFFDF9);
  static const Color surfaceAlt = Color(0xFFF2EEE7);

  static const Color textPrimary = Color(0xFF141B3D);
  static const Color textSecondary = Color(0xFF5B6180);
  static const Color textTertiary = Color(0xFF8E93A8);

  static const Color border = Color(0xFFE8E1D4);
  static const Color divider = Color(0xFFF0EBE2);
  static const Color input = Color(0xFFFFFCF6);

  static const Color success = found;
  static const Color warning = accent;
  static const Color danger = Color(0xFFC92A3F);
  static const Color info = primary;

  static const Color darkPrimary = Color(0xFF9D95FF);
  static const Color darkBackground = Color(0xFF10142B);
  static const Color darkSurface = Color(0xFF181D36);
  static const Color darkTextPrimary = Color(0xFFF6F3EC);
  static const Color darkTextSecondary = Color(0xFFB8B6C8);
  static const Color darkTextTertiary = Color(0xFF8A879C);
}
