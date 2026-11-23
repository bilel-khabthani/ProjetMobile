import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
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
              if (match.isCoordination) ...[
                const SizedBox(height: AppSpacing.md),
                _CoordinationCard(match: match),
              ],
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
              style: context.typography.headlineSmall,
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
    final colors = context.colors;
    final score = match.scores.global;
    final color = _scoreColor(score, colors);
    final verdict = score >= 80
        ? AppStrings.matchScoreExcellent
        : score >= 65
        ? AppStrings.matchScoreGood
        : AppStrings.matchScoreLow;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          ScoreGauge(
            value: score,
            size: 168,
            strokeWidth: 15,
            color: color,
            secondaryColor: color,
            label: AppStrings.matchScore,
            labelColor: colors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, size: 17, color: color),
                const SizedBox(width: 6),
                Text(
                  verdict,
                  style: context.typography.bodySmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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
    final colors = context.colors;
    final scores = match.scores;
    final rows = <_ScoreRowData>[
      _ScoreRowData(
        label: AppStrings.dimensionImage,
        value: scores.image,
        icon: Icons.image_rounded,
        color: colors.primary,
      ),
      _ScoreRowData(
        label: AppStrings.dimensionLocation,
        value: scores.location,
        icon: Icons.place_rounded,
        color: colors.tertiary,
      ),
      _ScoreRowData(
        label: AppStrings.dimensionTime,
        value: scores.time,
        icon: Icons.schedule_rounded,
        color: colors.secondary,
      ),
      _ScoreRowData(
        label: AppStrings.dimensionText,
        value: scores.text,
        icon: Icons.text_snippet_rounded,
        color: Color.lerp(colors.primary, colors.tertiary, 0.5)!,
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              'Détail de l’analyse',
              style: context.typography.headlineSmall,
            ),
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
    final colors = context.colors;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(data.icon, size: 17, color: data.color),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 96,
          child: Text(
            data.label,
            style: context.typography.labelMedium?.copyWith(
              color: colors.onSurface,
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
                backgroundColor: colors.surfaceContainerHighest,
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
            style: context.typography.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
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
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
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
    final colors = context.colors;
    return Row(
      children: [
        const SizedBox(width: 17),
        Container(width: 2, height: 18, color: colors.outlineVariant),
        const SizedBox(width: AppSpacing.sm),
        Icon(Icons.link_rounded, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text('Même objet probable', style: context.typography.bodySmall),
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
                      style: context.typography.bodySmall,
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
                style: context.typography.headlineSmall?.copyWith(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: context.typography.bodySmall,
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
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Avatar(
            initials: match.finderInitials,
            size: 46,
            color: colors.tertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.matchFoundBy,
                  style: context.typography.bodySmall,
                ),
                const SizedBox(height: 1),
                Text(
                  match.finderName,
                  style: context.typography.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                Text(
                  '${match.finderReputation}',
                  style: context.typography.headlineSmall?.copyWith(
                    fontSize: 15,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                Text(
                  '${match.finderRecoveredCount} rendus',
                  style: context.typography.bodySmall?.copyWith(
                    fontSize: 10,
                    color: colors.onSecondaryContainer,
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

class _CoordinationCard extends StatelessWidget {
  const _CoordinationCard({required this.match});

  final ItemMatch match;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final remaining = match.coordinationMessagesRemaining ?? 0;

    return AppCard(
      color: colors.secondaryContainer,
      showBorder: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.handshake_rounded,
            size: 22,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode coordination',
                  style: context.typography.labelMedium?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Votre score permet 5 messages maximum pour organiser la '
                  'restitution. Il en reste $remaining. Le chat complet '
                  's’ouvre à 40 points de confiance.',
                  style: context.typography.bodySmall?.copyWith(
                    color: colors.onSecondaryContainer,
                    height: 1.4,
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

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      color: colors.primaryContainer,
      showBorder: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: colors.onPrimaryContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.matchHowTitle,
                  style: context.typography.labelMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppStrings.matchHowBody,
                  style: context.typography.bodySmall?.copyWith(
                    color: colors.onPrimaryContainer,
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
    final colors = context.colors;
    final Widget action;
    if (match.isVerified && match.canChat) {
      action = AppButton(
        label: match.isCoordination
            ? 'Coordonner la restitution'
            : 'Contacter ${match.counterpartName.split(' ').first}',
        icon: match.isCoordination
            ? Icons.handshake_rounded
            : Icons.chat_bubble_rounded,
        variant: match.isCoordination
            ? AppButtonVariant.primary
            : AppButtonVariant.success,
        onPressed: () {
          ref.invalidate(matchProvider(match.id));
          context.push(AppRoutes.chatDetail(match.id));
        },
      );
    } else if (match.isVerified) {
      action = _VerificationNotice(
        icon: Icons.lock_outline_rounded,
        message:
            match.chatLockedReason ??
            'Le chat sera disponible dès que les conditions de confiance seront réunies.',
      );
    } else if (match.iAmFinder) {
      action = const _VerificationNotice(
        icon: Icons.hourglass_top_rounded,
        message:
            'En attente de la vérification du propriétaire. Le chat s’ouvrira '
            'automatiquement après confirmation.',
      );
    } else {
      action = AppButton(
        label: AppStrings.answerQuestion,
        icon: Icons.quiz_rounded,
        onPressed: () => showVerificationSheet(context, match),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: action,
    );
  }
}

class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.onSecondaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: context.typography.bodySmall?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
          ),
        ],
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
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Impossible de charger',
              style: context.typography.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }
}

Color _scoreColor(double score, ColorScheme colors) {
  if (score >= 80) return colors.tertiary;
  if (score >= 65) return colors.secondary;
  return colors.onSurfaceVariant;
}
