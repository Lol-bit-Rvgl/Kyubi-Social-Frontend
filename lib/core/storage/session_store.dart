import 'dart:convert';

import '../constants/storage_keys.dart';
import '../errors/api_exception.dart';
import 'secure_storage.dart';

/// Contiene el token de acceso actual y operaciones de sesión.
class TokenStorage {
  TokenStorage._();

  static String? _cachedAccessToken;
  static String? _cachedRefreshToken;

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    await SecureStorage.write(StorageKeys.accessToken, accessToken);
    await SecureStorage.write(StorageKeys.refreshToken, refreshToken);
  }

  static Future<String?> accessToken() async {
    if (_cachedAccessToken != null) return _cachedAccessToken;
    _cachedAccessToken = await SecureStorage.read(StorageKeys.accessToken);
    return _cachedAccessToken;
  }

  static Future<String?> refreshToken() async {
    if (_cachedRefreshToken != null) return _cachedRefreshToken;
    _cachedRefreshToken = await SecureStorage.read(StorageKeys.refreshToken);
    return _cachedRefreshToken;
  }

  static Future<void> updateAccessToken(String accessToken) async {
    _cachedAccessToken = accessToken;
    await SecureStorage.write(StorageKeys.accessToken, accessToken);
  }

  static Future<void> clear() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    await SecureStorage.delete(StorageKeys.accessToken);
    await SecureStorage.delete(StorageKeys.refreshToken);
    await SecureStorage.delete(StorageKeys.lastUserJson);
  }
}

/// Persiste el último usuario autenticado para arranque rápido.
class LastUserStorage {
  LastUserStorage._();

  static Future<void> save(Map<String, dynamic> userJson) async {
    await SecureStorage.write(StorageKeys.lastUserJson, jsonEncode(userJson));
  }

  static Future<Map<String, dynamic>?> read() async {
    final raw = await SecureStorage.read(StorageKeys.lastUserJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  static Future<void> clear() async {
    await SecureStorage.delete(StorageKeys.lastUserJson);
  }
}

/// Lanza [ApiException] cuando no hay sesión.
Future<String> requireAccessToken() async {
  final token = await TokenStorage.accessToken();
  if (token == null || token.isEmpty) {
    throw const ApiException(
      message: 'No hay sesión activa',
      type: ApiExceptionType.unauthorized,
      statusCode: 401,
    );
  }
  return token;
}

/// Cache local de conversaciones para mostrar hilos activos
/// mientras se carga desde el backend.
class ConversationsCache {
  ConversationsCache._();

  static Future<void> save(List<dynamic> conversations) async {
    final jsonList = conversations.map((c) => c.toJson()).toList();
    await SecureStorage.write(
      StorageKeys.conversationsCache,
      jsonEncode(jsonList),
    );
  }

  static Future<List<Map<String, dynamic>>> read() async {
    final raw = await SecureStorage.read(StorageKeys.conversationsCache);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } on FormatException {
      // ignore
    }
    return [];
  }

  static Future<void> clear() async {
    await SecureStorage.delete(StorageKeys.conversationsCache);
  }
}
