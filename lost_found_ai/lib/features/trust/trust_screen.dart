import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api_client.dart';
import '../../data/models/trust.dart';
import '../../data/providers.dart';
import '../../widgets/app_dialog.dart';

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
    final textTheme = context.typography;

    return Scaffold(
      appBar: AppBar(title: const Text('Fiabilite du compte')),
      body: trust.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _TrustError(error: error),
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(trustProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _ScoreCard(summary: summary),
              const SizedBox(height: AppSpacing.lg),
              _AccessCard(summary: summary),
              const SizedBox(height: AppSpacing.lg),
              _ExplainCard(inProbation: summary.inProbation),
              const SizedBox(height: AppSpacing.lg),
              Text('Historique des evenements', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (summary.history.isEmpty)
                const _EmptyHistory()
              else
                ...summary.history.map((event) => _HistoryTile(event: event)),
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
    final scheme = context.colors;
    final textTheme = context.typography;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (summary.score / 100).clamp(0.0, 1.0),
                  strokeWidth: 10,
                  color: scheme.primary,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${summary.score.round()}',
                      style: textTheme.headlineSmall,
                    ),
                    Text('Score de confiance', style: textTheme.bodySmall),
                  ],
                ),
              ],
            ),
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
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final textTheme = context.typography;

    return Column(
      children: [
        Icon(icon, color: scheme.primary, size: 22),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: textTheme.titleMedium),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.summary});

  final TrustSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final textTheme = context.typography;
    final (icon, color, title, body) = switch (summary) {
      TrustSummary(canChat: true) => (
        Icons.chat_bubble_rounded,
        scheme.primary,
        'Chat complet actif',
        'Vous pouvez échanger librement avec les personnes dont la '
            'correspondance est vérifiée.',
      ),
      TrustSummary(canCoordinate: true) => (
        Icons.handshake_rounded,
        scheme.tertiary,
        'Mode coordination actif',
        'Vous disposez de 5 messages maximum par correspondance vérifiée '
            'pour organiser la restitution. À ${summary.minScoreToChat} points, '
            'le chat complet s’ouvre.',
      ),
      _ => (
        Icons.lock_outline_rounded,
        scheme.error,
        'Chat verrouillé',
        'Il vous faut au moins ${summary.minScoreToCoordinate} points pour '
            'accéder au mode coordination.',
      ),
    };

    return AppCard(
      color: color.withValues(alpha: 0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(color: color),
                ),
                const SizedBox(height: 3),
                Text(body, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplainCard extends StatelessWidget {
  const _ExplainCard({required this.inProbation});

  final bool inProbation;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final textTheme = context.typography;
    final color = inProbation ? scheme.tertiary : scheme.primary;

    return AppCard(
      color: inProbation ? scheme.tertiaryContainer : scheme.secondaryContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            inProbation ? Icons.timelapse_rounded : Icons.verified_user_rounded,
            color: color,
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
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.event});

  final TrustEvent event;

  Future<void> _openAppeal(BuildContext context, WidgetRef ref) async {
    final reasonController = TextEditingController();
    final reason = await showAppDialog<String>(
      context: context,
      semanticLabel: 'Contester cette sanction',
      builder: (dialogContext) => AlertDialog(
        title: const Text('Contester cette sanction'),
        content: TextField(
          controller: reasonController,
          maxLines: 4,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText:
                'Expliquez pourquoi cette sanction vous semble injustifiée.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(reasonController.text.trim()),
            child: const Text('Envoyer l’appel'),
          ),
        ],
      ),
    );
    reasonController.dispose();

    if (reason == null || !context.mounted) return;

    try {
      await ref
          .read(repositoryProvider)
          .appealTrustEvent(event.id, reason: reason);
      if (!context.mounted) return;
      ref.invalidate(trustProvider);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Appel déposé. Un administrateur va examiner votre demande.',
            ),
          ),
        );
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colors;
    final textTheme = context.typography;
    final isGain = event.points >= 0;
    final color = isGain ? scheme.primary : scheme.error;
    final appealLabel = switch (event.appealStatus) {
      'OUVERTE' => 'Appel en cours d’examen',
      'RESOLUE' => 'Appel accepté',
      'CLOTUREE' => 'Appel rejeté',
      _ => null,
    };

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
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
                Text(event.label, style: textTheme.bodyMedium),
                Text(
                  event.automatic
                      ? 'Genere automatiquement'
                      : 'Valide par un administrateur',
                  style: textTheme.bodySmall,
                ),
                if (appealLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      appealLabel,
                      style: textTheme.bodySmall?.copyWith(
                        color: event.appealStatus == 'RESOLUE'
                            ? scheme.primary
                            : scheme.tertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (event.canAppeal)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => _openAppeal(context, ref),
                      child: Text(
                        'Contester',
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${isGain ? '+' : ''}${event.points}',
            style: textTheme.titleMedium?.copyWith(color: color),
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
    final textTheme = context.typography;

    return AppCard(
      child: Text(
        'Aucun evenement pour le moment. Votre score evoluera apres vos '
        'premieres restitutions confirmees.',
        style: textTheme.bodySmall,
      ),
    );
  }
}

class _TrustError extends StatelessWidget {
  const _TrustError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final textTheme = context.typography;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Score indisponible', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Verifiez que le serveur est lance puis reessayez.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
