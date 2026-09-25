import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/session_store.dart';
import '../../../core/widgets/app_messenger.dart';
import '../../../models/chat_conversation.dart';
import '../../../models/chat_message.dart';
import '../../../repositories/chat_repository.dart';
import '../../../services/auth_controller.dart';
import '../../../services/chat_socket.dart';
import '../../../services/providers.dart';

/// Estado de la bandeja de conversaciones.
class ConversationsState {
  const ConversationsState({
    this.conversations = const [],
    this.pinnedIds = const {},
    this.loading = false,
    this.refreshing = false,
    this.error,
  });

  final List<Conversation> conversations;

  /// Ids de chats fijados (`Pin to My Chats`): van primero en la lista.
  final Set<String> pinnedIds;
  final bool loading;
  final bool refreshing;
  final String? error;

  ConversationsState copyWith({
    List<Conversation>? conversations,
    Set<String>? pinnedIds,
    bool? loading,
    bool? refreshing,
    String? error,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      pinnedIds: pinnedIds ?? this.pinnedIds,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      error: error ?? this.error,
    );
  }
}

class ConversationsNotifier extends Notifier<ConversationsState> {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  ChatSocketService get _socket => ref.read(chatSocketProvider);

  @override
  ConversationsState build() {
    _mounted = true;
    _unsubscribed = false;
    ref.onDispose(() {
      _unsubscribed = true;
      _mounted = false;
    });
    final currentUserId = ref.watch(authControllerProvider.select((s) => s.user?.id));
    if (currentUserId == null || currentUserId.isEmpty) {
      return const ConversationsState();
    }
    _listen();
    _restoreFromCache(currentUserId);
    Future.microtask(_load);
    return const ConversationsState(loading: true);
  }

  bool _mounted = true;

  /// Purga el estado en memoria de conversaciones al cerrar sesión.
  void clear() {
    _seenMessages.clear();
    state = const ConversationsState();
  }

  /// Restaura conversaciones desde caché local antes de la carga de red,
  /// evitando que la lista desaparezca o se quede en spinner infinito.
  Future<void> _restoreFromCache([String? userId]) async {
    try {
      final cached = await ConversationsCache.read(userId: userId);
      if (cached.isEmpty || !_mounted) return;
      final conversations = cached
          .map(Conversation.fromJson)
          .where((c) => c.lastMessage != null)
          .toList();
      if (!_mounted) return;
      state = state.copyWith(conversations: conversations, loading: false);
    } catch (_) {}
  }

  bool _unsubscribed = false;

  /// Ids de mensajes ya contabilizados en la bandeja. Evita sumar dos veces el
  /// mismo mensaje si llega por duplicado (canal de conversación + sala personal).
  final _seenMessages = <String>{};

  void _listen() {
    final sub = _socket.events.listen((event) {
      if (_unsubscribed) return;
      switch (event) {
        case ChatMessageReceived():
          _onMessageReceived(event.conversationId, event.payload);
        case ChatConversationNew():
        case ChatMessageUpdated():
        case ChatMessageDeleted():
          refresh();
        case ChatTyping():
        case ChatRead():
          break;
        case ChatMatchFound():
        case ChatMatchNone():
        case ChatMatchMutualAccept():
        case ChatMatchPeerAccepted():
        case ChatMatchClosed():
          break;
      }
    });
    ref.onDispose(sub.cancel);
  }

  Future<void> _load() async {
    if (!_mounted) return;
    final hasExisting = state.conversations.isNotEmpty;
    state = state.copyWith(
      loading: !hasExisting,
      refreshing: hasExisting,
      error: null,
    );
    try {
      // Conectar socket en background sin bloquear la llamada HTTP crítica
      unawaited(_socket.connect().catchError((_) {}));

      final conversations = await _repo
          .getConversations()
          .timeout(const Duration(seconds: 15));
      if (!_mounted) return;
      state = state.copyWith(
        conversations: conversations,
        loading: false,
        refreshing: false,
        error: null,
      );
      final myId = ref.read(authControllerProvider).user?.id;
      ConversationsCache.save(conversations, userId: myId);
    } catch (e) {
      if (_mounted) {
        state = state.copyWith(
          loading: false,
          refreshing: false,
          error: state.conversations.isEmpty ? e.toString() : null,
        );
        if (state.conversations.isNotEmpty) {
          showAppSnackBar('Sin conexión / reintentando en segundo plano...');
        }
      }
    } finally {
      if (_mounted && (state.loading || state.refreshing)) {
        state = state.copyWith(loading: false, refreshing: false);
      }
    }
  }

  Future<void> refresh() async {
    if (!_mounted) return;
    state = state.copyWith(
      loading: state.conversations.isEmpty,
      refreshing: state.conversations.isNotEmpty,
      error: null,
    );
    try {
      final conversations = await _repo
          .getConversations()
          .timeout(const Duration(seconds: 15));
      if (!_mounted) return;
      state = state.copyWith(
        conversations: conversations,
        loading: false,
        refreshing: false,
        error: null,
      );
      final myId = ref.read(authControllerProvider).user?.id;
      ConversationsCache.save(conversations, userId: myId);
    } catch (e) {
      if (_mounted) {
        state = state.copyWith(
          loading: false,
          refreshing: false,
          error: state.conversations.isEmpty ? e.toString() : null,
        );
        if (state.conversations.isNotEmpty) {
          showAppSnackBar('Sin conexión / reintentando en segundo plano...');
        }
      }
    } finally {
      if (_mounted && (state.loading || state.refreshing)) {
        state = state.copyWith(loading: false, refreshing: false);
      }
    }
  }

