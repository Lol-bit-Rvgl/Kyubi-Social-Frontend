import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/chat_conversation.dart';
import '../../../models/chat_message.dart';
import '../../../repositories/chat_repository.dart';
import '../../../services/auth_controller.dart';
import '../../../services/chat_socket.dart';
import '../../../services/providers.dart';
import 'conversations_controller.dart';

/// Estado de una conversación abierta (mensajes cronológicos ascendentes).
class ConversationChatState {
  const ConversationChatState({
    this.messages = const [],
    this.conversation,
    this.loading = false,
    this.loadingOlder = false,
    this.hasMore = false,
    this.error,
    this.sending = false,
    this.typingUsers = const {},
  });

  final List<Message> messages;
  final Conversation? conversation;
  final bool loading;
  final bool loadingOlder;
  final bool hasMore;
  final String? error;
  final bool sending;
  final Set<String> typingUsers;

  ConversationChatState copyWith({
    List<Message>? messages,
    Conversation? conversation,
    bool? loading,
    bool? loadingOlder,
    bool? hasMore,
    String? error,
    bool? sending,
    Set<String>? typingUsers,
  }) {
    return ConversationChatState(
      messages: messages ?? this.messages,
      conversation: conversation ?? this.conversation,
      loading: loading ?? this.loading,
      loadingOlder: loadingOlder ?? this.loadingOlder,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      sending: sending ?? this.sending,
      typingUsers: typingUsers ?? this.typingUsers,
    );
  }
}

