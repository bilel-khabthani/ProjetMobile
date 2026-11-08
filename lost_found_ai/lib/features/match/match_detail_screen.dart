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
import '../../widgets/app_icon.dart';
import '../../widgets/photo_placeholder.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/score_gauge.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_pill.dart';

class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchProvider(matchId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: async.when(
          loading: () => const _DetailSkeleton(),
          error: (_, _) => _DetailError(onBack: () => context.pop()),
          data: (match) => _DetailBody(match: match),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.match});

  final ItemMatch match;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  final _verifyKey = GlobalKey();

  bool get _verified {
    final result = ref.watch(verificationProvider);
    final locallyVerified =
        result?.success == true && result?.matchId == widget.match.id;
    return widget.match.isVerified || locallyVerified;
  }

  void _scrollToVerification() {
    final target = _verifyKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  void _openChat() {
    context.push(AppRoutes.chatDetail(widget.match.id));
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;

    return Column(
      children: [
        _DetailAppBar(match: match),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            children: [
              _ScoreHero(match: match, verified: _verified),
              const SizedBox(height: 22),
              _SectionTitle(
                title: AppStrings.matchComparisonTitle,
                subtitle: AppStrings.matchComparisonSubtitle,
              ),
              const SizedBox(height: 12),
              _ComparisonCard(match: match),
              const SizedBox(height: 16),
              _FinderCard(match: match),
              const SizedBox(height: 16),
              _ScoreBreakdown(match: match),
              const SizedBox(height: 18),
              if (_verified)
                const _VerifiedNotice()
              else if (match.iAmFinder)
                const _WaitingOwnerNotice()
              else
                KeyedSubtree(
                  key: _verifyKey,
                  child: _VerificationCard(match: match),
                ),
              const SizedBox(height: 16),
              const _HowItWorksCard(),
            ],
          ),
        ),
        _DetailBottomBar(
          match: match,
          verified: _verified,
          onChat: _openChat,
          onVerify: _scrollToVerification,
        ),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          _CircleAction(
            icon: 'alt-arrow-left-linear',
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.home);
              }
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CORRESPONDANCE',
                  style: AppText.eyebrow.copyWith(color: AppColors.primary),
                ),
                Text(
                  AppStrings.matchTitle,
                  style: AppText.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _CircleAction(
            icon: 'flag-linear',
            onTap: () => context.push(AppRoutes.claimDetail(match.id)),
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider),
          boxShadow: AppShadows.card,
        ),
        child: AppIcon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.match, required this.verified});

  final ItemMatch match;
  final bool verified;

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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0EDFF), AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Row(
            children: [
              StatusPill(type: match.otherItemType),
              const Spacer(),
              if (verified) const VerifiedPill(),
            ],
          ),
          const SizedBox(height: 16),
          ScoreGauge(
            value: score,
            size: 116,
            strokeWidth: 9,
            color: color,
            secondaryColor: color.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 14),
          Text(verdict, style: AppText.h2, textAlign: TextAlign.center),
          const SizedBox(height: 5),
          Text(
            'Analyse croisée de 4 critères · ${match.foundItemTimeLabel}',
            style: AppText.caption,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.h2),
        const SizedBox(height: 3),
        Text(subtitle, style: AppText.caption),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.match});

  final ItemMatch match;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MiniItemCard(
              label: AppStrings.matchYourItem,
              title: match.myItemTitle,
              place: match.myItemPlace,
              time: match.myItemTimeLabel,
              category: match.myItemCategory,
              type: match.myItemType,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MiniItemCard(
              label: match.otherItemType == ItemType.lost
                  ? AppStrings.matchOtherLostItem
                  : AppStrings.matchOtherItem,
              title: match.foundItemTitle,
              place: match.foundItemPlace,
              time: match.foundItemTimeLabel,
              category: match.foundItemCategory,
              type: match.otherItemType,
              color: AppColors.found,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniItemCard extends StatelessWidget {
  const _MiniItemCard({
    required this.label,
    required this.title,
    required this.place,
    required this.time,
    required this.category,
    required this.type,
    required this.color,
  });

  final String label;
  final String title;
  final String place;
  final String time;
  final ItemCategory category;
  final ItemType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ItemArtwork(
            category: category,
            height: 88,
            width: double.infinity,
            borderRadius: 16,
            compact: true,
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              StatusPill(type: type, compact: true),
              const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: AppText.tiny.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            title,
            style: AppText.bodyStrong.copyWith(fontSize: 13.5),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const AppIcon(
                'map-point-linear',
                size: 12,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  place,
                  style: AppText.tiny.copyWith(color: AppColors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: AppText.tiny.copyWith(color: AppColors.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FinderCard extends StatelessWidget {
  const _FinderCard({required this.match});

  final ItemMatch match;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Avatar(
            initials: match.finderInitials,
            size: 44,
            color: AppColors.primary,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.iAmFinder
                      ? AppStrings.matchOwnerLabel
                      : AppStrings.matchFoundBy,
                  style: AppText.tiny.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  match.finderName,
                  style: AppText.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${match.finderRecoveredCount} restitution${match.finderRecoveredCount > 1 ? 's' : ''}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '${match.finderReputation.round()}',
                  style: AppText.label.copyWith(
                    color: const Color(0xFF9A6414),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'confiance',
                  style: AppText.tiny.copyWith(
                    color: const Color(0xFF9A6414),
                    fontSize: 9,
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
        icon: 'gallery-linear',
        color: AppColors.primary,
      ),
      _ScoreRowData(
        label: AppStrings.dimensionLocation,
        value: scores.location,
        icon: 'map-point-linear',
        color: AppColors.found,
      ),
      _ScoreRowData(
        label: AppStrings.dimensionTime,
        value: scores.time,
        icon: 'clock-circle-linear',
        color: AppColors.accent,
      ),
      _ScoreRowData(
        label: AppStrings.dimensionText,
        value: scores.text,
        icon: 'document-text-linear',
        color: const Color(0xFF7A6FE0),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Détail de l’analyse', style: AppText.bodyStrong),
          const SizedBox(height: 14),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 13),
            _ScoreRow(data: rows[i], delayMs: 90 * i),
          ],
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
  final String icon;
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
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          child: AppIcon(data.icon, size: 15, color: data.color),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 86,
          child: Text(
            data.label,
            style: AppText.label.copyWith(fontSize: 12.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: (data.value / 100).clamp(0.0, 1.0),
            ),
            duration: Duration(milliseconds: 800 + delayMs),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(data.color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 36,
          child: Text(
            '${data.value.round()} %',
            textAlign: TextAlign.right,
            style: AppText.tiny.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _VerifiedNotice extends StatelessWidget {
  const _VerifiedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.foundSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.found.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const AppIcon(
              'verified-check-bold',
              size: 22,
              color: AppColors.mintDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.verifiedNoticeTitle,
                  style: AppText.bodyStrong.copyWith(color: AppColors.mintDark),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.verifiedNoticeBody,
                  style: AppText.caption.copyWith(
                    color: AppColors.mintDark.withValues(alpha: 0.8),
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

class _WaitingOwnerNotice extends StatelessWidget {
  const _WaitingOwnerNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const AppIcon(
              'lock-keyhole-linear',
              size: 21,
              color: Color(0xFF9A6414),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.waitingOwnerTitle,
                  style: AppText.bodyStrong.copyWith(
                    color: const Color(0xFF7A4F0E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.waitingOwnerBody,
                  style: AppText.caption.copyWith(
                    color: const Color(0xFF7A4F0E),
                    height: 1.35,
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

class _VerificationCard extends ConsumerStatefulWidget {
  const _VerificationCard({required this.match});

  final ItemMatch match;

  @override
  ConsumerState<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends ConsumerState<_VerificationCard> {
  String? _choice;
  bool _loading = false;
  String? _message;
  String? _error;

  Future<void> _submit() async {
    final choice = _choice;
    if (choice == null || _loading) return;

    setState(() {
      _loading = true;
      _message = null;
      _error = null;
    });

    try {
      final ok = await ref
          .read(verificationProvider.notifier)
          .submit(matchId: widget.match.id, answer: choice);
      if (!mounted) return;

      if (ok) {
        ref.invalidate(matchesProvider);
        // La correspondance vient de passer en VERIFIED : il faut recharger
        // le detail pour obtenir can_chat et deverrouiller la messagerie.
        ref.invalidate(matchProvider(widget.match.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Correspondance vérifiée. La messagerie est ouverte.',
            ),
          ),
        );
      } else {
        setState(() {
          _message = choice == 'NON'
              ? AppStrings.answerRecordedNo
              : AppStrings.answerRecordedUnsure;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Impossible d’envoyer la réponse. Vérifiez votre connexion.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
          width: 1.4,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const AppIcon(
                  'shield-check-linear',
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vérification obligatoire', style: AppText.bodyStrong),
                    Text(
                      'Sécurise la mise en relation',
                      style: AppText.tiny.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const AppIcon(
                'lock-keyhole-linear',
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(AppStrings.verificationChoicesTitle, style: AppText.h3),
          const SizedBox(height: 4),
          Text(
            AppStrings.verificationHelp,
            style: AppText.caption.copyWith(height: 1.35),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.verificationQuestionLabel,
                  style: AppText.tiny.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.match.verificationQuestion,
                  style: AppText.body.copyWith(
                    color: AppColors.primaryDark,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ChoiceTile(
            icon: 'check-circle-bold',
            label: AppStrings.verificationYes,
            color: AppColors.found,
            selected: _choice == 'OUI',
            onTap: () => setState(() {
              _choice = 'OUI';
              _message = null;
              _error = null;
            }),
          ),
          const SizedBox(height: 8),
          _ChoiceTile(
            icon: 'question-circle-linear',
            label: AppStrings.verificationUnsure,
            color: AppColors.accent,
            selected: _choice == 'INCERTAIN',
            onTap: () => setState(() {
              _choice = 'INCERTAIN';
              _message = null;
              _error = null;
            }),
          ),
          const SizedBox(height: 8),
          _ChoiceTile(
            icon: 'close-circle-linear',
            label: AppStrings.verificationNo,
            color: AppColors.danger,
            selected: _choice == 'NON',
            onTap: () => setState(() {
              _choice = 'NON';
              _message = null;
              _error = null;
            }),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const AppIcon(
                    'info-circle-linear',
                    size: 16,
                    color: Color(0xFF9A6414),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _message!,
                      style: AppText.caption.copyWith(
                        color: const Color(0xFF7A4F0E),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: AppText.caption.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 14),
          AppButton(
            label: 'Valider ma réponse',
            iconName: 'shield-check-linear',
            loading: _loading,
            onPressed: _choice == null ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.09) : AppColors.input,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? color : AppColors.divider,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            AppIcon(icon, size: 19, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: AppText.label.copyWith(
                  color: selected ? color : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.transparent,
                border: Border.all(
                  color: selected ? color : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon(
            'info-circle-linear',
            size: 19,
            color: AppColors.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.matchHowTitle,
                  style: AppText.label.copyWith(
                    color: AppColors.primaryDark,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppStrings.matchHowBody,
                  style: AppText.tiny.copyWith(
                    color: AppColors.primaryDark,
                    height: 1.45,
                    fontSize: 11,
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

class _DetailBottomBar extends StatelessWidget {
  const _DetailBottomBar({
    required this.match,
    required this.verified,
    required this.onChat,
    required this.onVerify,
  });

  final ItemMatch match;
  final bool verified;
  final VoidCallback onChat;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: AppShadows.nav,
      ),
      child: SafeArea(
        top: false,
        child: verified
            ? match.canChat
                  ? AppButton(
                      label:
                          'Discuter avec ${match.finderName.split(' ').first}',
                      iconName: 'chat-round-linear',
                      variant: AppButtonVariant.success,
                      onPressed: onChat,
                    )
                  : _LockedBar(
                      title: 'Chat verrouillé',
                      subtitle:
                          match.chatLockedReason ??
                          'Votre score de confiance est encore trop bas.',
                    )
            : match.iAmFinder
            ? const _LockedBar()
            : AppButton(
                label: 'Répondre à la vérification',
                iconName: 'shield-check-linear',
                onPressed: onVerify,
              ),
      ),
    );
  }
}

class _LockedBar extends StatelessWidget {
  const _LockedBar({
    this.title = AppStrings.chatLocked,
    this.subtitle = 'En attente du propriétaire',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const AppIcon(
            'lock-keyhole-linear',
            size: 18,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.label.copyWith(fontSize: 13)),
                Text(
                  subtitle,
                  style: AppText.tiny.copyWith(color: AppColors.textTertiary),
                ),
              ],
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: const [
        Row(
          children: [
            SkeletonCircle(size: 44),
            SizedBox(width: 12),
            SkeletonBox(width: 170, height: 18),
          ],
        ),
        SizedBox(height: 22),
        SkeletonBox(height: 286, borderRadius: 28),
        SizedBox(height: 18),
        SkeletonBox(height: 160, borderRadius: 22),
        SizedBox(height: 14),
        SkeletonBox(height: 84, borderRadius: 22),
        SizedBox(height: 14),
        SkeletonBox(height: 180, borderRadius: 22),
      ],
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(
              'danger-triangle-linear',
              size: 40,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text('Impossible de charger', style: AppText.h3),
            const SizedBox(height: 6),
            Text(
              'Vérifiez votre connexion puis réessayez.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Retour',
              expand: false,
              height: 46,
              variant: AppButtonVariant.secondary,
              onPressed: onBack,
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
