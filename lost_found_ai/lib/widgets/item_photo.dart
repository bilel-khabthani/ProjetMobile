import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../data/models/item.dart';
import 'photo_placeholder.dart';

/// Photo d'annonce renvoyee par l'API, avec repli sur le visuel de categorie.
///
/// L'URL est deja resolue par [resolveItemImageUrl] cote modele : on utilise
/// ici `Image.network`, avec un placeholder pendant le chargement et un retour
/// au visuel de categorie si la photo est absente ou illisible.
class ItemPhoto extends StatelessWidget {
  const ItemPhoto({
    super.key,
    required this.imageUrl,
    required this.category,
    this.size,
    this.width,
    this.height,
    this.borderRadius = AppRadius.md,
    this.showLabel = false,
  });

  final String? imageUrl;
  final ItemCategory category;

  /// Cote d'une photo carree (raccourci pour width + height).
  final double? size;

  final double? width;
  final double? height;
  final double borderRadius;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final side = size ?? width ?? height;

    if (url.isEmpty) {
      return PhotoPlaceholder(
        category: category,
        size: side,
        borderRadius: borderRadius,
        showLabel: showLabel,
      );
    }

    return SizedBox(
      width: width ?? side,
      height: height ?? side,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          url,
          width: width ?? side,
          height: height ?? side,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => PhotoPlaceholder(
            category: category,
            size: side,
            borderRadius: borderRadius,
            showLabel: showLabel,
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return PhotoPlaceholder(
              category: category,
              size: side,
              borderRadius: borderRadius,
              showLabel: showLabel,
            );
          },
        ),
      ),
    );
  }
}
