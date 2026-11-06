import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda o token JWT entre aberturas do app.
abstract class TokenStorage {
  Future<String?> read();

  Future<void> save(String token);

  Future<void> clear();
}

/// Keystore (Android) / Keychain (iOS) via `flutter_secure_storage`.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      // Armazenamento ilegivel (ex.: backup restaurado no Android): trata como
      // "sem sessao" em vez de travar o boot do app.
      return null;
    }
  }

  @override
  Future<void> save(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Sem token legivel nao ha o que apagar.
    }
  }
}
