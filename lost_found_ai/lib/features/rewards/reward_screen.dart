import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/reward.dart';
import '../../data/providers.dart';
import 'widgets/coupon_card.dart';
import 'widgets/coupon_detail_sheet.dart';
import 'widgets/lucky_wheel.dart';

class RewardScreen extends ConsumerStatefulWidget {
  const RewardScreen({super.key});

  @override
  ConsumerState<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends ConsumerState<RewardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _selectedCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _redeemReward(Reward reward) async {
    final wallet = ref.read(rewardWalletProvider).valueOrNull;
    final currentPoints = wallet?.points ?? 0;

    if (currentPoints < reward.pointsCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Points insuffisants : vous avez $currentPoints pts, il vous faut ${reward.pointsCost} pts.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer l\'échange'),
        content: Text(
          'Voulez-vous échanger ${reward.pointsCost} points contre « ${reward.title} » ?\n\n'
          'Un coupon officiel vous sera attribué et envoyé par e-mail avec le PDF joint.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Échanger'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      HapticFeedback.mediumImpact();
      final res = await ref.read(repositoryProvider).redeemReward(reward.id);
      ref.invalidate(myCouponsProvider);
      ref.invalidate(rewardWalletProvider);

      if (!mounted) return;
      final emailSent = res['email_sent'] != false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] as String? ?? 'Coupon obtenu avec succès !'),
          backgroundColor: emailSent ? AppColors.success : AppColors.warning,
          duration: Duration(seconds: emailSent ? 4 : 6),
        ),
      );

      // Bascule vers l'onglet "Mes Coupons"
      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<SpinResult?> _handleSpin() async {
    try {
      final result = await ref.read(repositoryProvider).spinWheel();
      ref.invalidate(rewardWalletProvider);
      ref.invalidate(myCouponsProvider);
      return result;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(rewardWalletProvider);
    final rewardsAsync = ref.watch(rewardsProvider);
    final couponsAsync = ref.watch(myCouponsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Récompenses & Fidélité'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.storefront_rounded), text: 'Boutique'),
            Tab(icon: Icon(Icons.confirmation_number_rounded), text: 'Mes Bons'),
            Tab(icon: Icon(Icons.casino_rounded), text: 'Roue'),
          ],
        ),
      ),
      body: Column(
        children: [
          // En-tête : Solde de Points
          walletAsync.when(
            data: (wallet) => _WalletHeader(wallet: wallet),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // Contenu des onglets
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Onglet 1 : Boutique Partenaires
                _ShopTab(
                  rewardsAsync: rewardsAsync,
                  selectedCategory: _selectedCategory,
                  onCategoryChanged: (cat) => setState(() => _selectedCategory = cat),
                  onRedeem: _redeemReward,
                ),

                // Onglet 2 : Mes Coupons
                _MyCouponsTab(
                  couponsAsync: couponsAsync,
                  onRefresh: () async {
                    ref.invalidate(myCouponsProvider);
                    ref.invalidate(rewardWalletProvider);
                  },
                ),

                // Onglet 3 : Roue de la Chance
                _WheelTab(
                  walletAsync: walletAsync,
                  onSpin: _handleSpin,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletHeader extends StatelessWidget {
  const _WalletHeader({required this.wallet});

  final RewardWallet wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B6CF0), Color(0xFF4351D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.primary,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${wallet.points} Points Fidélité',
                  style: AppText.h2.copyWith(color: Colors.white),
                ),
                Text(
                  'Gagnez des points en restituant des objets perdus !',
                  style: AppText.caption.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: wallet.canSpinFreeToday ? const Color(0xFFFFB33C) : Colors.white24,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              wallet.canSpinFreeToday ? '1 Tour Dispo' : 'Tour Effectué (Demain)',
              style: AppText.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopTab extends StatelessWidget {
  const _ShopTab({
    required this.rewardsAsync,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onRedeem,
  });

  final AsyncValue<List<Reward>> rewardsAsync;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<Reward> onRedeem;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtres catégories
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Row(
            children: [
              _FilterChip(
                label: 'Tous',
                selected: selectedCategory == 'ALL',
                onSelected: () => onCategoryChanged('ALL'),
              ),
              _FilterChip(
                label: '🛵 Livraison (Glovo / Yassir)',
                selected: selectedCategory == 'DELIVERY',
                onSelected: () => onCategoryChanged('DELIVERY'),
              ),
              _FilterChip(
                label: '🍔 Restauration',
                selected: selectedCategory == 'RESTAURANT',
                onSelected: () => onCategoryChanged('RESTAURANT'),
              ),
              _FilterChip(
                label: '☕ Cafétéria',
                selected: selectedCategory == 'CAFE',
                onSelected: () => onCategoryChanged('CAFE'),
              ),
            ],
          ),
        ),

        // Liste des récompenses
        Expanded(
          child: rewardsAsync.when(
            data: (rewards) {
              final filtered = selectedCategory == 'ALL'
                  ? rewards
                  : rewards.where((r) => r.partnerType.toUpperCase() == selectedCategory).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('Aucune récompense dans cette catégorie.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final reward = filtered[index];
                  return _RewardShopCard(reward: reward, onRedeem: () => onRedeem(reward));
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur : $e')),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: AppColors.primarySoft,
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RewardShopCard extends StatelessWidget {
  const _RewardShopCard({required this.reward, required this.onRedeem});

  final Reward reward;
  final VoidCallback onRedeem;

  Color _color() {
    try {
      final hex = reward.colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.card_giftcard_rounded, color: color, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.partnerName,
                  style: AppText.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  reward.title,
                  style: AppText.bodyStrong,
                ),
                Text(
                  reward.discountText,
                  style: AppText.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: onRedeem,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: AppColors.primary,
            ),
            child: Text('${reward.pointsCost} pts'),
          ),
        ],
      ),
    );
  }
}

class _MyCouponsTab extends StatelessWidget {
  const _MyCouponsTab({
    required this.couponsAsync,
    required this.onRefresh,
  });

  final AsyncValue<List<UserCoupon>> couponsAsync;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: couponsAsync.when(
        data: (coupons) {
          if (coupons.isEmpty) {
            return ListView(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.confirmation_number_outlined,
                        size: 54,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aucun coupon actif', style: AppText.h3),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Restituez un objet ou tournez la Roue de la Chance pour en gagner !',
                        style: AppText.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: coupons.length,
            itemBuilder: (context, index) {
              final coupon = coupons[index];
              return CouponCard(
                coupon: coupon,
                onTap: () => CouponDetailSheet.show(context, coupon),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
      ),
    );
  }
}

class _WheelTab extends StatelessWidget {
  const _WheelTab({
    required this.walletAsync,
    required this.onSpin,
  });

  final AsyncValue<RewardWallet> walletAsync;
  final Future<SpinResult?> Function() onSpin;

  @override
  Widget build(BuildContext context) {
    final wallet = walletAsync.valueOrNull;
    final canSpinToday = wallet?.canSpinFreeToday ?? true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: canSpinToday ? const Color(0xFFFEF3C7) : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: canSpinToday ? const Color(0xFFF59E0B) : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  canSpinToday ? Icons.celebration_rounded : Icons.check_circle_rounded,
                  color: canSpinToday ? const Color(0xFFD97706) : AppColors.success,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    canSpinToday
                        ? '🎯 1 tour gratuit disponible aujourd\'hui !'
                        : '✅ Tour du jour déjà effectué ! Revenez demain.',
                    style: AppText.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: canSpinToday ? const Color(0xFF78350F) : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // La Roue de la Chance
          LuckyWheelWidget(
            onSpinRequested: onSpin,
            canSpin: canSpinToday,
          ),

          const SizedBox(height: AppSpacing.xl),
          Text(
            'Règle : 1 seul tour par jour.\nPlus les points augmentent, plus la chance est rare ! (De +5 à +100 Pts Jackpot)\nÉchangez vos points dans la Boutique contre vos bons partenaires.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

