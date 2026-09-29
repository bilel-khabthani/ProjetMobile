import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/item.dart';
import '../../widgets/app_button.dart';
import '../../widgets/photo_placeholder.dart';
import '../../widgets/pressable_scale.dart';

class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key});

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  final PageController _controller = PageController();
  int _step = 0;

  bool _photoAdded = false;
  ItemCategory? _category;
  final _descriptionController = TextEditingController();
  bool _useCurrentPosition = false;
  bool _publishing = false;
  int _publishPhase = 0;

  @override
  void dispose() {
    _controller.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
    0 => _photoAdded,
    1 => _category != null && _descriptionController.text.trim().length >= 5,
    _ => _useCurrentPosition,
  };

  void _goTo(int step) {
    setState(() => _step = step);
    _controller.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _next() async {
    HapticFeedback.mediumImpact();
    if (_step < 2) {
      _goTo(_step + 1);
      return;
    }
    await _publish();
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _publishPhase = 1);
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    setState(() => _publishPhase = 2);
  }

  @override
  Widget build(BuildContext context) {
    if (_publishing) {
      return _PublishStatusScreen(
        phase: _publishPhase,
        onDone: () {
          setState(() {
            _publishing = false;
            _publishPhase = 0;
            _photoAdded = false;
            _category = null;
            _descriptionController.clear();
            _useCurrentPosition = false;
          });
          _goTo(0);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(AppStrings.stepOf(_step + 1, 3)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(step: _step),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _PhotoStep(
                    added: _photoAdded,
                    onAdd: () => setState(() => _photoAdded = true),
                    onRemove: () => setState(() => _photoAdded = false),
                  ),
                  _DetailsStep(
                    category: _category,
                    descriptionController: _descriptionController,
                    onCategory: (value) => setState(() => _category = value),
                    onDescription: (_) => setState(() {}),
                  ),
                  _PlaceStep(
                    useCurrentPosition: _useCurrentPosition,
                    onTogglePosition: (value) =>
                        setState(() => _useCurrentPosition = value),
                  ),
                ],
              ),
            ),
            _BottomBar(
              step: _step,
              canContinue: _canContinue,
              onContinue: _next,
              onBack: _step == 0 ? null : () => _goTo(_step - 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: List.generate(3, (index) {
          final active = index <= step;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              height: 6,
              margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.h1),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: AppText.body),
          const SizedBox(height: AppSpacing.xl),
          ...children,
        ],
      ),
    );
  }
}

class _PhotoStep extends StatelessWidget {
  const _PhotoStep({
    required this.added,
    required this.onAdd,
    required this.onRemove,
  });

  final bool added;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: AppStrings.stepPhotoTitle,
      subtitle: AppStrings.stepPhotoSubtitle,
      children: [
        PressableScale(
          onTap: onAdd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(
              color: added ? AppColors.primarySoft : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: added ? AppColors.primary : AppColors.border,
                width: 2,
              ),
            ),
            child: added
                ? Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xl - 4),
                          child: const PhotoPlaceholder(
                            category: ItemCategory.bag,
                            showLabel: false,
                          ),
                        ),
                      ),
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: PressableScale(
                          onTap: onRemove,
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surface.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: AppSpacing.md,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.found,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Photo ajoutée',
                                  style: AppText.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.card,
                        ),
                        child: const Icon(
                          Icons.add_a_photo_rounded,
                          size: 32,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        AppStrings.photoDropzone,
                        style: AppText.h3,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(AppStrings.photoHint, style: AppText.caption),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lightbulb_outline_rounded,
              size: 16,
              color: AppColors.accent,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Une photo similaire suffit si vous n’avez plus l’originale.',
                style: AppText.caption,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.category,
    required this.descriptionController,
    required this.onCategory,
    required this.onDescription,
  });

  final ItemCategory? category;
  final TextEditingController descriptionController;
  final ValueChanged<ItemCategory?> onCategory;
  final ValueChanged<String> onDescription;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: AppStrings.stepDetailsTitle,
      subtitle: AppStrings.stepDetailsSubtitle,
      children: [
        Text(AppStrings.fieldCategory, style: AppText.label),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: ItemCategory.values.map((item) {
            final selected = item == category;
            return PressableScale(
              onTap: () => onCategory(selected ? null : item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      categoryIcon(item),
                      size: 17,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: AppText.label.copyWith(
                        color: selected ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(AppStrings.fieldDescription, style: AppText.label),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: descriptionController,
          maxLines: 4,
          onChanged: onDescription,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: AppStrings.fieldDescriptionHint,
          ),
        ),
      ],
    );
  }
}

