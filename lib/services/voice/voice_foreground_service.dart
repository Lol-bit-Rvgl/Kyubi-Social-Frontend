import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Servicio en primer plano (Android Foreground Service) y control de WakeLock
/// para llamadas y canales de voz en vivo (LiveKit VoIP).
///
/// Evita que el sistema operativo congele los sockets, la conexión WebRTC o
/// mate el proceso cuando el usuario bloquea la pantalla o cambia de app.
class VoiceForegroundService {
  VoiceForegroundService._();

  /// Instancia única accesible globalmente.
  static final VoiceForegroundService instance = VoiceForegroundService._();

  static const int notificationId = 8888;
  static const String channelId = 'kyubi_voice_call';
  static const String channelName = 'Kyubi · Chat de Voz';
  static const String channelDescription =
      'Mantiene la llamada de voz activa cuando la pantalla se apaga o sales de la aplicación.';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isRunning = false;

  /// Indica si el servicio en primer plano está actualmente activo.
  bool get isRunning => _isRunning;

  /// Callback invocado cuando el usuario pulsa "Colgar" en la notificación.
  VoidCallback? onHangup;

  /// Arranca el Foreground Service en Android y activa el WakeLock para
  /// asegurar la continuidad ininterrumpida del audio en WebRTC.
  Future<void> start({
    String title = 'Kyubi — Chat de Voz Activo',
    String body = 'Conectado a la sala',
  }) async {
    // 1. WakeLock: evita reposo profundo de CPU al apagar pantalla
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await WakelockPlus.enable();
      } catch (e) {
        debugPrint('[VoiceForegroundService] Error activando WakeLock: $e');
      }
    }

    if (kIsWeb || !Platform.isAndroid) {
      _isRunning = true;
      return;
    }

    // 2. Foreground Service en Android
    try {
      // Verificar que el permiso de micrófono esté concedido ANTES de iniciar el FGS.
      // En Android 14+ el sistema mata la app con SecurityException si arranca un FGS de tipo microphone
      // sin RECORD_AUDIO concedido en runtime.
      final isGranted = await Permission.microphone.isGranted;
      if (!isGranted) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          debugPrint(
            '[VoiceForegroundService] Permiso RECORD_AUDIO no concedido en runtime. Omitiendo inicio de FGS para prevenir SecurityException.',
          );
          _isRunning = false;
          return;
        }
      }
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        const voiceChannel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        );
        await androidPlugin.createNotificationChannel(voiceChannel);

        await androidPlugin.startForegroundService(
          id: notificationId,
          title: title,
          body: body,
          notificationDetails: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            showWhen: true,
            usesChronometer: true,
            icon: '@mipmap/ic_launcher',
            category: AndroidNotificationCategory.call,
            audioAttributesUsage: AudioAttributesUsage.voiceCommunication,
            actions: const <AndroidNotificationAction>[
              AndroidNotificationAction(
                'action_hangup_voice',
                'Colgar',
                showsUserInterface: true,
                cancelNotification: false,
              ),
            ],
          ),
          payload: 'voice_call_ongoing',
          startType: AndroidServiceStartType.startSticky,
          foregroundServiceTypes: {
            AndroidServiceForegroundType.foregroundServiceTypeMicrophone,
          },
        );
        _isRunning = true;
        debugPrint(
          '[VoiceForegroundService] Foreground Service iniciado con éxito.',
        );
      }
    } catch (e) {
      debugPrint(
        '[VoiceForegroundService] Error al iniciar Foreground Service: $e',
      );
    }
  }

  /// Actualiza el texto de la notificación en ejecución (ej. al cambiar de sala o estado de mic).
  Future<void> update({required String title, required String body}) async {
    if (!_isRunning || kIsWeb || !Platform.isAndroid) return;
    try {
      final isGranted = await Permission.microphone.isGranted;
      if (!isGranted) {
        debugPrint(
          '[VoiceForegroundService] Permiso RECORD_AUDIO no concedido al actualizar FGS. Omitiendo.',
        );
        return;
      }
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.startForegroundService(
          id: notificationId,
          title: title,
          body: body,
          notificationDetails: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            showWhen: true,
            usesChronometer: true,
            icon: '@mipmap/ic_launcher',
            category: AndroidNotificationCategory.call,
            audioAttributesUsage: AudioAttributesUsage.voiceCommunication,
            actions: const <AndroidNotificationAction>[
              AndroidNotificationAction(
                'action_hangup_voice',
                'Colgar',
                showsUserInterface: true,
                cancelNotification: false,
              ),
            ],
          ),
          payload: 'voice_call_ongoing',
          startType: AndroidServiceStartType.startSticky,
          foregroundServiceTypes: {
            AndroidServiceForegroundType.foregroundServiceTypeMicrophone,
          },
        );
      }
    } catch (e) {
      debugPrint(
        '[VoiceForegroundService] Error actualizando Foreground Service: $e',
      );
    }
  }

  /// Detiene el Foreground Service y desactiva el WakeLock de forma limpia.
  Future<void> stop() async {
    // 1. Desactivar WakeLock
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await WakelockPlus.disable();
      } catch (e) {
        debugPrint('[VoiceForegroundService] Error desactivando WakeLock: $e');
      }
    }

    if (kIsWeb || !Platform.isAndroid) {
      _isRunning = false;
      return;
    }

    // 2. Detener servicio en Android y cancelar notificación
    try {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        await androidPlugin.stopForegroundService();
        await _notifications.cancel(id: notificationId);
      }
      _isRunning = false;
      debugPrint(
        '[VoiceForegroundService] Foreground Service detenido limpiamente.',
      );
    } catch (e) {
      debugPrint(
        '[VoiceForegroundService] Error al detener Foreground Service: $e',
      );
    }
  }
}