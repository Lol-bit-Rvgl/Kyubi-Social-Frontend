import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';

/// Estados de conexión normalizados para clientes Socket.IO.
enum SocketState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Clase base abstracta para servicios de tiempo real basados en Socket.IO.
///
/// Centraliza:
/// - Máquina de estados de conexión (`SocketState`) con stream reactivo.
/// - Estrategia de reconexión con backoff exponencial configurable.
/// - Verificación preventiva de expiración de JWT (`isTokenExpired`).
/// - Refresco silencioso de credenciales vía [ApiClient.runRefreshExplicit].
/// - Inyección de credenciales renovadas en reconexiones antes del handshake.
/// - Sanitización de registros de depuración condicionados por [kDebugMode].
abstract class BaseSocket<TEvent> {
  BaseSocket({
    required this.serviceName,
    this.transports = const ['websocket', 'polling'],
    this.reconnectionAttempts = 5,
    this.reconnectionDelay = 2000,
    this.reconnectionDelayMax = 10000,
  });

  final String serviceName;
  final List<String> transports;
  final int reconnectionAttempts;
  final int reconnectionDelay;
  final int reconnectionDelayMax;

  final StreamController<TEvent> _eventController =
      StreamController<TEvent>.broadcast();
  final StreamController<SocketState> _stateController =
      StreamController<SocketState>.broadcast();

  io.Socket? _socket;
  SocketState _state = SocketState.disconnected;

  /// Stream de eventos de negocio tipados de este socket.
  Stream<TEvent> get events => _eventController.stream;

  /// Stream de cambios de estado de la conexión.
  Stream<SocketState> get stateChanges => _stateController.stream;

  /// Estado de conexión actual.
  SocketState get state => _state;

  /// Retorna `true` si el socket está activamente conectado al servidor.
  bool get isConnected =>
      _socket?.connected == true && _state == SocketState.connected;

  /// Retorna `true` si se está estableciendo la conexión inicial.
  bool get isConnecting => _state == SocketState.connecting;

  @protected
  io.Socket? get socket => _socket;

