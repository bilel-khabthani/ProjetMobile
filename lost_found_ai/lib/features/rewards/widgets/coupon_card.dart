import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/reward.dart';

class CouponCard extends StatelessWidget {
  const CouponCard({super.key, required this.coupon, required this.onTap});

  final UserCoupon coupon;
  final VoidCallback onTap;

  Color _partnerColor(ColorScheme scheme) {
    final name = coupon.partnerName.toLowerCase();
    if (name.contains('glovo')) return scheme.tertiary;
    if (name.contains('yassir')) return scheme.secondary;
    if (name.contains('resto') || name.contains('campus')) {
      return scheme.error;
    }
    if (name.contains('café') || name.contains('cafe')) {
      return scheme.primary;
    }
    if (name.contains('jumia')) return scheme.primary;
    return scheme.primary;
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
    final scheme = context.colors;
    final textTheme = context.typography;
    final partnerColor = _partnerColor(scheme);
    final isUsed = coupon.status == CouponStatus.used;
    final isExpired = coupon.isExpired;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),

          border: Border.all(
            color: isUsed || isExpired
                ? scheme.outlineVariant
                : partnerColor.withValues(alpha: 0.35),
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
                    ? scheme.surfaceContainerHighest
                    : partnerColor.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    Icon(
                      _partnerIcon(),
                      size: 18,
                      color: isUsed || isExpired
                          ? scheme.onSurfaceVariant
                          : partnerColor,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      coupon.partnerName,
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isUsed || isExpired
                            ? scheme.onSurfaceVariant
                            : partnerColor,
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
                            style: textTheme.titleLarge?.copyWith(
                              fontSize: 18,
                              color: isUsed || isExpired
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            coupon.title,
                            style: textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Expire le ${coupon.expiresAt.day.toString().padLeft(2, '0')}/${coupon.expiresAt.month.toString().padLeft(2, '0')}/${coupon.expiresAt.year}',
                                style: textTheme.labelSmall?.copyWith(
                                  color: isExpired
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
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
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            coupon.code,
                            style: textTheme.titleSmall?.copyWith(
                              fontSize: 12,
                              letterSpacing: 1.2,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: coupon.code),
                              );
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Code promo copié dans le presse-papiers !',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Copier',
                                  style: textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
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
    final scheme = context.colors;
    final textTheme = context.typography;
    if (isExpired && status != CouponStatus.used) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          'Expiré',
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onErrorContainer,
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
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          'Utilisé',
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'Actif',
        style: textTheme.labelSmall?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
