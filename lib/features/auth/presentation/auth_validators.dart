/// Validacoes dos formularios de login e cadastro.
class AuthValidators {
  const AuthValidators._();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _codePattern = RegExp(r'^\d{6}$');

  static String? name(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Informe seu nome completo.';
    return null;
  }

  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Informe seu e-mail.';
    if (!_emailPattern.hasMatch(text)) return 'E-mail inválido.';
    return null;
  }

  /// Login: so exige preenchimento (a regra de tamanho vale na criacao).
  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Informe sua senha.';
    return null;
  }

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Crie uma senha.';
    if (value.length < 8) return 'A senha deve ter no mínimo 8 caracteres.';
    return null;
  }

  static String? linkCode(String? value) {
    if (!_codePattern.hasMatch((value ?? '').trim())) {
      return 'Digite o código de 6 dígitos.';
    }
    return null;
  }

  static String? age(String? value) {
    final age = int.tryParse((value ?? '').trim());
    if (age == null) return 'Informe sua idade.';
    if (age < 10 || age > 120) return 'Informe uma idade entre 10 e 120 anos.';
    return null;
  }

  static String? height(String? value) {
    final height = int.tryParse((value ?? '').trim());
    if (height == null) return 'Informe sua altura em cm.';
    if (height < 100 || height > 250) {
      return 'Informe uma altura entre 100 e 250 cm.';
    }
    return null;
  }

  static String? weight(String? value) {
    final weight = parseDecimal(value ?? '');
    if (weight == null) return 'Informe seu peso em kg.';
    if (weight < 20 || weight > 250) {
      return 'Informe um peso entre 20 e 250 kg.';
    }
    return null;
  }

  /// Aceita virgula ou ponto como separador decimal.
  static double? parseDecimal(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
}
