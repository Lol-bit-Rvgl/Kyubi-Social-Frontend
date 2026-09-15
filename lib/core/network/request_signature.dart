import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Firma de peticiones estilo ProjZ (`HJTRFS`).
///
/// Genera una cabecera `X-Signature: HJTRFS <timestamp>.<hmac>` derivada del
/// método, la ruta y un digest del body, para que el servidor pueda validar
/// que la petición no fue manipulada en tránsito.
class RequestSignature {
  RequestSignature._();

  static const String prefix = 'HJTRFS';

  /// Secreto de cliente inyectado en build time:
  ///   `--dart-define=KYUBI_CLIENT_SIGN_SECRET=<valor>`
  /// Nunca se versiona en el repositorio.
  static const String _envSecret = String.fromEnvironment(
    'KYUBI_CLIENT_SIGN_SECRET',
    defaultValue: '',
  );

  /// Secreto de desarrollo local (nunca usado en producción).
  static const String _debugFallbackSecret = 'kyubi-hjtrfs-client-sign-v1';

  /// Hook SOLO para tests: simula `kDebugMode` sin tocar el modo de compilación.
  /// `null` == usar `kDebugMode` real; `true/false` fuerza el modo de debug.
  @visibleForTesting
  static bool? debugForTest;

  static bool get _isDebug => debugForTest ?? kDebugMode;

  /// Secreto efectivo si la configuración es válida, o `null` en release sin
  /// `--dart-define=KYUBI_CLIENT_SIGN_SECRET`. Usar en `main()` para fail-fast.
  static String? get secretOrNull {
    if (_envSecret.isNotEmpty) return _envSecret;
    if (_isDebug) return _debugFallbackSecret;
    return null;
  }

  /// Secreto efectivo. En debug permite un fallback local; en release, si la
  /// variable de entorno está vacía, lanza (config inválida — validar en main).
  static String get _secret {
    final secret = secretOrNull;
    if (secret != null) return secret;
    throw StateError(
      'KYUBI_CLIENT_SIGN_SECRET no está definida. '
      'Compila con --dart-define=KYUBI_CLIENT_SIGN_SECRET=<valor>.',
    );
  }

  static String sign({
    required String method,
    required String path,
    Object? body,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now().toUtc();
    final ts = now.millisecondsSinceEpoch.toString();
    final payload = '${method.toUpperCase()}\n$path\n${_bodyDigest(body)}';
    final hmac = Hmac(sha256, utf8.encode(_secret));
    final digest = hmac.convert(utf8.encode('$payload\n$ts')).toString();
    return '$prefix $ts.$digest';
  }

  /// Digest SHA-256 del cuerpo para estabilizar la firma.
  static String _bodyDigest(Object? body) {
    if (body == null) return '';
    if (body is String) {
      return sha256.convert(utf8.encode(body)).toString();
    }
    try {
      return sha256.convert(utf8.encode(jsonEncode(body))).toString();
    } catch (_) {
      return '';
    }
  }
}
