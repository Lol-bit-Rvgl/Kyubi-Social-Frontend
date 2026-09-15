import 'dart:async';

import '../models/realtime_event.dart';

/// Event Bus en memoria que distribuye los [RealtimeEvent] a toda la app.
///
/// Es un singleton *broadcast*: cualquier parte de la app puede suscribirse
/// a streams tipados (chats, notificaciones, presencia) sin acoplarse al
/// transporte subyacente ([WebSocketService]).
class RealtimeEventBus {
  RealtimeEventBus._internal();

  static final RealtimeEventBus instance = RealtimeEventBus._internal();

  final StreamController<RealtimeEvent> _controller =
      StreamController<RealtimeEvent>.broadcast();

  /// Todos los eventos en tiempo real.
  Stream<RealtimeEvent> get events => _controller.stream;

  /// Solo eventos de mensajería (mensajes, conversaciones, typing, lectura).
  Stream<ChatRealtimeEvent> get chatEvents =>
      _controller.stream.where((e) => e is ChatRealtimeEvent).cast();

  /// Solo notificaciones nuevas.
  Stream<NotificationRealtimeEvent> get notificationEvents =>
      _controller.stream.where((e) => e is NotificationRealtimeEvent).cast();

  /// Solo cambios de presencia.
  Stream<PresenceEvent> get presenceEvents =>
      _controller.stream.where((e) => e is PresenceEvent).cast();

  bool get isClosed => _controller.isClosed;

  /// Publica un evento en el bus. Ignora publicaciones si el bus está cerrado.
  void dispatch(RealtimeEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