  void _onMessageReceived(String conversationId, Map<String, dynamic> payload) {
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    final senderId = payload['senderId'] as String? ?? '';
    // Los mensajes propios no cuentan como no leídos.
    if (senderId.isNotEmpty && senderId == myId) return;
    final messageId = payload['id'] as String? ?? '';
    if (messageId.isNotEmpty) {
      if (!_seenMessages.add(messageId)) return;
      if (_seenMessages.length > 200) _seenMessages.clear();
    }
    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index < 0) {
      refresh();
      return;
    }
    final updated = [...state.conversations];
    final current = updated[index];
    updated[index] = Conversation(
      id: current.id,
      type: current.type,
      title: current.title,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      members: current.members,
      otherMember: current.otherMember,
      isGroup: current.isGroup,
      lastMessage: Message.fromJson(payload),
      unreadCount: current.unreadCount + 1,
      lastReadMessageId: current.lastReadMessageId,
      muted: current.muted,
    );
    state = state.copyWith(conversations: _sorted(updated));
  }

  /// Ordena la lista: fijados primero y luego por fecha descendente.
  List<Conversation> _sorted(List<Conversation> list) {
    final sorted = List<Conversation>.from(list);
    sorted.sort((a, b) {
      final aPinned = state.pinnedIds.contains(a.id);
      final bPinned = state.pinnedIds.contains(b.id);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      return _compare(a.updatedAt, b.updatedAt);
    });
    return sorted;
  }

  void upsertConversation(Conversation conversation) {
    if (conversation.lastMessage == null) return;
    final list = [...state.conversations];
    final index = list.indexWhere((c) => c.id == conversation.id);
    if (index >= 0) {
      list[index] = conversation;
    } else {
      list.insert(0, conversation);
    }
    state = state.copyWith(conversations: _sorted(list));
    ConversationsCache.save(state.conversations);
  }

  // ── Pin to My Chats ───────────────────────────────────────────────────
  // Los chats fijados quedan al tope de la pestaña Private.

  void togglePin(String conversationId) {
    final pinned = Set<String>.from(state.pinnedIds);
    if (!pinned.remove(conversationId)) pinned.add(conversationId);
    state = state.copyWith(
      pinnedIds: pinned,
      conversations: _sorted(state.conversations),
    );
  }

  bool isPinned(String conversationId) =>
      state.pinnedIds.contains(conversationId);

  // ── Preferencias locales por chat (sesión) ────────────────────────────
  // Color de burbuja y etiquetas (#Add a Tag) para la vista de conversación.

  final Map<String, Color> _chatBubbleColors = {};
  final Map<String, List<String>> _chatTags = {};

  Color? bubbleColorFor(String conversationId) =>
      _chatBubbleColors[conversationId];

  void setBubbleColor(String conversationId, Color color) {
    _chatBubbleColors[conversationId] = color;
  }

  List<String> tagsFor(String conversationId) =>
      List.unmodifiable(_chatTags[conversationId] ?? const []);

  void addTag(String conversationId, String tag) {
    final tagClean = tag.trim().replaceAll('#', '');
    if (tagClean.isEmpty) return;
    final list = [...tagsFor(conversationId)];
    if (list.contains('#$tagClean')) return;
    list.add('#$tagClean');
    _chatTags[conversationId] = list;
  }

  void removeTag(String conversationId, String tag) {
    final list = [...tagsFor(conversationId)]..remove(tag);
    _chatTags[conversationId] = list;
  }

  void removeConversation(String conversationId) {
    state = state.copyWith(
      conversations: state.conversations
          .where((c) => c.id != conversationId)
          .toList(),
    );
  }

  /// Silencia o reactiva las notificaciones de la conversación.
  Future<void> toggleMute(String conversationId) async {
    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index < 0) return;
    final current = state.conversations[index];
    final nextMuted = !current.muted;
    final updated = [...state.conversations];
    updated[index] = current.copyWith(muted: nextMuted);
    state = state.copyWith(conversations: updated);
    ConversationsCache.save(state.conversations);

    try {
      await _repo.setMuted(conversationId, nextMuted);
    } catch (_) {
      if (!_mounted) return;
      final rollback = [...state.conversations];
      final rollbackIdx = rollback.indexWhere((c) => c.id == conversationId);
      if (rollbackIdx >= 0) {
        rollback[rollbackIdx] = current;
        state = state.copyWith(conversations: rollback);
        ConversationsCache.save(state.conversations);
      }
      rethrow;
    }
  }

  /// Elimina la conversación en backend y la remueve del estado local reactivamente.
  Future<void> deleteConversation(String conversationId) async {
    removeConversation(conversationId);
    ConversationsCache.save(state.conversations);
    try {
      await _repo.deleteConversation(conversationId);
    } catch (_) {
      if (!_mounted) return;
      refresh();
      rethrow;
    }
  }

  void markRead(String conversationId) {
    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index < 0) return;
    final updated = [...state.conversations];
    final current = updated[index];
    updated[index] = Conversation(
      id: current.id,
      type: current.type,
      title: current.title,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
      members: current.members,
      otherMember: current.otherMember,
      isGroup: current.isGroup,
      lastMessage: current.lastMessage,
      unreadCount: 0,
      lastReadMessageId: current.lastMessage?.id ?? current.lastReadMessageId,
      muted: current.muted,
    );
    state = state.copyWith(conversations: updated);
  }
}

final conversationsControllerProvider =
    NotifierProvider<ConversationsNotifier, ConversationsState>(
      ConversationsNotifier.new,
    );

/// Ordena descendentemente por fecha (nulas al final).
int _compare(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}
