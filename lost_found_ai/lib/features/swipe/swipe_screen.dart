import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/swipe_candidate.dart';
import '../../data/providers.dart';
import '../../widgets/app_button.dart';
import '../../widgets/skeleton.dart';
import 'widgets/ai_insight_sheet.dart';
import 'widgets/swipe_action_bar.dart';
import 'widgets/swipe_deck.dart';

/// Module Tinder Cards : tri des correspondances par glissement.
class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen> {
  final SwipeDeckController _deck = SwipeDeckController();

  Future<void> _openInsight(SwipeCandidate candidate) async {
    final notifier = ref.read(swipeDeckProvider.notifier);
    await showAiInsightSheet(
      context,
      candidate: candidate,
      loadInsight: () => notifier.insight(candidate),
    );
  }

  void _decide(SwipeCandidate candidate, SwipeDirection direction) {
    final isDemo = ref.read(swipeDeckProvider).valueOrNull?.isDemo ?? false;
    ref.read(swipeDeckProvider.notifier).decide(candidate, direction);

    if (direction != SwipeDirection.like) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Carte validée. Vérifiez votre objet avec ${candidate.finderName} '
          'avant de récupérer vos affaires.',
        ),
        action: isDemo
            ? null
            : SnackBarAction(
                label: 'Voir',
                onPressed: () {
                  if (mounted) {
                    context.push(AppRoutes.matchDetail(candidate.matchId));
                  }
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncDeck = ref.watch(swipeDeckProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              state: asyncDeck.valueOrNull,
              onRefresh: () => ref.read(swipeDeckProvider.notifier).refresh(),
            ),
            Expanded(
              child: asyncDeck.when(
                loading: () => const _DeckLoading(),
                error: (error, _) => _DeckError(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(swipeDeckProvider),
                ),
                data: (state) {
                  if (state.candidates.isEmpty) {
                    return _DeckFinished(
                      state: state,
                      onReload: () =>
                          ref.read(swipeDeckProvider.notifier).refresh(),
                    );
                  }

                  return Column(
                    children: [
                      if (state.isDemo) _DemoBanner(message: state.message),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.xs,
                            AppSpacing.lg,
                            AppSpacing.sm,
                          ),
                          child: SwipeDeck(
                            controller: _deck,
                            candidates: state.candidates,
                            onDecide: _decide,
                            onOpenInsight: () =>
                                _openInsight(state.candidates.first),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.xs,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        child: SwipeActionBar(
                          onPass: () => _deck.swipe(SwipeDirection.pass),
                          onInsight: () => _openInsight(state.candidates.first),
                          onLike: () => _deck.swipe(SwipeDirection.like),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onRefresh});

  final SwipeDeckState? state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final deck = state;
    final total = deck?.initialTotal ?? 0;
    final remaining = deck?.remaining ?? 0;
    final done = total == 0 ? 0.0 : (total - remaining) / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.home);
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Retour',
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Tinder Cards', style: AppText.h2),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'IA',
                                style: AppText.caption.copyWith(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text('L’IA trie, vous décidez.', style: AppText.caption),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Recharger',
              ),
            ],
          ),
          if (deck != null && total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '$remaining carte${remaining > 1 ? 's' : ''} à trier',
                        style: AppText.label,
                      ),
                      const Spacer(),
                      Text(
                        '${deck.liked} validée(s) · ${deck.passed} passée(s)',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: done.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.primarySoft,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_rounded, size: 16, color: Color(0xFF9A5B00)),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message == null
                  ? 'Mode démo : API indisponible, deck de démonstration.'
                  : 'Mode démo : ${message!}. Deck de démonstration chargé.',
              style: AppText.caption.copyWith(color: const Color(0xFF9A5B00)),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeckLoading extends StatelessWidget {
  const _DeckLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.card,
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 120, height: 24, borderRadius: 999),
            const Spacer(),
            const SkeletonBox(width: 240, height: 26),
            const SizedBox(height: AppSpacing.sm),
            const SkeletonBox(width: 190, height: 14),
            const SizedBox(height: AppSpacing.xl),
            const SkeletonBox(width: double.infinity, height: 68),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const SkeletonBox(width: 34, height: 34, borderRadius: 99),
                const SizedBox(width: AppSpacing.xs),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 140, height: 12),
                    SizedBox(height: 6),
                    SkeletonBox(width: 180, height: 10),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckError extends StatelessWidget {
  const _DeckError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: Icons.cloud_off_rounded,
      color: AppColors.danger,
      title: 'Deck indisponible',
      subtitle: message,
      child: AppButton(
        label: 'Réessayer',
        icon: Icons.refresh_rounded,
        onPressed: onRetry,
      ),
    );
  }
}

class _DeckFinished extends StatelessWidget {
  const _DeckFinished({required this.state, required this.onReload});

  final SwipeDeckState state;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: Icons.task_alt_rounded,
      color: AppColors.found,
      title: 'Deck terminé !',
      subtitle: state.liked == 0
          ? 'Aucune carte validée pour le moment. Rechargez le deck ou publiez une annonce pour recevoir de nouvelles correspondances.'
          : '${state.liked} correspondance(s) validée(s). Ouvrez la fiche pour répondre à la question de vérification et discuter avec le trouveur.',
      child: Column(
        children: [
          if (state.initialTotal == 0) ...[
            AppButton(
              label: 'Publier une annonce',
              icon: Icons.add_rounded,
              onPressed: () => context.push(AppRoutes.publish),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton(
            label: 'Recharger le deck',
            icon: Icons.refresh_rounded,
            onPressed: onReload,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: Text(
              'Retour à l’accueil',
              style: AppText.label.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppText.h2, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: AppText.body, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(width: 260, child: child),
          ],
        ),
      ),
    );
  }
}
