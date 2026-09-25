import 'package:flutter/material.dart';

/// Clave global del ScaffoldMessenger de la aplicación para emitir mensajes y
/// SnackBars desde cualquier capa (controladores, notifiers, callbacks de socket)
/// sin requerir un BuildContext explícito.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Muestra un SnackBar flotante y discreto en la parte inferior de la pantalla.
void showAppSnackBar(
  String message, {
  Duration duration = const Duration(seconds: 3),
  SnackBarAction? action,
}) {
  final state = rootScaffoldMessengerKey.currentState;
  if (state == null) return;
  state
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
}
