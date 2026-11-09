import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_config.dart';
import '../../core/app_strings.dart';
import '../../core/perceptual_hash.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/item.dart';
import '../../data/providers.dart';
import '../objects/data/models/location_model.dart';
import '../objects/data/providers/objects_providers.dart';
import '../objects/data/services/location_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/photo_placeholder.dart';
import '../../widgets/pressable_scale.dart';

class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({
    super.key,
    this.initialType = ItemType.lost,
    this.itemId,
  });

  final ItemType initialType;

  /// Renseigne par la route `/publish?edit=<id>`. L'edition est desormais
  /// portee par le module objects ; le parametre reste accepte pour ne pas
  /// casser les liens existants.
  final String? itemId;

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  final PageController _controller = PageController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _secretController = TextEditingController();

  int _step = 0;
  late ItemType _type = widget.initialType;
  Uint8List? _imageBytes;
  String? _imageName;
  ItemCategory? _category;
  bool _publishing = false;
  int _publishPhase = 0;
  LatLng? _position;
  String _placeLabel = '';
  bool _locating = false;
  bool _resolvingPlace = false;
  DateTime _occurredAt = DateTime.now();

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
    0 => _imageBytes != null,
    1 =>
      _category != null &&
          _titleController.text.trim().length >= 3 &&
          _descriptionController.text.trim().length >= 10 &&
          (_type == ItemType.found ||
              _secretController.text.trim().length >= 3),
    _ => _position != null,
  };

  void _goTo(int step) {
    setState(() => _step = step);
    _controller.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    if (step == 2 && _position == null) {
      _useCurrentLocation();
    }
  }

  Future<void> _next() async {
    HapticFeedback.mediumImpact();
    if (_step < 2) {
      _goTo(_step + 1);
      return;
    }
    await _publish();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.primary,
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

    try {
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
      });
    } catch (_) {
      _showMessage('Impossible de récupérer la photo.');
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final location = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (location != null) {
        _position = LatLng(location.latitude, location.longitude);
        _placeLabel = location.displayName;
      }
    });
    if (location == null && mounted) {
      _showMessage(
        'Localisation indisponible. Activez le GPS ou touchez la carte.',
      );
    }
  }

  Future<void> _onMapTap(LatLng point) async {
    setState(() {
      _position = point;
      _placeLabel = _formatCoords(point);
      _resolvingPlace = true;
    });
    final resolved = await LocationService.getAddressFromCoordinates(
      point.latitude,
      point.longitude,
    );
    if (!mounted) return;
    setState(() {
      _resolvingPlace = false;
      _placeLabel = resolved?.displayName ?? _formatCoords(point);
    });
  }

  Future<void> _pickOnMapFullScreen() async {
    final result = await context.push<LocationData>(
      AppRoutes.objectsMapSelection,
    );
    if (result == null || !mounted) return;
    setState(() {
      _position = LatLng(result.latitude, result.longitude);
      _placeLabel = result.displayName;
    });
  }

  Future<void> _pickDateTime() async {
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
    if (!mounted) return;
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

  String _formatCoords(LatLng point) =>
      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

  Future<void> _publish() async {
    final imageBytes = _imageBytes;
    final position = _position;

    if (imageBytes == null || position == null) return;

    setState(() {
      _publishing = true;
      _publishPhase = 0;
    });

    try {
      if (!AppConfig.useMockData) {
        final imageHash = await PerceptualHash.of(imageBytes);
        final image = http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: _imageName ?? 'photo.jpg',
        );

        await ref
            .read(objectsRepositoryProvider)
            .createObject(
              type: _type,
              category: _category ?? ItemCategory.other,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              secretDetail: _type == ItemType.lost
                  ? _secretController.text.trim()
                  : null,
              placeLabel: _placeLabel.trim().isEmpty
                  ? 'Position sélectionnée'
                  : _placeLabel.trim(),
              occurredAt: _occurredAt,
              latitude: position.latitude,
              longitude: position.longitude,
              image: image,
              imageHash: imageHash,
            );

        if (!mounted) return;
        ref.invalidate(matchesProvider);
        ref.invalidate(myItemsProvider);
        ref.invalidate(nearbyFoundProvider);
        ref.invalidate(swipeDeckProvider);
        ref.invalidate(allObjectsProvider);
        ref.invalidate(lostObjectsProvider);
        ref.invalidate(foundObjectsProvider);
        ref.invalidate(objectsStatsProvider);
        ref.invalidate(myObjectsProvider);
        ref.invalidate(myObjectsStatsProvider);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }

      if (!mounted) return;
      setState(() => _publishPhase = 1);
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;
      setState(() => _publishPhase = 2);
    } catch (error) {
      if (!mounted) return;
      setState(() => _publishing = false);
      _showMessage('Publication impossible : $error');
    }
  }

  void _finishPublish() {
    setState(() {
      _publishing = false;
      _publishPhase = 0;
      _step = 0;
      _imageBytes = null;
      _imageName = null;
      _category = null;
      _titleController.clear();
      _descriptionController.clear();
      _secretController.clear();
      _position = null;
      _placeLabel = '';
      _occurredAt = DateTime.now();
    });
    if (_controller.hasClients) {
      _controller.jumpToPage(0);
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_publishing) {
      return _PublishStatusScreen(phase: _publishPhase, onDone: _finishPublish);
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
                    imageBytes: _imageBytes,
                    onAdd: _pickImage,
                    onRemove: () => setState(() {
                      _imageBytes = null;
                      _imageName = null;
                    }),
                  ),
                  _DetailsStep(
                    type: _type,
                    category: _category,
                    titleController: _titleController,
                    descriptionController: _descriptionController,
                    secretController: _secretController,
                    onType: (value) => setState(() => _type = value),
                    onCategory: (value) => setState(() => _category = value),
                    onTitle: (_) => setState(() {}),
                    onDescription: (_) => setState(() {}),
                    onSecret: (_) => setState(() {}),
                  ),
                  _PlaceStep(
                    position: _position,
                    placeLabel: _placeLabel,
                    locating: _locating,
                    resolvingPlace: _resolvingPlace,
                    occurredAt: _occurredAt,
                    onMapTap: _onMapTap,
                    onUseCurrentLocation: _useCurrentLocation,
                    onFullScreen: _pickOnMapFullScreen,
                    onPickDateTime: _pickDateTime,
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
    required this.imageBytes,
    required this.onAdd,
    required this.onRemove,
  });

  final Uint8List? imageBytes;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final added = imageBytes != null;

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
            clipBehavior: Clip.antiAlias,
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
                        child: Image.memory(imageBytes!, fit: BoxFit.cover),
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
                'Une photo similaire suffit si vous n\'avez plus l\'originale.',
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
    required this.type,
    required this.category,
    required this.titleController,
    required this.descriptionController,
    required this.secretController,
    required this.onType,
    required this.onCategory,
    required this.onTitle,
    required this.onDescription,
    required this.onSecret,
  });

  final ItemType type;
  final ItemCategory? category;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController secretController;
  final ValueChanged<ItemType> onType;
  final ValueChanged<ItemCategory?> onCategory;
  final ValueChanged<String> onTitle;
  final ValueChanged<String> onDescription;
  final ValueChanged<String> onSecret;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: AppStrings.stepDetailsTitle,
      subtitle: AppStrings.stepDetailsSubtitle,
      children: [
        Row(
          children: [
            Expanded(
              child: _TypeChip(
                label: 'Perdu',
                icon: Icons.search_off_rounded,
                selected: type == ItemType.lost,
                color: AppColors.lost,
                background: AppColors.lostSoft,
                onTap: () => onType(ItemType.lost),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _TypeChip(
                label: 'Trouvé',
                icon: Icons.redeem_rounded,
                selected: type == ItemType.found,
                color: AppColors.found,
                background: AppColors.foundSoft,
                onTap: () => onType(ItemType.found),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Titre', style: AppText.label),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: titleController,
          maxLength: 120,
          onChanged: onTitle,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ex : Sac à dos noir Nike',
            counterText: '',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
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
          maxLength: 600,
          onChanged: onDescription,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: AppStrings.fieldDescriptionHint,
            counterText: '',
          ),
        ),
        if (type == ItemType.lost) ...[
          const SizedBox(height: AppSpacing.xl),
          _SecretDetailField(controller: secretController, onChanged: onSecret),
        ],
      ],
    );
  }
}

