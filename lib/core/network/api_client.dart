import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Cliente HTTP da API do Nutri Vision.
///
/// O token JWT e injetado em um unico ponto (`authToken`) para que a Task 1.2
/// so precise preencher esse campo depois do login.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  String? authToken;

  Map<String, String> _headers({bool hasBody = false}) => {
        'Accept': 'application/json',
        if (hasBody) 'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) => Uri.parse(
        '$baseUrl$path',
      ).replace(queryParameters: query?.map((k, v) => MapEntry(k, '$v')));

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers()));

  Future<dynamic> post(String path, Object? body) => _send(
        () => _http.post(
          _uri(path),
          headers: _headers(hasBody: true),
          body: jsonEncode(body),
        ),
      );

  Future<dynamic> put(String path, Object? body) => _send(
        () => _http.put(
          _uri(path),
          headers: _headers(hasBody: true),
          body: jsonEncode(body),
        ),
      );

  Future<dynamic> delete(String path) =>
      _send(() => _http.delete(_uri(path), headers: _headers()));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request();
    } catch (error) {
      throw ApiException('Falha de conexao com o servidor: $error');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.statusCode == 204 || response.body.isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    }

    throw ApiException(
      response.body.isEmpty ? 'HTTP ${response.statusCode}' : response.body,
      statusCode: response.statusCode,
    );
  }

  void close() => _http.close();
}
