import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Moldura comum das telas de autenticacao: AppBar, rolagem e largura maxima.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de texto dos formularios; com [obscure] ganha o botao de ver senha.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.suffixText,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscure = false,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final String? suffixText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscure;
  final String? Function(String?)? validator;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.obscure && _hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixText: widget.suffixText,
        border: const OutlineInputBorder(),
        prefixIcon: widget.icon == null ? null : Icon(widget.icon),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Mostrar senha' : 'Ocultar senha',
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              )
            : null,
      ),
    );
  }
}

/// Botao principal; mostra um indicador de progresso enquanto [loading].
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Text(label),
    );
  }
}

/// Faixa de mensagem: erro (padrao) ou aviso informativo.
class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner({
    required this.message,
    this.isError = true,
    super.key,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background =
        isError ? scheme.errorContainer : scheme.secondaryContainer;
    final foreground =
        isError ? scheme.onErrorContainer : scheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            color: foreground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}

/// Checkbox de aceite dos termos; so passa na validacao do Form se marcado.
class TermsCheckboxField extends FormField<bool> {
  TermsCheckboxField({super.key})
      : super(
          initialValue: false,
          validator: (value) => value == true
              ? null
              : 'Aceite os Termos de Uso e a Política de Privacidade.',
          builder: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                value: state.value ?? false,
                onChanged: state.didChange,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Li e aceito os Termos de Uso e a Política de Privacidade.',
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
