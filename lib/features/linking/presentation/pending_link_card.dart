import 'package:flutter/material.dart';

import '../../../app_services.dart';
import '../../../core/ui/nv_widgets.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/presentation/link_confirmation_page.dart';
import '../../profile/domain/patient_profile.dart';

/// Convite de vínculo ainda não respondido (código resgatado, sem aceite).
///
/// Aparece no Início e no Perfil até o paciente aceitar ou recusar, para o
/// convite não se perder quando ele sai da tela de confirmação do cadastro.
class PendingLinkCard extends StatelessWidget {
  const PendingLinkCard({
    required this.services,
    required this.nutritionist,
    super.key,
  });

  final AppServices services;
  final ProfileNutritionist nutritionist;

  Future<void> _open(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LinkConfirmationPage(
          auth: services.auth,
          professional: LinkedProfessional(
            id: nutritionist.id,
            name: nutritionist.name,
          ),
        ),
      ),
    );
    await services.profile.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crn = nutritionist.crn.isEmpty ? '' : ' (${nutritionist.crn})';
    return NvCard(
      key: const Key('pending-link-card'),
      semanticLabel: 'Convite de vínculo de ${nutritionist.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: const Icon(Icons.medical_services_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Convite de vínculo',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${nutritionist.name}$crn quer acompanhar você '
                      'no Nutri Vision.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          NvButton(
            key: const Key('open-pending-link'),
            label: 'Ver convite',
            icon: Icons.mark_email_unread_outlined,
            onPressed: () => _open(context),
          ),
        ],
      ),
    );
  }
}
