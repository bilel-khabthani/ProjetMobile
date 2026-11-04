import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/models/item.dart';

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

Color categoryColor(ItemCategory category) => switch (category) {
  ItemCategory.bag => AppColors.primary,
  ItemCategory.phone => const Color(0xFF3B9DDB),
  ItemCategory.keys => const Color(0xFFE0A33C),
  ItemCategory.documents => const Color(0xFF8B7BD8),
  ItemCategory.clothing => const Color(0xFFE0709A),
  ItemCategory.glasses => const Color(0xFF3BB2A8),
  ItemCategory.wallet => const Color(0xFFC97B4A),
  ItemCategory.other => AppColors.textTertiary,
};

class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({
    super.key,
    required this.category,
    this.size,
    this.borderRadius = 20,
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
    final base = categoryColor(category);
    final width = size;
    final height = size;

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      // initials non affiches pour l'instant; on conserve la mise en page
            decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, 0.72)!,
            Color.lerp(base, Colors.white, 0.42)!,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _BlobPainter(base)),
          Center(
            child: Padding(
              padding: EdgeInsets.all((size ?? 96) * 0.06),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    categoryIcon(category),
                    color: base,
                    size: (size ?? 96) * 0.34,
                  ),
                  if (showLabel)
                    Padding(
                      padding: EdgeInsets.only(top: (size ?? 96) * 0.05),
                      child: Text(
                        category.label,
                        style: TextStyle(
                          color: Color.lerp(base, Colors.black, 0.25),
                          fontSize: (size ?? 96) * 0.1,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                ],
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
    final soft = Paint()..color = base.withValues(alpha: 0.12);
    final softer = Paint()..color = base.withValues(alpha: 0.07);

    canvas.drawCircle(
      Offset(size.width * 0.16, size.height * 0.2),
      size.width * 0.3,
      softer,
    );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.82),
      size.width * 0.24,
      soft,
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.12),
      size.width * 0.08,
      soft,
    );
  }

  @override
  bool shouldRepaint(covariant _BlobPainter old) => old.base != base;
}
