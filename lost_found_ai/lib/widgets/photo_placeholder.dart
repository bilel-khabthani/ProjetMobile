import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../data/models/item.dart';
import 'app_icon.dart';

IconData categoryIcon(ItemCategory category) => switch (category) {
  ItemCategory.bag => Icons.shopping_bag_rounded,
  ItemCategory.phone => Icons.smartphone_rounded,
  ItemCategory.keys => Icons.vpn_key_rounded,
  ItemCategory.documents => Icons.description_rounded,
  ItemCategory.clothing => Icons.checkroom_rounded,
  ItemCategory.glasses => Icons.remove_red_eye_rounded,
  ItemCategory.wallet => Icons.account_balance_wallet_rounded,
  ItemCategory.other => Icons.category_rounded,
};

String categoryIconName(ItemCategory category) => switch (category) {
  ItemCategory.bag => 'bag-2-linear',
  ItemCategory.phone => 'smartphone-linear',
  ItemCategory.keys => 'key-minimalistic-square-linear',
  ItemCategory.documents => 'document-text-linear',
  ItemCategory.clothing => 't-shirt-linear',
  ItemCategory.glasses => 'glasses-linear',
  ItemCategory.wallet => 'wallet-linear',
  ItemCategory.other => 'box-linear',
};

Color categoryColor(ItemCategory category) {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.seed);
  return switch (category) {
    ItemCategory.bag => scheme.primary,
    ItemCategory.phone => scheme.secondary,
    ItemCategory.keys => scheme.tertiary,
    ItemCategory.documents => scheme.primary,
    ItemCategory.clothing => scheme.tertiary,
    ItemCategory.glasses => scheme.secondary,
    ItemCategory.wallet => scheme.primary,
    ItemCategory.other => scheme.outline,
  };
}

class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({
    super.key,
    required this.category,
    this.size,
    this.borderRadius = AppRadius.lg,
    this.initials,
    this.showLabel = true,
  });

  final ItemCategory category;
  final double? size;
  final double borderRadius;
  final String? initials;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final side = size ?? 96;
    return SizedBox(
      width: side,
      height: side,
      child: ItemArtwork(
        category: category,
        borderRadius: borderRadius,
        compact: side < 90,
        showLabel: showLabel,
      ),
    );
  }
}

/// Visuel d'annonce : degrade doux + icone de categorie, utilisable en carre
/// ou en paysage (cartes de correspondance).
class ItemArtwork extends StatelessWidget {
  const ItemArtwork({
    super.key,
    required this.category,
    this.width,
    this.height,
    this.borderRadius = AppRadius.lg,
    this.compact = false,
    this.showLabel = false,
  });

  final ItemCategory category;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool compact;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = categoryColor(category);
    final shortest = compact ? 72.0 : 150.0;

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _BlobPainter(
              first: colors.secondaryContainer,
              second: colors.tertiaryContainer,
              third: colors.surfaceContainerHighest,
            ),
          ),
          Center(
            child: Container(
              width: shortest * 0.44,
              height: shortest * 0.44,
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colors.outlineVariant, width: 1.2),
              ),
              child: Center(
                child: AppIcon(
                  categoryIconName(category),
                  size: shortest * 0.22,
                  color: base,
                ),
              ),
            ),
          ),
          if (showLabel && !compact)
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  category.label,
                  style: context.typography.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  const _BlobPainter({
    required this.first,
    required this.second,
    required this.third,
  });

  final Color first;
  final Color second;
  final Color third;

  @override
  void paint(Canvas canvas, Size size) {
    final primary = Paint()..color = first;
    final secondary = Paint()..color = second;
    final tertiary = Paint()..color = third;

    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.18),
      size.shortestSide * 0.34,
      tertiary,
    );
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.84),
      size.shortestSide * 0.3,
      secondary,
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.1),
      size.shortestSide * 0.1,
      primary,
    );
    canvas.drawCircle(
      Offset(size.width * 0.24, size.height * 0.9),
      size.shortestSide * 0.06,
      primary,
    );
  }

  @override
  bool shouldRepaint(covariant _BlobPainter old) =>
      old.first != first || old.second != second || old.third != third;
}
