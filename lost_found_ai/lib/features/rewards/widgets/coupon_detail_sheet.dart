import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/reward.dart';
import '../../../data/providers.dart';
import 'official_voucher_dialog.dart';

class CouponDetailSheet extends ConsumerStatefulWidget {
  const CouponDetailSheet({super.key, required this.coupon});

  final UserCoupon coupon;

  static Future<void> show(BuildContext context, UserCoupon coupon) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CouponDetailSheet(coupon: coupon),
    );
  }

  @override
  ConsumerState<CouponDetailSheet> createState() => _CouponDetailSheetState();
}

class _CouponDetailSheetState extends ConsumerState<CouponDetailSheet> {
  bool _sendingEmail = false;
  bool _markingUsed = false;

  void _showEmailDialog() {
    final userEmail = ref.read(sessionProvider)?.email ?? '';
    final emailCtrl = TextEditingController(text: userEmail);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mail_outline_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Envoyer le Bon par E-mail',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Le bon de réduction avec le PDF officiel en pièce jointe sera transmis à cette adresse :',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Adresse e-mail',
                hintText: 'ex: votre-email@gmail.com',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '💡 Astuce : l\'e-mail contient le bon officiel en PDF. En développement, consultez-le dans Mailpit sur http://127.0.0.1:8025',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () {
              final target = emailCtrl.text.trim();
              Navigator.of(ctx).pop();
              _sendEmail(targetEmail: target.isNotEmpty ? target : null);
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmail({String? targetEmail}) async {
    if (!mounted) return;
    setState(() => _sendingEmail = true);
    HapticFeedback.lightImpact();

    try {
      final msg = await ref.read(repositoryProvider).sendCouponEmail(
            widget.coupon.id,
            targetEmail: targetEmail,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
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

  Future<void> _markUsed() async {
    setState(() => _markingUsed = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(repositoryProvider).markCouponUsed(widget.coupon.id);
      ref.invalidate(myCouponsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coupon marqué comme utilisé !'),
          backgroundColor: AppColors.success,
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
      if (mounted) setState(() => _markingUsed = false);
    }
  }

  void _downloadPdf() {
    HapticFeedback.mediumImpact();
    OfficialVoucherDialog.show(context, widget.coupon);
  }

  @override
  Widget build(BuildContext context) {
    final coupon = widget.coupon;
    final isUsed = coupon.status == CouponStatus.used;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Barre de glissement
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // En-tête du Bon
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: AppColors.accent,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coupon.partnerName,
                      style: AppText.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      coupon.discountText,
                      style: AppText.h2.copyWith(fontSize: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Cadre Code Promo & Barcode
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(
                  'CODE DE RÉDUCTION EXCLUSIF',
                  style: AppText.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                  coupon.code,
                  style: AppText.h1.copyWith(
                    fontSize: 26,
                    letterSpacing: 3,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Simulation Code-barres
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '|||| | ||| |||| | ||| |||| | ||| | ||',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'N° ${coupon.id.substring(0, 8).toUpperCase()}',
                        style: AppText.caption.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: coupon.code));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code promo copié !')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copier le code'),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Conditions
          Text(
            '• Valable jusqu\'au ${coupon.expiresAt.day}/${coupon.expiresAt.month}/${coupon.expiresAt.year}',
            style: AppText.caption,
          ),
          if (coupon.terms != null && coupon.terms!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('• ${coupon.terms}', style: AppText.caption),
          ],

          const SizedBox(height: AppSpacing.xl),

          // Boutons d'action Métier Avancé : PDF & Mail
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _downloadPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Bon PDF'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _sendingEmail ? null : _showEmailDialog,
                  icon: _sendingEmail
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.email_rounded),
                  label: Text(_sendingEmail ? 'Envoi...' : 'Par E-mail'),
                ),
              ),
            ],
          ),

          if (!isUsed) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: _markingUsed ? null : _markUsed,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(
                _markingUsed ? 'Validation...' : 'Marquer comme utilisé en caisse / livraison',
                style: AppText.caption.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }
}

