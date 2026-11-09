import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

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

  bool get _empty =>
      score <= 0 && shared.isEmpty && contradictions.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_empty) return const SizedBox.shrink();

    final hasContradictions = contradictions.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notes_rounded,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(title, style: AppText.h3)),
              if (score > 0)
                Text(
                  '$score/100',
                  style: AppText.label.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
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
                backgroundColor: AppColors.surfaceAlt,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
          ],
          if (shared.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Détails partagés', style: AppText.label),
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
                      color: AppColors.foundSoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: AppColors.found,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          detail,
                          style: AppText.caption.copyWith(
                            color: AppColors.found,
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
            Text('Contradictions détectées', style: AppText.label),
            const SizedBox(height: AppSpacing.xs),
            for (final contradiction in contradictions)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 15,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        contradiction,
                        style: AppText.caption.copyWith(
                          color: AppColors.danger,
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
