import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/auth_controller.dart';
import '../data/auth_models.dart';
import 'auth_error_message.dart';
import 'auth_validators.dart';
import 'widgets/auth_widgets.dart';

/// Cadastro autonomo ("Vou seguir sozinho") em 3 passos:
/// 1) dados corporais, 2) nivel de atividade, 3) conta.
class AutonomousSignupPage extends StatefulWidget {
  const AutonomousSignupPage({required this.auth, super.key});

  final AuthController auth;

  @override
  State<AutonomousSignupPage> createState() => _AutonomousSignupPageState();
}

class _ActivityOption {
  const _ActivityOption(this.value, this.label, this.description);

  final String value;
  final String label;
  final String description;
}

class _AutonomousSignupPageState extends State<AutonomousSignupPage> {
  static const _totalSteps = 3;

  static const _activityOptions = [
    _ActivityOption('sedentario', 'Sedentário', 'Pouco ou nenhum exercício'),
    _ActivityOption('leve', 'Leve', 'Exercício 1 a 3 dias por semana'),
    _ActivityOption('moderado', 'Moderado', 'Exercício 3 a 5 dias por semana'),
    _ActivityOption('intenso', 'Intenso', 'Exercício 6 a 7 dias por semana'),
  ];

  final _formKeys = List.generate(_totalSteps, (_) => GlobalKey<FormState>());
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  int _step = 0;
  String? _gender;
  String? _activity;
  bool _genderError = false;
  bool _activityError = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validateStep() {
    final formValid = _formKeys[_step].currentState!.validate();
    setState(() {
      _genderError = _step == 0 && _gender == null;
      _activityError = _step == 1 && _activity == null;
    });
    return formValid && !_genderError && !_activityError;
  }

  void _next() {
    if (!_validateStep()) return;
    setState(() => _step++);
  }

  void _back() {
    setState(() {
      _step--;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_validateStep()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.auth.registerPatient(
        PatientSignup(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          age: int.parse(_age.text.trim()),
          gender: _gender,
          heightCm: double.parse(_height.text.trim()),
          weightKg: AuthValidators.parseDecimal(_weight.text),
          activityLevel: _activity,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = authErrorMessage(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _step == _totalSteps - 1;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: AuthScaffold(
        title: 'Cadastro',
        children: [
          Text(
            'PASSO ${_step + 1} DE $_totalSteps',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_step + 1) / _totalSteps,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            AuthMessageBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          Form(
            key: _formKeys[_step],
            child: switch (_step) {
              0 => _bodyStep(theme),
              1 => _activityStep(theme),
              _ => _accountStep(theme),
            },
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: isLast ? 'Criar conta' : 'Continuar',
            loading: _loading,
            onPressed: isLast ? _submit : _next,
          ),
        ],
      ),
    );
  }

  Widget _heading(ThemeData theme, String title, [String? subtitle]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          if (subtitle != null)
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _bodyStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          theme,
          'Vamos conhecer você.',
          'Esses dados nos ajudam a calcular sua energia exata para o dia a '
              'dia.',
        ),
        AuthTextField(
          controller: _age,
          label: 'Sua idade',
          hint: '25',
          suffixText: 'anos',
          icon: Icons.cake_outlined,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: AuthValidators.age,
        ),
        const SizedBox(height: 16),
        Text('Gênero biológico', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'masculino', label: Text('Masculino')),
            ButtonSegment(value: 'feminino', label: Text('Feminino')),
            ButtonSegment(value: 'outro', label: Text('Outro')),
          ],
          selected: _gender == null ? <String>{} : {_gender!},
          onSelectionChanged: (selection) => setState(() {
            _gender = selection.isEmpty ? null : selection.first;
            _genderError = false;
          }),
        ),
        if (_genderError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Selecione uma opção.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: _height,
          label: 'Sua altura',
          hint: '175',
          suffixText: 'cm',
          icon: Icons.height,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: AuthValidators.height,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: _weight,
          label: 'Peso atual',
          hint: '70,5',
          suffixText: 'kg',
          icon: Icons.monitor_weight_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          validator: AuthValidators.weight,
        ),
      ],
    );
  }

  Widget _activityStep(ThemeData theme) {
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          theme,
          'Qual é o seu nível de atividade?',
          'Escolha a opção que mais se parece com a sua rotina.',
        ),
        for (final option in _activityOptions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              selected: _activity == option.value,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _activity == option.value
                      ? scheme.primary
                      : scheme.outlineVariant,
                ),
              ),
              title: Text(option.label),
              subtitle: Text(option.description),
              trailing: _activity == option.value
                  ? const Icon(Icons.check_circle)
                  : null,
              onTap: () => setState(() {
                _activity = option.value;
                _activityError = false;
              }),
            ),
          ),
        if (_activityError)
          Text('Selecione uma opção.', style: TextStyle(color: scheme.error)),
      ],
    );
  }

  Widget _accountStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          theme,
          'Crie sua conta',
          'Quase lá! Use esses dados para entrar no app.',
        ),
        AuthTextField(
          controller: _name,
          label: 'Nome completo',
          icon: Icons.badge_outlined,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          validator: AuthValidators.name,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: _email,
          label: 'E-mail (para login)',
          hint: 'alex.silva@email.com',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: AuthValidators.email,
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: _password,
          label: 'Criar senha',
          hint: 'Mínimo 8 caracteres',
          icon: Icons.lock_outline,
          obscure: true,
          textInputAction: TextInputAction.done,
          validator: AuthValidators.newPassword,
        ),
        const SizedBox(height: 8),
        TermsCheckboxField(),
      ],
    );
  }
}
