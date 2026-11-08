import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/reward.dart';

class CouponCard extends StatelessWidget {
  const CouponCard({
    super.key,
    required this.coupon,
    required this.onTap,
  });

  final UserCoupon coupon;
  final VoidCallback onTap;

  Color _partnerColor() {
    final name = coupon.partnerName.toLowerCase();
    if (name.contains('glovo')) return const Color(0xFFFFC244);
    if (name.contains('yassir')) return const Color(0xFF00A859);
    if (name.contains('resto') || name.contains('campus')) return const Color(0xFFE11D48);
    if (name.contains('café') || name.contains('cafe')) return const Color(0xFF8B5CF6);
    if (name.contains('jumia')) return const Color(0xFFF97316);
    return AppColors.primary;
  }

  IconData _partnerIcon() {
    final type = coupon.partnerType.toUpperCase();
    if (type.contains('DELIVERY')) return Icons.delivery_dining_rounded;
    if (type.contains('RESTAURANT')) return Icons.restaurant_rounded;
    if (type.contains('CAFE')) return Icons.coffee_rounded;
    return Icons.card_giftcard_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final partnerColor = _partnerColor();
    final isUsed = coupon.status == CouponStatus.used;
    final isExpired = coupon.isExpired;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
          border: Border.all(
            color: isUsed || isExpired ? AppColors.border : partnerColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bandeau supérieur partenaire
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                color: isUsed || isExpired
                    ? AppColors.surfaceAlt
                    : partnerColor.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    Icon(
                      _partnerIcon(),
                      size: 18,
                      color: isUsed || isExpired ? AppColors.textTertiary : partnerColor,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      coupon.partnerName,
                      style: AppText.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isUsed || isExpired ? AppColors.textTertiary : partnerColor,
                      ),
                    ),
                    const Spacer(),
                    _StatusBadge(status: coupon.status, isExpired: isExpired),
                  ],
                ),
              ),

              // Corps du ticket
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            coupon.discountText,
                            style: AppText.h3.copyWith(
                              fontSize: 18,
                              color: isUsed || isExpired
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            coupon.title,
                            style: AppText.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Expire le ${coupon.expiresAt.day.toString().padLeft(2, '0')}/${coupon.expiresAt.month.toString().padLeft(2, '0')}/${coupon.expiresAt.year}',
                                style: AppText.caption.copyWith(
                                  color: isExpired ? AppColors.danger : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Code Promo avec bouton Copier
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            coupon.code,
                            style: AppText.bodyStrong.copyWith(
                              fontSize: 12,
                              letterSpacing: 1.2,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: coupon.code));
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Code promo copié dans le presse-papiers !'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.copy_rounded,
                                  size: 12,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Copier',
                                  style: AppText.caption.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.isExpired});

  final CouponStatus status;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    if (isExpired && status != CouponStatus.used) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          'Expiré',
          style: AppText.caption.copyWith(
            color: AppColors.danger,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      );
    }

    if (status == CouponStatus.used) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.textTertiary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          'Utilisé',
          style: AppText.caption.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'Actif',
        style: AppText.caption.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}

