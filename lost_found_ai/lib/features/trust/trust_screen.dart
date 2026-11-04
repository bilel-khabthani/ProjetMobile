import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/trust.dart';
import '../../data/providers.dart';
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
      appBar: AppBar(title: const Text('Fiabilite du compte')),
      body: trust.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (error, _) => _TrustError(error: error),
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(trustProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _ScoreCard(summary: summary),
              const SizedBox(height: AppSpacing.lg),
              _ExplainCard(inProbation: summary.inProbation),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Historique des evenements',
                style: AppText.bodyStrong,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (summary.history.isEmpty)
                const _EmptyHistory()
              else
                ...summary.history.map(
                  (event) => _HistoryTile(event: event),
                ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          ScoreGauge(
            value: summary.score,
            label: 'Score de confiance',
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.handshake_rounded,
                  value: '${summary.recoveredCount}',
                  label: 'Restitutions',
                ),
              ),
              Expanded(
                child: _Stat(
                  icon: summary.canChat
                      ? Icons.chat_bubble_rounded
                      : Icons.chat_bubble_outline_rounded,
                  value: summary.canChat ? 'Autorise' : 'Bloque',
                  label: 'Chat',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppText.bodyStrong),
        Text(label, style: AppText.caption),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: inProbation ? AppColors.accentSoft : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            inProbation
                ? Icons.timelapse_rounded
                : Icons.verified_user_rounded,
            color: inProbation ? AppColors.accent : AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              inProbation
                  ? 'Votre compte est en periode de probation : les gains sont '
                        'plafonnes a 50% tant que le telephone n\'est pas verifie '
                        'et que le compte a moins de 14 jours.'
                  : 'Votre score evolue uniquement lors d\'evenements verifies. '
                        'Vous ne pouvez pas le modifier vous-meme.',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.event});

  final TrustEvent event;

  @override
  Widget build(BuildContext context) {
    final isGain = event.points >= 0;
    final color = isGain ? AppColors.success : AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            isGain ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.label, style: AppText.body),
                Text(
                  event.automatic
                      ? 'Genere automatiquement'
                      : 'Valide par un administrateur',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Text(
            '${isGain ? '+' : ''}${event.points}',
            style: AppText.bodyStrong.copyWith(color: color),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Aucun evenement pour le moment. Votre score evoluera apres vos '
        'premieres restitutions confirmees.',
        style: AppText.caption,
      ),
    );
  }
}

class _TrustError extends StatelessWidget {
  const _TrustError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Score indisponible',
              style: AppText.bodyStrong,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Verifiez que le serveur est lance puis reessayez.',
              textAlign: TextAlign.center,
              style: AppText.caption,
            ),
          ],
        ),
      ),
    );
  }
}