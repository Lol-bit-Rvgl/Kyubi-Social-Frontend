import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/notification_item.dart';
import '../../../models/post_author.dart';
import '../../../repositories/notification_repository.dart';
import '../../../services/providers.dart';

/// Estado del centro de actividad con paginación.
class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.loading = false,
    this.loadingMore = false,
    this.refreshing = false,
    this.hasMore = false,
    this.page = 0,
    this.error,
  });

  final List<NotificationItem> items;
  final bool loading;
  final bool loadingMore;
  final bool refreshing;
  final bool hasMore;
  final int page;
  final String? error;

  NotificationsState copyWith({
    List<NotificationItem>? items,
    bool? loading,
    bool? loadingMore,
    bool? refreshing,
    bool? hasMore,
    int? page,
    String? error,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      refreshing: refreshing ?? this.refreshing,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      error: error ?? this.error,
    );
  }
}

class NotificationsNotifier extends Notifier<NotificationsState> {
  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);

  bool _disposed = false;

  @override
  NotificationsState build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(_loadFirst);
    return const NotificationsState();
  }

  Future<void> _loadFirst() async {
    if (_disposed) return;
    if (state.loading) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final page = await _repo.getNotifications(page: 1, limit: 20);
      if (_disposed) return;
      state = state.copyWith(
        items: page.items,
        page: 1,
        hasMore: page.items.length < page.total && page.page < page.pages,
        loading: false,
      );
      await _markAllReadIfNeeded(page.unread);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    state = state.copyWith(refreshing: true, error: null);
    try {
      final page = await _repo.getNotifications(page: 1, limit: 20);
      if (_disposed) return;
      state = state.copyWith(
        items: page.items,
        page: 1,
        hasMore: page.items.length < page.total && page.page < page.pages,
        refreshing: false,
      );
      await _markAllReadIfNeeded(page.unread);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(refreshing: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (_disposed) return;
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final next = await _repo.getNotifications(
        page: state.page + 1,
        limit: 20,
      );
      if (_disposed) return;
      state = state.copyWith(
        items: [...state.items, ...next.items],
        page: next.page,
        hasMore: next.items.length < next.total && next.page < next.pages,
        loadingMore: false,
      );
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  /// Actualización optimista del estado de follow de un actor en notificaciones.
  void updateActorFollowStatus(String actorId, bool isFollowing) {
    final updated = state.items.map((n) {
      final actor = n.actor;
      if (actor == null || actor.id != actorId) return n;
      return NotificationItem(
        id: n.id,
        type: n.type,
        timeAgo: n.timeAgo,
        createdAt: n.createdAt,
        actor: PostAuthor(
          id: actor.id,
          username: actor.username,
          displayName: actor.displayName,
          avatarUrl: actor.avatarUrl,
          usernameColor: actor.usernameColor,
          avatarFrame: actor.avatarFrame,
          level: actor.level,
          isOnline: actor.isOnline,
          showOnline: actor.showOnline,
          gender: actor.gender,
          showGender: actor.showGender,
          isFollowing: isFollowing,
        ),
        targetType: n.targetType,
        targetId: n.targetId,
        text: n.text,
        readAt: n.readAt,
      );
    }).toList();
    state = state.copyWith(items: updated);
  }

  /// Al abrir el centro, todo se considera leído (comportamiento estándar).
  Future<void> _markAllReadIfNeeded(int unread) async {
    if (unread <= 0) return;
    try {
      await _repo.markAllRead();
      ref.read(unreadCountProvider.notifier).clear();
    } catch (_) {
      // No bloquear la lista si falla la confirmación de lectura.
    }
  }
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
      NotificationsNotifier.new,
    );
