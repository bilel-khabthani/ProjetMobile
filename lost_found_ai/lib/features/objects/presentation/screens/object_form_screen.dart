import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../../core/perceptual_hash.dart';
import '../../../../core/router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/item.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_icon.dart';
import '../../../../widgets/photo_placeholder.dart';
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
  bool _removeImage = false;

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
      final object = await ref.read(
        objectDetailProvider(widget.objectId!).future,
      );
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
      (_type == ItemType.found || _secretController.text.trim().length >= 3) &&
      (_placeController.text.trim().isNotEmpty ||
          (_latitude != null && _longitude != null));

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.photo_camera_rounded,
                  color: sheetContext.colors.primary,
                ),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library_rounded,
                  color: sheetContext.colors.primary,
                ),
                title: const Text('Choisir dans la galerie'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageName = picked.name;
      _removeImage = false;
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
    final result = await context.push<LocationData>(
      AppRoutes.objectsMapSelection,
    );
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
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);

    http.MultipartFile? image;
    String? imageHash;
    if (_imageBytes != null) {
      imageHash = await PerceptualHash.of(_imageBytes!);
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
          type: _type,
          category: _category,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          placeLabel: _placeController.text.trim(),
          occurredAt: _occurredAt,
          latitude: _gpsEnabled ? _latitude : null,
          longitude: _gpsEnabled ? _longitude : null,
          contactPhone: _phoneController.text.trim(),
          secretDetail: _secretController.text.trim(),
          removeImage: _removeImage,
          clearLocation: !_gpsEnabled,
          image: image,
          imageHash: imageHash,
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
          imageHash,
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
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Modifier l\'annonce' : 'Signaler un objet',
          style: context.typography.titleLarge,
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
            Text('Titre', style: context.typography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _titleController,
              maxLength: 120,
              onChanged: (_) => setState(() {}),
              decoration: _decoration('Ex : Sac à dos noir Nike'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Description', style: context.typography.titleMedium),
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
            Text('Catégorie', style: context.typography.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            _buildCategoryGrid(),
            const SizedBox(height: AppSpacing.lg),
            _buildLocationSection(),
            const SizedBox(height: AppSpacing.lg),
            Text('Quand ?', style: context.typography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            _buildDateField(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Téléphone de contact (optionnel)',
              style: context.typography.titleMedium,
            ),
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
    return InputDecoration(hintText: hint, counterText: '');
  }

  Widget _buildTypeSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ItemType>(
        segments: const [
          ButtonSegment<ItemType>(
            value: ItemType.lost,
            icon: Icon(Icons.search_rounded),
            label: Text('Perdu'),
          ),
          ButtonSegment<ItemType>(
            value: ItemType.found,
            icon: Icon(Icons.volunteer_activism_rounded),
            label: Text('Trouvé'),
          ),
        ],
        selected: {_type},
        showSelectedIcon: false,
        multiSelectionEnabled: false,
        style: SegmentedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
        onSelectionChanged: (selection) =>
            setState(() => _type = selection.first),
      ),
    );
  }

  Widget _buildImagePicker() {
    final hasImage =
        _imageBytes != null || (_existingImageUrl != null && !_removeImage);
    return AppCard(
      onTap: _pickImage,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 170,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
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
                        errorBuilder: (_, _, _) =>
                            Center(child: ItemArtwork(category: _category)),
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
                          color: context.colors.inverseSurface.withValues(
                            alpha: 0.7,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcon(
                              'camera-linear',
                              size: 14,
                              color: context.colors.onInverseSurface,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Changer',
                              style: context.typography.labelSmall?.copyWith(
                                color: context.colors.onInverseSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _imageBytes = null;
                            _imageName = null;
                            _existingImageUrl = null;
                            _removeImage = true;
                          });
                        },
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: context.colors.onInverseSurface,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: context.colors.inverseSurface
                              .withValues(alpha: 0.7),
                          minimumSize: const Size(48, 48),
                          shape: const CircleBorder(),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: AppSpacing.huge + 8,
                      height: AppSpacing.huge + 8,
                      decoration: BoxDecoration(
                        color: context.colors.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Center(
                        child: AppIcon(
                          'gallery-linear',
                          size: 26,
                          color: context.colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Ajouter une photo',
                      style: context.typography.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Optionnel — JPG ou PNG',
                      style: context.typography.bodySmall,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSecretField() {
    return AppCard(
      color: context.colors.secondaryContainer,
      showBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                'lock-keyhole-linear',
                size: 16,
                color: context.colors.onSecondaryContainer,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Détail secret de vérification',
                style: context.typography.titleMedium?.copyWith(
                  color: context.colors.onSecondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Visible uniquement par vous. Il servira à prouver que l\'objet vous appartient.',
            style: context.typography.bodySmall?.copyWith(
              color: context.colors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _secretController,
            obscureText: !_showSecret,
            decoration: InputDecoration(
              hintText: 'Ex : étiquette bleue à l\'intérieur',
              suffixIcon: IconButton(
                icon: Icon(
                  _showSecret
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                  color: context.colors.onSecondaryContainer,
                ),
                onPressed: () => setState(() => _showSecret = !_showSecret),
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
        return FilterChip(
          label: Text(category.label),
          avatar: AppIcon(
            categoryIconName(category),
            size: 16,
            color: selected
                ? context.colors.onSecondaryContainer
                : context.colors.onSurfaceVariant,
          ),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => setState(() => _category = category),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 14,
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
            Text('Localisation', style: context.typography.titleMedium),
            Switch(
              value: _gpsEnabled,
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
                      : AppIcon(
                          'map-point-linear',
                          size: 17,
                          color: context.colors.primary,
                        ),
                  label: Text(_locating ? 'Localisation…' : 'Ma position'),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickOnMap,
                  icon: AppIcon(
                    'map-linear',
                    size: 17,
                    color: context.colors.primary,
                  ),
                  label: const Text('Sur la carte'),
                ),
              ),
            ],
          ),
          if (hasCoords) ...[
            const SizedBox(height: 6),
            Text(
              '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
              style: context.typography.bodySmall,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildDateField() {
    return AppCard(
      onTap: _pickDate,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          AppIcon('calendar-linear', size: 18, color: context.colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${_occurredAt.day.toString().padLeft(2, '0')}/'
            '${_occurredAt.month.toString().padLeft(2, '0')}/'
            '${_occurredAt.year} à '
            '${_occurredAt.hour.toString().padLeft(2, '0')}:'
            '${_occurredAt.minute.toString().padLeft(2, '0')}',
            style: context.typography.titleMedium,
          ),
          const Spacer(),
          Icon(
            Icons.chevron_right_rounded,
            color: context.colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
