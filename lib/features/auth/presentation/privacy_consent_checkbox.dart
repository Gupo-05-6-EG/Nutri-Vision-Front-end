import 'package:flutter/material.dart';

/// Consentimento explícito exigido para criar uma conta com dados de saúde.
class PrivacyConsentCheckboxField extends FormField<bool> {
  PrivacyConsentCheckboxField({super.key})
      : super(
          initialValue: false,
          validator: (value) => value == true
              ? null
              : 'É necessário consentir com o tratamento dos dados de saúde.',
          builder: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                value: state.value ?? false,
                onChanged: state.didChange,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Consinto com o tratamento dos meus dados pessoais e de '
                  'saúde para oferecer os recursos nutricionais do app.',
                ),
                subtitle: const Text(
                  'Você pode consultar, revogar, exportar ou excluir seus '
                  'dados nas configurações de privacidade.',
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => showDialog<void>(
                    context: state.context,
                    builder: (context) => AlertDialog(
                      title: const Text('Consentimento e privacidade'),
                      content: const SingleChildScrollView(
                        child: Text(
                          'O Nutri Vision utiliza dados de cadastro e dados '
                          'de saúde informados por você para fornecer '
                          'acompanhamento nutricional, metas e recursos '
                          'relacionados. Se você optar por se vincular a um '
                          'nutricionista, os dados necessários ao '
                          'acompanhamento poderão ser compartilhados com '
                          'esse profissional.\n\n'
                          'Ao marcar a opção, seu consentimento explícito '
                          'será registrado com a versão do aviso e a data. '
                          'Nas configurações do app você poderá consultar o '
                          'histórico, revogar o consentimento, exportar seus '
                          'dados ou excluir sua conta.',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Fechar'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Saiba como seus dados são utilizados'),
                ),
              ),
              if (state.hasError)
                Text(
                  state.errorText!,
                  style: TextStyle(
                    color: Theme.of(state.context).colorScheme.error,
                  ),
                ),
            ],
          ),
        );
}