class _SecretDetailField extends StatefulWidget {
  const _SecretDetailField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_SecretDetailField> createState() => _SecretDetailFieldState();
}

class _SecretDetailFieldState extends State<_SecretDetailField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
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
              const Icon(
                Icons.lock_outline_rounded,
                size: 17,
                color: AppColors.mintDark,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Détail secret de vérification',
                style: AppText.bodyStrong.copyWith(color: AppColors.mintDark),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Visible uniquement par vous. Il servira à prouver que l’objet vous '
            'appartient lorsqu’une personne publie un objet trouvé correspondant.',
            style: AppText.caption.copyWith(
              color: AppColors.mintDark.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: widget.controller,
            onChanged: widget.onChanged,
            obscureText: !_visible,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Ex : étiquette bleue à l’intérieur',
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              suffixIcon: IconButton(
                icon: Icon(
                  _visible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                  color: AppColors.mintDark,
                ),
                onPressed: () => setState(() => _visible = !_visible),
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
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final String label;
  final IconData icon;
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
            Icon(
              icon,
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

class _PlaceStep extends StatefulWidget {
  const _PlaceStep({
    required this.position,
    required this.placeLabel,
    required this.locating,
    required this.resolvingPlace,
    required this.occurredAt,
    required this.onMapTap,
    required this.onUseCurrentLocation,
    required this.onFullScreen,
    required this.onPickDateTime,
  });

  final LatLng? position;
  final String placeLabel;
  final bool locating;
  final bool resolvingPlace;
  final DateTime occurredAt;
  final ValueChanged<LatLng> onMapTap;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onFullScreen;
  final VoidCallback onPickDateTime;

  @override
  State<_PlaceStep> createState() => _PlaceStepState();
}

class _PlaceStepState extends State<_PlaceStep> {
  static const _fallbackCenter = LatLng(36.8065, 10.1815);

  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant _PlaceStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    final position = widget.position;
    if (position != null && position != oldWidget.position) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(position, 15.5);
        }
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  String _formatCoords(LatLng point) =>
      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

  String _dateTimeLabel(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/${dateTime.year} à $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.position;

    return _StepScaffold(
      title: AppStrings.stepPlaceTitle,
      subtitle: AppStrings.stepPlaceSubtitle,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: SizedBox(
            height: 260,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: position ?? _fallbackCenter,
                    initialZoom: position == null ? 13 : 15.5,
                    onTap: (_, point) => widget.onMapTap(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'fr.campus.lost_found_ai',
                    ),
                    if (position != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: position,
                            width: 48,
                            height: 52,
                            alignment: Alignment.topCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: AppShadows.raised,
                                  ),
                                  child: const Icon(
                                    Icons.place_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  width: 3,
                                  height: 8,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: FloatingActionButton.small(
                    heroTag: 'publish-map-locate',
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primary,
                    onPressed: widget.locating
                        ? null
                        : widget.onUseCurrentLocation,
                    child: widget.locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                  ),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: FloatingActionButton.small(
                    heroTag: 'publish-map-fullscreen',
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primary,
                    onPressed: widget.onFullScreen,
                    child: const Icon(Icons.open_in_full_rounded),
                  ),
                ),
                if (widget.resolvingPlace)
                  Positioned(
                    left: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 6),
                          Text('Recherche de l\'adresse…', style: AppText.tiny),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.place_rounded,
                  size: 19,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emplacement sélectionné',
                      style: AppText.caption.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      position == null
                          ? 'Touchez la carte pour placer le point.'
                          : (widget.placeLabel.isEmpty
                                ? _formatCoords(position)
                                : widget.placeLabel),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Quand ?', style: AppText.label),
        const SizedBox(height: AppSpacing.sm),
        PressableScale(
          onTap: widget.onPickDateTime,
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
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _dateTimeLabel(widget.occurredAt),
                  style: AppText.bodyStrong,
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            const Icon(
              Icons.touch_app_outlined,
              size: 16,
              color: AppColors.accent,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Touchez la carte pour ajuster la position exacte.',
                style: AppText.caption,
              ),
            ),
          ],
        ),
      ],
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
