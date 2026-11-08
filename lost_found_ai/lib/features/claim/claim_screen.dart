import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

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
    },
    {
      'value': 'CONTESTATION_PROPRIETE',
      'label': 'Contestation de propriete',
    },
    {
      'value': 'SUSPICION_FRAUDE',
      'label': 'Suspicion de fraude',
    },
    {
      'value': 'COMPORTEMENT_ABUSIF',
      'label': 'Comportement abusif',
    },
    {
      'value': 'ERREUR_CORRESPONDANCE',
      'label': 'Erreur de correspondance',
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
        content: Text('Reclamation envoyee. Vous recevrez une reponse.'),
        backgroundColor: AppColors.success,
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un probleme')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Type de reclamation', style: AppText.bodyStrong),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  hintText: 'Selectionnez un motif',
                ),
                validator: (value) =>
                    value == null ? 'Selectionnez un motif' : null,
                items: _claimTypes
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type['value'],
                        child: Text(type['label']!),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _type = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Description', style: AppText.bodyStrong),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 6,
                validator: (value) {
                  if (value == null || value.trim().length < 10) {
                    return 'Decrivez brievement le probleme (10 caracteres minimum).';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  hintText:
                      'Indiquez les faits, les dates et tout element utile.',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  'Toute reclamation est enregistree, traitee et repondue. '
                  'Le systeme n\'applique aucune sanction automatiquement.',
                  style: AppText.caption,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              FilledButton(
                onPressed: _submit,
                child: const Text('Envoyer la reclamation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}