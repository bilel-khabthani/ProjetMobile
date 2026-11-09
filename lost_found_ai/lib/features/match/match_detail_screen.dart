import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/item.dart';
import '../../data/models/item_match.dart';
import '../../data/providers.dart';
import '../../widgets/app_button.dart';
import '../../widgets/photo_placeholder.dart';
import '../../widgets/score_gauge.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_pill.dart';
import 'verification_sheet.dart';

class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchProvider(matchId));

    return Scaffold(
      body: SafeArea(
        child: async.when(
          loading: () => const _DetailSkeleton(),
          error: (error, _) => const _DetailError(),
          data: (match) => _DetailBody(match: match),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.match});

  final ItemMatch match;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DetailAppBar(match: match),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: [
              _ScoreHero(match: match),
              const SizedBox(height: AppSpacing.xl),
              _ScoreBreakdown(match: match),
              const SizedBox(height: AppSpacing.xl),
              _ComparisonCard(match: match),
              const SizedBox(height: AppSpacing.md),
              _FinderCard(match: match),
              const SizedBox(height: AppSpacing.md),
              _HowItWorksCard(),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
        _VerifyBar(match: match),
      ],
    );
  }
}

class _DetailAppBar extends StatelessWidget {
  const _DetailAppBar({required this.match});

  final ItemMatch match;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              AppStrings.matchTitle,
              style: AppText.h2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.match});

  final ItemMatch match;

  @override
  Widget build(BuildContext context) {
    final score = match.scores.global;
    final color = _scoreColor(score);
    final verdict = score >= 80
        ? AppStrings.matchScoreExcellent
        : score >= 65
        ? AppStrings.matchScoreGood
        : AppStrings.matchScoreLow;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        children: [
          ScoreGauge(
            value: score,
            size: 168,
            strokeWidth: 15,
            color: color,
            secondaryColor: color.withValues(alpha: 0.5),
            label: AppStrings.matchScore,
            labelColor: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, size: 17, color: color),
                const SizedBox(width: 6),
                Text(
                  verdict,
                  style: AppText.caption.copyWith(
                    color: Color.lerp(color, Colors.black, 0.2),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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

class _ScoreBreakdown extends StatelessWidget {
  const _ScoreBreakdown({required this.match});

  final ItemMatch match;

  @override
  Widget build(BuildContext context) {
    final scores = match.scores;
    final rows = <_ScoreRowData>[
      _ScoreRowData(
        label: AppStrings.dimensionImage,
        value: scores.image,
        icon: Icons.image_rounded,
        color: AppColors.primary,
      ),
      _ScoreRowData(
        label: AppStrings.dimensionLocation,
        value: scores.location,
        icon: Icons.place_rounded,
        color: AppColors.found,
      ),
      _ScoreRowData(
        label: AppStrings.dimensionTime,
        value: scores.time,
        icon: Icons.schedule_rounded,
        color: AppColors.accent,
      ),
      _ScoreRowData(
        label: AppStrings.dimensionText,
        value: scores.text,
        icon: Icons.text_snippet_rounded,
        color: const Color(0xFF8B7BD8),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text('Détail de l’analyse', style: AppText.h3),
          ),
          ...List.generate(rows.length, (index) {
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : AppSpacing.md),
              child: _ScoreRow(data: rows[index], delayMs: 120 * index),
            );
          }),
        ],
      ),
    );
  }
}

class _ScoreRowData {
  const _ScoreRowData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final double value;
  final IconData icon;
  final Color color;
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.data, required this.delayMs});

  final _ScoreRowData data;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(data.icon, size: 17, color: data.color),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 96,
          child: Text(
            data.label,
            style: AppText.label.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: (data.value / 100).clamp(0.0, 1.0),
            ),
            duration: Duration(milliseconds: 900 + delayMs),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(data.color),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 38,
          child: Text(
            '${data.value.round()} %',
            textAlign: TextAlign.right,
            style: AppText.label.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.match});

  final ItemMatch match;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          _ComparisonRow(
            title: AppStrings.matchYourItem,
            subtitle: '${match.myItemPlace} · ${match.myItemTimeLabel}',
            category: match.myItemCategory,
            badge: match.myItemTitle,
            pill: const StatusPill(type: ItemType.lost),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: _ConnectorLine(),
          ),
          _ComparisonRow(
            title: AppStrings.matchOtherItem,
            subtitle: '${match.foundItemPlace} · ${match.foundItemTimeLabel}',
            category: match.foundItemCategory,
            badge: match.foundItemTitle,
            pill: const StatusPill(type: ItemType.found),
          ),
        ],
      ),
    );
  }
}

class _ConnectorLine extends StatelessWidget {
  const _ConnectorLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 17),
        Container(width: 2, height: 18, color: AppColors.border),
        const SizedBox(width: AppSpacing.sm),
        Icon(Icons.link_rounded, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Text('Même objet probable', style: AppText.caption),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.badge,
    required this.pill,
  });

  final String title;
  final String subtitle;
  final ItemCategory category;
  final String badge;
  final Widget pill;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PhotoPlaceholder(
          category: category,
          size: 52,
          borderRadius: AppRadius.md,
          showLabel: false,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: AppText.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  pill,
                ],
              ),
              const SizedBox(height: 2),
              Text(
                badge,
                style: AppText.h3.copyWith(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: AppText.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FinderCard extends StatelessWidget {
  const _FinderCard({required this.match});

  final ItemMatch match;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Avatar(
            initials: match.finderInitials,
            size: 46,
            color: AppColors.found,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.matchFoundBy, style: AppText.caption),
                const SizedBox(height: 1),
                Text(
                  match.finderName,
                  style: AppText.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                Text(
                  '${match.finderReputation}',
                  style: AppText.h3.copyWith(fontSize: 15),
                ),
                Text(
                  '${match.finderRecoveredCount} rendus',
                  style: AppText.caption.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.matchHowTitle,
                  style: AppText.label.copyWith(
                    color: AppColors.primaryDark,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppStrings.matchHowBody,
                  style: AppText.caption.copyWith(
                    color: AppColors.primaryDark,
                    height: 1.45,
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

class _VerifyBar extends ConsumerWidget {
  const _VerifyBar({required this.match});

  final ItemMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verified =
        ref.watch(verificationProvider)?.success == true &&
        ref.watch(verificationProvider)?.matchId == match.id;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: verified
          ? AppButton(
              label: 'Contacter ${match.finderName.split(' ').first}',
              icon: Icons.chat_bubble_rounded,
              variant: AppButtonVariant.success,
              onPressed: () {
                ref.invalidate(matchProvider(match.id));
                context.push(AppRoutes.chatDetail(match.id));
              },
            )
          : AppButton(
              label: AppStrings.answerQuestion,
              icon: Icons.quiz_rounded,
              onPressed: () => showVerificationSheet(context, match),
            ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      children: const [
        SkeletonBox(width: 190, height: 24, borderRadius: 8),
        SizedBox(height: AppSpacing.xl),
        SkeletonBox(height: 230, borderRadius: AppRadius.xl),
        SizedBox(height: AppSpacing.xl),
        SkeletonBox(height: 210, borderRadius: AppRadius.lg),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 130, borderRadius: AppRadius.lg),
      ],
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError();

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
            const SizedBox(height: AppSpacing.sm),
            Text('Impossible de charger', style: AppText.h3),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(
                'Retour',
                style: AppText.label.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _scoreColor(double score) {
  if (score >= 80) return AppColors.found;
  if (score >= 65) return AppColors.accent;
  return AppColors.textTertiary;
}
