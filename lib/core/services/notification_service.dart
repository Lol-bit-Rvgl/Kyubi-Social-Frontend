import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../../services/voice/voice_foreground_service.dart';

/// Handler de mensajes en background/terminated (app cerrada o segundo plano).
///
/// Debe ser una función top-level y estar anotada con
/// `@pragma('vm:entry-point')` para que no sea eliminada por el tree-shaking.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // En background es obligatorio inicializar Firebase antes de usarlo.
  await Firebase.initializeApp();
  debugPrint(
    '[FCM][BG] Mensaje recibido: ${message.messageId} data=${message.data}',
  );
}

/// Servicio central de notificaciones push (FCM) + banners locales.
///
/// - **Foreground:** muestra un banner local con `flutter_local_notifications`
///   (FCM no muestra notificaciones visibles con la app abierta).
/// - **Background/Terminated:** el sistema muestra la notificación; la
///   navegación se maneja con `onMessageOpenedApp` / `getInitialMessage`.
/// - El token FCM se envía a `POST /users/device-token` tras autenticarse y
///   se mantiene actualizado con `onTokenRefresh`.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _currentToken;

  /// Callback de navegación profunda: se registra desde `main.dart` con el
  /// router y se invoca con `type` y `targetId` del payload FCM.
  void Function(String type, String targetId)? onNotificationTap;

  static const String _channelId = 'kyubi_push';
  static const String _channelName = 'Kyubi · Notificaciones';
  static const String _channelDescription =
      'Mensajes, respuestas, menciones y firmas en el muro';

  /// Inicializa Firebase, permisos, canales locales y listeners. Defensivo:
  /// nunca lanza (la app debe funcionar sin Firebase configurado).
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();

      // Registrar handler de background (idempotente).
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Permisos de forma contextual: banners, badge, sonido y alerta.
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      await _initLocalNotifications();

      // Foreground: mostrar banner local (FCM no lo hace en primer plano).
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Usuario tocó la notificación con la app en background.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

      // Usuario tocó la notificación con la app terminada.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleOpenedMessage(initial);

      // Mantener el token actualizado en el backend.
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _currentToken = token;
        debugPrint('[FCM] Token refrescado');
      });

      _initialized = true;
      debugPrint('[FCM] Servicio de notificaciones inicializado');
    } catch (e) {
      debugPrint('[FCM] No se pudo inicializar Firebase Messaging: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == 'action_hangup_voice') {
          VoiceForegroundService.instance.onHangup?.call();
          return;
        }
        final payload = response.payload;
        if (payload != null &&
            payload.isNotEmpty &&
            payload != 'voice_call_ongoing') {
          _navigateFromPayload(payload);
        }
      },
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
    }
  }

  /// Muestra el banner local estilizado mientras la app está en foreground.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM][FG] ${message.messageId}');
    final notification = message.notification;
    try {
      await _localNotifications.show(
        id: message.hashCode,
        title: notification?.title ?? 'Kyubi',
        body: notification?.body ?? '',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: _encodePayload(message.data),
      );
    } catch (e) {
      debugPrint('[FCM] Error mostrando banner local: $e');
    }
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final parts = _payloadParts(message.data);
    onNotificationTap?.call(parts.$1, parts.$2);
  }

  (String, String) _payloadParts(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final targetId =
        data['targetId']?.toString() ??
        data['conversationId']?.toString() ??
        '';
    return (type, targetId);
  }

  String _encodePayload(Map<String, dynamic> data) {
    // Formato simple "type|targetId" para el tap del banner local.
    final parts = _payloadParts(data);
    return '${parts.$1}|${parts.$2}';
  }

  void _navigateFromPayload(String payload) {
    final parts = payload.split('|');
    if (parts.length < 2) return;
    onNotificationTap?.call(parts[0], parts[1]);
  }

  /// Obtiene el token FCM actual (si está disponible).
  Future<String?> getToken() async {
    if (_currentToken != null) return _currentToken;
    if (!_initialized) return null;
    try {
      return _currentToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('[FCM] Error obteniendo token: $e');
      return null;
    }
  }

  /// Envía el token FCM al backend tras autenticarse (múltiples dispositivos
  /// soportados: cada token se registra con upsert en el backend).
  Future<void> syncTokenWithBackend(ApiClient api) async {
    try {
      final token = await getToken();
      if (token == null) {
        debugPrint('[FCM] Sin token aún; se reintentará más tarde');
        return;
      }
      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
          ? 'ios'
          : 'web';
      await api.postJson(
        AppConfig.usersDeviceToken,
        data: {'token': token, 'platform': platform},
      );
      debugPrint('[FCM] Token registrado en el backend');
    } catch (e) {
      debugPrint('[FCM] No se pudo registrar el token: $e');
    }
  }

  /// Elimina el token del backend (logout).
  Future<void> unregisterToken(ApiClient api) async {
    final token = _currentToken;
    if (token == null) return;
    try {
      await api.deleteJson(AppConfig.usersDeviceToken, data: {'token': token});
    } catch (e) {
      debugPrint('[FCM] No se pudo eliminar el token: $e');
    }
  }
}
