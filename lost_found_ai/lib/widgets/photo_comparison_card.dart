import 'package:flutter/material.dart';

import '../core/ai/photo_similarity.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../data/models/item.dart';
import 'item_photo.dart';

/// Compare deux photos d'annonces sur l'appareil (dHash + histogramme) et
/// affiche le score obtenu.
///
/// Ne leve jamais : sans photos exploitables, la carte indique simplement que
/// la comparaison est indisponible et le texte reste utilisable.
class PhotoComparisonCard extends StatefulWidget {
  const PhotoComparisonCard({
    super.key,
    required this.leftUrl,
    required this.rightUrl,
    required this.leftCategory,
    required this.rightCategory,
    this.leftLabel = 'Votre annonce',
    this.rightLabel = 'Annonce trouvée',
    this.title = 'Comparaison des photos',
  });

  final String? leftUrl;
  final String? rightUrl;
  final ItemCategory leftCategory;
  final ItemCategory rightCategory;
  final String leftLabel;
  final String rightLabel;
  final String title;

  @override
  State<PhotoComparisonCard> createState() => _PhotoComparisonCardState();
}

class _PhotoComparisonCardState extends State<PhotoComparisonCard> {
  final PhotoSimilarityEngine _engine = PhotoSimilarityEngine();
  PhotoSimilarity? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _compare();
  }

  @override
  void didUpdateWidget(covariant PhotoComparisonCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leftUrl != widget.leftUrl ||
        oldWidget.rightUrl != widget.rightUrl) {
      _compare();
    }
  }

  Future<void> _compare() async {
    setState(() => _loading = true);
    final result = await _engine.compare(
      leftUrl: widget.leftUrl,
      rightUrl: widget.rightUrl,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.compare_arrows_rounded,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(widget.title, style: AppText.h3)),
              if (_loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (result != null && result.available)
                Text(
                  '${result.score}/100',
                  style: AppText.label.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _PhotoTile(
                  url: widget.leftUrl,
                  category: widget.leftCategory,
                  label: widget.leftLabel,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
              Expanded(
                child: _PhotoTile(
                  url: widget.rightUrl,
                  category: widget.rightCategory,
                  label: widget.rightLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!_loading && result != null) ...[
            Text(
              result.available
                  ? result.label
                  : (result.message ?? 'Photos non comparables.'),
              style: AppText.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            if (result.available) ...[
              const SizedBox(height: AppSpacing.xs),
              _ScoreBar(label: 'Forme', value: result.shapeScore),
              _ScoreBar(label: 'Couleurs', value: result.colorScore),
            ],
          ],
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.url,
    required this.category,
    required this.label,
  });

  final String? url;
  final ItemCategory category;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ItemPhoto(
          imageUrl: url,
          category: category,
          height: 92,
          borderRadius: AppRadius.md,
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: AppText.caption.copyWith(fontSize: 10),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: AppText.caption.copyWith(fontSize: 10),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 5,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 24,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: AppText.caption.copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
