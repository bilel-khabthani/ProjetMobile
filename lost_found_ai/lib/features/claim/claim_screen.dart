import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/pressable_scale.dart';

/// Module 5 - Reclamation (signalement).
///
/// L'ecran permet de deposer une reclamation. Le CDC exige que toute
/// reclamation soit tracee et obtienne une reponse : cet ecran facilite
/// le depot, tout en rappelant le principe de tracabilite.
class ClaimScreen extends StatefulWidget {
  const ClaimScreen({this.matchId, super.key});

  final String? matchId;

  @override
  State<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends State<ClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String? _type;

  static const List<Map<String, String>> _claimTypes = [
    {
      'value': 'OBJET_NON_REMIS',
      'label': 'Objet non remis',
      'icon': 'box-linear',
    },
    {
      'value': 'CONTESTATION_PROPRIETE',
      'label': 'Contestation de propriété',
      'icon': 'flag-linear',
    },
    {
      'value': 'SUSPICION_FRAUDE',
      'label': 'Suspicion de fraude',
      'icon': 'danger-triangle-linear',
    },
    {
      'value': 'COMPORTEMENT_ABUSIF',
      'label': 'Comportement abusif',
      'icon': 'user-linear',
    },
    {
      'value': 'ERREUR_CORRESPONDANCE',
      'label': 'Erreur de correspondance',
      'icon': 'link-round-linear',
    },
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Réclamation envoyée. Vous recevrez une réponse.'),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Row(
                children: [
                  PressableScale(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      }
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const AppIcon(
                        'alt-arrow-left-linear',
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SIGNALEMENT',
                          style: AppText.eyebrow.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Signaler un problème', style: AppText.h2),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.matchId == null
                    ? 'Décrivez la situation. Chaque signalement est tracé et traité par notre équipe.'
                    : 'Ce signalement sera rattaché à cette correspondance.',
                style: AppText.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Text('Motif', style: AppText.bodyStrong),
              const SizedBox(height: 8),
              FormField<String>(
                initialValue: _type,
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Choisissez un motif' : null,
                builder: (field) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: field.hasError
                                ? AppColors.danger
                                : AppColors.divider,
                          ),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < _claimTypes.length; i++) ...[
                              _TypeTile(
                                label: _claimTypes[i]['label']!,
                                icon: _claimTypes[i]['icon']!,
                                selected:
                                    _type == _claimTypes[i]['value'],
                                onTap: () {
                                  final value = _claimTypes[i]['value'];
                                  setState(() => _type = value);
                                  field.didChange(value);
                                },
                              ),
                              if (i != _claimTypes.length - 1)
                                const Divider(
                                  height: 1,
                                  indent: 52,
                                  color: AppColors.divider,
                                ),
                            ],
                          ],
                        ),
                      ),
                      if (field.hasError)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 6, 0, 0),
                          child: Text(
                            field.errorText!,
                            style: AppText.tiny.copyWith(
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Text('Description', style: AppText.bodyStrong),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                minLines: 5,
                maxLines: 7,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().length < 10) {
                    return 'Décrivez brièvement le problème (10 caractères minimum).';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  hintText:
                      'Indiquez les faits, les dates et tout élément utile.',
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.foundSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppIcon(
                      'shield-check-linear',
                      size: 19,
                      color: AppColors.mintDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Toute réclamation est enregistrée, traitée et répondue. '
                        'Aucune sanction n’est appliquée automatiquement.',
                        style: AppText.caption.copyWith(
                          color: AppColors.mintDark,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              AppButton(
                label: 'Envoyer la réclamation',
                iconName: 'flag-linear',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const AppIcon(
                      'check-circle-bold',
                      size: 16,
                      color: Colors.white,
                    )
                  : const AppIcon(
                      'add-circle-bold',
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
            ),
            const SizedBox(width: 12),
            AppIcon(
              icon,
              size: 17,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
