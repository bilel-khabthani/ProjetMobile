import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
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

Color categoryColor(ItemCategory category) => switch (category) {
  ItemCategory.bag => AppColors.primary,
  ItemCategory.phone => const Color(0xFF2E7BE0),
  ItemCategory.keys => const Color(0xFFC98A2E),
  ItemCategory.documents => const Color(0xFF7A6FE0),
  ItemCategory.clothing => const Color(0xFFD95C86),
  ItemCategory.glasses => const Color(0xFF1F9C93),
  ItemCategory.wallet => const Color(0xFFB86A3C),
  ItemCategory.other => AppColors.textTertiary,
};

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
    final base = categoryColor(category);
    final shortest = compact ? 72.0 : 150.0;

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, 0.86)!,
            Color.lerp(base, Colors.white, 0.66)!,
            Color.lerp(base, AppColors.background, 0.7)!,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _BlobPainter(base)),
          Center(
            child: Container(
              width: shortest * 0.44,
              height: shortest * 0.44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: base.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: AppIcon(
                  categoryIconName(category),
                  size: shortest * 0.22,
                  color: Color.lerp(base, AppColors.textPrimary, 0.18)!,
                ),
              ),
            ),
          ),
          if (showLabel && !compact)
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  category.label,
                  style: AppText.tiny.copyWith(
                    color: Color.lerp(base, AppColors.textPrimary, 0.25),
                    fontWeight: FontWeight.w800,
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
  const _BlobPainter(this.base);

  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    final soft = Paint()..color = base.withValues(alpha: 0.13);
    final softer = Paint()..color = base.withValues(alpha: 0.07);
    final white = Paint()..color = Colors.white.withValues(alpha: 0.16);

    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.18),
      size.shortestSide * 0.34,
      softer,
    );
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.84),
      size.shortestSide * 0.3,
      soft,
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.1),
      size.shortestSide * 0.1,
      white,
    );
    canvas.drawCircle(
      Offset(size.width * 0.24, size.height * 0.9),
      size.shortestSide * 0.06,
      white,
    );
  }

  @override
  bool shouldRepaint(covariant _BlobPainter old) => old.base != base;
}
