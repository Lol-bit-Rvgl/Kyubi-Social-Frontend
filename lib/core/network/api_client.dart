import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../config/app_config.dart';
import '../errors/api_exception.dart';
import '../storage/secure_storage.dart';
import '../storage/session_store.dart';
import 'client_identity.dart';
import 'request_signature.dart';

/// Cliente HTTP centralizado.
///
/// - Inyecta `Authorization: Bearer <accessToken>` y `sid` de sesión.
/// - Añade metadatos del cliente (`X-Device-Id`, `X-Uuid`, `X-Locale`, ...).
/// - Firma cada petición con `X-Signature: HJTRFS ...`.
/// - Refresca automáticamente el token de acceso cuando la API responde 401.
/// - Serializa/deserializa JSON y lanza [ApiException] tipadas.
/// - Soportes de subida con progreso.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        headers: {'Accept': 'application/json'},
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    // Solo registrar cuerpos en modo debug; en release evitar volcar tokens,
    // refreshToken o contenido de mensajes a logs del dispositivo.
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint('[API] $obj'),
        ),
      );
    }
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Desactivar keep-alive en peticiones GET para evitar que el socket quede
          // latente y sea abortado por el sistema operativo al pausar/reanudar la app.
          if (options.method.toUpperCase() == 'GET') {
            options.headers['Connection'] = 'close';
          }
          await _injectRequestHeaders(options);
          handler.next(options);
        },
        onError: (error, handler) async {
          final response = error.response;
          final status = response?.statusCode;

          // ── Mensaje amigable para cold-start de Render (502/503/504) y timeouts ──
          final isServerStarting =
              status == 502 || status == 503 || status == 504;
          final isTimeout = error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout;
          if (isServerStarting || isTimeout) {
            // Sobreescribimos el mensaje en el DioException para que
            // mapDioException o _toException lo lean al convertir a ApiException.
            error = error.copyWith(
              message: 'El servidor está iniciando, reintentando automáticamente...',
            );
          }

          final isIdempotent =
              (error.requestOptions.method.toUpperCase()) == 'GET';
          final retryCount =
              (error.requestOptions.extra['__kyubi_retry_count'] as int?) ?? 0;

          // ── 1. Reintento ante socket abort / conexión cerrada al reanudar la app ──
          final isAbortOrReset = _isConnectionAbortOrReset(error);
          if (isAbortOrReset && retryCount < _maxRetries) {
            final opts = error.requestOptions;
            opts.extra['__kyubi_retry_count'] = retryCount + 1;
            // Forzar una nueva conexión cerrando el socket existente
            opts.headers['Connection'] = 'close';
            invalidateConnectionPool();

            // Backoff exponencial breve: 300ms → 800ms
            final delayMs = retryCount == 0 ? 300 : 800;
            if (kDebugMode) {
              debugPrint(
                '[API] Socket abort/reset detectado en ${opts.path} (${error.error ?? error.message}). Reintentando ${retryCount + 1}/$_maxRetries en ${delayMs}ms...',
              );
            }
            await Future<void>.delayed(Duration(milliseconds: delayMs));

            try {
              final res = await _retry(opts);
              handler.resolve(res);
              return;
            } catch (retryError) {
              if (retryError is DioException) {
                error = retryError;
              }
            }
          }

          // ── 2. Reintento con backoff exponencial para servidor iniciando o timeouts (GET) ──
          if (isIdempotent &&
              retryCount < _maxRetries &&
              (isServerStarting ||
                  error.type == DioExceptionType.connectionTimeout)) {
            final opts = error.requestOptions;
            opts.extra['__kyubi_retry_count'] = retryCount + 1;
            // Backoff exponencial: 1s → 2s.
            await Future<void>.delayed(
              Duration(seconds: 1 << retryCount),
            );
            try {
              final res = await _retry(opts);
              handler.resolve(res);
              return;
            } catch (retryError) {
              if (retryError is DioException) {
                error = retryError;
              }
            }
          }

          final is401 = response?.statusCode == 401;
          final alreadyRetried =
              error.requestOptions.extra['__kyubi_retried'] == true;
          if (is401 && !alreadyRetried) {
            // Si ya hay un refresco en curso, nos encadenamos al mismo Future;
            // al resolver, reintentamos con el token ya renovado en vez de
            // fallar con 401.
            final done = await _runRefresh();
            if (done) {
              final opts = error.requestOptions;
              // Si el cuerpo es FormData, su stream ya fue finalizado en el
              // intento original; hay que clonarlo o el reintento lanza
              // "Bad state: The FormData has already been finalized".
              if (opts.data is FormData) {
                opts.data = (opts.data as FormData).clone();
              }
              opts.extra['__kyubi_retried'] = true;
              handler.resolve(await _retry(opts));
              return;
            }
          }
          handler.next(error);
        },
      ),
    );
    _initLifecycleObserver();
  }

  static final ApiClient instance = ApiClient._internal();

  /// Reintentos con backoff para peticiones GET ante fallos transitorios.
  static const int _maxRetries = 2;

  late final Dio _dio;
  Future<bool>? _refreshFuture;

  // -------------------------------------------------------------------------
  // Helpers públicos
  // -------------------------------------------------------------------------
  Dio get dio => _dio;

  /// Actualiza o purga el token de autorización en las opciones globales de Dio.
  void updateAuthToken(String? token) {
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  /// Token de autorización configurado en cabeceras en memoria.
  String? get currentAuthToken {
    final header = _dio.options.headers['Authorization'] as String?;
    if (header != null && header.startsWith('Bearer ')) {
      return header.substring(7);
    }
    return null;
  }

  /// Cancela cualquier refresco en vuelo tras logout o conmutación de cuenta.
  void resetRefresh() {
    _refreshFuture = null;
  }

  /// Inyecta cabeceras de autenticación, metadatos del cliente y firma.
  Future<void> _injectRequestHeaders(RequestOptions options) async {
    try {
      final token = await TokenStorage.accessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
        options.headers['sid'] = await ClientIdentity.sid();
      } else {
        options.headers.remove('Authorization');
        options.headers.remove('sid');
      }

      options.headers['X-Device-Id'] = await ClientIdentity.deviceId();
      options.headers['X-Uuid'] = await ClientIdentity.uuid();
      options.headers['X-Locale'] = ClientIdentity.locale;
      options.headers['X-Client-Platform'] = ClientIdentity.platform;
      options.headers['X-Signature'] = RequestSignature.sign(
        method: options.method,
        path: options.path,
        body: options.data,
      );
    } on StateError {
      // Config inválida (KYUBI_CLIENT_SIGN_SECRET ausente en release):
      // se bloquea la petición en lugar de enviarla sin firmar.
      rethrow;
    } catch (_) {
      // Si algo falla al preparar cabeceras, la petición sigue sin ellas.
    }
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final res = await _dio.get<dynamic>(
      path,
      queryParameters: query,
      options: Options(headers: {'Connection': 'close'}),
    );
    return _decodeObject(res);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    final res = await _dio.post<dynamic>(
      path,
      data: data,
      queryParameters: query,
    );
    return _decodeObject(res);
  }

  Future<Map<String, dynamic>> patchJson(String path, {Object? data}) async {
    final res = await _dio.patch<dynamic>(path, data: data);
    return _decodeObject(res);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    final res = await _dio.delete<dynamic>(
      path,
      data: data,
      queryParameters: query,
    );
    return _decodeObject(res);
  }

  Future<Map<String, dynamic>> postForm(
    String path, {
    required Map<String, dynamic> fields,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData();
    fields.forEach((key, value) {
      if (value == null) return;
      if (value is List<dynamic>) {
        for (final item in value) {
          if (item is MultipartFile) {
            form.files.add(MapEntry(key, item));
          } else if (item != null) {
            form.fields.add(MapEntry(key, item.toString()));
          }
        }
      } else if (value is MultipartFile) {
        form.files.add(MapEntry(key, value));
      } else {
        form.fields.add(MapEntry(key, value.toString()));
      }
    });
    final res = await _dio.post<dynamic>(
      path,
      data: form,
      onSendProgress: onProgress,
    );
    return _decodeObject(res);
  }

  /// Envía un formulario multipart vía PATCH (p. ej. avatar/username).
  Future<Map<String, dynamic>> patchForm(
    String path, {
    required Map<String, dynamic> fields,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData();
    fields.forEach((key, value) {
      if (value == null) return;
      if (value is List<dynamic>) {
        for (final item in value) {
          if (item is MultipartFile) {
            form.files.add(MapEntry(key, item));
          } else if (item != null) {
            form.fields.add(MapEntry(key, item.toString()));
          }
        }
      } else if (value is MultipartFile) {
        form.files.add(MapEntry(key, value));
      } else {
        form.fields.add(MapEntry(key, value.toString()));
      }
    });
    final res = await _dio.patch<dynamic>(
      path,
      data: form,
      onSendProgress: onProgress,
    );
    return _decodeObject(res);
  }

  /// Sube bytes como multipart `file`.
  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required Uint8List bytes,
    required String filename,
    String? contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    return postForm(
      path,
      fields: {
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: contentType == null
              ? null
              : DioMediaType.parse(contentType),
        ),
      },
      onProgress: onProgress,
    );
  }

  // -------------------------------------------------------------------------
  // Internos
  // -------------------------------------------------------------------------
  Map<String, dynamic> _decodeObject(Response<dynamic> res) {
    final body = res.data;
    if (body is String) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        if (decoded is List) return {'data': decoded};
        throw _toException(res, 'Respuesta inválida del servidor');
      } catch (_) {
        throw _toException(res, 'Respuesta inválida del servidor');
      }
    }
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    if (body is List) return {'data': body};
    throw _toException(res, 'Respuesta inválida del servidor');
  }

  /// Refresca el token de forma compartida: si ya hay un refresco en curso,
  /// devuelve ese mismo [Future] para que todas las peticiones concurrentes que
  /// reciban 401 esperen y reintenten con el nuevo token en lugar de rebotar.
  Future<bool> _runRefresh() {
    final inFlight = _refreshFuture;
    if (inFlight != null) return inFlight;
    final future = _tryRefresh();
    _refreshFuture = future;
    future.whenComplete(() {
      if (identical(_refreshFuture, future)) _refreshFuture = null;
    });
    return future;
  }

  /// Ejecuta un refresco explícito de sesión respetando el Future en vuelo.
  Future<bool> runRefreshExplicit() => _runRefresh();

  Future<bool> _tryRefresh() async {
    final refreshToken = await TokenStorage.refreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final res =
          await Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.receiveTimeout,
            ),
          ).post<dynamic>(
            AppConfig.authRefresh,
            data: {'refreshToken': refreshToken},
          );
      final body = res.data;
      if (res.statusCode != 200 || body is! Map<String, dynamic>) {
        if (res.statusCode == 401 || res.statusCode == 403) {
          await TokenStorage.clear();
        }
        return false;
      }
      final newAccess = body['accessToken'] as String?;
      final newRefresh = body['refreshToken'] as String?;
      if (newAccess == null || newRefresh == null) return false;
      await TokenStorage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );
      return true;
    } catch (e) {
      if (e is DioException) {
        final code = e.response?.statusCode;
        // Solo purgar credenciales si el backend responde explícitamente 401 o 403 confirmando revocación.
        if (code == 401 || code == 403) {
          await TokenStorage.clear();
        }
      }
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final token = await TokenStorage.accessToken();
    final opts = requestOptions;
    if (token != null && token.isNotEmpty) {
      opts.headers['Authorization'] = 'Bearer $token';
    }
    if (opts.data is FormData) {
      opts.data = (opts.data as FormData).clone();
    }
    return _dio.fetch<dynamic>(opts);
  }

  void _initLifecycleObserver() {
    try {
      WidgetsBinding.instance.addObserver(_ApiClientLifecycleObserver(this));
    } catch (_) {
      // Ignorar si WidgetsBinding no está disponible (ej. tests unitarios)
    }
  }

  /// Invalida el pool de conexiones del HttpClient para forzar la creación de
  /// nuevos sockets TCP limpios al salir y volver a la app.
  void invalidateConnectionPool() {
    if (kIsWeb) return;
    try {
      final oldAdapter = _dio.httpClientAdapter;
      _dio.httpClientAdapter = IOHttpClientAdapter();
      oldAdapter.close(force: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[API] Error al renovar adapter HTTP: $e');
      }
    }
  }

  /// Detecta si el fallo fue por desconexión de socket, socket abort, o conexión
  /// cerrada prematuramente por el sistema operativo al reanudar la app.
  static bool _isConnectionAbortOrReset(DioException error) {
    final rawError = error.error;
    if (rawError is HttpException) {
      final msg = rawError.message.toLowerCase();
      if (msg.contains('software caused connection abort') ||
          msg.contains('connection closed before full header was received') ||
          msg.contains('connection closed') ||
          msg.contains('connection reset')) {
        return true;
      }
    }
    if (rawError is SocketException) {
      final msg = rawError.message.toLowerCase();
      final osMsg = rawError.osError?.message.toLowerCase() ?? '';
      if (msg.contains('software caused connection abort') ||
          msg.contains('connection reset') ||
          msg.contains('connection closed') ||
          msg.contains('broken pipe') ||
          osMsg.contains('abort') ||
          osMsg.contains('reset') ||
          osMsg.contains('broken pipe')) {
        return true;
      }
    }

    final combinedMsg =
        '${error.message ?? ''} ${error.error ?? ''}'.toLowerCase();
    if (combinedMsg.contains('software caused connection abort') ||
        combinedMsg.contains('connection closed before full header was received') ||
        combinedMsg.contains('connection reset') ||
        combinedMsg.contains('connection closed') ||
        combinedMsg.contains('broken pipe')) {
      return true;
    }

    if (error.type == DioExceptionType.connectionError &&
        (combinedMsg.contains('abort') ||
            combinedMsg.contains('closed') ||
            combinedMsg.contains('reset') ||
            combinedMsg.contains('broken'))) {
      return true;
    }

    return false;
  }

  ApiException _toException(Response<dynamic> res, String fallback) {
    final status = res.statusCode ?? 0;
    final body = res.data;
    String message = fallback;
    String? code;
    if (body is Map<String, dynamic>) {
      message = body['message']?.toString() ?? fallback;
      code = _extractApiCode(body);
    } else if (body is String && body.isNotEmpty) {
      message = body;
    }
    return ApiException(
      message: message,
      statusCode: status,
      code: code,
      type: _typeFor(status),
      details: body,
    );
  }

  /// Extrae el `apiCode`/`code` del servidor en formato robusto.
  static String? _extractApiCode(Map<String, dynamic> body) {
    final value = body['apiCode'] ?? body['code'];
    if (value is String && value.isNotEmpty) return value;
    if (value is num) return value.toString();
    return null;
  }

  ApiExceptionType _typeFor(int status) {
    switch (status) {
      case 400:
        return ApiExceptionType.validation;
      case 401:
        return ApiExceptionType.unauthorized;
      case 403:
        return ApiExceptionType.forbidden;
      case 404:
        return ApiExceptionType.notFound;
      case 409:
        return ApiExceptionType.conflict;
      default:
        if (status >= 500) return ApiExceptionType.server;
        return ApiExceptionType.unknown;
    }
  }
}

