import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/api_client.dart';
import '../../data/models/item_match.dart';
import '../../data/providers.dart';
import '../../widgets/agreement_signals.dart';
import '../../widgets/app_button.dart';
import '../../widgets/item_photo.dart';
import '../../widgets/photo_comparison_card.dart';
import '../../widgets/status_pill.dart';

Future<void> showVerificationSheet(BuildContext context, ItemMatch match) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => VerificationSheet(match: match),
  );
}

class VerificationSheet extends ConsumerStatefulWidget {
  const VerificationSheet({super.key, required this.match});

  final ItemMatch match;

  @override
  ConsumerState<VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends ConsumerState<VerificationSheet> {
  final _answerController = TextEditingController();
  VerificationOutcome? _outcome;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      setState(() => _error = 'Écrivez votre réponse avant de valider.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final outcome = await ref
          .read(verificationProvider.notifier)
          .submit(matchId: widget.match.id, answer: answer);

      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _loading = false;
      });

      if (outcome.accepted) {
        // La fiche et la liste doivent refleter le match desormais verifie.
        ref.invalidate(matchProvider(widget.match.id));
        ref.invalidate(matchesProvider);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.userMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Réponse impossible à envoyer. Vérifiez votre connexion.';
      });
    }
  }

  void _retry() {
    setState(() {
      _outcome = null;
      _error = null;
      _answerController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final verification = ref.watch(verificationProvider);
    final verified =
        verification != null &&
        verification.success &&
        verification.matchId == widget.match.id;
    final outcome = _outcome;
    final accepted = verified || (outcome?.accepted ?? false);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: accepted
                ? _SuccessState(
                    match: widget.match,
                    outcome: outcome ?? verification?.outcome,
                  )
                : outcome != null
                    ? _OutcomeState(outcome: outcome, onRetry: _retry)
                    : _QuestionState(
                        match: widget.match,
                        controller: _answerController,
                        loading: _loading,
                        error: _error,
                        onSubmit: _submit,
                        onHint: () {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}

class _QuestionState extends StatelessWidget {
  const _QuestionState({
    required this.match,
    required this.controller,
    required this.loading,
    required this.error,
    required this.onSubmit,
    required this.onHint,
  });

  final ItemMatch match;
  final TextEditingController controller;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    final agreement = match.agreement;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Handle(),
        Row(
          children: [
            ItemPhoto(
              imageUrl: match.foundItemImageUrl,
              category: match.foundItemCategory,
              size: 56,
              borderRadius: AppRadius.md,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.verificationTitle, style: AppText.h2),
                  const SizedBox(height: 2),
                  Text(
                    '${match.foundItemTitle} · trouvé par ${match.finderName}',
                    style: AppText.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(AppStrings.verificationSubtitle, style: AppText.body),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.verificationQuestionLabel,
                style: AppText.caption.copyWith(color: AppColors.primaryDark),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                match.verificationQuestion,
                style: AppText.h3.copyWith(
                  color: AppColors.primaryDark,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (agreement != null) ...[
          const SizedBox(height: AppSpacing.md),
          AgreementSignals(
            score: agreement.score,
            shared: agreement.shared,
            contradictions: agreement.contradictions,
            title: 'Ce que le moteur a compris',
            compact: true,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        PhotoComparisonCard(
          leftUrl: match.myItemImageUrl,
          rightUrl: match.foundItemImageUrl,
          leftCategory: match.myItemCategory,
          rightCategory: match.foundItemCategory,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: controller,
          autofocus: false,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => onHint(),
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: AppStrings.fieldAnswer,
            hintText: AppStrings.fieldAnswerHint,
            errorText: error,
            prefixIcon: const Icon(Icons.edit_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            const Icon(
              Icons.school_outlined,
              size: 15,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(AppStrings.demoHint, style: AppText.caption)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: AppStrings.verify,
          icon: Icons.lock_open_rounded,
          loading: loading,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

class _OutcomeState extends StatelessWidget {
  const _OutcomeState({required this.outcome, required this.onRetry});

  final VerificationOutcome outcome;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final partial = outcome.partial;
    final color = partial ? AppColors.accent : AppColors.danger;
    final icon = partial ? Icons.help_rounded : Icons.cancel_rounded;
    final subtitle = partial
        ? 'Les éléments partagés ne suffisent pas : précisez votre réponse pour confirmer.'
        : 'Votre réponse ne correspond pas au détail enregistré. Réessayez avec plus de précision.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Handle(),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 42, color: color),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          outcome.decision.label,
          style: AppText.h1.copyWith(color: color),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: AppText.body, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        if (outcome.neutral) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.info,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Aucun détail secret n’est enregistré pour cette annonce : '
                    'la réponse reste en sursis tant que le propriétaire n’a pas '
                    'fourni de preuve supplémentaire.',
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('Score de correspondance', style: AppText.label),
                    const Spacer(),
                    Text(
                      '${outcome.score}/100',
                      style: AppText.label.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: outcome.score / 100,
                    minHeight: 7,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          if (outcome.matched.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Éléments reconnus', style: AppText.h3),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final detail in outcome.matched)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.foundSoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      detail,
                      style: AppText.caption.copyWith(
                        color: AppColors.found,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (outcome.contradictions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Contradictions', style: AppText.h3),
            const SizedBox(height: AppSpacing.xs),
            for (final contradiction in outcome.contradictions)
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
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Réessayer',
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.match, this.outcome});

  final ItemMatch match;
  final VerificationOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Handle(),
        const Center(child: _SuccessCheck()),
        const SizedBox(height: AppSpacing.lg),
        Text(
          AppStrings.answerCorrect,
          style: AppText.h1.copyWith(color: AppColors.found),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppStrings.answerCorrectSubtitle,
          style: AppText.body,
          textAlign: TextAlign.center,
        ),
        if (outcome != null && outcome!.matched.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final detail in outcome!.matched)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.foundSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    detail,
                    style: AppText.caption.copyWith(
                      color: AppColors.found,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              Avatar(
                initials: match.finderInitials,
                size: 44,
                color: AppColors.found,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match.finderName, style: AppText.h3),
                    Text(
                      'Propriétaire vérifié · mise en relation débloquée',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.verified_rounded,
                color: AppColors.found,
                size: 22,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: AppStrings.continue_,
          variant: AppButtonVariant.success,
          icon: Icons.chat_bubble_rounded,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _SuccessCheck extends StatefulWidget {
  const _SuccessCheck();

  @override
  State<_SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<_SuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
      child: Container(
        width: 96,
        height: 96,
        decoration: const BoxDecoration(
          color: AppColors.foundSoft,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 50,
          color: AppColors.found,
        ),
      ),
    );
  }
}
