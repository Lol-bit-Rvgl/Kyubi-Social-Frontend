import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user.dart';
import '../../../repositories/follow_requests_repository.dart';
import '../../../services/providers.dart';

/// Estado de las solicitudes de seguimiento pendientes (tab Invites).
class FollowRequestsState {
  const FollowRequestsState({
    this.items = const [],
    this.loading = false,
    this.refreshing = false,
    this.loadingMore = false,
    this.error,
    this.nextCursor,
    this.hasMore = false,
    this.busyIds = const {},
  });

  final List<FollowRequestItem> items;
  final bool loading;
  final bool refreshing;
  final bool loadingMore;
  final String? error;
  final String? nextCursor;
  final bool hasMore;

  /// IDs de solicitudes con una acción (aceptar/rechazar) en curso.
  final Set<String> busyIds;

  FollowRequestsState copyWith({
    List<FollowRequestItem>? items,
    bool? loading,
    bool? refreshing,
    bool? loadingMore,
    String? error,
    String? nextCursor,
    bool? hasMore,
    Set<String>? busyIds,
  }) {
    return FollowRequestsState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error ?? this.error,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      busyIds: busyIds ?? this.busyIds,
    );
  }
}

/// Controlador de solicitudes de seguimiento entrantes.
class FollowRequestsNotifier extends Notifier<FollowRequestsState> {
  FollowRequestsRepository get _repo =>
      ref.read(followRequestsRepositoryProvider);

  bool _disposed = false;

  @override
  FollowRequestsState build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(_load);
    return const FollowRequestsState();
  }

  void clear() {
    state = const FollowRequestsState();
  }

  Future<void> _load() async {
    if (_disposed) return;
    if (state.loading || state.refreshing) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final page = await _repo.getFollowRequests().timeout(const Duration(seconds: 8));
      if (_disposed) return;
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.nextCursor != null,
        loading: false,
      );
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
      final page = await _repo.getFollowRequests().timeout(const Duration(seconds: 8));
      if (_disposed) return;
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.nextCursor != null,
        refreshing: false,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(refreshing: false, error: e.toString());
    } finally {
      if (!_disposed && state.refreshing) {
        state = state.copyWith(refreshing: false);
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed) return;
    if (state.loadingMore || !state.hasMore || state.nextCursor == null) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repo.getFollowRequests(cursor: state.nextCursor);
      if (_disposed) return;
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.nextCursor != null,
        loadingMore: false,
      );
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  /// Acepta o rechaza una solicitud y la retira de la lista.
  Future<void> respond(String requestId, {required bool accept}) async {
    if (state.busyIds.contains(requestId)) return;
    state = state.copyWith(busyIds: {...state.busyIds, requestId});
    try {
      await _repo.respond(requestId, accept: accept);
      if (_disposed) return;
      state = state.copyWith(
        items: state.items.where((r) => r.id != requestId).toList(),
        busyIds: {...state.busyIds}..remove(requestId),
      );
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(
        busyIds: {...state.busyIds}..remove(requestId),
        error: 'No se pudo procesar la solicitud',
      );
    }
  }
}

final followRequestsControllerProvider =
    NotifierProvider<FollowRequestsNotifier, FollowRequestsState>(
      FollowRequestsNotifier.new,
    );
