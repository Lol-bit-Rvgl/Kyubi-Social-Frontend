import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/mention_item.dart';
import '../../../repositories/mentions_repository.dart';
import '../../../services/auth_controller.dart';
import '../../../services/notification_socket.dart';
import '../../../services/providers.dart';

/// Estado de la pestaña de menciones pendientes (@Mentions).
class MentionsState {
  const MentionsState({
    this.mentions = const [],
    this.loading = false,
    this.refreshing = false,
    this.error,
  });

  final List<MentionItem> mentions;
  final bool loading;
  final bool refreshing;
  final String? error;

  int get unreadCount => mentions.where((m) => !m.isRead).length;

  MentionsState copyWith({
    List<MentionItem>? mentions,
    bool? loading,
    bool? refreshing,
    String? error,
  }) {
    return MentionsState(
      mentions: mentions ?? this.mentions,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      error: error,
    );
  }
}

/// Controlador de menciones pendientes en salas y chats.
class MentionsNotifier extends Notifier<MentionsState> {
  MentionsRepository get _repo => ref.read(mentionsRepositoryProvider);
  NotificationSocketService get _socket => ref.read(notificationSocketProvider);

  StreamSubscription<NotificationEvent>? _socketSub;
  bool _disposed = false;

  @override
  MentionsState build() {
    ref.onDispose(() {
      _disposed = true;
      _socketSub?.cancel();
    });

    final currentUserId = ref.watch(
      authControllerProvider.select((s) => s.user?.id),
    );
    if (currentUserId == null || currentUserId.isEmpty) {
      return const MentionsState();
    }

    _listen();
    Future.microtask(_load);
    return const MentionsState(loading: true);
  }

  void _listen() {
    _socketSub = _socket.events.listen((event) {
      if (_disposed) return;
      if (event is NotificationReceived && event.type == 'MENTION') {
        // Al recibir mención en tiempo real, sincronizamos para obtener metadatos completos
        refresh();
      }
    });
  }

  void clear() {
    state = const MentionsState();
  }

  Future<void> _load() async {
    if (_disposed) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await _repo
          .getMentions(all: true)
          .timeout(const Duration(seconds: 8));
      if (_disposed) return;
      state = state.copyWith(mentions: items, loading: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: e.toString());
    } finally {
      if (!_disposed && state.loading) {
        state = state.copyWith(loading: false);
      }
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    state = state.copyWith(refreshing: true, error: null);
    try {
      final items = await _repo
          .getMentions(all: true)
          .timeout(const Duration(seconds: 8));
      if (_disposed) return;
      state = state.copyWith(mentions: items, refreshing: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(refreshing: false, error: e.toString());
    } finally {
      if (!_disposed && state.refreshing) {
        state = state.copyWith(refreshing: false);
      }
    }
  }

  /// Marca una mención como leída optimísticamente y notifica al backend.
  Future<void> markAsRead(String mentionId) async {
    final index = state.mentions.indexWhere((m) => m.id == mentionId);
    if (index < 0) return;
    final item = state.mentions[index];
    if (item.isRead) return;

    final updated = [...state.mentions];
    updated[index] = item.copyWith(readAt: DateTime.now().toIso8601String());
    state = state.copyWith(mentions: updated);

    try {
      await _repo.markRead(mentionId);
    } catch (_) {
      // Ignorar fallo de red puntual
    }
  }

  /// Marca todas las menciones como leídas.
  Future<void> markAllAsRead() async {
    final now = DateTime.now().toIso8601String();
    final updated = state.mentions.map((m) => m.copyWith(readAt: now)).toList();
    state = state.copyWith(mentions: updated);

    try {
      await _repo.markAllRead();
    } catch (_) {}
  }
}

final mentionsControllerProvider =
    NotifierProvider<MentionsNotifier, MentionsState>(
  MentionsNotifier.new,
);
