import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/widgets/vhs_notification_toast.dart';
import 'routing/app_router.dart';
import 'services/providers.dart';
import 'services/notification_socket.dart';
import 'services/auth_controller.dart';
import 'services/theme_controller.dart';
import 'services/user_theme_provider.dart';

/// Raíz de Kyubi: tema + router.
class KyubiApp extends ConsumerStatefulWidget {
  const KyubiApp({super.key});

  @override
  ConsumerState<KyubiApp> createState() => _KyubiAppState();
}

class _KyubiAppState extends ConsumerState<KyubiApp> {
  StreamSubscription<NotificationEvent>? _notificationSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNotificationListener();
    });
  }

  void _initNotificationListener() {
    final socket = ref.read(notificationSocketProvider);
    socket.connect();
    _notificationSub = socket.events.listen((event) {
      if (!mounted) return;
      if (event is NotificationReceived) {
        ref.read(unreadCountProvider.notifier).increment();
        showVhsNotification(context, content: event.content, type: event.type);
      }
      if (event is UserSanctioned) {
        _handleUserSanction(event);
      }
    });
  }

  /// Maneja una sanción en tiempo real emitida por el panel de moderación.
  ///
  /// WARN / MUTE      → toast informativo, la sesión sigue activa.
  /// SUSPEND / BAN    → modal no cancelable + cierre de sesión forzado.
  Future<void> _handleUserSanction(UserSanctioned event) async {
    if (event.isSessionKilling) {
      // 1. Limpieza local garantizada: tokens + sockets DOWN, Auth reset.
      await ref.read(authControllerProvider.notifier).forceLogoutBySanction();

      if (!mounted) return;
      // Capturar contexto local tras el await para evitar use_build_context_synchronously.
      final localContext = context;
      if (!localContext.mounted) return;

      // 2. Diálogo no cancelable con detalle de la sanción.
      await showDialog<void>(
        context: localContext,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x33FF4D6D)),
          ),
          title: Row(
            children: [
              Icon(
                event.action == 'BAN'
                    ? Icons.gavel_rounded
                    : Icons.pause_circle_filled_rounded,
                color: const Color(0xFFFF4D6D),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                event.action == 'BAN'
                    ? 'Cuenta suspendida'
                    : 'Cuenta temporalmente suspendida',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.reason,
                style: const TextStyle(fontSize: 14, color: Color(0xFFCCCCD4)),
              ),
              if (event.expiresAt != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x14FF4D6D),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Expira: ${event.expiresAt!.toLocal().toString().substring(0, 16)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF8A9D),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                localContext.go('/login');
              },
              child: const Text(
                'Entendido',
                style: TextStyle(
                  color: Color(0xFFA594F9),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // WARN / MUTE → toast no invasivo que no cierra la sesión.
      showVhsNotification(
        context,
        content: event.action == 'MUTE'
            ? 'Has sido silenciado temporalmente. ${event.reason}'
            : 'Aviso de moderación: ${event.reason}',
        type: 'WARNING',
      );
    }
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    final userTheme = ref.watch(userThemeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildLight(themeSettings: userTheme),
      darkTheme: AppTheme.buildDark(themeSettings: userTheme),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
