import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../auth/presentation/auth_validators.dart';
import '../../domain/screening.dart';

/// Estado do formulario de triagem, compartilhado entre os passos (e entre o
/// cadastro autonomo e a tela de triagem avulsa).
class ScreeningFormController {
  ScreeningFormController([ScreeningData? initial])
      : age = TextEditingController(text: initial?.age.toString() ?? ''),
        height = TextEditingController(
          text: initial == null ? '' : _plain(initial.heightCm),
        ),
        weight = TextEditingController(
          text: initial == null ? '' : _plain(initial.weightKg),
        ),
        gender = initial?.gender,
        calcSex = initial?.calcSex,
        activity = initial?.activity;

  final TextEditingController age;
  final TextEditingController height;
  final TextEditingController weight;
  Gender? gender;
  CalcSex? calcSex;
  ActivityLevel? activity;

  static String _plain(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString().replaceAll('.', ',');

  /// Monta os dados ja validados pelos [Form]s dos passos.
  ScreeningData toData() => ScreeningData(
        age: int.parse(age.text.trim()),
        gender: gender!,
        calcSex: gender == Gender.outro ? calcSex : null,
        heightCm: double.parse(height.text.trim()),
        weightKg: AuthValidators.parseDecimal(weight.text)!,
        activity: activity!,
      );

  void dispose() {
    age.dispose();
    height.dispose();
    weight.dispose();
  }
}

/// Cabecalho dos passos: raio + "PASSO 1 DE 3" e o indicador de pontos.
class ScreeningStepHeader extends StatelessWidget {
  const ScreeningStepHeader({
    required this.step,
    required this.total,
    super.key,
  });

