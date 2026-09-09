/// Authentication credentials returned by the backend.
///
/// Mage's FastAPI authentication endpoint returns three values:
///
/// - access_token: short-lived credential used for authenticated API calls.
/// - refresh_token: longer-lived credential used to obtain a new access token.
/// - token_type: describes the authentication scheme used with the token.
///
/// This model represents that API contract on the Flutter side.
///
/// The model does NOT decide:
/// - where tokens are stored,
/// - when tokens are refreshed,
/// - how tokens are attached to requests.
///
/// Those responsibilities belong to the storage and networking layers.
class AuthTokens {
  /// Creates an authentication-token response.
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  /// Short-lived token used to authenticate normal API requests.
  final String accessToken;

  /// Longer-lived token used to obtain a new access token.
  final String refreshToken;

  /// Authentication scheme returned by the backend.
  ///
  /// Mage's backend currently returns `bearer`.
  ///
  /// The value is kept in the model rather than hard-coded into every
  /// networking operation because it is part of the backend response
  /// contract.
  final String tokenType;

  /// Creates an AuthTokens object from a decoded JSON response.
  ///
  /// Mage's FastAPI endpoint returns JSON using snake_case field names:
  ///
  ///     access_token
  ///     refresh_token
  ///     token_type
  ///
  /// Dart conventionally uses camelCase for fields, so this factory performs
  /// the translation at the API boundary.
  ///
  /// This means the rest of our Flutter application can work with:
  ///
  ///     tokens.accessToken
  ///
  /// rather than repeatedly accessing raw JSON maps.
  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String,
    );
  }

  /// Converts the authentication response back into JSON.
  ///
  /// This mirrors the backend's naming convention and is useful for
  /// serialization, testing, or other infrastructure code that needs the
  /// API representation.
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
    };
  }
}
