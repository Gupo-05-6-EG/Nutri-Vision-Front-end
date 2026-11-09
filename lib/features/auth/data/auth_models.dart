/// Token e id do usuario devolvidos pelo login e pelo cadastro.
class AuthResult {
  const AuthResult({required this.token, required this.userId});

  final String token;
  final int userId;
}

/// Nutricionista com quem o paciente acabou de se vincular.
class LinkedProfessional {
  const LinkedProfessional({required this.name});

  final String name;
}

/// Dados do cadastro do paciente. A API so aceita nome, e-mail e senha; os
/// dados corporais vao depois, na triagem (`features/screening`, RF14).
class PatientSignup {
  const PatientSignup({
    required this.name,
    required this.email,
    required this.password,
  });

  final String name;
  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
        'nome': name,
        'email': email,
        'senha': password,
      };
}
