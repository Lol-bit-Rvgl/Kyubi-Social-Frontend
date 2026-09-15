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
    _load();
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
    await _socket.connect();
    _socket.joinConversation(conversationId);
    final conversation = await _repo.getConversation(conversationId);
    state = state.copyWith(conversation: conversation);
    await _load();
  }

  Future<void> _load() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final page = await _repo.getMessages(_conversationId);
      state = state.copyWith(
        messages: page.messages.reversed.toList(),
        hasMore: page.hasMore,
        loading: false,
      );
      await _markRead();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadOlder() async {
    if (state.loadingOlder || !state.hasMore || state.messages.isEmpty) return;
    state = state.copyWith(loadingOlder: true);
    try {
      final before = state.messages.first.id;
      final page = await _repo.getMessages(_conversationId, before: before);
      state = state.copyWith(
        messages: [...page.messages.reversed, ...state.messages],
        hasMore: page.hasMore,
        loadingOlder: false,
      );
    } catch (_) {
      state = state.copyWith(loadingOlder: false);
    }
  }

  Future<bool> send(String body) async {
    final text = body.trim();
    if (text.isEmpty || state.sending) return false;
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    final optimistic = Message(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: _conversationId,
      senderId: myId,
      sender: ChatAuthor(id: myId, username: '', displayName: 'Tú'),
      body: text,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, optimistic],
      sending: true,
    );
    try {
      final sent = await _repo.sendMessage(_conversationId, body: text);
      state = state.copyWith(
        messages: [
          ...state.messages.where(
            (m) => m.id != optimistic.id && m.id != sent.id,
          ),
          sent,
        ],
        sending: false,
      );
      await _markRead();
      return true;
    } catch (_) {
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != optimistic.id).toList(),
        sending: false,
      );
      return false;
    }
  }

  void _addIncoming(Map<String, dynamic> payload) {
    final message = Message.fromJson(payload);
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
          m.id.startsWith('local-') &&
          m.senderId == message.senderId &&
          m.body == message.body,
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
}

final conversationChatProvider = NotifierProvider.autoDispose
    .family<ConversationChatNotifier, ConversationChatState, String>(
      ConversationChatNotifier.new,
    );