class _PlaceStep extends StatelessWidget {
  const _PlaceStep({
    required this.useCurrentPosition,
    required this.onTogglePosition,
  });

  final bool useCurrentPosition;
  final ValueChanged<bool> onTogglePosition;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: AppStrings.stepPlaceTitle,
      subtitle: AppStrings.stepPlaceSubtitle,
      children: [
        PressableScale(
          onTap: () => onTogglePosition(!useCurrentPosition),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: useCurrentPosition
                  ? AppColors.primarySoft
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: useCurrentPosition
                    ? AppColors.primary
                    : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: useCurrentPosition
                        ? AppColors.primary
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.my_location_rounded,
                    color: useCurrentPosition
                        ? Colors.white
                        : AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.useCurrentPosition, style: AppText.h3),
                      const SizedBox(height: 2),
                      Text(
                        useCurrentPosition
                            ? 'Bloc A · Position enregistrée'
                            : 'Touchez pour utiliser votre position',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: useCurrentPosition
                      ? const Icon(
                          Icons.check_circle_rounded,
                          key: ValueKey('on'),
                          color: AppColors.primary,
                        )
                      : const Icon(
                          Icons.radio_button_unchecked_rounded,
                          key: ValueKey('off'),
                          color: AppColors.textTertiary,
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: _FakeField(
                icon: Icons.calendar_today_rounded,
                label: AppStrings.fieldDate,
                value: 'Aujourd’hui',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _FakeField(
                icon: Icons.schedule_rounded,
                label: AppStrings.fieldTime,
                value: '10:30',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _QuickChip(label: 'Aujourd’hui', selected: true, onTap: () {}),
            const SizedBox(width: AppSpacing.xs),
            _QuickChip(label: 'Hier', selected: false, onTap: () {}),
            const SizedBox(width: AppSpacing.xs),
            _QuickChip(label: 'Il y a 2 jours', selected: false, onTap: () {}),
          ],
        ),
      ],
    );
  }
}

class _FakeField extends StatelessWidget {
  const _FakeField({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.caption.copyWith(fontSize: 11)),
                Text(
                  value,
                  style: AppText.label.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 14,
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

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppText.caption.copyWith(
            color: selected ? AppColors.primaryDark : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.canContinue,
    required this.onContinue,
    required this.onBack,
  });

  final int step;
  final bool canContinue;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
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
      child: Row(
        children: [
          if (onBack != null) ...[
            SizedBox(
              width: 56,
              child: AppButton(
                label: 'Retour',
                variant: AppButtonVariant.secondary,
                onPressed: onBack,
                height: 56,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: AppButton(
              label: step == 2 ? AppStrings.publish : AppStrings.onboardingNext,
              icon: step == 2
                  ? Icons.check_rounded
                  : Icons.arrow_forward_rounded,
              onPressed: canContinue ? onContinue : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublishStatusScreen extends StatelessWidget {
  const _PublishStatusScreen({required this.phase, required this.onDone});

  final int phase;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    if (phase == 2) return _PublishSuccess(onDone: onDone);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 84,
                height: 84,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                AppStrings.searching,
                style: AppText.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.searchingSubtitle,
                style: AppText.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _SearchStepRow(
                icon: Icons.photo_rounded,
                label: 'Image analysée',
              ),
              const SizedBox(height: AppSpacing.sm),
              const _SearchStepRow(
                icon: Icons.place_rounded,
                label: 'Localisation comparée',
              ),
              const SizedBox(height: AppSpacing.sm),
              const _SearchStepRow(
                icon: Icons.schedule_rounded,
                label: 'Horodatage vérifié',
              ),
              const SizedBox(height: AppSpacing.sm),
              const _SearchStepRow(
                icon: Icons.text_snippet_rounded,
                label: 'Description analysée',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchStepRow extends StatelessWidget {
  const _SearchStepRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.found),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppText.label),
      ],
    );
  }
}

class _PublishSuccess extends StatelessWidget {
  const _PublishSuccess({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _SuccessBadge(),
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppStrings.publishedTitle,
                style: AppText.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.publishedSubtitle,
                style: AppText.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.huge),
              AppButton(label: AppStrings.backHome, onPressed: onDone),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessBadge extends StatefulWidget {
  const _SuccessBadge();

  @override
  State<_SuccessBadge> createState() => _SuccessBadgeState();
}

class _SuccessBadgeState extends State<_SuccessBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
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
        width: 116,
        height: 116,
        decoration: const BoxDecoration(
          color: AppColors.foundSoft,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 60,
          color: AppColors.found,
        ),
      ),
    );
  }
}