  /// Passo atual, comecando em 1.
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Row(
      children: [
        Icon(Icons.bolt, color: primary, size: 22),
        const SizedBox(width: 4),
        Text(
          'PASSO $step DE $total',
          style: theme.textTheme.labelLarge?.copyWith(
            color: primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Semantics(
          label: 'Passo $step de $total',
          child: Row(
            children: [
              for (var i = 1; i <= total; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(left: 6),
                  width: i == step ? 32 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        i == step ? primary : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Titulo e texto de apoio de cada passo.
class ScreeningHeading extends StatelessWidget {
  const ScreeningHeading({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rotulo acima do campo, como no prototipo.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

/// Campo numerico com rotulo em cima, icone e unidade ("anos", "cm", "kg").
class ScreeningNumberField extends StatelessWidget {
  const ScreeningNumberField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.unit,
    required this.icon,
    required this.validator,
    this.decimal = false,
    this.textInputAction = TextInputAction.next,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String unit;
  final IconData icon;
  final String? Function(String?) validator;
  final bool decimal;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        TextFormField(
          controller: controller,
          validator: validator,
          textInputAction: textInputAction,
          keyboardType: decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          inputFormatters: [
            decimal
                ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                : FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            hintText: hint,
            suffixText: unit,
            prefixIcon: Icon(icon, color: scheme.primary),
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 20,
            ),
            border: OutlineInputBorder(borderRadius: radius),
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
          ),
        ),
      ],
    );
  }
}

/// Opcao em forma de "chip" com icone (genero e sexo usado no calculo).
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

/// "Genero Biologico": Masculino / Feminino / Outro. Com "Outro", pede qual
/// sexo biologico usar na equacao, que so tem esses dois conjuntos.
class GenderField extends StatefulWidget {
  const GenderField({required this.form, super.key});

  final ScreeningFormController form;

  @override
  State<GenderField> createState() => _GenderFieldState();
}

class _GenderFieldState extends State<GenderField> {
  @override
  Widget build(BuildContext context) {
    final form = widget.form;

    return FormField<Gender>(
      initialValue: form.gender,
      validator: (_) {
        if (form.gender == null) return 'Selecione uma opção.';
        if (form.gender == Gender.outro && form.calcSex == null) {
          return 'Escolha qual referência usar no cálculo.';
        }
        return null;
      },
      builder: (field) {
        void pickGender(Gender value) {
          setState(() {
            form.gender = value;
            if (value != Gender.outro) form.calcSex = null;
          });
          field.didChange(value);
        }

        void pickSex(CalcSex value) {
          setState(() => form.calcSex = value);
          field.didChange(form.gender);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FieldLabel('Gênero Biológico'),
            Row(
              children: [
                Expanded(
                  child: _OptionTile(
                    label: 'Masculino',
                    icon: Icons.male,
                    selected: form.gender == Gender.masculino,
                    onTap: () => pickGender(Gender.masculino),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OptionTile(
                    label: 'Feminino',
                    icon: Icons.female,
                    selected: form.gender == Gender.feminino,
                    onTap: () => pickGender(Gender.feminino),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OptionTile(
                    label: 'Outro',
                    icon: Icons.people_outline,
                    selected: form.gender == Gender.outro,
                    onTap: () => pickGender(Gender.outro),
                  ),
                ),
              ],
            ),
            if (form.gender == Gender.outro) ...[
              const SizedBox(height: 16),
              Text(
                'A fórmula do cálculo usa referências de sexo biológico. '
                'Qual devemos usar para a sua meta?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _OptionTile(
                      label: 'Masculina',
                      icon: Icons.male,
                      selected: form.calcSex == CalcSex.masculino,
                      onTap: () => pickSex(CalcSex.masculino),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _OptionTile(
                      label: 'Feminina',
                      icon: Icons.female,
                      selected: form.calcSex == CalcSex.feminino,
                      onTap: () => pickSex(CalcSex.feminino),
                    ),
                  ),
                ],
              ),
            ],
            if (field.hasError) _ErrorText(field.errorText!),
          ],
        );
      },
    );
  }
}

/// Passo "Vamos conhecer voce": idade, genero, altura e peso.
class BodyDataStep extends StatelessWidget {
  const BodyDataStep({required this.form, super.key});

  final ScreeningFormController form;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreeningHeading(
          title: 'Vamos conhecer você.',
          subtitle: 'Esses dados nos ajudam a calcular sua energia exata para '
              'o dia a dia.',
        ),
        ScreeningNumberField(
          controller: form.age,
          label: 'Sua Idade',
          hint: '25',
          unit: 'anos',
          icon: Icons.cake_outlined,
          validator: AuthValidators.age,
        ),
        const SizedBox(height: 20),
        GenderField(form: form),
        const SizedBox(height: 20),
        ScreeningNumberField(
          controller: form.height,
          label: 'Sua Altura',
          hint: '175',
          unit: 'cm',
          icon: Icons.height,
          validator: AuthValidators.height,
        ),
        const SizedBox(height: 20),
        ScreeningNumberField(
          controller: form.weight,
          label: 'Peso Atual',
          hint: '70.5',
          unit: 'kg',
          icon: Icons.fitness_center,
          decimal: true,
          textInputAction: TextInputAction.done,
          validator: AuthValidators.weight,
        ),
      ],
    );
  }
}

/// Passo do nivel de atividade fisica.
class ActivityLevelStep extends StatefulWidget {
  const ActivityLevelStep({required this.form, super.key});

  final ScreeningFormController form;

  @override
  State<ActivityLevelStep> createState() => _ActivityLevelStepState();
}

class _ActivityLevelStepState extends State<ActivityLevelStep> {
  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final scheme = Theme.of(context).colorScheme;

    return FormField<ActivityLevel>(
      initialValue: form.activity,
      validator: (_) => form.activity == null ? 'Selecione uma opção.' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreeningHeading(
            title: 'Qual é o seu nível de atividade?',
            subtitle: 'Escolha a opção que mais se parece com a sua rotina.',
          ),
          for (final level in ActivityLevel.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                selected: form.activity == level,
                selectedTileColor: scheme.primaryContainer,
                tileColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: form.activity == level
                        ? scheme.primary
                        : scheme.outlineVariant,
                    width: form.activity == level ? 2 : 1,
                  ),
                ),
                title: Text(level.label),
                subtitle: Text(level.description),
                trailing: form.activity == level
                    ? const Icon(Icons.check_circle)
                    : null,
                onTap: () {
                  setState(() => form.activity = level);
                  field.didChange(level);
                },
              ),
            ),
          if (field.hasError) _ErrorText(field.errorText!),
        ],
      ),
    );
  }
}

/// Botao principal dos passos ("Continuar ->"), com estado de carregamento.
class ScreeningPrimaryButton extends StatelessWidget {
  const ScreeningPrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.showArrow = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: loading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (showArrow) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 20),
                ],
              ],
            ),
    );
  }
}
