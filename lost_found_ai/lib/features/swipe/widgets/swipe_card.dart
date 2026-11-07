import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/swipe_candidate.dart';
import '../../../widgets/photo_placeholder.dart';
import '../../../widgets/pressable_scale.dart';
import '../../../widgets/score_gauge.dart';

/// Carte "Tinder" plein ecran : visuel de l'objet, indices de matching et
/// synthese IA. Elle ne gere pas le geste elle-meme : le deck lui transmet le
/// decalage courant pour animer la rotation et les tampons PASSER / A MOI.
class SwipeCard extends StatelessWidget {
  const SwipeCard({
    super.key,
    required this.candidate,
    required this.drag,
    this.onOpenInsight,
  });

  final SwipeCandidate candidate;
  final Offset drag;
  final VoidCallback? onOpenInsight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        final passOpacity = (-drag.dx / 110).clamp(0.0, 1.0);
        final likeOpacity = (drag.dx / 110).clamp(0.0, 1.0);

        return DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
            boxShadow: AppShadows.raised,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PhotoPlaceholder(
                  category: candidate.foundCategory,
                  borderRadius: 0,
                  showLabel: false,
                ),
                // Voile sombre pour garantir la lisibilite du texte sur
                // n'importe quelle categorie (chaque categorie a sa couleur).
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x331F1B2E),
                        Color(0x001F1B2E),
                        Color(0xB31F1B2E),
                        Color(0xF21F1B2E),
                      ],
                      stops: [0, 0.32, 0.62, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.md,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: _TopBar(candidate: candidate),
                ),
                Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.md,
                  child: _BottomPanel(
                    candidate: candidate,
                    compact: compact,
                    onOpenInsight: onOpenInsight,
                  ),
                ),
                Positioned(
                  top: 96,
                  left: 22,
                  child: _SwipeStamp(
                    label: 'PASSER',
                    color: AppColors.danger,
                    opacity: passOpacity,
                    angle: -0.2,
                  ),
                ),
                Positioned(
                  top: 96,
                  right: 22,
                  child: _SwipeStamp(
                    label: "C'EST À MOI",
                    color: AppColors.found,
                    opacity: likeOpacity,
                    angle: 0.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.candidate});

  final SwipeCandidate candidate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                categoryIcon(candidate.foundCategory),
                size: 16,
                color: categoryColor(candidate.foundCategory),
              ),
              const SizedBox(width: 6),
              Text(
                'OBJET TROUVÉ',
                style: AppText.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: ScoreGauge(
            value: candidate.scores.global,
            size: 56,
            strokeWidth: 5,
            color: Colors.white,
            secondaryColor: Colors.white70,
            labelColor: Colors.white,
            label: 'score',
          ),
        ),
      ],
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.candidate,
    required this.compact,
    this.onOpenInsight,
  });

  final SwipeCandidate candidate;
  final bool compact;
  final VoidCallback? onOpenInsight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _VerdictPill(insight: candidate.ai),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                candidate.foundTimeLabel,
                style: AppText.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          candidate.foundTitle,
          style: AppText.h1.copyWith(
            color: Colors.white,
            fontSize: compact ? 21 : 24,
            height: 1.15,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          Text(
            candidate.foundDescription,
            style: AppText.body.copyWith(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            const Icon(Icons.place_rounded, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${candidate.foundPlace} · ${candidate.distanceLabel}',
                style: AppText.caption.copyWith(color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _ScoreChip(
              icon: Icons.near_me_rounded,
              label: 'Lieu',
              value: candidate.scores.location,
            ),
            _ScoreChip(
              icon: Icons.schedule_rounded,
              label: 'Horaire',
              value: candidate.scores.time,
            ),
            _ScoreChip(
              icon: Icons.notes_rounded,
              label: 'Texte',
              value: candidate.scores.text,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        PressableScale(
          onTap: onOpenInsight,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Analyse IA',
                                    style: AppText.label.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  ${candidate.ai.confidence}%',
                                    style: AppText.caption.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.86,
                                      ),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              candidate.ai.isLiveAi ? 'GPT' : 'pré-analyse',
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        candidate.ai.summary,
                        style: AppText.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.84),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                candidate.finderInitials,
                style: AppText.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trouvé par ${candidate.finderName}',
                    style: AppText.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Confiance ${candidate.finderReputation.round()} · '
                    '${candidate.finderRecoveredCount} objet(s) rendu(s)',
                    style: AppText.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!compact)
              Text(
                'Glissez →',
                style: AppText.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _VerdictPill extends StatelessWidget {
  const _VerdictPill({required this.insight});

  final AiInsight insight;

  @override
  Widget build(BuildContext context) {
    final color = switch (insight.verdict) {
      AiVerdict.strong => AppColors.found,
      AiVerdict.possible => AppColors.accent,
      AiVerdict.weak => AppColors.textTertiary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            insight.verdict.label,
            style: AppText.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            '$label ${value.round()}',
            style: AppText.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeStamp extends StatelessWidget {
  const _SwipeStamp({
    required this.label,
    required this.color,
    required this.opacity,
    required this.angle,
  });

  final String label;
  final Color color;
  final double opacity;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: angle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color, width: 3),
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: Text(
              label,
              style: AppText.h3.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
