/// Claves para el almacenamiento seguro y persistente.
class StorageKeys {
  StorageKeys._();

  // Almacenamiento seguro (tokens).
  static const String accessToken = 'kyubi_access_token';
  static const String refreshToken = 'kyubi_refresh_token';
  static const String lastUserJson = 'kyubi_last_user_json';

  // Conversaciones (caché local).
  static const String conversationsCache = 'kyubi_conversations_cache';

  // Preferencias.
  static const String themeMode = 'kyubi_theme_mode';
  static const String onboardingCompleted = 'kyubi_onboarding_completed';
  static const String languageCode = 'kyubi_language';
}
