import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import '../../widgets/app_transitions.dart';

ThemeData buildAppTheme() => _buildTheme(Brightness.light);

ThemeData buildAppDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.seed,
    brightness: brightness,
  );
  final textTheme = _buildTextTheme(scheme);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.lg),
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: AppFadeSlideTransition(),
        TargetPlatform.iOS: AppFadeSlideTransition(),
        TargetPlatform.fuchsia: AppFadeSlideTransition(),
        TargetPlatform.linux: AppFadeSlideTransition(),
        TargetPlatform.macOS: AppFadeSlideTransition(),
        TargetPlatform.windows: AppFadeSlideTransition(),
      },
    ),
    fontFamily: AppText.family,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.h2.copyWith(color: scheme.onSurface),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape.copyWith(side: BorderSide(color: scheme.outlineVariant)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        shape: buttonShape,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        textStyle: AppText.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 56),
        shape: buttonShape,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        textStyle: AppText.button,
        side: BorderSide(color: scheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: buttonShape,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        textStyle: AppText.button,
      ),
    ),
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: AppText.h3.copyWith(color: scheme.onSurface),
      subtitleTextStyle: AppText.body.copyWith(color: scheme.onSurfaceVariant),
      shape: shape,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.secondaryContainer,
      disabledColor: scheme.surfaceContainerHighest,
      labelStyle: AppText.label.copyWith(color: scheme.onSurfaceVariant),
      secondaryLabelStyle: AppText.label.copyWith(
        color: scheme.onSecondaryContainer,
      ),
      side: BorderSide(color: scheme.outlineVariant),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: scheme.surfaceContainerLow,
        selectedBackgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSurfaceVariant,
        selectedForegroundColor: scheme.onSecondaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: AppText.label,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.primaryContainer,
      circularTrackColor: scheme.primaryContainer,
      refreshBackgroundColor: scheme.surfaceContainer,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      hintStyle: AppText.body.copyWith(color: scheme.onSurfaceVariant),
      labelStyle: AppText.label.copyWith(color: scheme.onSurfaceVariant),
      floatingLabelStyle: AppText.label.copyWith(color: scheme.primary),
      border: _inputBorder(scheme.outlineVariant),
      enabledBorder: _inputBorder(scheme.outlineVariant),
      focusedBorder: _inputBorder(scheme.primary, width: 2),
      errorBorder: _inputBorder(scheme.error),
      focusedErrorBorder: _inputBorder(scheme.error, width: 2),
      errorStyle: AppText.caption.copyWith(color: scheme.error),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      indicatorColor: scheme.secondaryContainer,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        return states.contains(WidgetState.selected)
            ? AppText.label.copyWith(color: scheme.onSecondaryContainer)
            : AppText.label.copyWith(color: scheme.onSurfaceVariant);
      }),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: AppShadows.raised.first.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: AppText.body.copyWith(color: scheme.onInverseSurface),
      behavior: SnackBarBehavior.floating,
      shape: shape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: AppShadows.raised.first.color,
      shape: shape,
      titleTextStyle: AppText.h2.copyWith(color: scheme.onSurface),
      contentTextStyle: AppText.body.copyWith(color: scheme.onSurfaceVariant),
    ),
  );
}

OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: BorderSide(color: color, width: width),
  );
}

TextTheme _buildTextTheme(ColorScheme scheme) {
  return TextTheme(
    displayLarge: AppText.display.copyWith(color: scheme.onSurface),
    displayMedium: AppText.h1.copyWith(color: scheme.onSurface),
    displaySmall: AppText.h2.copyWith(color: scheme.onSurface),
    headlineLarge: AppText.h1.copyWith(color: scheme.onSurface),
    headlineMedium: AppText.h2.copyWith(color: scheme.onSurface),
    headlineSmall: AppText.h3.copyWith(color: scheme.onSurface),
    titleLarge: AppText.h3.copyWith(color: scheme.onSurface),
    titleMedium: AppText.bodyStrong.copyWith(color: scheme.onSurface),
    titleSmall: AppText.label.copyWith(color: scheme.onSurface),
    bodyLarge: AppText.body.copyWith(color: scheme.onSurface),
    bodyMedium: AppText.body.copyWith(color: scheme.onSurfaceVariant),
    bodySmall: AppText.caption.copyWith(color: scheme.onSurfaceVariant),
    labelLarge: AppText.button.copyWith(color: scheme.onPrimary),
    labelMedium: AppText.label.copyWith(color: scheme.onSurfaceVariant),
    labelSmall: AppText.tiny.copyWith(color: scheme.onSurfaceVariant),
  );
}

extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get typography => Theme.of(this).textTheme;
}

extension ColorSchemeSemantics on ColorScheme {
  Color get danger => error;
  Color get lost => primary;
  Color get found => tertiary;
  Color get textTertiary => onSurfaceVariant;
  bool get isDark => brightness == Brightness.dark;
  Color get scoreHigh => isDark ? AppColors.scoreHighDark : AppColors.scoreHigh;
  Color get scoreMedium =>
      isDark ? AppColors.scoreMediumDark : AppColors.scoreMedium;
  Color get scoreLow => isDark ? AppColors.scoreLowDark : AppColors.scoreLow;
  Color get onScoreHigh =>
      isDark ? AppColors.onScoreHighDark : AppColors.onScoreHigh;
  Color get onScoreMedium =>
      isDark ? AppColors.onScoreMediumDark : AppColors.onScoreMedium;
  Color get onScoreLow =>
      isDark ? AppColors.onScoreLowDark : AppColors.onScoreLow;
}

extension TextThemeSemantics on TextTheme {
  TextStyle? get h2 => headlineSmall;
  TextStyle? get h3 => titleMedium;
  TextStyle? get caption => bodySmall;
  TextStyle? get bodyStrong => titleMedium;
}

class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = EdgeInsets.zero,
    this.color,
    this.borderRadius = AppRadius.lg,
    this.showBorder = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final double borderRadius;
  final bool showBorder;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final radius = BorderRadius.circular(widget.borderRadius);
    final card = Card(
      color: widget.color ?? scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: widget.margin,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: widget.showBorder
            ? BorderSide(color: scheme.outlineVariant)
            : BorderSide.none,
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    return Semantics(
      button: widget.onTap != null,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: context.motion(AppMotion.micro),
        curve: AppMotion.standard,
        transform: Matrix4.diagonal3Values(
          _pressed && !context.reduceMotion ? 0.985 : 1.0,
          _pressed && !context.reduceMotion ? 0.985 : 1.0,
          1,
        ),
        child: widget.onTap == null
            ? card
            : InkWell(
                onTap: widget.onTap,
                onTapDown: (_) => _setPressed(true),
                onTapUp: (_) => _setPressed(false),
                onTapCancel: () => _setPressed(false),
                borderRadius: radius,
                child: card,
              ),
      ),
    );
  }
}
