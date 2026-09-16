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
  static const String themeColor = 'kyubi_theme_color';
  static const String accentColor = 'kyubi_accent_color';
  static const String cardStyle = 'kyubi_card_style';
  static const String onboardingCompleted = 'kyubi_onboarding_completed';
  static const String languageCode = 'kyubi_language';
}
