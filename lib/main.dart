import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/network/request_signature.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_colors.dart';
import 'core/utils/animated_emoji_manager.dart';
import 'core/widgets/kyubi_logo.dart';
import 'services/chat_socket.dart';
import 'services/notification_socket.dart';
import 'services/theme_controller.dart';

/// Logger global de errores no capturados.
///
/// Evita excepciones silenciosas: registra en consola (debug) y envía la excepción
/// a Crashlytics de forma defensiva si está inicializado.
void _logUncaught(Object error, StackTrace stack, {String? zone, String? context, bool fatal = false}) {
  debugPrint(
    '[Kyubi][Uncaught${context != null ? '/$context' : ''}${zone != null ? ' @$zone' : ''}] '
    '$error\n$stack',
  );
  try {
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal: fatal,
      reason: context != null ? 'Uncaught context: $context' : null,
    );
  } catch (_) {
    // Ignorar si Firebase/Crashlytics no está inicializado (e.g. en tests unitarios o sin google-services).
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Global Error Dispatcher ────────────────────────────────────────────────
  // Errores de framework (build/layout/paint) que nadie captura.
  FlutterError.onError = (FlutterErrorDetails details) {
    _logUncaught(
      details.exception,
      details.stack ?? StackTrace.current,
      context: 'FlutterError',
      fatal: false,
    );
    try {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    } catch (_) {
      // Ignorar si Crashlytics no está disponible en este entorno
    }
    // Se conserva el dump por defecto en debug; en release solo loguea.
    FlutterError.presentError(details);
  };
  // Errores asíncronos no capturados (Futures sin catch, etc.).
  PlatformDispatcher.instance.onError = (error, stack) {
    _logUncaught(error, stack, context: 'PlatformDispatcher', fatal: true);
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {
      // Ignorar si Crashlytics no está disponible en este entorno
    }
    return true; // marcado como manejado para no tumbar la isolate en release
  };

  // ── Fail-fast de configuración de firma (HMAC) ─────────────────────────────
  // En release, sin el secreto de firma cada petición HTTP fallaría. Se
  // detecta aquí, en el arranque, bloqueando la ejecución normal y montando
  // ConfigurationErrorApp para alertar inmediatamente al usuario o tester.
  if (RequestSignature.secretOrNull == null) {
    debugPrint(
      '[Kyubi][FATAL] KYUBI_CLIENT_SIGN_SECRET no está configurada. '
      'Compila con --dart-define=KYUBI_CLIENT_SIGN_SECRET=<valor>. '
      'Deteniendo arranque para evitar peticiones HTTP rotas.',
    );
    runApp(const ConfigurationErrorApp());
    return;
  }

  // ErrorWidget builder global: previene pantalla ploma/gris silenciosa.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) {
      return Material(
        color: AppColors.backgroundBase,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFFF5252),
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Error de Renderizado UI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    details.exceptionAsString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFF8A80),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Release: vista genérica sin detalles internos.
    return Material(
      color: AppColors.backgroundBase,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const KyubiLogo(size: 80, withWordmark: true),
              const SizedBox(height: 24),
              const Text(
                'Ha ocurrido un error inesperado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Intenta de nuevo. Si el problema persiste, reinicia la app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _restartApp,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // ── Montaje Inmediato del Primer Frame ─────────────────────────────────────
  // No bloquear el arranque con múltiples awaits ni lecturas masivas síncronas.
  _runApp();

  // ── Inicialización Diferida de Servicios Secundarios ───────────────────────
  // Se ejecutan en microtask / post-primer-frame sin congelar la interfaz ni
  // retrasar la renderización del SplashScreen / pantalla inicial.
  Future.microtask(() async {
    // 1. Inicializar localización para intl
    try {
      await initializeDateFormatting('es', null);
    } catch (e) {
      debugPrint('[Intl] Advertencia al inicializar formato de fechas: $e');
    }

    // 2. Inicializar notificaciones push (FCM) de forma defensiva
    try {
      await NotificationService.instance.initialize();
    } catch (e) {
      debugPrint('[FCM] Advertencia al inicializar notificaciones: $e');
    }

    // 3. Configuración de telemetría Crashlytics
    try {
      if (kDebugMode) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
      } else {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      }
    } catch (e) {
      debugPrint('[Crashlytics] Advertencia al configurar Crashlytics: $e');
    }

    // 4. Precargar catálogo de emojis animados WebP
    try {
      await AnimatedEmojiManager.instance.init();
    } catch (e) {
      debugPrint('[EmojiManager] Advertencia al inicializar emojis: $e');
    }
  });
}

/// Monta el árbol principal de la app. Se usa tanto al arrancar como desde
/// la pantalla de error genérica en release (botón "Reintentar"), que
/// reconstruye el árbol desde cero para salir de un estado de widget roto.
void _runApp() {
  runApp(
    ProviderScope(
      overrides: [themeModeInitialProvider.overrideWithValue(ThemeMode.dark)],
      child: const KyubiApp(),
    ),
  );
}

void _restartApp() {
  // Al reconstruir el árbol (botón "Reintentar" en release) los singleton de
  // socket sobreviven en memoria. Desconectar aquí evita que hereden el token
  // del usuario previo y queden listeners reconectando en segundo plano con el
  // ProviderScope viejo.
  if (ChatSocketService.instance.isConnected) {
    ChatSocketService.instance.disconnect();
  }
  if (NotificationSocketService.instance.isConnected) {
    NotificationSocketService.instance.disconnect();
  }
  _runApp();
}

/// Pantalla de error fatal de configuración presentada cuando la app se compila
/// en modo release sin las credenciales o firmas requeridas (ej: KYUBI_CLIENT_SIGN_SECRET).
class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.backgroundBase,
      ),
      home: Scaffold(
        backgroundColor: AppColors.backgroundBase,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.accentCrimson.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentCrimson.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: AppColors.accentCrimson,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Error de configuración de seguridad',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Error de configuración de seguridad de la aplicación. Comuníquese con soporte.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
