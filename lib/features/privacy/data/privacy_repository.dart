import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class PrivacyConsent {
  const PrivacyConsent({
    required this.version,
    required this.acceptedAt,
    this.revokedAt,
  });

  final String version;
  final DateTime acceptedAt;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;

  factory PrivacyConsent.fromJson(Map<String, dynamic> json) {
    return PrivacyConsent(
      version: json['versao_termo'] as String,
      acceptedAt: DateTime.parse(json['aceito_em'] as String),
      revokedAt: json['revogado_em'] == null
          ? null
          : DateTime.parse(json['revogado_em'] as String),
    );
  }
}

class PrivacyConsentStatus {
  const PrivacyConsentStatus({
    required this.consents,
    required this.isActive,
  });

  final List<PrivacyConsent> consents;
  final bool isActive;

  factory PrivacyConsentStatus.fromJson(Map<String, dynamic> json) {
    final consents = json['consentimentos'];
    if (consents is! List) {
      throw const ApiException(
        'Resposta inesperada ao consultar o consentimento.',
      );
    }
    return PrivacyConsentStatus(
      consents: consents
          .map(
            (item) => PrivacyConsent.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      isActive: json['consentimento_ativo'] as bool? ?? false,
    );
  }
}

class PrivacyRepository {
  const PrivacyRepository(this._client);

  static const consentVersion = '1.0';
  static const _basePath = '/privacidade';

  final ApiClient _client;

  Future<PrivacyConsentStatus> getConsentStatus() async {
    final result = await _client.get('$_basePath/consentimento');
    if (result is! Map) {
      throw const ApiException(
        'Resposta inesperada ao consultar o consentimento.',
      );
    }
    return PrivacyConsentStatus.fromJson(Map<String, dynamic>.from(result));
  }

  Future<PrivacyConsent> acceptConsent() async {
    final result = await _client.post('$_basePath/consentimento', {
      'versao_termo': consentVersion,
    });
    return PrivacyConsent.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<PrivacyConsent> revokeConsent() async {
    final result = await _client.post('$_basePath/consentimento/revogar', null);
    return PrivacyConsent.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<Map<String, dynamic>> exportData() async {
    final result = await _client.get('$_basePath/dados');
    if (result is! Map) {
      throw const ApiException('Resposta inesperada ao exportar os dados.');
    }
    return Map<String, dynamic>.from(result);
  }

  Future<void> deleteAccount() => _client.delete('$_basePath/conta');
}
