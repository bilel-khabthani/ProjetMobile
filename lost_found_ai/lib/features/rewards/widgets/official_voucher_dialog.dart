import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
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
  ConsumerState<OfficialVoucherDialog> createState() => _OfficialVoucherDialogState();
}

class _OfficialVoucherDialogState extends ConsumerState<OfficialVoucherDialog> {
  bool _sendingEmail = false;

  Future<void> _sendToGmail() async {
    final userEmail = ref.read(sessionProvider)?.email;
    if (userEmail == null || userEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune adresse e-mail disponible sur votre compte.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _sendingEmail = true);
    HapticFeedback.lightImpact();

    try {
      final msg = await ref.read(repositoryProvider).sendCouponEmail(
            widget.coupon.id,
            targetEmail: userEmail,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $msg'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupon = widget.coupon;
    final expiresFormatted = '${coupon.expiresAt.day.toString().padLeft(2, '0')}/${coupon.expiresAt.month.toString().padLeft(2, '0')}/${coupon.expiresAt.year}';
    final createdFormatted = '${coupon.createdAt.day.toString().padLeft(2, '0')}/${coupon.createdAt.month.toString().padLeft(2, '0')}/${coupon.createdAt.year}';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête bleu marine "PDF Document Officiel"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BON OFFICIEL CERTIFIÉ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            'Généré par Dompdf Engine (PDF)',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            '🏛️ CAMPUS UNIVERSITAIRE — LOST&FOUND AI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          coupon.title,
                          textAlign: TextAlign.center,
                          style: AppText.h3.copyWith(fontSize: 16),
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
                          AppColors.primary.withValues(alpha: 0.08),
                          AppColors.accent.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          coupon.partnerName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          coupon.discountText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Code Promo
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                coupon.code,
                                style: const TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: coupon.code));
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Code promo copié !')),
                                  );
                                },
                                child: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
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
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '║▌║▌║█│▌▌│║▌║▌█║▌│▌▌│║▌║▌█',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID VOUCHER : ${coupon.id.length > 12 ? coupon.id.substring(0, 12).toUpperCase() : coupon.id}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
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
                      Text('Émis le : $createdFormatted', style: AppText.caption),
                      Text('Expire le : $expiresFormatted', style: AppText.caption.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (coupon.terms != null && coupon.terms!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '• ${coupon.terms}',
                      style: AppText.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Tampon de conformité
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Certifié conforme & vérifié par Lost&Found AI',
                            style: AppText.caption.copyWith(
                              color: AppColors.success,
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
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.mark_email_read_rounded, size: 18),
                    label: Text(_sendingEmail ? 'Envoi en cours...' : 'Envoyer par e-mail'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEA4335), // Google Red
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

