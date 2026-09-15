import 'chat_conversation.dart';
import 'chat_message.dart';
import 'notification_item.dart';

/// Evento en tiempo real ya tipado, distribuido por el Event Bus.
///
/// El [WebSocketService] recibe tramas del servidor y las convierte en
/// instancias de estas clases para que chats, notificaciones y presencia
/// puedan suscribirse a streams tipados sin conocer el protocolo de red.
sealed class RealtimeEvent {
  const RealtimeEvent();
}

/// Eventos de mensajería (conversaciones y mensajes en tiempo real).
sealed class ChatRealtimeEvent extends RealtimeEvent {
  const ChatRealtimeEvent();
}

/// Llega un mensaje nuevo a una conversación en la que estamos unidos.
class ChatMessageEvent extends ChatRealtimeEvent {
  const ChatMessageEvent({required this.message});

  final Message message;

  String get conversationId => message.conversationId;
}

/// Se crea una conversación nueva (otra persona nos escribió por primera vez).
class ChatConversationNewEvent extends ChatRealtimeEvent {
  const ChatConversationNewEvent({required this.conversation});

  final Conversation conversation;
}

/// Alguien está escribiendo / dejó de escribir.
class ChatTypingEvent extends ChatRealtimeEvent {
  const ChatTypingEvent({
    required this.conversationId,
    required this.userId,
    required this.isTyping,
  });

  final String conversationId;
  final String userId;
  final bool isTyping;
}

/// Alguien marcó la conversación como leída.
class ChatReadEvent extends ChatRealtimeEvent {
  const ChatReadEvent({
    required this.conversationId,
    required this.userId,
    this.lastReadMessageId,
  });

  final String conversationId;
  final String userId;
  final String? lastReadMessageId;
}

/// Llega una notificación nueva del centro de actividad.
class NotificationRealtimeEvent extends RealtimeEvent {
  const NotificationRealtimeEvent({required this.notification});

  final NotificationItem notification;
}

/// Cambio de estado de presencia de un usuario.
class PresenceEvent extends RealtimeEvent {
  const PresenceEvent({
    required this.userId,
    required this.isOnline,
    this.details = const {},
  });

  final String userId;
  final bool isOnline;
  final Map<String, dynamic> details;
}

/// Evento del servidor que aún no tiene un tipo específico.
///
/// Se publica igualmente en el bus para no perder información y permite
/// a los consumidores reaccionar a eventos futuros del backend.
class UnknownRealtimeEvent extends RealtimeEvent {
  const UnknownRealtimeEvent({required this.name, required this.data});

  final String name;
  final Map<String, dynamic> data;
}

/// Convierte una trama `event` del servidor en un [RealtimeEvent] tipado.
///
/// Se soportan las nomenclaturas `evento:subtipo`, `evento.subtipo` y
/// `evento_subtipo` (el backend histórico de Socket.IO usaba `message:new`,
/// `conversation:new`, `notification_received`, ...).
RealtimeEvent? parseRealtimeEvent(String eventName, Map<String, dynamic> data) {
  final normalized = eventName
      .replaceAll('.', ':')
      .replaceAll('_', ':')
      .toLowerCase();

  switch (normalized) {
    case 'chat:message':
    case 'message:new':
    case 'chat:new:message':
      return ChatMessageEvent(message: Message.fromJson(data));

    case 'chat:conversation':
    case 'conversation:new':
      return ChatConversationNewEvent(
        conversation: Conversation.fromJson(data),
      );

    case 'chat:typing':
    case 'typing':
      return ChatTypingEvent(
        conversationId: data['conversationId'] as String? ?? '',
        userId: data['userId'] as String? ?? '',
        isTyping: data['isTyping'] as bool? ?? true,
      );

    case 'chat:read':
    case 'read':
      return ChatReadEvent(
        conversationId: data['conversationId'] as String? ?? '',
        userId: data['userId'] as String? ?? '',
        lastReadMessageId: data['lastReadMessageId'] as String?,
      );

    case 'notification:new':
    case 'notification:received':
    case 'notification_received':
      return NotificationRealtimeEvent(
        notification: NotificationItem.fromJson(data),
      );

    case 'presence':
    case 'presence:update':
      return PresenceEvent(
        userId: data['userId'] as String? ?? '',
        isOnline: data['isOnline'] as bool? ?? true,
        details: _mapOrEmpty(data['details']),
      );

    default:
      return UnknownRealtimeEvent(name: eventName, data: data);
  }
}

Map<String, dynamic> _mapOrEmpty(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}
