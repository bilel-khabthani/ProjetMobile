import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';

/// Signaux d'accord textuel entre deux annonces : score, details partages et
/// contradictions. N'affiche rien quand le moteur n'a aucun signal a montrer,
/// pour ne pas encombrer les fiches sans photo ni description exploitable.
class AgreementSignals extends StatelessWidget {
  const AgreementSignals({
    super.key,
    required this.score,
    required this.shared,
    required this.contradictions,
    this.title = 'Accord des descriptions',
    this.compact = false,
  });

  final int score;
  final List<String> shared;
  final List<String> contradictions;
  final String title;
  final bool compact;

  bool get _empty => score <= 0 && shared.isEmpty && contradictions.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_empty) return const SizedBox.shrink();

    final colors = context.colors;
    final hasContradictions = contradictions.isNotEmpty;

    return AppCard(
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 17, color: colors.primary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(title, style: context.typography.headlineSmall),
              ),
              if (score > 0)
                Text(
                  '$score/100',
                  style: context.typography.labelMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (score > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 6,
                backgroundColor: colors.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
          ],
          if (shared.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Détails partagés', style: context.typography.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final detail in shared)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.tertiaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: colors.onTertiaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          detail,
                          style: context.typography.bodySmall?.copyWith(
                            color: colors.onTertiaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (hasContradictions) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Contradictions détectées',
              style: context.typography.labelMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final contradiction in contradictions)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 15,
                      color: colors.error,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        contradiction,
                        style: context.typography.bodySmall?.copyWith(
                          color: colors.error,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
