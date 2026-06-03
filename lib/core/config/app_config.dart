class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://cupet.semantik-code.com/api/v1',
  );

  // Realtime config (socket-hub URL + connection token) is fetched at runtime
  // from the backend's GET /socket/token endpoint, so nothing is hardcoded here.

  /// Privacy Policy (which also carries the acceptable-use / zero-tolerance
  /// terms). Linked from the login screen's agreement checkbox.
  static const String privacyPolicyUrl = 'https://cupet.net/privacy';
}