class ConversationChatNotifier
    extends AutoDisposeFamilyNotifier<ConversationChatState, String> {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  ChatSocketService get _socket => ref.read(chatSocketProvider);
  String get _conversationId => arg;

  @override
  ConversationChatState build(String arg) {
    _disposed = false;
    _listen();
    Future.microtask(_load);
    return const ConversationChatState();
  }

  bool _disposed = false;

  void _listen() {
    final sub = _socket.events.listen((event) {
      if (_disposed) return;
      switch (event) {
        case ChatMessageReceived():
          if (event.conversationId == _conversationId) {
            _addIncoming(event.payload);
          }
        case ChatMessageUpdated():
          if (event.conversationId == _conversationId) {
            _updateMessage(event.payload);
          }
        case ChatMessageDeleted():
          if (event.conversationId == _conversationId) {
            _markDeleted(event.messageId);
          }
        case ChatTyping():
          if (event.conversationId == _conversationId) {
            _setTyping(event.userId, event.isTyping);
          }
        case ChatConversationNew():
          break;
        case ChatRead():
          break;
        case ChatMatchFound():
        case ChatMatchNone():
          break;
        case ChatMatchMutualAccept():
          if (event.conversationId == _conversationId &&
              state.conversation != null) {
            final conv = state.conversation!;
            final currentExt = Map<String, dynamic>.from(conv.extensions ?? {});
            currentExt['status'] = 'accepted';
            final updatedConv = conv.copyWith(extensions: currentExt);
            state = state.copyWith(conversation: updatedConv);
            ref
                .read(conversationsControllerProvider.notifier)
                .upsertConversation(updatedConv);
          }
        case ChatMatchPeerAccepted():
          if (event.conversationId == _conversationId &&
              state.conversation != null) {
            final conv = state.conversation!;
            final currentExt = Map<String, dynamic>.from(conv.extensions ?? {});
            final acceptedBy = List<String>.from(
              currentExt['acceptedBy'] ?? <String>[],
            );
            if (!acceptedBy.contains(event.acceptedByUserId)) {
              acceptedBy.add(event.acceptedByUserId);
            }
            currentExt['acceptedBy'] = acceptedBy;
            final updatedConv = conv.copyWith(extensions: currentExt);
            state = state.copyWith(conversation: updatedConv);
            ref
                .read(conversationsControllerProvider.notifier)
                .upsertConversation(updatedConv);
          }
        case ChatMatchClosed():
          if (event.conversationId == _conversationId &&
              state.conversation != null) {
            final conv = state.conversation!;
            final currentExt = Map<String, dynamic>.from(conv.extensions ?? {});
            currentExt['status'] = 'closed';
            final updatedConv = conv.copyWith(extensions: currentExt);
            state = state.copyWith(conversation: updatedConv);
            ref
                .read(conversationsControllerProvider.notifier)
                .upsertConversation(updatedConv);
          }
      }
    });
    ref.onDispose(() {
      _disposed = true;
      sub.cancel();
    });
  }

  Future<void> loadFor(String conversationId) async {
    try {
      try {
        await _socket.connect();
      } catch (_) {}
      if (_disposed) return;
      _socket.joinConversation(conversationId);
      final conversation = await _repo.getConversation(conversationId);
      if (_disposed) return;
      state = state.copyWith(conversation: conversation);
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final page = await _repo.getMessages(_conversationId);
      if (_disposed) return;
      final pendingOptimistic = state.messages
          .where((m) => m.id.startsWith('temp-') || m.id.startsWith('local-'))
          .toList();
      state = state.copyWith(
        messages: [...pendingOptimistic, ...page.messages.reversed],
        hasMore: page.hasMore,
        loading: false,
      );
      try {
        await _markRead();
      } catch (_) {}
    } catch (e) {
      if (!_disposed) {
        state = state.copyWith(loading: false, error: e.toString());
      }
    } finally {
      if (!_disposed && state.loading) {
        state = state.copyWith(loading: false);
      }
    }
  }

  Future<void> loadOlder() async {
    if (state.loadingOlder || !state.hasMore || state.messages.isEmpty) return;
    state = state.copyWith(loadingOlder: true);
    try {
      final before = state.messages.first.id;
      final page = await _repo.getMessages(_conversationId, before: before);
      if (_disposed) return;
      state = state.copyWith(
        messages: [...page.messages.reversed, ...state.messages],
        hasMore: page.hasMore,
        loadingOlder: false,
      );
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(loadingOlder: false);
      }
    } finally {
      if (!_disposed && state.loadingOlder) {
        state = state.copyWith(loadingOlder: false);
      }
    }
  }

  Future<bool> send(
    String body, {
    String? type,
    String? mediaUrl,
    String? mediaType,
    String? stickerUrl,
    String? stickerId,
    Map<String, dynamic>? poll,
    String? replyToId,
    Map<String, dynamic>? extensions,
  }) async {
    final text = body.trim();
    final effectiveMediaUrl = mediaUrl ?? stickerUrl;
    final hasMedia = effectiveMediaUrl != null && effectiveMediaUrl.isNotEmpty;
    final hasPoll = poll != null && poll.isNotEmpty;
    final hasExtensions = extensions != null && extensions.isNotEmpty;
    final hasSpecialType = (mediaType != null && mediaType.isNotEmpty) ||
        (type != null && type.isNotEmpty);
    if (text.isEmpty && !hasMedia && !hasPoll && !hasExtensions && !hasSpecialType) {
      return false;
    }
    final currentUser = ref.read(authControllerProvider).user;
    final myId = currentUser?.id ?? '';
    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final combinedExt = <String, dynamic>{
      ...?extensions,
      'status': 'sending',
      'tempId': tempId,
      'poll': ?poll,
      'stickerId': ?stickerId,
      'stickerUrl': ?stickerUrl,
    };
    final optimisticBody = text.isNotEmpty
        ? text
        : (poll != null
            ? '📊 Encuesta: ${poll['question'] ?? 'Encuesta'}'
            : (mediaType == 'sticker' || type == 'STICKER' ? '🎨 Sticker' : ''));
    final myName = currentUser?.displayName.isNotEmpty == true
        ? currentUser!.displayName
        : (currentUser?.username.isNotEmpty == true
            ? currentUser!.username
            : 'Tú');
    final optimistic = Message(
      id: tempId,
      conversationId: _conversationId,
      senderId: myId,
      sender: ChatAuthor(
        id: myId,
        username: currentUser?.username ?? '',
        displayName: myName,
        avatarUrl: currentUser?.avatarUrl,
      ),
      body: optimisticBody,
      mediaUrl: effectiveMediaUrl,
      mediaType: mediaType ?? (effectiveMediaUrl != null ? 'image' : null),
      replyToId: replyToId,
      extensions: combinedExt,
      createdAt: DateTime.now().toUtc(),
    );

    // Frame 0: Inserción 100% síncrona en la lista local
    state = state.copyWith(
      messages: [...state.messages, optimistic],
      sending: false,
    );

    // Sincronización asíncrona sin bloquear la UI ni esperar await
    unawaited(
      _dispatchAsyncSend(
        optimistic: optimistic,
        text: text,
        type: type,
        mediaUrl: mediaUrl,
        mediaType: mediaType ?? (effectiveMediaUrl != null ? 'image' : null),
        stickerUrl: stickerUrl,
        stickerId: stickerId,
        poll: poll,
        replyToId: replyToId,
        combinedExt: combinedExt,
      ),
    );

    return true;
  }

  Future<void> _dispatchAsyncSend({
    required Message optimistic,
    required String text,
    String? type,
    String? mediaUrl,
    String? mediaType,
    String? stickerUrl,
    String? stickerId,
    Map<String, dynamic>? poll,
    String? replyToId,
    required Map<String, dynamic> combinedExt,
  }) async {
    try {
      final sent = await _repo.sendMessage(
        _conversationId,
        body: text,
        type: type,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        stickerUrl: stickerUrl,
        stickerId: stickerId,
        poll: poll,
        replyToId: replyToId,
        extensions: combinedExt.isNotEmpty ? combinedExt : null,
      );
      if (_disposed) return;

      // Reemplazo en el mismo índice del tempId por el mensaje confirmado con status 'sent'
      final idx = state.messages.indexWhere(
        (m) => m.id == optimistic.id || m.id == sent.id,
      );
      final sentWithStatus = sent.copyWith(
        extensions: {
          ...?sent.extensions,
          'status': 'sent',
        },
      );
      if (idx >= 0) {
        final updated = [...state.messages];
        updated[idx] = sentWithStatus;
        state = state.copyWith(messages: updated);
      } else {
        state = state.copyWith(messages: [...state.messages, sentWithStatus]);
      }

      if (state.conversation != null) {
        final updatedConv = state.conversation!.copyWith(
          lastMessage: sentWithStatus,
          updatedAt: sent.createdAt,
        );
        state = state.copyWith(conversation: updatedConv);
        ref
            .read(conversationsControllerProvider.notifier)
            .upsertConversation(updatedConv);
      }
      try {
        await _markRead();
      } catch (_) {}
    } catch (e) {
      if (!_disposed) {
        String errorMsg = 'Error al enviar mensaje';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map) {
            final serverMsg = data['message'] ?? data['error'];
            if (serverMsg is String && serverMsg.isNotEmpty) {
              errorMsg = serverMsg;
            }
          }
        }
        // En caso de error, marcar el mensaje con error para permitir reintento o retirarlo
        final idx = state.messages.indexWhere((m) => m.id == optimistic.id);
        if (idx >= 0) {
          final updated = [...state.messages];
          updated[idx] = optimistic.copyWith(
            extensions: {
              ...?optimistic.extensions,
              'status': 'error',
              'errorMessage': errorMsg,
            },
          );
          state = state.copyWith(messages: updated, error: errorMsg);
        }
      }
    }
  }

  void _addIncoming(Map<String, dynamic> payload) {
    final rawMessage = Message.fromJson(payload);
    final message = rawMessage.copyWith(
      extensions: {
        ...?rawMessage.extensions,
        'status': 'sent',
      },
    );
    final existing = state.messages.indexWhere((m) => m.id == message.id);
    if (existing >= 0) {
      final updated = [...state.messages];
      updated[existing] = message;
      state = state.copyWith(
        messages: updated,
        typingUsers: {...state.typingUsers}..remove(message.senderId),
      );
      return;
    }
    final localIndex = state.messages.indexWhere(
      (m) =>
          (m.id.startsWith('temp-') || m.id.startsWith('local-')) &&
          m.senderId == message.senderId &&
          (m.body.trim() == message.body.trim() ||
              (message.mediaUrl != null && m.mediaUrl == message.mediaUrl)),
    );
    if (localIndex >= 0) {
      final updated = [...state.messages];
      updated[localIndex] = message;
      state = state.copyWith(
        messages: updated,
        typingUsers: {...state.typingUsers}..remove(message.senderId),
      );
      return;
    }
    state = state.copyWith(
      messages: [...state.messages, message],
      typingUsers: {...state.typingUsers}..remove(message.senderId),
    );
  }

  void _setTyping(String userId, bool isTyping) {
    final users = {...state.typingUsers};
    if (isTyping) {
      users.add(userId);
    } else {
      users.remove(userId);
    }
    state = state.copyWith(typingUsers: users);
  }

  void _updateMessage(Map<String, dynamic> payload) {
    final updated = Message.fromJson(payload);
    final idx = state.messages.indexWhere((m) => m.id == updated.id);
    if (idx >= 0) {
      final updatedList = [...state.messages];
      updatedList[idx] = updated;
      state = state.copyWith(messages: updatedList);
    }
  }

  void _markDeleted(String messageId) {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx >= 0) {
      final updatedList = [...state.messages];
      final m = updatedList[idx];
      updatedList[idx] = m.copyWith(
        deletedAt: DateTime.now().toIso8601String(),
        body: 'Mensaje eliminado',
      );
      state = state.copyWith(messages: updatedList);
    }
  }

  Future<bool> editMessage(String messageId, String newContent) async {
    final oldMessages = state.messages;
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return false;

    // Actualización optimista inmediata
    final updatedList = [...state.messages];
    updatedList[idx] = updatedList[idx].copyWith(
      body: newContent,
      editedAt: DateTime.now().toIso8601String(),
    );
    state = state.copyWith(messages: updatedList);

    try {
      final updated = await _repo.editMessage(
        _conversationId,
        messageId,
        newContent,
      );
      if (!_disposed) {
        final currentIdx = state.messages.indexWhere((m) => m.id == messageId);
        if (currentIdx >= 0) {
          final list = [...state.messages];
          list[currentIdx] = updated;
          state = state.copyWith(messages: list);
        }
      }
      return true;
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(messages: oldMessages);
      }
      return false;
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    final oldMessages = state.messages;
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return false;

    // Actualización optimista inmediata
    final updatedList = [...state.messages];
    updatedList[idx] = updatedList[idx].copyWith(
      deletedAt: DateTime.now().toIso8601String(),
      body: 'Mensaje eliminado',
    );
    state = state.copyWith(messages: updatedList);

    try {
      await _repo.deleteMessage(_conversationId, messageId);
      return true;
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(messages: oldMessages);
      }
      return false;
    }
  }

  Future<void> _markRead() async {
    final lastId = state.messages.isNotEmpty ? state.messages.last.id : null;
    if (lastId == null || lastId.startsWith('local-')) return;
    try {
      await _repo.markConversationRead(_conversationId);
      _socket.sendRead(_conversationId, lastReadMessageId: lastId);
      ref
          .read(conversationsControllerProvider.notifier)
          .markRead(_conversationId);
    } catch (_) {}
  }

  void sendTyping({bool isTyping = true}) {
    _socket.sendTyping(_conversationId, isTyping: isTyping);
  }

  void acceptMatch() {
    _socket.acceptMatch(_conversationId);
    final conv = state.conversation;
    if (conv != null) {
      final myId = ref.read(authControllerProvider).user?.id ?? '';
      final currentExt = Map<String, dynamic>.from(conv.extensions ?? {});
      final acceptedBy = List<String>.from(currentExt['acceptedBy'] ?? <String>[]);
      if (myId.isNotEmpty && !acceptedBy.contains(myId)) {
        acceptedBy.add(myId);
      }
      currentExt['acceptedBy'] = acceptedBy;
      final updatedConv = conv.copyWith(extensions: currentExt);
      state = state.copyWith(conversation: updatedConv);
      ref
          .read(conversationsControllerProvider.notifier)
          .upsertConversation(updatedConv);
    }
  }

  void rejectMatch() {
    _socket.rejectMatch(_conversationId);
    final conv = state.conversation;
    if (conv != null) {
      final currentExt = Map<String, dynamic>.from(conv.extensions ?? {});
      currentExt['status'] = 'closed';
      final updatedConv = conv.copyWith(extensions: currentExt);
      state = state.copyWith(conversation: updatedConv);
      ref
          .read(conversationsControllerProvider.notifier)
          .upsertConversation(updatedConv);
    }
  }

  void nextMatch({String category = 'general'}) {
    _socket.nextMatch(_conversationId, category: category);
    final conv = state.conversation;
    if (conv != null) {
      final currentExt = Map<String, dynamic>.from(conv.extensions ?? {});
      currentExt['status'] = 'closed';
      final updatedConv = conv.copyWith(extensions: currentExt);
      state = state.copyWith(conversation: updatedConv);
      ref
          .read(conversationsControllerProvider.notifier)
          .upsertConversation(updatedConv);
    }
  }

  void leave() {
    _socket.leaveConversation(_conversationId);
  }

  Future<void> votePoll(String messageId, String optionId) async {
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    final msgIndex = state.messages.indexWhere((m) => m.id == messageId);
    if (msgIndex < 0) return;

    final targetMessage = state.messages[msgIndex];
    final extensions = Map<String, dynamic>.from(targetMessage.extensions ?? {});
    final pollMap = Map<String, dynamic>.from(
      (extensions['poll'] as Map<String, dynamic>?) ?? {},
    );
    final rawOptions = (pollMap['options'] as List<dynamic>?) ?? [];
    final votes = Map<String, dynamic>.from(
      (pollMap['votes'] as Map<String, dynamic>?) ?? {},
    );

    // Si ya votó por esta opción, no reenviar
    if (votes[myId] == optionId) return;
    votes[myId] = optionId;

    // Recalcular conteo de votos
    final updatedOptions = rawOptions.map((opt) {
      if (opt is Map<String, dynamic>) {
        final optCopy = Map<String, dynamic>.from(opt);
        final optId = optCopy['id'] as String? ?? '';
        final count = votes.values.where((v) => v == optId).length;
        optCopy['votes'] = count;
        return optCopy;
      }
      return opt;
    }).toList();

    final totalVotes = votes.length;
    pollMap['options'] = updatedOptions;
    pollMap['votes'] = votes;
    pollMap['totalVotes'] = totalVotes;
    extensions['poll'] = pollMap;

    final optimisticMessage = targetMessage.copyWith(
      extensions: extensions,
    );

    final updatedList = [...state.messages];
    updatedList[msgIndex] = optimisticMessage;
    state = state.copyWith(messages: updatedList);

    try {
      final updatedFromServer = await _repo.votePoll(
        _conversationId,
        messageId,
        optionId: optionId,
      );
      if (_disposed) return;
      final currentIndex = state.messages.indexWhere((m) => m.id == messageId);
      if (currentIndex >= 0) {
        final syncedList = [...state.messages];
        syncedList[currentIndex] = updatedFromServer;
        state = state.copyWith(messages: syncedList);
      }
    } catch (_) {
      if (!_disposed) {
        await _load();
      }
    }
  }
}

final conversationChatProvider = NotifierProvider.autoDispose
    .family<ConversationChatNotifier, ConversationChatState, String>(
      ConversationChatNotifier.new,
    );
