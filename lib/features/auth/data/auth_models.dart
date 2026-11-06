/// Token e id do usuario devolvidos pelo login e pelo cadastro.
class AuthResult {
  const AuthResult({required this.token, required this.userId});

  final String token;
  final int userId;
}

/// Nutricionista com quem o paciente acabou de se vincular.
///
/// O vinculo nasce `pendente` e so vale depois que o paciente aceita.
class LinkedProfessional {
  const LinkedProfessional({
    required this.name,
    this.id,
    this.photoUrl,
    this.status = pendingStatus,
  });

  static const pendingStatus = 'pendente';

  final int? id;
  final String name;
  final String? photoUrl;
  final String status;

  bool get isPending => status == pendingStatus;
}

/// Dados do cadastro do paciente.
///
/// O cadastro em si so aceita nome, e-mail e senha. Os dados corporais do
/// fluxo autonomo seguem para a triagem (ver [triagemJson]).
class PatientSignup {
  const PatientSignup({
    required this.name,
    required this.email,
    required this.password,
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
  });

  final String name;
  final String email;
  final String password;
  final int? age;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final String? activityLevel;

  Map<String, dynamic> toJson() => {
    'nome': name,
    'email': email,
    'senha': password,
  };

  /// Corpo da triagem, ou `null` se o cadastro nao trouxe os dados corporais
  /// (fluxo "Tenho nutricionista").
  Map<String, dynamic>? triagemJson() {
    if (age == null ||
        gender == null ||
        heightCm == null ||
        weightKg == null ||
        activityLevel == null) {
      return null;
    }
    return {
      'peso_kg': weightKg,
      'altura_cm': heightCm,
      'idade': age,
      'genero': gender,
      'nivel_atividade': activityLevel,
    };
  }
}
