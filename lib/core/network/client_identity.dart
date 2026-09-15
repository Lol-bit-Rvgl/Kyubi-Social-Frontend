import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../storage/secure_storage.dart';

/// Identidad del cliente para metadatos enviados en cada petición.
///
/// - `device_id`: identificador persistente del dispositivo.
/// - `uuid`: identificador aleatorio persistente (fingerprint de la instalación).
/// - `sid`: id de sesión, se regenera al iniciar sesión y se limpia al salir.
/// - `locale`: código de idioma activo.
class ClientIdentity {
  ClientIdentity._();

  static const _deviceIdKey = 'kyubi_device_id';
  static const _uuidKey = 'kyubi_client_uuid';
  static const _sidKey = 'kyubi_session_id';

  static String? _deviceId;
  static String? _uuid;
  static String? _sid;

  static Future<String> deviceId() async {
    final cached = _deviceId;
    if (cached != null) return cached;
    final existing = await SecureStorage.read(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return _deviceId = existing;
    }
    final generated = _randomHex();
    await SecureStorage.write(_deviceIdKey, generated);
    return _deviceId = generated;
  }

  static Future<String> uuid() async {
    final cached = _uuid;
    if (cached != null) return cached;
    final existing = await SecureStorage.read(_uuidKey);
    if (existing != null && existing.isNotEmpty) {
      return _uuid = existing;
    }
    final generated = _randomHex();
    await SecureStorage.write(_uuidKey, generated);
    return _uuid = generated;
  }

  static Future<String> sid() async {
    final cached = _sid;
    if (cached != null) return cached;
    final existing = await SecureStorage.read(_sidKey);
    if (existing != null && existing.isNotEmpty) {
      return _sid = existing;
    }
    final generated = _randomHex();
    await SecureStorage.write(_sidKey, generated);
    return _sid = generated;
  }

  /// Regenera el sid para una nueva sesión (login).
  static Future<void> resetSid() async {
    _sid = null;
    await SecureStorage.delete(_sidKey);
  }

  /// Idioma activo (de `Intl`) o `es` como fallback.
  static String get locale {
    final defaultLocale = Intl.defaultLocale;
    if (defaultLocale != null && defaultLocale.isNotEmpty) {
      return defaultLocale.split('_').first;
    }
    return 'es';
  }

  /// Plataforma del cliente.
  static String get platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static String _randomHex() {
    final rand = Random.secure();
    const hexChars = '0123456789abcdef';
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(hexChars[rand.nextInt(16)]);
    }
    return buffer.toString();
  }
}
