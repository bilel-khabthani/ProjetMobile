import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../../core/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/item.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_icon.dart';
import '../../../../widgets/photo_placeholder.dart';
import '../../../../widgets/pressable_scale.dart';
import '../../data/models/location_model.dart';
import '../../data/providers/objects_providers.dart';
import '../../data/services/location_service.dart';

class ObjectFormScreen extends ConsumerStatefulWidget {
  const ObjectFormScreen({
    this.objectId,
    this.initialType = ItemType.lost,
    super.key,
  });

  final String? objectId;
  final ItemType initialType;

  @override
  ConsumerState<ObjectFormScreen> createState() => _ObjectFormScreenState();
}

class _ObjectFormScreenState extends ConsumerState<ObjectFormScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _secretController = TextEditingController();
  final _placeController = TextEditingController();
  final _phoneController = TextEditingController();

  late ItemType _type;
  ItemCategory _category = ItemCategory.bag;
  DateTime _occurredAt = DateTime.now();
  double? _latitude;
  double? _longitude;
  bool _gpsEnabled = true;
  bool _showSecret = false;
  bool _locating = false;
  bool _submitting = false;
  bool _prefilled = false;

  Uint8List? _imageBytes;
  String? _imageName;
  String? _existingImageUrl;

  bool get _isEditing => widget.objectId != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    if (_isEditing) {
      _prefill();
    }
  }

  Future<void> _prefill() async {
    if (_prefilled) return;
    _prefilled = true;
    try {
      final object =
          await ref.read(objectDetailProvider(widget.objectId!).future);
      if (!mounted) return;
      setState(() {
        _type = object.type;
        _category = object.category;
        _titleController.text = object.title;
        _descriptionController.text = object.description;
        _secretController.text = object.secretDetail ?? '';
        _placeController.text = object.placeLabel;
        _phoneController.text = object.contactPhone ?? '';
        _occurredAt = object.occurredAt;
        _latitude = object.latitude;
        _longitude = object.longitude;
        _existingImageUrl = object.imageUrl;
        _gpsEnabled = object.latitude != null && object.longitude != null;
      });
    } catch (_) {
      // Keep the form usable even if the detail could not be loaded.
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _secretController.dispose();
    _placeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting &&
      _titleController.text.trim().isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty &&
      (_placeController.text.trim().isNotEmpty ||
          (_latitude != null && _longitude != null));

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageName = picked.name;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final location = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (location != null) {
        _latitude = location.latitude;
        _longitude = location.longitude;
        if (_placeController.text.trim().isEmpty) {
          _placeController.text = location.displayName;
        }
      }
    });
    if (location == null && mounted) {
      _showMessage('Localisation indisponible. Activez le GPS.');
    }
  }

  Future<void> _pickOnMap() async {
    final result = await context.push<LocationData>(AppRoutes.objectsMapSelection);
    if (result == null || !mounted) return;
    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
      if (result.placeLabel != null && result.placeLabel!.isNotEmpty) {
        _placeController.text = result.placeLabel!;
      }
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _occurredAt.hour,
        time?.minute ?? _occurredAt.minute,
      );
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);

    http.MultipartFile? image;
    if (_imageBytes != null) {
      image = http.MultipartFile.fromBytes(
        'image',
        _imageBytes!,
        filename: _imageName ?? 'photo.jpg',
      );
    }

    final notifier = ref.read(objectFormProvider.notifier);
    try {
      if (_isEditing) {
        final updated = await notifier.updateObject(
          widget.objectId!,
          category: _category,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          placeLabel: _placeController.text.trim(),
          occurredAt: _occurredAt,
          latitude: _gpsEnabled ? _latitude : null,
          longitude: _gpsEnabled ? _longitude : null,
          contactPhone: _phoneController.text.trim(),
          secretDetail: _secretController.text.trim(),
          image: image,
        );
        if (!mounted) return;
        ref.invalidate(objectDetailProvider(widget.objectId!));
        ref.invalidate(myObjectsProvider);
        ref.invalidate(objectsStatsProvider);
        _showMessage('Annonce mise à jour.');
        if (updated != null) {
          context.pushReplacement(AppRoutes.objectDetail(updated.id));
        } else {
          context.pop();
        }
      } else {
        final created = await notifier.createObject(
          _type,
          _category,
          _titleController.text.trim(),
          _descriptionController.text.trim(),
          _placeController.text.trim(),
          _occurredAt,
          _gpsEnabled ? _latitude : null,
          _gpsEnabled ? _longitude : null,
          _phoneController.text.trim(),
          _secretController.text.trim(),
          image,
        );
        if (!mounted) return;
        ref.invalidate(allObjectsProvider);
        ref.invalidate(lostObjectsProvider);
        ref.invalidate(foundObjectsProvider);
        ref.invalidate(objectsStatsProvider);
        ref.invalidate(myObjectsProvider);
        _showMessage('Votre annonce est en ligne.');
        if (created != null) {
          context.pushReplacement(AppRoutes.objectDetail(created.id));
        } else {
          context.pop();
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showMessage('Échec : $error');
      return;
    }
    if (mounted) {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _isEditing ? 'Modifier l\'annonce' : 'Signaler un objet',
          style: AppText.h3,
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.huge,
          ),
          children: [
            _buildTypeSelector(),
            const SizedBox(height: AppSpacing.lg),
            _buildImagePicker(),
            const SizedBox(height: AppSpacing.lg),
            Text('Titre', style: AppText.label),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _titleController,
              maxLength: 120,
              onChanged: (_) => setState(() {}),
              decoration: _decoration('Ex : Sac à dos noir Nike'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Description', style: AppText.label),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 600,
              onChanged: (_) => setState(() {}),
              decoration: _decoration(
                'Décrivez l\'objet, le contexte et tout détail utile.',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildSecretField(),
            const SizedBox(height: AppSpacing.lg),
            Text('Catégorie', style: AppText.label),
            const SizedBox(height: AppSpacing.sm),
            _buildCategoryGrid(),
            const SizedBox(height: AppSpacing.lg),
            _buildLocationSection(),
            const SizedBox(height: AppSpacing.lg),
            Text('Quand ?', style: AppText.label),
            const SizedBox(height: AppSpacing.xs),
            _buildDateField(),
            const SizedBox(height: AppSpacing.lg),
            Text('Téléphone de contact (optionnel)', style: AppText.label),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _decoration('+33 6 00 00 00 00'),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _isEditing ? 'Enregistrer' : 'Publier l\'annonce',
              iconName: _isEditing ? 'check-circle-bold' : 'add-circle-bold',
              loading: _submitting,
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.caption,
      filled: true,
      fillColor: AppColors.surface,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _TypeOption(
            label: 'Perdu',
            iconName: 'magnifer-linear',
            selected: _type == ItemType.lost,
            color: AppColors.lost,
            background: AppColors.lostSoft,
            onTap: () => setState(() => _type = ItemType.lost),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _TypeOption(
            label: 'Trouvé',
            iconName: 'hand-heart-linear',
            selected: _type == ItemType.found,
            color: AppColors.found,
            background: AppColors.foundSoft,
            onTap: () => setState(() => _type = ItemType.found),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    final hasImage = _imageBytes != null || _existingImageUrl != null;
    return PressableScale(
      onTap: _pickImage,
      child: Container(
        height: 170,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  if (_imageBytes != null)
                    Image.memory(_imageBytes!, fit: BoxFit.cover)
                  else
                    Image.network(
                      _existingImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: ItemArtwork(category: _category),
                      ),
                    ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon('camera-linear',
                              size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Changer',
                            style: AppText.tiny.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Center(
                      child: AppIcon('gallery-linear',
                          size: 26, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Ajouter une photo', style: AppText.bodyStrong),
                  const SizedBox(height: 2),
                  Text(
                    'Optionnel — JPG ou PNG',
                    style: AppText.caption,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSecretField() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.mintDark.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon('lock-keyhole-linear',
                  size: 16, color: AppColors.mintDark),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Détail secret de vérification',
                style: AppText.bodyStrong.copyWith(color: AppColors.mintDark),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Visible uniquement par vous. Il servira à prouver que l\'objet vous appartient.',
            style: AppText.caption.copyWith(
              color: AppColors.mintDark.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _secretController,
            obscureText: !_showSecret,
            decoration: InputDecoration(
              hintText: 'Ex : étiquette bleue à l\'intérieur',
              hintStyle: AppText.caption,
              filled: true,
              fillColor: Colors.white,
              suffixIcon: IconButton(
                icon: Icon(
                  _showSecret
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                  color: AppColors.mintDark,
                ),
                onPressed: () => setState(() => _showSecret = !_showSecret),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: ItemCategory.values.map((category) {
        final selected = _category == category;
        final color = categoryColor(category);
        return GestureDetector(
          onTap: () => setState(() => _category = category),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.14)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selected ? color : AppColors.border,
                width: selected ? 1.6 : 1,
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
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLocationSection() {
    final hasCoords = _latitude != null && _longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Localisation', style: AppText.label),
            Switch(
              value: _gpsEnabled,
              activeThumbColor: AppColors.primary,
              onChanged: (value) => setState(() => _gpsEnabled = value),
            ),
          ],
        ),
        TextField(
          controller: _placeController,
          onChanged: (_) => setState(() {}),
          decoration: _decoration('Ex : Bâtiment B, université'),
        ),
        if (_gpsEnabled) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const AppIcon('map-point-linear',
                          size: 17, color: AppColors.primary),
                  label: Text(_locating ? 'Localisation…' : 'Ma position'),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickOnMap,
                  icon: const AppIcon('map-linear',
                      size: 17, color: AppColors.primary),
                  label: const Text('Sur la carte'),
                ),
              ),
            ],
          ),
          if (hasCoords) ...[
            const SizedBox(height: 6),
            Text(
              '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
              style: AppText.tiny,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildDateField() {
    return PressableScale(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const AppIcon('calendar-linear',
                size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${_occurredAt.day.toString().padLeft(2, '0')}/'
              '${_occurredAt.month.toString().padLeft(2, '0')}/'
              '${_occurredAt.year} à '
              '${_occurredAt.hour.toString().padLeft(2, '0')}:'
              '${_occurredAt.minute.toString().padLeft(2, '0')}',
              style: AppText.bodyStrong,
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.iconName,
    required this.selected,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final String label;
  final String iconName;
  final bool selected;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? background : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            AppIcon(
              iconName,
              size: 22,
              color: selected ? color : AppColors.textTertiary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppText.label.copyWith(
                color: selected ? color : AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
