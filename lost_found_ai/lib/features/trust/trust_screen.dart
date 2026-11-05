import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/trust.dart';
import '../../data/providers.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/score_gauge.dart';

/// Module 4 - Score de confiance et historique des evenements.
///
/// Le score est en lecture seule : il n'existe aucun bouton pour le modifier.
/// C'est une traduction directe de la regle du CDC qui interdit toute
/// auto-declaration du score de confiance.
class TrustScreen extends ConsumerWidget {
  const TrustScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trust = ref.watch(trustProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: trust.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, _) => _TrustError(
                  onRetry: () => ref.invalidate(trustProvider),
                ),
                data: (summary) => RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async => ref.invalidate(trustProvider),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    children: [
                      _ScoreCard(summary: summary),
                      const SizedBox(height: 14),
                      _ExplainCard(inProbation: summary.inProbation),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Text('Historique', style: AppText.h3),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Text(
                              '${summary.history.length}',
                              style: AppText.tiny.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chaque mouvement est vérifié et horodaté.',
                        style: AppText.caption,
                      ),
                      const SizedBox(height: 12),
                      if (summary.history.isEmpty)
                        const _EmptyHistory()
                      else
                        for (var i = 0; i < summary.history.length; i++)
                          _HistoryTile(
                            event: summary.history[i],
                            isLast: i == summary.history.length - 1,
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          PressableScale(
            onTap: () {
              if (context.canPop()) {
                context.pop();
              }
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: const AppIcon(
                'alt-arrow-left-linear',
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FIABILITÉ',
                  style: AppText.eyebrow.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 2),
                Text('Score de confiance', style: AppText.h2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.summary});

  final TrustSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Row(
              children: [
                ScoreGauge(value: summary.score, size: 112, strokeWidth: 9),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.canChat
                            ? 'Messagerie ouverte'
                            : 'Messagerie verrouillée',
                        style: AppText.bodyStrong,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        summary.canChat
                            ? 'Votre numéro est vérifié et votre score dépasse le seuil requis.'
                            : 'Vérifiez votre téléphone et augmentez votre score pour discuter.',
                        style: AppText.caption.copyWith(height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      _Badge(
                        icon: summary.canChat
                            ? 'chat-round-linear'
                            : 'lock-keyhole-linear',
                        label: summary.canChat
                            ? 'Chat autorisé'
                            : 'Chat bloqué',
                        color: summary.canChat
                            ? AppColors.mintDark
                            : AppColors.accent,
                        background: summary.canChat
                            ? AppColors.foundSoft
                            : AppColors.accentSoft,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    icon: 'cup-star-linear',
                    value: '${summary.recoveredCount}',
                    label: 'Restitutions',
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: AppColors.border,
                ),
                Expanded(
                  child: _Stat(
                    icon: 'clock-circle-linear',
                    value: summary.inProbation ? 'Probation' : 'Standard',
                    label: 'Statut',
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

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  final String icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppText.tiny.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppIcon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value, style: AppText.bodyStrong, maxLines: 1),
        const SizedBox(height: 1),
        Text(label, style: AppText.tiny),
      ],
    );
  }
}

class _ExplainCard extends StatelessWidget {
  const _ExplainCard({required this.inProbation});

  final bool inProbation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: inProbation ? AppColors.accentSoft : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            inProbation ? 'clock-circle-linear' : 'shield-check-linear',
            size: 20,
            color: inProbation ? AppColors.accent : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              inProbation
                  ? 'Votre compte est en période de probation : les gains sont '
                        'plafonnés à 50 % tant que le téléphone n’est pas vérifié '
                        'et que le compte a moins de 14 jours.'
                  : 'Votre score évolue uniquement lors d’événements vérifiés. '
                        'Vous ne pouvez pas le modifier vous-même.',
              style: AppText.caption.copyWith(
                color: inProbation ? AppColors.textPrimary : AppColors.primaryDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.event, required this.isLast});

  final TrustEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isGain = event.points >= 0;
    final color = isGain ? AppColors.found : AppColors.danger;
    final background = isGain ? AppColors.foundSoft : AppColors.lostSoft;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: background,
                    shape: BoxShape.circle,
                  ),
                  child: AppIcon(
                    isGain
                        ? 'cup-star-linear'
                        : 'danger-triangle-linear',
                    size: 14,
                    color: color,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.label, style: AppText.bodyStrong),
                        const SizedBox(height: 2),
                        Text(
                          '${_dateLabel(event.at)} · '
                          '${event.automatic ? 'automatique' : 'validé par un admin'}',
                          style: AppText.tiny,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${isGain ? '+' : ''}${event.points}',
                    style: AppText.bodyStrong.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
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

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const AppIcon(
              'clock-circle-linear',
              size: 24,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text('Aucun événement pour le moment', style: AppText.bodyStrong),
          const SizedBox(height: 3),
          Text(
            'Votre score évoluera après vos premières restitutions confirmées.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TrustError extends StatelessWidget {
  const _TrustError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(
              'danger-triangle-linear',
              size: 42,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text('Score indisponible', style: AppText.bodyStrong),
            const SizedBox(height: 4),
            Text(
              'Vérifiez que le serveur est lancé puis réessayez.',
              textAlign: TextAlign.center,
              style: AppText.caption,
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Réessayer',
                style: AppText.label.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month · $hour:$minute';
}
