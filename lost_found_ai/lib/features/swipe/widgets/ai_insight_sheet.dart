import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/swipe_candidate.dart';
import '../../../widgets/agreement_signals.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/photo_comparison_card.dart';

/// Ouvre l'analyse IA detaillee d'une carte.
Future<void> showAiInsightSheet(
  BuildContext context, {
  required SwipeCandidate candidate,
  required Future<AiInsight> Function() loadInsight,
}) {
  return showAppBottomSheet<void>(
    context: context,
    showHandle: false,
    backgroundColor: Colors.transparent,
    semanticLabel: 'Analyse détaillée',
    builder: (_) =>
        _AiInsightSheet(candidate: candidate, loadInsight: loadInsight),
  );
}

class _AiInsightSheet extends StatefulWidget {
  const _AiInsightSheet({required this.candidate, required this.loadInsight});

  final SwipeCandidate candidate;
  final Future<AiInsight> Function() loadInsight;

  @override
  State<_AiInsightSheet> createState() => _AiInsightSheetState();
}

class _AiInsightSheetState extends State<_AiInsightSheet> {
  late final Future<AiInsight> _insight = widget.loadInsight().catchError(
    (Object _) => widget.candidate.ai,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: colors.onPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analyse IA',
                        style: context.typography.headlineSmall,
                      ),
                      Text(
                        '${widget.candidate.matchId} · ${widget.candidate.foundTitle}',
                        style: context.typography.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Fermer',
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: FutureBuilder<AiInsight>(
              future: _insight,
              initialData: widget.candidate.ai,
              builder: (context, snapshot) {
                final insight = snapshot.data ?? widget.candidate.ai;
                final loading =
                    snapshot.connectionState == ConnectionState.waiting;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (loading) ...[
                        LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor: colors.primaryContainer,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      _VerdictHeader(insight: insight),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        insight.summary,
                        style: context.typography.bodyLarge?.copyWith(
                          height: 1.5,
                        ),
                      ),
                      if (insight.agreementScore > 0 ||
                          insight.sharedDetails.isNotEmpty ||
                          insight.contradictions.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        AgreementSignals(
                          score: insight.agreementScore,
                          shared: insight.sharedDetails,
                          contradictions: insight.contradictions,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      PhotoComparisonCard(
                        leftUrl: widget.candidate.lostImageUrl,
                        rightUrl: widget.candidate.foundImageUrl,
                        leftCategory: widget.candidate.lostCategory,
                        rightCategory: widget.candidate.foundCategory,
                      ),
                      if (insight.reasons.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Pourquoi cette correspondance ?',
                          style: context.typography.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final reason in insight.reasons)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    size: 17,
                                    color: colors.tertiary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: context.typography.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      if (insight.tags.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final tag in insight.tags)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.secondaryContainer,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: context.typography.bodySmall?.copyWith(
                                    color: colors.onSecondaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (insight.icebreaker.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Message suggéré',
                          style: context.typography.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        AppCard(
                          color: colors.surfaceContainerHighest,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '« ${insight.icebreaker} »',
                                style: context.typography.bodyLarge?.copyWith(
                                  color: colors.onSurface,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: insight.icebreaker),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Message copié. Collez-le dans le chat sécurisé.',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 17,
                                  ),
                                  label: const Text('Copier'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        color: colors.secondaryContainer,
                        showBorder: false,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: colors.onSecondaryContainer,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'L’IA analyse le texte, les photos, la distance et l’écart horaire. '
                                'Elle ne remplace pas la question de vérification : '
                                'le propriétaire doit toujours prouver que l’objet est le sien.',
                                style: context.typography.bodySmall?.copyWith(
                                  color: colors.onSecondaryContainer,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        insight.isLiveAi
                            ? 'Analyse générée par le modèle OpenAI.'
                            : 'Pré-analyse locale (le modèle OpenAI n’est pas configuré).',
                        style: context.typography.bodySmall?.copyWith(
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'L’accord des descriptions et la comparaison des photos '
                        'sont calculés sur l’appareil.',
                        style: context.typography.bodySmall?.copyWith(
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VerdictHeader extends StatelessWidget {
  const _VerdictHeader({required this.insight});

  final AiInsight insight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final background = switch (insight.verdict) {
      AiVerdict.strong => colors.tertiaryContainer,
      AiVerdict.possible => colors.secondaryContainer,
      AiVerdict.weak => colors.surfaceContainerHighest,
    };
    final foreground = switch (insight.verdict) {
      AiVerdict.strong => colors.onTertiaryContainer,
      AiVerdict.possible => colors.onSecondaryContainer,
      AiVerdict.weak => colors.onSurfaceVariant,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                insight.verdict.label,
                style: context.typography.bodySmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${insight.confidence}% de confiance',
              style: context.typography.labelMedium?.copyWith(
                color: foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: insight.confidence / 100,
            minHeight: 8,
            backgroundColor: colors.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(foreground),
          ),
        ),
      ],
    );
  }
}
