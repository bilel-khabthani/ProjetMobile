import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';

/// Boutons d'action du deck : passer, ouvrir l'analyse IA, valider.
class SwipeActionBar extends StatelessWidget {
  const SwipeActionBar({
    super.key,
    required this.onPass,
    required this.onInsight,
    required this.onLike,
    this.enabled = true,
  });

  final VoidCallback onPass;
  final VoidCallback onInsight;
  final VoidCallback onLike;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActionButton(
          label: 'Passer',
          icon: Icons.close_rounded,
          background: colors.surface,
          foreground: colors.error,
          outlined: true,
          onTap: enabled ? onPass : null,
        ),
        const SizedBox(width: AppSpacing.xl),
        _ActionButton(
          label: 'Analyse IA',
          icon: Icons.auto_awesome_rounded,
          background: colors.primary,
          foreground: colors.onPrimary,
          size: 66,
          onTap: enabled ? onInsight : null,
        ),
        const SizedBox(width: AppSpacing.xl),
        _ActionButton(
          label: "C'est à moi",
          icon: Icons.favorite_rounded,
          background: colors.tertiary,
          foreground: colors.onTertiary,
          onTap: enabled ? onLike : null,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 58,
    this.outlined = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final bool outlined;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = ButtonStyle(
      backgroundColor: WidgetStatePropertyAll<Color>(background),
      foregroundColor: WidgetStatePropertyAll<Color>(foreground),
      minimumSize: WidgetStatePropertyAll<Size>(Size(size, size)),
      fixedSize: WidgetStatePropertyAll<Size>(Size(size, size)),
      maximumSize: WidgetStatePropertyAll<Size>(Size(size, size)),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.zero,
      ),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(CircleBorder()),
      side: outlined
          ? WidgetStatePropertyAll<BorderSide>(
              BorderSide(color: foreground, width: 1.5),
            )
          : const WidgetStatePropertyAll<BorderSide>(BorderSide.none),
      elevation: const WidgetStatePropertyAll<double>(0),
      shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    );

    final button = outlined
        ? OutlinedButton(
            onPressed: onTap,
            style: style,
            child: Icon(icon, color: foreground, size: size * 0.42),
          )
        : FilledButton(
            onPressed: onTap,
            style: style,
            child: Icon(icon, color: foreground, size: size * 0.42),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 6),
        Text(
          label,
          style: context.typography.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
