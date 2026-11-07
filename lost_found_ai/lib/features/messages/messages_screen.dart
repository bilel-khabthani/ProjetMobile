import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/item_match.dart';
import '../../data/providers.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/photo_placeholder.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/scene_art.dart';
import '../../widgets/skeleton.dart';
import '../activity/activity_feed.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  bool _onlyPending = false;

  @override
  Widget build(BuildContext context) {
    final matches = ref.watch(matchesProvider);
    final list = matches.valueOrNull ?? const <ItemMatch>[];
    final visible = _onlyPending
        ? list.where((match) => !match.isVerified).toList(growable: false)
        : list;
    final pendingCount = list.where((match) => !match.isVerified).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppBottomNav(active: AppTab.messages),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(matchesProvider);
            try {
              await ref.read(matchesProvider.future);
            } catch (_) {
              // L'etat d'erreur est affiche dans la liste.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
            children: [
              Text(
                'MESSAGERIE',
                style: AppText.eyebrow.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.messagesTitle, style: AppText.h1),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.messagesSubtitle,
                          style: AppText.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${list.length}',
                      style: AppText.label.copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SafetyBanner(),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Segment(
                    label: 'Toutes',
                    selected: !_onlyPending,
                    onTap: () => setState(() => _onlyPending = false),
                  ),
                  const SizedBox(width: 8),
                  _Segment(
                    label:
                        'À vérifier${pendingCount > 0 ? ' · $pendingCount' : ''}',
                    selected: _onlyPending,
                    onTap: () => setState(() => _onlyPending = true),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (matches.isLoading)
                const _MessagesSkeleton()
              else if (matches.hasError)
                const _MessagesNotice(
                  icon: 'danger-triangle-linear',
                  title: 'Messagerie indisponible',
                  body: 'Vérifiez votre connexion puis réessayez.',
                )
              else if (visible.isEmpty)
                _MessagesEmpty(pendingOnly: _onlyPending)
              else
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _ConversationTile(
                    match: visible[i],
                    onTap: () async {
                      if (visible[i].canChat) {
                        await context.push(AppRoutes.chatDetail(visible[i].id));
                      } else {
                        await context.push(
                          AppRoutes.matchDetail(visible[i].id),
                        );
                      }
                      if (!mounted) return;
                      // Le chat a pu marquer des messages comme lus : on
                      // rafraichit les apercus et compteurs au retour.
                      ref.invalidate(matchesProvider);
                    },
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.foundSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.found.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const AppIcon(
              'shield-check-linear',
              size: 20,
              color: AppColors.mintDark,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Les conversations s’ouvrent après vérification. '
              'Vos échanges sont protégés.',
              style: AppText.caption.copyWith(
                color: AppColors.mintDark,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppText.label.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.match, required this.onTap});

  final ItemMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusFor(match);

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.divider),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            ItemArtwork(
              category: match.foundItemCategory,
              width: 56,
              height: 56,
              borderRadius: 16,
              compact: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          match.foundItemTitle,
                          style: AppText.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        relativeTime(
                          match.lastMessageAt ??
                              DateTime.now().subtract(
                                Duration(minutes: match.minutesAgo),
                              ),
                        ),
                        style: AppText.tiny.copyWith(
                          color: match.unreadCount > 0
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          fontWeight: match.unreadCount > 0
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      AppIcon(status.icon, size: 14, color: status.color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          status.label,
                          style: AppText.tiny.copyWith(
                            color: status.color,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${match.scores.global.round()} %',
                        style: AppText.tiny.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    match.hasConversation
                        ? '${match.lastMessageIsMine ? 'Vous : ' : ''}'
                              '${match.lastMessage}'
                        : 'Avec ${match.finderName}',
                    style: AppText.caption.copyWith(
                      color: match.unreadCount > 0
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: match.unreadCount > 0
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: match.canChat
                        ? AppColors.primarySoft
                        : AppColors.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: AppIcon(
                    match.canChat ? 'chat-round-linear' : 'lock-keyhole-linear',
                    size: 16,
                    color: match.canChat
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
                ),
                if (match.unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        match.unreadCount > 99 ? '99+' : '${match.unreadCount}',
                        style: AppText.tiny.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static _StatusInfo _statusFor(ItemMatch match) => switch (match.status) {
    'RECOVERED' => const _StatusInfo(
      icon: 'cup-star-linear',
      color: AppColors.primary,
      label: 'Objet restitué',
    ),
    'CONTACTED' => const _StatusInfo(
      icon: 'chat-round-dots-linear',
      color: AppColors.primary,
      label: 'Échange en cours',
    ),
    'VERIFIED' => const _StatusInfo(
      icon: 'verified-check-bold',
      color: AppColors.mintDark,
      label: 'Correspondance vérifiée',
    ),
    'REJECTED' => const _StatusInfo(
      icon: 'close-circle-linear',
      color: AppColors.danger,
      label: 'Correspondance refusée',
    ),
    _ => const _StatusInfo(
      icon: 'lock-keyhole-linear',
      color: AppColors.accent,
      label: 'Vérification requise',
    ),
  };
}

class _StatusInfo {
  const _StatusInfo({
    required this.icon,
    required this.color,
    required this.label,
  });

  final String icon;
  final Color color;
  final String label;
}

class _MessagesEmpty extends StatelessWidget {
  const _MessagesEmpty({required this.pendingOnly});

  final bool pendingOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const SceneArt(variant: SceneVariant.link, size: 120),
          const SizedBox(height: 10),
          Text(
            pendingOnly
                ? 'Aucune vérification en attente'
                : AppStrings.messagesEmptyTitle,
            style: AppText.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            pendingOnly
                ? 'Toutes vos correspondances sont à jour.'
                : AppStrings.messagesEmptyBody,
            style: AppText.caption.copyWith(height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.go(AppRoutes.explore),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                'Explorer les objets',
                style: AppText.label.copyWith(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesNotice extends StatelessWidget {
  const _MessagesNotice({
    required this.icon,
    required this.title,
    required this.body,
  });

  final String icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          AppIcon(icon, size: 22, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bodyStrong),
                const SizedBox(height: 2),
                Text(body, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesSkeleton extends StatelessWidget {
  const _MessagesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Row(
              children: [
                SkeletonBox(width: 56, height: 56, borderRadius: 16),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 150, height: 13),
                      SizedBox(height: 8),
                      SkeletonBox(width: 120, height: 10),
                      SizedBox(height: 6),
                      SkeletonBox(width: 90, height: 9),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
