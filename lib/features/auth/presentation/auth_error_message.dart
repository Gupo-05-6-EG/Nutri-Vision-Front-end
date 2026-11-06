import 'dart:convert';

import '../../../core/network/api_exception.dart';

/// Traduz um erro da API/rede em texto para o usuario.
///
/// [unauthorized] e [notFound] permitem trocar o texto de 401/404 conforme a
/// tela (ex.: 404 no codigo de vinculo = "codigo invalido").
String authErrorMessage(
  Object error, {
  String unauthorized = 'E-mail ou senha incorretos.',
  String notFound = 'Não encontrado.',
}) {
  if (error is! ApiException) {
    return 'Algo deu errado. Tente novamente.';
  }

  final status = error.statusCode;
  if (status == null) {
    return 'Não foi possível conectar ao servidor. '
        'Verifique sua conexão e tente novamente.';
  }
  if (status == 401) return unauthorized;
  if (status == 404) return notFound;
  if (status == 410) {
    return 'Código expirado. Peça um novo ao seu nutricionista.';
  }
  if (status == 409) {
    return _detail(error.message) ?? 'Este e-mail já está cadastrado.';
  }
  if (status == 400 || status == 422) {
    return _detail(error.message) ??
        'Dados inválidos. Revise os campos e tente novamente.';
  }
  if (status >= 500) {
    return 'O servidor está indisponível no momento. '
        'Tente novamente em instantes.';
  }
  return _detail(error.message) ??
      'Não foi possível concluir. Tente novamente.';
}

/// Le `{"detail": "texto"}` (formato do FastAPI). Detalhes em lista (erros de
/// validacao do Pydantic) nao sao exibidos.
String? _detail(String body) {
  try {
    final data = jsonDecode(body);
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
  } catch (_) {
    // Corpo nao e JSON: usa a mensagem padrao.
  }
  return null;
}
