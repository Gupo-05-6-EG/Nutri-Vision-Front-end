import 'package:flutter/material.dart';

import '../../screening/data/screening_repository.dart';
import '../../screening/presentation/calorie_goal_page.dart';
import '../../screening/presentation/screening_page.dart';
import '../../screening/presentation/widgets/screening_widgets.dart';
import '../application/auth_controller.dart';
import '../data/auth_models.dart';
import 'auth_error_message.dart';
import 'auth_validators.dart';
import 'widgets/auth_widgets.dart';

/// Cadastro autonomo ("Vou seguir sozinho") em 3 passos:
/// 1) dados corporais e 2) nivel de atividade (a triagem, RF14), 3) conta.
///
/// Ao criar a conta, envia a triagem e mostra a meta gerada. Se a triagem
/// falhar, a conta continua criada e o paciente cai na tela de triagem com
/// os dados ja preenchidos para tentar de novo.
class AutonomousSignupPage extends StatefulWidget {
  const AutonomousSignupPage({
    required this.auth,
    required this.screening,
    super.key,
  });

  final AuthController auth;
  final ScreeningRepository screening;

  @override
  State<AutonomousSignupPage> createState() => _AutonomousSignupPageState();
}

class _AutonomousSignupPageState extends State<AutonomousSignupPage> {
  static const _totalSteps = 3;

  static const triagemFailedNotice = 'Sua conta foi criada, mas não '
      'conseguimos calcular sua meta agora. Confira seus dados e tente de novo.';

  final _formKeys = List.generate(_totalSteps, (_) => GlobalKey<FormState>());
  final _screening = ScreeningFormController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  int _step = 0;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _screening.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validateStep() => _formKeys[_step].currentState!.validate();

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

    final data = _screening.toData();
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
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = authErrorMessage(error);
        _loading = false;
      });
      return;
    }

    // Conta criada e sessao aberta: agora a triagem.
    Widget next;
    try {
      final goal = await widget.screening.submit(widget.auth.userId!, data);
      next = CalorieGoalPage(goal: goal, activity: data.activity);
    } catch (_) {
      next = ScreeningPage(
        auth: widget.auth,
        repository: widget.screening,
        initial: data,
        notice: triagemFailedNotice,
      );
    }

    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => next),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == _totalSteps - 1;

    return PopScope(
      canPop: _step == 0 && !_loading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _step > 0 && !_loading) _back();
      },
      child: AuthScaffold(
        title: 'Cadastro',
        alignTop: true,
        children: [
          ScreeningStepHeader(step: _step + 1, total: _totalSteps),
          const SizedBox(height: 24),
          if (_error != null) ...[
            AuthMessageBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          Form(
            key: _formKeys[_step],
            child: switch (_step) {
              0 => BodyDataStep(form: _screening),
              1 => ActivityLevelStep(form: _screening),
              _ => _accountStep(),
            },
          ),
          const SizedBox(height: 32),
          ScreeningPrimaryButton(
            label: isLast ? 'Criar conta' : 'Continuar',
            loading: _loading,
            onPressed: isLast ? _submit : _next,
          ),
        ],
      ),
    );
  }

  Widget _accountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ScreeningHeading(
          title: 'Crie sua conta',
          subtitle: 'Quase lá! Use esses dados para entrar no app.',
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
