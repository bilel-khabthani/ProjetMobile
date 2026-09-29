import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/item_match.dart';
import '../../data/providers.dart';
import '../../widgets/app_button.dart';
import '../../widgets/photo_placeholder.dart';
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
  bool _loading = false;
  bool _wrong = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _wrong = false;
    });

    final ok = await ref
        .read(verificationProvider.notifier)
        .submit(matchId: widget.match.id, answer: _answerController.text);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _wrong = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final verified =
        ref.watch(verificationProvider)?.success == true &&
        ref.watch(verificationProvider)?.matchId == widget.match.id;

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
            child: verified
                ? _SuccessState(match: widget.match)
                : _QuestionState(
                    match: widget.match,
                    controller: _answerController,
                    loading: _loading,
                    wrong: _wrong,
                    onSubmit: _submit,
                    onHint: () => setState(() => _wrong = false),
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
    required this.wrong,
    required this.onSubmit,
    required this.onHint,
  });

  final ItemMatch match;
  final TextEditingController controller;
  final bool loading;
  final bool wrong;
  final VoidCallback onSubmit;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Handle(),
        Row(
          children: [
            PhotoPlaceholder(
              category: match.foundItemCategory,
              size: 56,
              borderRadius: AppRadius.md,
              showLabel: false,
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
            errorText: wrong ? AppStrings.answerWrong : null,
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

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.match});

  final ItemMatch match;

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
