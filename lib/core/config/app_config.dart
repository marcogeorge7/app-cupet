class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://cupet.semantik-code.com/api/v1',
  );

  // Realtime config (socket-hub URL + connection token) is fetched at runtime
  // from the backend's GET /socket/token endpoint, so nothing is hardcoded here.
}
