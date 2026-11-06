import 'dart:convert';

/// Utilitarios para ler o JWT guardado no aparelho.
///
/// Nao valida assinatura (isso e papel do back-end): serve apenas para saber
/// se o token ja expirou antes de tentar usa-lo.
class JwtUtils {
  const JwtUtils._();

  /// Instante de expiracao (claim `exp`) ou `null` se o token for malformado
  /// ou nao tiver `exp`.
  static DateTime? expiresAt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return null;

      final exp = payload['exp'];
      if (exp is! num) return null;

      return DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }

  /// `true` quando o token tem `exp` e ele ja passou. Sem `exp` nao da para
  /// saber, entao o token vale ate a API responder 401.
  static bool isExpired(String token, {DateTime? now}) {
    final expiresAt = JwtUtils.expiresAt(token);
    if (expiresAt == null) return false;
    return !(now ?? DateTime.now()).isBefore(expiresAt);
  }
}
