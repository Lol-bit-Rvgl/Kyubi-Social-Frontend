import 'package:socket_io_client/socket_io_client.dart' as io;

import 'base_socket.dart';

/// Evento recibido por socket.
sealed class ChatSocketEvent {}

/// Llega un mensaje nuevo a una conversación en la que estamos unidos.
class ChatMessageReceived extends ChatSocketEvent {
  ChatMessageReceived(this.conversationId, this.payload);
  final String conversationId;
  final Map<String, dynamic> payload;
}

/// Se crea una conversación nueva (otra persona nos escribió por primera vez).
class ChatConversationNew extends ChatSocketEvent {
  ChatConversationNew(this.payload);
  final Map<String, dynamic> payload;
}

/// Alguien está escribiendo / dejó de escribir.
class ChatTyping extends ChatSocketEvent {
  ChatTyping(this.conversationId, this.userId, this.isTyping);
  final String conversationId;
  final String userId;
  final bool isTyping;
}

/// Alguien marcó la conversación como leída.
class ChatRead extends ChatSocketEvent {
  ChatRead(this.conversationId, this.userId, this.lastReadMessageId);
  final String conversationId;
  final String userId;
  final String? lastReadMessageId;
}

/// Se encontró un match de matchmaking aleatorio (perfil público del otro y conversación).
class ChatMatchFound extends ChatSocketEvent {
  ChatMatchFound(this.peer, this.category, {this.conversationId = ''});
  final Map<String, dynamic> peer;
  final String category;
  final String conversationId;
}

/// Ambos usuarios aceptaron el match provisional.
class ChatMatchMutualAccept extends ChatSocketEvent {
  ChatMatchMutualAccept(this.conversationId);
  final String conversationId;
}

/// El compañero aceptó el match (esperando confirmación mutua).
class ChatMatchPeerAccepted extends ChatSocketEvent {
  ChatMatchPeerAccepted(this.conversationId, this.acceptedByUserId);
  final String conversationId;
  final String acceptedByUserId;
}

/// El match fue cancelado o el compañero se fue.
class ChatMatchClosed extends ChatSocketEvent {
  ChatMatchClosed(this.conversationId, this.reason);
  final String conversationId;
  final String reason;
}

/// La búsqueda de match terminó sin encontrar a nadie (timeout / cola vacía).
class ChatMatchNone extends ChatSocketEvent {
  ChatMatchNone(this.category, this.reason);
  final String category;
  final String reason;
}

/// Cliente Socket.IO para mensajería en tiempo real.
class ChatSocketService extends BaseSocket<ChatSocketEvent> {
  ChatSocketService._()
      : super(
          serviceName: 'chat',
          transports: const ['websocket', 'polling'],
          reconnectionAttempts: 5,
          reconnectionDelay: 2000,
        );

  static final ChatSocketService instance = ChatSocketService._();

  final _joinedConversations = <String>{};

  @override
  void registerCustomEvents(io.Socket socket) {
    socket.on('message:new', (payload) {
      final data = asMap(payload);
      final conversationId = data['conversationId'] as String? ?? '';
      if (conversationId.isNotEmpty) {
        emitEvent(ChatMessageReceived(conversationId, data));
      }
    });

    socket.on('conversation:message', (payload) {
      final data = asMap(payload);
      final conversationId = data['conversationId'] as String? ?? '';
      if (conversationId.isNotEmpty) {
        emitEvent(ChatMessageReceived(conversationId, data));
      }
    });

    socket.on('conversation:new', (payload) {
      final data = asMap(payload);
      emitEvent(ChatConversationNew(data));
    });

    socket.on('typing', (payload) {
      final data = asMap(payload);
      emitEvent(
        ChatTyping(
          data['conversationId'] as String? ?? '',
          data['userId'] as String? ?? '',
          data['isTyping'] as bool? ?? false,
        ),
      );
    });

    socket.on('read', (payload) {
      final data = asMap(payload);
      emitEvent(
        ChatRead(
          data['conversationId'] as String? ?? '',
          data['userId'] as String? ?? '',
          data['lastReadMessageId'] as String?,
        ),
      );
    });

    socket.on('match:found', (payload) {
      final data = asMap(payload);
      final rawPeer = data['partner'] ?? data['peer'];
      final peer = rawPeer is Map
          ? Map<String, dynamic>.from(rawPeer)
          : const <String, dynamic>{};
      final conversationId = data['conversationId'] as String? ?? '';
      emitEvent(
        ChatMatchFound(
          peer,
          data['category'] as String? ?? '',
          conversationId: conversationId,
        ),
      );
    });

    socket.on('match:mutual_accept', (payload) {
      final data = asMap(payload);
      final conversationId = data['conversationId'] as String? ?? '';
      emitEvent(ChatMatchMutualAccept(conversationId));
    });

    socket.on('match:peer_accepted', (payload) {
      final data = asMap(payload);
      final conversationId = data['conversationId'] as String? ?? '';
      final acceptedByUserId = data['acceptedByUserId'] as String? ?? '';
      emitEvent(ChatMatchPeerAccepted(conversationId, acceptedByUserId));
    });

    socket.on('match:closed', (payload) {
      final data = asMap(payload);
      final conversationId = data['conversationId'] as String? ?? '';
      final reason = data['reason'] as String? ?? 'partner_left';
      emitEvent(ChatMatchClosed(conversationId, reason));
    });

    socket.on('match:none', (payload) {
      final data = asMap(payload);
      emitEvent(
        ChatMatchNone(
          data['category'] as String? ?? '',
          data['reason'] as String? ?? 'timeout',
        ),
      );
    });
  }

  @override
  void onConnected() {
    _rejoin();
  }

  void joinConversation(String conversationId) {
    _joinedConversations.add(conversationId);
    socket?.emit('conversation:join', conversationId);
  }

  void leaveConversation(String conversationId) {
    _joinedConversations.remove(conversationId);
    socket?.emit('conversation:leave', conversationId);
  }

  void _rejoin() {
    for (final conversationId in _joinedConversations) {
      socket?.emit('conversation:join', conversationId);
    }
  }

  void sendTyping(String conversationId, {bool isTyping = true}) {
    socket?.emit('typing', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  void sendRead(String conversationId, {String? lastReadMessageId}) {
    socket?.emit('read', {
      'conversationId': conversationId,
      'lastReadMessageId': ?lastReadMessageId,
    });
  }

  /// Se une a la cola de matchmaking aleatorio.
  void joinMatchmaking({String category = 'general'}) {
    socket?.emit('match:join', {'category': category});
    socket?.emit('match:start', {'category': category});
  }

  /// Sale de la cola de matchmaking aleatorio.
  void leaveMatchmaking() {
    socket?.emit('match:leave');
    socket?.emit('match:cancel');
  }

  /// Alias retrocompatibles para iniciar y detener búsqueda.
  void startMatchmaking(String category) => joinMatchmaking(category: category);
  void stopMatchmaking() => leaveMatchmaking();

  /// Acepta el match provisional para conservarlo como conversación permanente.
  void acceptMatch(String conversationId) {
    socket?.emit('match:accept', {'conversationId': conversationId});
  }

  /// Rechaza o cancela el match provisional.
  void rejectMatch(String conversationId) {
    socket?.emit('match:reject', {'conversationId': conversationId});
  }

  /// Pasa al siguiente match aleatorio (cierra el actual y vuelve a encolar).
  void nextMatch(String conversationId, {String category = 'general'}) {
    socket?.emit('match:next', {
      'conversationId': conversationId,
      'category': category,
    });
  }

  @override
  void disconnect() {
    super.disconnect();
    _joinedConversations.clear();
  }
}