  /// Comprueba si un token JWT está expirado o próximo a expirar dentro del
  /// margen preventivo [buffer] (30 segundos por defecto).
  static bool isTokenExpired(
    String token, {
    Duration buffer = const Duration(seconds: 30),
  }) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final normalized = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadString);
      if (payload is! Map<String, dynamic>) return true;
      final exp = payload['exp'];
      if (exp is num) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
        return DateTime.now().isAfter(expiry.subtract(buffer));
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  /// Resuelve un token de acceso válido, refrescándolo si ha expirado.
  Future<String?> ensureValidToken() async {
    var token = await TokenStorage.accessToken();
    if (token == null || token.isEmpty || isTokenExpired(token)) {
      if (kDebugMode) {
        debugPrint(
          '[SOCKET][$serviceName] Token expirado o ausente. Solicitando refresco...',
        );
      }
      final refreshed = await ApiClient.instance.runRefreshExplicit();
      if (refreshed) {
        token = await TokenStorage.accessToken();
        if (kDebugMode) {
          debugPrint(
            '[SOCKET][$serviceName] Token renovado exitosamente para socket.',
          );
        }
      } else if (kDebugMode) {
        debugPrint(
          '[SOCKET][$serviceName] No se pudo refrescar el token de acceso.',
        );
      }
    }
    return token;
  }

  /// Actualiza las credenciales en la instancia de Socket.IO en ejecución.
  void updateSocketAuth(String token) {
    final s = _socket;
    if (s == null) return;

    s.auth = {'token': token};
    final opts = s.io.options;
    if (opts != null) {
      opts['auth'] = {'token': token};
      final extraHeaders = opts['extraHeaders'];
      if (extraHeaders is Map) {
        extraHeaders['Authorization'] = 'Bearer $token';
      } else {
        opts['extraHeaders'] = {'Authorization': 'Bearer $token'};
      }
    }
  }

  /// Espera a que el socket esté conectado (`isConnected == true`).
  /// Si está desconectado o en error, invoca [connect] y espera el evento
  /// de conexión con un timeout.
  Future<bool> ensureConnected({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (isConnected) return true;

    final connectionFuture = stateChanges
        .firstWhere((s) => s == SocketState.connected || s == SocketState.error)
        .timeout(timeout);

    if (!isConnecting) {
      await connect();
    }

    if (isConnected) return true;

    try {
      final target = await connectionFuture;
      return target == SocketState.connected && isConnected;
    } catch (_) {
      return isConnected;
    }
  }

  /// Fuerza el cierre de cualquier socket previo y establece una conexión limpia desde cero con token renovado.
  Future<bool> reconnect({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    disconnect();
    return ensureConnected(timeout: timeout);
  }

  /// Conecta al servidor de Socket.IO utilizando el token de sesión vigente.
  Future<void> connect() async {
    if (_socket?.connected == true || _state == SocketState.connecting) return;

    final stale = _socket;
    if (stale != null) {
      stale.dispose();
      _socket = null;
    }

    _updateState(SocketState.connecting);

    final token = await ensureValidToken();
    if (token == null || token.isEmpty) {
      _updateState(SocketState.disconnected);
      return;
    }

    try {
      _socket = io.io(
        AppConfig.apiBaseUrl,
        io.OptionBuilder()
            .setTransports(transports)
            .disableAutoConnect()
            .setAuth({'token': token})
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .enableReconnection()
            .setReconnectionAttempts(reconnectionAttempts)
            .setReconnectionDelay(reconnectionDelay)
            .setReconnectionDelayMax(reconnectionDelayMax)
            .build(),
      );

      _setupBaseListeners();
      registerCustomEvents(_socket!);

      _socket!.connect();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SOCKET_STATUS][$serviceName] Excepción al inicializar: $e');
      }
      _updateState(SocketState.error);
    }
  }

  void _setupBaseListeners() {
    final s = _socket;
    if (s == null) return;

    s.onConnect((_) {
      _updateState(SocketState.connected);
      if (kDebugMode) {
        debugPrint('[SOCKET_STATUS][$serviceName] Conectado: ${s.id}');
      }
      onConnected();
    });

    s.onDisconnect((reason) {
      _updateState(SocketState.disconnected);
      if (kDebugMode) {
        debugPrint('[SOCKET_STATUS][$serviceName] Desconectado: $reason');
      }
      onDisconnected(reason);
    });

    s.onConnectError((err) {
      _updateState(SocketState.error);
      if (kDebugMode) {
        debugPrint('[SOCKET_STATUS][$serviceName] Error de conexión: $err');
      }
      onConnectError(err);
    });

    s.onError((err) {
      _updateState(SocketState.error);
      if (kDebugMode) {
        debugPrint('[SOCKET_STATUS][$serviceName] Error interno de socket: $err');
      }
      onError(err);
    });

    // ── Interceptor de Reconexión: Refresco preventivo de JWT ────────────────
    s.io.on('reconnect_attempt', (attempt) async {
      if (kDebugMode) {
        debugPrint(
          '[SOCKET][$serviceName] Intento de reconexión #$attempt. Verificando vigencia de token...',
        );
      }
      try {
        final freshToken = await ensureValidToken();
        if (freshToken != null && freshToken.isNotEmpty && _socket != null) {
          updateSocketAuth(freshToken);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[SOCKET][$serviceName] Excepción al actualizar credenciales en reconexión: $e',
          );
        }
      }
    });

    s.io.on('reconnect', (attempt) {
      if (kDebugMode) {
        debugPrint(
          '[SOCKET_STATUS][$serviceName] Reconectado exitosamente en intento #$attempt',
        );
      }
      onReconnected(attempt);
    });
  }

  /// Suscribe listeners para los eventos específicos del dominio.
  @protected
  void registerCustomEvents(io.Socket socket);

  /// Callback invocado cuando la conexión se establece con éxito.
  @protected
  void onConnected() {}

  /// Callback invocado al desconectarse.
  @protected
  void onDisconnected(dynamic reason) {}

  /// Callback invocado ante error de handshake/conexión.
  @protected
  void onConnectError(dynamic err) {}

  /// Callback invocado ante error general del socket.
  @protected
  void onError(dynamic err) {}

  /// Callback invocado cuando se completa una reconexión exitosa.
  @protected
  void onReconnected(dynamic attempt) {}

  /// Emite un evento tipado al stream público [events].
  @protected
  void emitEvent(TEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Convierte dinámicamente cualquier payload recibido a Map tipado seguro.
  @protected
  Map<String, dynamic> asMap(dynamic payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return const {};
  }

  /// Desconecta el socket y limpia los recursos de red sin cerrar el stream de
  /// eventos (permite reutilizar la instancia tras un nuevo login).
  void disconnect() {
    final s = _socket;
    if (s != null) {
      s.dispose();
      _socket = null;
    }
    _updateState(SocketState.disconnected);
    onDisconnected('manual_disconnect');
  }

  /// Libera el socket y cierra definitivamente los controladores de streams.
  void dispose() {
    disconnect();
    if (!_eventController.isClosed) {
      _eventController.close();
    }
    if (!_stateController.isClosed) {
      _stateController.close();
    }
  }

  void _updateState(SocketState newState) {
    if (_state == newState) return;
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }
}
