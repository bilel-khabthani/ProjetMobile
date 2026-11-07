import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/swipe_candidate.dart';

/// Ouvre l'analyse IA detaillee d'une carte.
Future<void> showAiInsightSheet(
  BuildContext context, {
  required SwipeCandidate candidate,
  required Future<AiInsight> Function() loadInsight,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
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
              color: AppColors.divider,
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
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Analyse IA', style: AppText.h3),
                      Text(
                        '${widget.candidate.matchId} · ${widget.candidate.foundTitle}',
                        style: AppText.caption,
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
                        const LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor: AppColors.primarySoft,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      _VerdictHeader(insight: insight),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        insight.summary,
                        style: AppText.body.copyWith(height: 1.5),
                      ),
                      if (insight.reasons.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Pourquoi cette correspondance ?',
                          style: AppText.h3,
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
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    size: 17,
                                    color: AppColors.found,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(reason, style: AppText.body),
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
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: AppText.caption.copyWith(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (insight.icebreaker.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Text('Message suggéré', style: AppText.h3),
                        const SizedBox(height: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '« ${insight.icebreaker} »',
                                style: AppText.body.copyWith(
                                  color: AppColors.textPrimary,
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
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'L’IA analyse le texte, la distance et l’écart horaire. '
                                'Elle ne remplace pas la question de vérification : '
                                'le propriétaire doit toujours prouver que l’objet est le sien.',
                                style: AppText.caption.copyWith(
                                  color: AppColors.info,
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
                        style: AppText.caption.copyWith(fontSize: 10),
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
    final color = switch (insight.verdict) {
      AiVerdict.strong => AppColors.found,
      AiVerdict.possible => AppColors.accent,
      AiVerdict.weak => AppColors.textTertiary,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                insight.verdict.label,
                style: AppText.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${insight.confidence}% de confiance',
              style: AppText.label.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: insight.confidence / 100,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
