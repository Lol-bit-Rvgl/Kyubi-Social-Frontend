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
/// mientras se carga desde el backend, aislado por userId.
class ConversationsCache {
  ConversationsCache._();

  static String _key([String? userId]) =>
      userId != null && userId.isNotEmpty
          ? '${StorageKeys.conversationsCache}_$userId'
          : StorageKeys.conversationsCache;

  static Future<void> save(List<dynamic> conversations, {String? userId}) async {
    final jsonList = conversations.map((c) => c.toJson()).toList();
    await SecureStorage.write(
      _key(userId),
      jsonEncode(jsonList),
    );
  }

  static Future<List<Map<String, dynamic>>> read({String? userId}) async {
    final raw = await SecureStorage.read(_key(userId));
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

  static Future<void> clear({String? userId}) async {
    await SecureStorage.delete(_key(userId));
    if (userId != null && userId.isNotEmpty) {
      await SecureStorage.delete(StorageKeys.conversationsCache);
    }
  }
}

/// Cache local de salas aislado por usuario (rooms_cache_${userId}).
class RoomsCache {
  RoomsCache._();

  static String _key([String? userId]) =>
      userId != null && userId.isNotEmpty
          ? 'rooms_cache_$userId'
          : 'rooms_cache_default';

  static Future<void> save(List<dynamic> rooms, {String? userId}) async {
    final jsonList = rooms.map((r) => r.toJson()).toList();
    await SecureStorage.write(
      _key(userId),
      jsonEncode(jsonList),
    );
  }

  static Future<List<Map<String, dynamic>>> read({String? userId}) async {
    final raw = await SecureStorage.read(_key(userId));
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

  static Future<void> clear({String? userId}) async {
    await SecureStorage.delete(_key(userId));
    await SecureStorage.delete('rooms_cache_default');
  }
}

/// Cache local de notificaciones aislado por usuario (notifications_cache_${userId}).
class NotificationsCache {
  NotificationsCache._();

  static String _key([String? userId]) =>
      userId != null && userId.isNotEmpty
          ? 'notifications_cache_$userId'
          : 'notifications_cache_default';

  static Future<void> save(List<dynamic> items, {String? userId}) async {
    final jsonList = items.map((n) => n.toJson()).toList();
    await SecureStorage.write(
      _key(userId),
      jsonEncode(jsonList),
    );
  }

  static Future<List<Map<String, dynamic>>> read({String? userId}) async {
    final raw = await SecureStorage.read(_key(userId));
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

  static Future<void> clear({String? userId}) async {
    await SecureStorage.delete(_key(userId));
    await SecureStorage.delete('notifications_cache_default');
  }
}

