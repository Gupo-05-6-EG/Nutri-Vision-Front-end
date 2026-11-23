import 'package:flutter/material.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/auth_error_message.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../data/screening_repository.dart';
import 'calorie_goal_page.dart';
import 'widgets/screening_widgets.dart';
import '../domain/screening.dart';

/// Triagem inicial avulsa (RF14) em 2 passos: dados corporais e nivel de
/// atividade. Usada por quem entrou pelo fluxo "Tenho nutricionista", para
/// refazer a triagem ou quando a triagem do cadastro falhou.
///
/// Ao concluir, troca esta tela pela confirmacao com a meta gerada.
class ScreeningPage extends StatefulWidget {
  const ScreeningPage({
    required this.auth,
    required this.repository,
    this.initial,
    this.notice,
    super.key,
  });

  final AuthController auth;
  final ScreeningRepository repository;

  /// Respostas ja preenchidas (ex.: vindas do cadastro).
  final ScreeningData? initial;

  /// Mensagem exibida no topo ao abrir (ex.: a triagem do cadastro falhou).
  final String? notice;

  @override
  State<ScreeningPage> createState() => _ScreeningPageState();
}

class _ScreeningPageState extends State<ScreeningPage> {
  static const _totalSteps = 2;

  final _formKeys = List.generate(_totalSteps, (_) => GlobalKey<FormState>());
  late final _form = ScreeningFormController(widget.initial);

  int _step = 0;
  bool _loading = false;
  late String? _error = widget.notice;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  bool get _isLast => _step == _totalSteps - 1;

  void _next() {
    if (!_formKeys[_step].currentState!.validate()) return;
    setState(() {
      _step++;
      _error = null;
    });
  }

  void _back() => setState(() {
        _step--;
        _error = null;
      });

  Future<void> _submit() async {
    if (!_formKeys[_step].currentState!.validate()) return;

    final patientId = widget.auth.userId;
    if (patientId == null) {
      setState(() => _error = 'Entre novamente para fazer a triagem.');
      return;
    }

    final data = _form.toData();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final goal = await widget.repository.submit(patientId, data);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CalorieGoalPage(goal: goal, activity: data.activity),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = authErrorMessage(
          error,
          notFound: 'Não encontramos seu cadastro. Entre novamente.',
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0 && !_loading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _step > 0 && !_loading) _back();
      },
      child: AuthScaffold(
        title: 'Triagem',
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
            child: _step == 0
                ? BodyDataStep(form: _form)
                : ActivityLevelStep(form: _form),
          ),
          const SizedBox(height: 32),
          ScreeningPrimaryButton(
            label: _isLast ? 'Calcular minha meta' : 'Continuar',
            loading: _loading,
            onPressed: _isLast ? _submit : _next,
          ),
        ],
      ),
    );
  }
}
