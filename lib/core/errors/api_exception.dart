/// Excepción unificada de la capa de red/API.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.type = ApiExceptionType.unknown,
    this.details,
  });

  /// Mensaje legible para el usuario.
  final String message;

  /// Código HTTP (200-599) o `null` para errores de red.
  final int? statusCode;

  /// `apiCode`/`code` enviado por el servidor en el cuerpo de error.
  final String? code;

  /// Clasificación interna del error.
  final ApiExceptionType type;

  /// Cuerpo crudo de la respuesta o causa original.
  final Object? details;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isServerError => (statusCode ?? 0) >= 500;

  @override
  String toString() {
    final codeSuffix = code == null ? '' : '·$code';
    return 'ApiException($statusCode$codeSuffix): $message';
  }
}

enum ApiExceptionType {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  server,
  connectivity,
  unknown,
}

/// Convierte cualquier error en un [ApiException] con mensaje legible.
ApiException mapError(Object error, {String fallback = 'Error de conexión'}) {
  if (error is ApiException) return error;
  return ApiException(message: fallback, details: error);
}
