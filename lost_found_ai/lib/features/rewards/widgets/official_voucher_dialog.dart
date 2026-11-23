import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/reward.dart';
import '../../../data/providers.dart';

/// Affichage plein écran du Bon Officiel format PDF dans l'application mobile.
class OfficialVoucherDialog extends ConsumerStatefulWidget {
  const OfficialVoucherDialog({super.key, required this.coupon});

  final UserCoupon coupon;

  static Future<void> show(BuildContext context, UserCoupon coupon) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => OfficialVoucherDialog(coupon: coupon),
    );
  }

  @override
  ConsumerState<OfficialVoucherDialog> createState() =>
      _OfficialVoucherDialogState();
}

class _OfficialVoucherDialogState extends ConsumerState<OfficialVoucherDialog> {
  bool _sendingEmail = false;

  Future<void> _sendToGmail() async {
    final userEmail = ref.read(sessionProvider)?.email;
    if (userEmail == null || userEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Aucune adresse e-mail disponible sur votre compte.',
          ),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    setState(() => _sendingEmail = true);
    HapticFeedback.lightImpact();

    try {
      final msg = await ref
          .read(repositoryProvider)
          .sendCouponEmail(widget.coupon.id, targetEmail: userEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Envoyé : $msg'),
          backgroundColor: context.colors.primary,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: context.colors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupon = widget.coupon;
    final expiresFormatted =
        '${coupon.expiresAt.day.toString().padLeft(2, '0')}/${coupon.expiresAt.month.toString().padLeft(2, '0')}/${coupon.expiresAt.year}';
    final createdFormatted =
        '${coupon.createdAt.day.toString().padLeft(2, '0')}/${coupon.createdAt.month.toString().padLeft(2, '0')}/${coupon.createdAt.year}';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadow.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête bleu marine "PDF Document Officiel"
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.colors.onPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.picture_as_pdf_rounded,
                        color: context.colors.onPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BON OFFICIEL CERTIFIÉ',
                            style: TextStyle(
                              color: context.colors.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            'Généré par Dompdf Engine (PDF)',
                            style: TextStyle(
                              color: context.colors.onPrimary.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: context.colors.onPrimary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Corps du Bon d'achat style "Document A4 / Ticket Officiel"
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sceau Campus & Titre
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.tertiaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              border: Border.all(
                                color: context.colors.tertiary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: Text(
                              'CAMPUS UNIVERSITAIRE — LOST&FOUND AI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: context.colors.tertiary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            coupon.title,
                            textAlign: TextAlign.center,
                            style: context.typography.titleMedium?.copyWith(
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Cadre Partenaire & Remise
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.colors.primary.withValues(alpha: 0.08),
                            context.colors.tertiary.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.colors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            coupon.partnerName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            coupon.discountText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: context.colors.primary,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Code Promo
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: context.colors.outlineVariant,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.shadow.withValues(
                                    alpha: 0.12,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  coupon.code,
                                  style: TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    color: context.colors.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: coupon.code),
                                    );
                                    HapticFeedback.lightImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Code promo copié !'),
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                    color: context.colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Représentation Code-barres & QR
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.colors.outlineVariant,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '║▌║▌║█│▌▌│║▌║▌█║▌│▌▌│║▌║▌█',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID VOUCHER : ${coupon.id.length > 12 ? coupon.id.substring(0, 12).toUpperCase() : coupon.id}',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold,
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Métadonnées & Validité
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Émis le : $createdFormatted',
                          style: context.typography.caption,
                        ),
                        Text(
                          'Expire le : $expiresFormatted',
                          style: context.typography.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (coupon.terms != null && coupon.terms!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '• ${coupon.terms}',
                        style: context.typography.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Tampon de conformité
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.primaryContainer.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: context.colors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: context.colors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Certifié conforme & vérifié par Lost&Found AI',
                              style: context.typography.bodySmall?.copyWith(
                                color: context.colors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Bouton d'action directe : envoyer le bon à l'utilisateur connecté
                    FilledButton.icon(
                      onPressed: _sendingEmail ? null : _sendToGmail,
                      icon: _sendingEmail
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colors.onPrimary,
                              ),
                            )
                          : const Icon(Icons.mark_email_read_rounded, size: 18),
                      label: Text(
                        _sendingEmail
                            ? 'Envoi en cours...'
                            : 'Envoyer par e-mail',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
