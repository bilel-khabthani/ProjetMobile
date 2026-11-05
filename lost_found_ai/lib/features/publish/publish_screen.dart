import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_config.dart';
import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/item.dart';
import '../../data/providers.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/photo_placeholder.dart';
import '../../widgets/pressable_scale.dart';

class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key, this.initialType = ItemType.lost});

  final ItemType initialType;

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  late ItemType _type = widget.initialType;
  ItemCategory? _category;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _secretController = TextEditingController();
  final _placeController = TextEditingController();

  bool _useCurrentPosition = false;
  Position? _currentPosition;
  DateTime _occurredAt = DateTime.now();
  bool _publishing = false;
  bool _published = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _secretController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _category != null &&
      _titleController.text.trim().length >= 3 &&
      _descriptionController.text.trim().length >= 10 &&
      (_placeController.text.trim().length >= 2 || _useCurrentPosition);

  Future<bool> _getCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return true;
      setState(() {
        _currentPosition = position;
        _useCurrentPosition = true;
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggleGps(bool value) async {
    if (!value) {
      setState(() => _useCurrentPosition = false);
      return;
    }
    final ok = await _getCurrentLocation();
    if (!ok && mounted) {
      setState(() => _useCurrentPosition = false);
      _showMessage('Localisation indisponible. Autorisez l’accès puis réessayez.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _pickDay(int daysAgo) {
    final now = DateTime.now();
    setState(() {
      _occurredAt = DateTime(
        now.year,
        now.month,
        now.day - daysAgo,
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (picked == null) return;
    setState(() {
      _occurredAt = DateTime(
        _occurredAt.year,
        _occurredAt.month,
        _occurredAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _publish() async {
    if (!_canSubmit || _publishing) return;
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    setState(() => _publishing = true);

    final place = _placeController.text.trim();
    final useGps = _useCurrentPosition && _currentPosition != null;

    if (!AppConfig.useMockData) {
      try {
        await ref
            .read(repositoryProvider)
            .publishItem(
              type: _type,
              category: _category!,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              secretDetail: _secretController.text.trim(),
              place: place.isNotEmpty
                  ? place
                  : (useGps ? 'Position actuelle' : 'Campus'),
              occurredAt: _occurredAt,
              latitude: useGps ? _currentPosition!.latitude : null,
              longitude: useGps ? _currentPosition!.longitude : null,
            );
        ref.invalidate(myItemsProvider);
        ref.invalidate(matchesProvider);
        ref.invalidate(nearbyFoundProvider);
      } catch (_) {
        if (mounted) {
          _showMessage(
            'Publication hors ligne : l’annonce sera synchronisée plus tard.',
          );
        }
      }
    } else {
      ref.invalidate(myItemsProvider);
      ref.invalidate(matchesProvider);
    }

    if (!mounted) return;
    setState(() {
      _publishing = false;
      _published = true;
    });
  }

  void _reset() {
    setState(() {
      _published = false;
      _category = null;
      _titleController.clear();
      _descriptionController.clear();
      _secretController.clear();
      _placeController.clear();
      _useCurrentPosition = false;
      _occurredAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_published) {
      return _PublishSuccess(
        type: _type,
        onHome: () => context.go(AppRoutes.home),
        onMatches: () => context.go(AppRoutes.messages),
        onAgain: _reset,
      );
    }

    final accent = _type == ItemType.lost ? AppColors.lost : AppColors.found;
    final accentSoft =
        _type == ItemType.lost ? AppColors.lostSoft : AppColors.foundSoft;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _PublishBottomBar(
        enabled: _canSubmit,
        loading: _publishing,
        type: _type,
        onPressed: _publish,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          children: [
            Row(
              children: [
                _CircleClose(onTap: () => context.pop()),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: accentSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _type == ItemType.lost ? 'Objet perdu' : 'Objet trouvé',
                        style: AppText.tiny.copyWith(
                          color: Color.lerp(accent, AppColors.textPrimary, 0.3),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'NOUVELLE ANNONCE',
              style: AppText.eyebrow.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            Text(AppStrings.publishTitle, style: AppText.h1),
            const SizedBox(height: 4),
            Text(
              AppStrings.publishSubtitle,
              style: AppText.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            _TypeSelector(
              value: _type,
              onChanged: (value) => setState(() => _type = value),
            ),
            const SizedBox(height: 20),
            ItemArtwork(
              category: _category ?? ItemCategory.other,
              height: 168,
              width: double.infinity,
              borderRadius: 24,
              showLabel: _category != null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const AppIcon(
                  'camera-linear',
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Visuel de démonstration · l’ajout de photos arrive bientôt.',
                    style: AppText.tiny.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text('Catégorie', style: AppText.label),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in ItemCategory.values)
                  _CategoryChip(
                    category: category,
                    selected: _category == category,
                    onTap: () => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _LabeledField(
              label: AppStrings.fieldTitle,
              child: TextField(
                controller: _titleController,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLength: 120,
                style: AppText.body,
                decoration: InputDecoration(
                  hintText: AppStrings.fieldTitleHint,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 14),
            _LabeledField(
              label: 'Description',
              child: TextField(
                controller: _descriptionController,
                onChanged: (_) => setState(() {}),
                minLines: 3,
                maxLines: 6,
                maxLength: 600,
                textCapitalization: TextCapitalization.sentences,
                style: AppText.body,
                decoration: InputDecoration(
                  hintText:
                      'Couleur, marque, signes particuliers, contenu…',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 14),
            _SecretField(controller: _secretController),
            const SizedBox(height: 14),
            _LabeledField(
              label: AppStrings.fieldPlace,
              child: TextField(
                controller: _placeController,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.sentences,
                style: AppText.body,
                maxLength: 160,
                decoration: InputDecoration(
                  hintText: AppStrings.fieldPlaceHint,
                  counterText: '',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 12, right: 8),
                    child: AppIcon(
                      'map-point-linear',
                      size: 19,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _GpsCard(
              active: _useCurrentPosition,
              onChanged: _toggleGps,
            ),
            const SizedBox(height: 20),
            Text('Quand ?', style: AppText.label),
            const SizedBox(height: 10),
            Row(
              children: [
                _DayChip(
                  label: 'Aujourd’hui',
                  selected: _isSameDay(_occurredAt, DateTime.now()),
                  onTap: () => _pickDay(0),
                ),
                const SizedBox(width: 8),
                _DayChip(
                  label: 'Hier',
                  selected: _isSameDay(
                    _occurredAt,
                    DateTime.now().subtract(const Duration(days: 1)),
                  ),
                  onTap: () => _pickDay(1),
                ),
                const SizedBox(width: 8),
                _DayChip(
                  label: 'Avant-hier',
                  selected: _isSameDay(
                    _occurredAt,
                    DateTime.now().subtract(const Duration(days: 2)),
                  ),
                  onTap: () => _pickDay(2),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PickerButton(
                    icon: 'calendar-linear',
                    label: _formatDate(_occurredAt),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerButton(
                    icon: 'clock-circle-linear',
                    label: _formatTime(_occurredAt),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _formatDate(DateTime date) {
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

class _CircleClose extends StatelessWidget {
  const _CircleClose({required this.onTap});

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
        child: const AppIcon(
          'close-circle-linear',
          size: 21,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.value, required this.onChanged});

  final ItemType value;
  final ValueChanged<ItemType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypeOption(
              label: AppStrings.actionLostTitle,
              icon: 'magnifer-linear',
              selected: value == ItemType.lost,
              color: AppColors.lost,
              background: AppColors.lostSoft,
              onTap: () => onChanged(ItemType.lost),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _TypeOption(
              label: AppStrings.actionFoundTitle,
              icon: 'hand-heart-linear',
              selected: value == ItemType.found,
              color: AppColors.found,
              background: AppColors.foundSoft,
              onTap: () => onChanged(ItemType.found),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool selected;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? background : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(
              icon,
              size: 17,
              color: selected ? color : AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label.copyWith(
                  color: selected ? color : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ItemCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              categoryIconName(category),
              size: 16,
              color: selected ? color : AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              category.label,
              style: AppText.label.copyWith(
                color: selected ? color : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _SecretField extends StatelessWidget {
  const _SecretField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.foundSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.found.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const AppIcon(
                  'lock-keyhole-linear',
                  size: 16,
                  color: AppColors.mintDark,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  AppStrings.fieldSecret,
                  style: AppText.bodyStrong.copyWith(color: AppColors.mintDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'Privé',
                  style: AppText.tiny.copyWith(
                    color: AppColors.mintDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 2,
            maxLength: 300,
            style: AppText.body.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: AppStrings.fieldSecretHint,
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.found.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.mintDark,
                  width: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.fieldSecretHelp,
            style: AppText.tiny.copyWith(
              color: AppColors.mintDark.withValues(alpha: 0.75),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _GpsCard extends StatelessWidget {
  const _GpsCard({required this.active, required this.onChanged});

  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.border,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: active ? AppColors.primarySoft : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(11),
            ),
            child: AppIcon(
              'map-point-linear',
              size: 17,
              color: active ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Utiliser ma position',
                  style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                ),
                Text(
                  active ? 'Position partagée' : 'Optionnel · plus précis',
                  style: AppText.tiny.copyWith(
                    color: active ? AppColors.primary : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: active,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primarySoft,
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.tiny.copyWith(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            AppIcon(icon, size: 17, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: AppText.label.copyWith(fontSize: 12.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishBottomBar extends StatelessWidget {
  const _PublishBottomBar({
    required this.enabled,
    required this.loading,
    required this.type,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final ItemType type;
  final VoidCallback onPressed;

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
        child: AppButton(
          label: type == ItemType.lost
              ? 'Lancer la recherche'
              : 'Publier l’objet trouvé',
          iconName: type == ItemType.lost
              ? 'magnifer-linear'
              : 'hand-heart-linear',
          loading: loading,
          onPressed: enabled ? onPressed : null,
        ),
      ),
    );
  }
}

class _PublishSuccess extends StatelessWidget {
  const _PublishSuccess({
    required this.type,
    required this.onHome,
    required this.onMatches,
    required this.onAgain,
  });

  final ItemType type;
  final VoidCallback onHome;
  final VoidCallback onMatches;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final accent = type == ItemType.lost ? AppColors.lost : AppColors.found;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const AppIcon(
                      'check-circle-bold',
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                type == ItemType.lost
                    ? 'Votre recherche est lancée'
                    : 'Merci pour votre geste',
                style: AppText.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                type == ItemType.lost
                    ? 'Notre moteur analyse les objets trouvés et vous préviendra dès qu’une correspondance apparaît.'
                    : 'Votre annonce est en ligne. Le propriétaire pourra la retrouver et la vérifier.',
                style: AppText.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              AppButton(
                label: 'Voir mes correspondances',
                iconName: 'link-round-linear',
                onPressed: onMatches,
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Retour à l’accueil',
                variant: AppButtonVariant.secondary,
                onPressed: onHome,
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: onAgain,
                child: Text(
                  'Publier une autre annonce',
                  style: AppText.label.copyWith(color: AppColors.textSecondary),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
