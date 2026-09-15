import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/post_author.dart';
import '../../../models/room.dart';
import '../../../repositories/room_repository.dart';
import '../../../services/auth_controller.dart';
import '../../../services/providers.dart';
import '../../../services/room_socket.dart';

/// Estado del chat en vivo de una sala (mensajes cronológicos ascendentes).
class SalaChatState {
  const SalaChatState({
    this.messages = const [],
    this.loading = false,
    this.loadingOlder = false,
    this.hasMore = false,
    this.error,
    this.sending = false,
  });

  final List<RoomChatMessage> messages;
  final bool loading;
  final bool loadingOlder;
  final bool hasMore;
  final String? error;
  final bool sending;

  SalaChatState copyWith({
    List<RoomChatMessage>? messages,
    bool? loading,
    bool? loadingOlder,
    bool? hasMore,
    String? error,
    bool? sending,
  }) {
    return SalaChatState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      loadingOlder: loadingOlder ?? this.loadingOlder,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      sending: sending ?? this.sending,
    );
  }
}

class SalaChatNotifier
    extends AutoDisposeFamilyNotifier<SalaChatState, String> {
  RoomRepository get _repo => ref.read(roomRepositoryProvider);
  RoomSocketService get _socket => ref.read(roomSocketProvider);
  String get _roomId => arg;

  @override
  SalaChatState build(String arg) {
    _disposed = false;
    _listen();
    Future.microtask(_init);
    return const SalaChatState();
  }

  bool _disposed = false;

  void _listen() {
    final sub = _socket.events.listen((event) {
      if (_disposed) return;
      switch (event) {
        case RoomMessageReceived():
          if (event.roomId == _roomId) _addIncoming(event.payload);
          break;
        case RoomMessageUpdated():
          if (event.roomId == _roomId && !_disposed) {
            final idx = state.messages.indexWhere((m) => m.id == event.messageId);
            if (idx >= 0) {
              final old = state.messages[idx];
              final updated = old.copyWith(
                body: event.content.isNotEmpty ? event.content : old.body,
                content: event.content.isNotEmpty ? event.content : old.content,
                isEdited: event.isEdited,
                editedAt: event.editedAt ?? old.editedAt,
              );
              final list = List<RoomChatMessage>.from(state.messages);
              list[idx] = updated;
              state = state.copyWith(messages: list);
            }
          }
          break;
        case RoomMessageDeleted():
          if (event.roomId == _roomId && !_disposed) {
            state = state.copyWith(
              messages: state.messages
                  .where((m) => m.id != event.messageId)
                  .toList(),
            );
          }
          break;
        case RoomCinemaSync():
          // Los eventos de cine se manejan en CinemaPlayerView; aquí no-op.
          break;
        case RoomModeChanged():
        case RoomModeRejected():
        case RoomVoiceModerated():
        case RoomStageRoleChanged():
        case RoomPollVoted():
        case RoomInvited():
          // Modo, stage roles, encuestas, invitaciones y moderación de voz se manejan en sala_detail_screen.
          break;
        case RoomRateLimited():
        case RoomAccountSanctioned():
        case RoomErrorSanctioned():
        case RoomForceDisconnect():
          // Moderación de sanciones: descartar mensajes locales optimistas
          if (!_disposed) {
            state = state.copyWith(
              sending: false,
              messages: state.messages
                  .where((m) => !m.id.startsWith('local-'))
                  .toList(),
            );
          }
          break;
      }
    });
    ref.onDispose(() {
      _disposed = true;
      sub.cancel();
      _socket.leaveRoom(_roomId);
    });
  }

  Future<void> _init() async {
    try {
      await _socket.connect();
      _socket.joinRoom(_roomId);
      await loadMessages();
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Reintenta de forma limpia tras un error: reconecta socket, re-unifica a
  /// la sala y recarga el historial. Nunca relanza la excepción para evitar
  /// una pantalla de error inesperado; el ErrorView vuelve a un estado
  /// recuperado o con un mensaje legible.
  Future<void> retry() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, error: null);
    try {
      await _socket.connect();
      _socket.joinRoom(_roomId);
      await loadMessages();
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Comprueba si un mensaje corresponde a la creación o inicio de la sala.
  static bool _isRoomCreation(RoomChatMessage m) {
    final type = m.type.toUpperCase();
    final subType = m.extensions?['subType']?.toString().toUpperCase();
    final body = m.body.toLowerCase();
    return type == 'ROOM_CREATED' ||
        subType == 'ROOM_CREATED' ||
        body.contains('sala iniciada') ||
        body.contains('sala creada');
  }

  Future<void> loadMessages() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final page = await _repo.getRoomMessages(_roomId);
      var hasCreation = false;
      final deduplicated = <RoomChatMessage>[];
      for (final m in page.messages.reversed) {
        if (_isRoomCreation(m)) {
          if (hasCreation) continue;
          hasCreation = true;
        }
        deduplicated.add(m);
      }
      state = state.copyWith(
        messages: deduplicated,
        hasMore: page.hasMore,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadOlder() async {
    if (state.loadingOlder || !state.hasMore || state.messages.isEmpty) return;
    state = state.copyWith(loadingOlder: true);
    try {
      final before = state.messages.first.id;
      final page = await _repo.getRoomMessages(_roomId, before: before);
      var hasCreation = state.messages.any(_isRoomCreation);
      final deduplicated = <RoomChatMessage>[];
      for (final m in page.messages.reversed) {
        if (_isRoomCreation(m)) {
          if (hasCreation) continue;
          hasCreation = true;
        }
        deduplicated.add(m);
      }
      state = state.copyWith(
        messages: [...deduplicated, ...state.messages],
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
    final me = ref.read(authControllerProvider).user;
    final myId = me?.id ?? '';
    final optimistic = RoomChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      roomId: _roomId,
      senderId: myId,
      sender: me == null
          ? const PostAuthor(id: '', username: '', displayName: 'Tú')
          : PostAuthor(
              id: me.id,
              username: me.username,
              displayName: me.displayName,
              avatarUrl: me.effectiveAvatarUrl,
              usernameColor: me.usernameColor,
              avatarFrame: me.avatarFrame,
              level: me.level,
              isOnline: me.isOnline,
            ),
      body: text,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, optimistic],
      sending: true,
    );
    try {
      final sent = await _repo.sendRoomMessage(_roomId, body: text);
      state = state.copyWith(
        messages: [
          ...state.messages.where(
            (m) => m.id != optimistic.id && m.id != sent.id,
          ),
          sent,
        ],
        sending: false,
      );
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
    final message = RoomChatMessage.fromJson(payload);
    final existing = state.messages.indexWhere((m) => m.id == message.id);
    if (existing >= 0) {
      final updated = [...state.messages];
      updated[existing] = message;
      state = state.copyWith(messages: updated);
      return;
    }

    // Deduplicar mensajes de creación / inicio de sala
    if (_isRoomCreation(message)) {
      final alreadyHasCreation = state.messages.any(_isRoomCreation);
      if (alreadyHasCreation) return;
    }

    // Deduplicar mensajes de join cercanos en el tiempo
    final isJoin = message.extensions?['subType'] == 'USER_JOIN' ||
        message.body.contains('se ha unido') ||
        message.body.contains('Te has unido');
    if (isJoin) {
      final joinUserId = message.extensions?['userId'] ?? message.senderId;
      final recentDuplicate = state.messages.any((m) {
        final mIsJoin = m.extensions?['subType'] == 'USER_JOIN' ||
            m.body.contains('se ha unido') ||
            m.body.contains('Te has unido');
        if (!mIsJoin) return false;
        final mUserId = m.extensions?['userId'] ?? m.senderId;
        return mUserId == joinUserId &&
            message.createdAt.difference(m.createdAt).abs().inSeconds < 10;
      });
      if (recentDuplicate) return;
    }

    final localIndex = state.messages.indexWhere(
      (m) {
        if (!m.id.startsWith('local-')) return false;
        if (message.clientTempId != null &&
            (m.clientTempId == message.clientTempId ||
                m.id == message.clientTempId)) {
          return true;
        }
        final sameSender = m.senderId == message.senderId;
        final sameBody = m.body.trim() == message.body.trim();
        if (sameBody && (sameSender || message.senderId.isEmpty)) {
          return message.createdAt.difference(m.createdAt).abs().inSeconds < 5;
        }
        return false;
      },
    );
    if (localIndex >= 0) {
      final updated = [...state.messages];
      updated[localIndex] = message;
      state = state.copyWith(messages: updated);
      return;
    }
    state = state.copyWith(messages: [...state.messages, message]);
  }
}

final salaChatControllerProvider = NotifierProvider.autoDispose
    .family<SalaChatNotifier, SalaChatState, String>(SalaChatNotifier.new);