/// Convierte errores de [DioException] en [ApiException] legibles.
ApiException mapDioException(Object error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    final response = error.response;
    final status = response?.statusCode;
    String? message;
    String? code;
    final data = response?.data;
    if (data is Map<String, dynamic>) {
      message = data['message']?.toString();
      code = _extractCode(data);
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: message ?? 'El servidor tardó demasiado en responder',
          statusCode: status,
          code: code,
          type: ApiExceptionType.timeout,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message: message ?? 'No se pudo conectar con el servidor',
          statusCode: status,
          code: code,
          type: ApiExceptionType.connectivity,
        );
      case DioExceptionType.badResponse:
        return ApiException(
          message: message ?? 'El servidor respondió con un error',
          statusCode: status,
          code: code,
          type: _statusType(status),
        );
      case DioExceptionType.cancel:
        return ApiException(
          message: 'Operación cancelada',
          type: ApiExceptionType.unknown,
        );
      default:
        return ApiException(
          message: message ?? 'Error de conexión',
          code: code,
          type: ApiExceptionType.network,
        );
    }
  }
  return ApiException(message: 'Error inesperado');
}

String? _extractCode(Map<String, dynamic> body) {
  final value = body['apiCode'] ?? body['code'];
  if (value is String && value.isNotEmpty) return value;
  if (value is num) return value.toString();
  return null;
}

ApiExceptionType _statusType(int? status) {
  switch (status) {
    case 401:
      return ApiExceptionType.unauthorized;
    case 403:
      return ApiExceptionType.forbidden;
    case 404:
      return ApiExceptionType.notFound;
    case 409:
      return ApiExceptionType.conflict;
    default:
      return ApiExceptionType.server;
  }
}

/// Wrapper para leer el storage con seguridad tipada.
Future<String?> readStoredString(String key) {
  return SecureStorage.read(key);
}

class _ApiClientLifecycleObserver with WidgetsBindingObserver {
  final ApiClient _client;
  _ApiClientLifecycleObserver(this._client);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) {
        debugPrint('[API] App resumed: invalidando pool de conexiones de HttpClient');
      }
      _client.invalidateConnectionPool();
    }
  }
}
