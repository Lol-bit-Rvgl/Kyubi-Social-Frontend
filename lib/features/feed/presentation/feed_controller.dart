import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/session_store.dart';
import '../../../models/post.dart';
import '../../../models/room.dart';
import '../../../repositories/post_repository.dart';
import '../../../repositories/room_repository.dart';
import '../../../services/providers.dart';

/// Estado del feed con paginación por cursor, categorías y salas en vivo.
class FeedState {
  const FeedState({
    this.posts = const [],
    this.liveRooms = const [],
    this.category = 'para_ti',
    this.loading = false,
    this.refreshing = false,
    this.loadingMore = false,
    this.error,
    this.nextCursor,
    this.hasMore = false,
    this.isServerWakingUp = false,
  });

  final List<Post> posts;
  final List<Room> liveRooms;
  final String category;
  final bool loading;
  final bool refreshing;
  final bool loadingMore;
  final String? error;
  final String? nextCursor;
  final bool hasMore;
  final bool isServerWakingUp;

  FeedState copyWith({
    List<Post>? posts,
    List<Room>? liveRooms,
    String? category,
    bool? loading,
    bool? refreshing,
    bool? loadingMore,
    String? error,
    String? nextCursor,
    bool? hasMore,
    bool? isServerWakingUp,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      liveRooms: liveRooms ?? this.liveRooms,
      category: category ?? this.category,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error ?? this.error,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      isServerWakingUp: isServerWakingUp ?? this.isServerWakingUp,
    );
  }
}

class FeedNotifier extends Notifier<FeedState> {
  PostRepository get _repo => ref.read(postRepositoryProvider);
  RoomRepository get _roomRepo => ref.read(roomRepositoryProvider);

  bool _disposed = false;

  @override
  FeedState build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(_initCacheAndLoad);
    return const FeedState();
  }

  Future<void> _initCacheAndLoad() async {
    if (_disposed) return;
    // 1. Hidratar caché de inmediato (Cache-First)
    try {
      final cachedJson = await FeedCache.read(category: state.category);
      if (cachedJson.isNotEmpty && !_disposed && state.posts.isEmpty) {
        final cachedPosts = cachedJson.map(Post.fromJson).toList();
        state = state.copyWith(
          posts: cachedPosts,
          loading: false,
          refreshing: true,
        );
      }
    } catch (_) {}

    // 2. Sincronizar datos frescos en segundo plano
    await _load();
  }

  Future<void> _load() async {
    if (_disposed) return;
    final hasPosts = state.posts.isNotEmpty;
    state = state.copyWith(
      loading: !hasPosts,
      refreshing: hasPosts,
      error: null,
      isServerWakingUp: false,
    );
    try {
      final feedFuture = _repo.getFeed(
        category: state.category,
        followingOnly: state.category == 'following',
        page: 1,
        limit: 20,
      );
      final roomsFuture = _roomRepo.getSalas(limit: 10);
      final page = await feedFuture;
      final allRooms = await roomsFuture;
      final rooms = allRooms
          .where((r) => r.status == RoomStatus.active)
          .toList();
      if (_disposed) return;
      state = state.copyWith(
        posts: page.posts,
        liveRooms: rooms,
        nextCursor: page.nextCursor,
        hasMore: page.nextCursor != null,
        loading: false,
        refreshing: false,
        isServerWakingUp: false,
        error: null,
      );
      unawaited(FeedCache.save(page.posts, category: state.category));
    } catch (e) {
      if (_disposed) return;
      final errStr = e.toString().toLowerCase();
      final isTimeoutOrColdStart = errStr.contains('timeout') ||
          errStr.contains('iniciando') ||
          errStr.contains('reintentando') ||
          errStr.contains('502') ||
          errStr.contains('503') ||
          errStr.contains('504');

      if (state.posts.isNotEmpty) {
        // Tolerancia a cold start: MANTENER los posts cacheados visibles
        state = state.copyWith(
          loading: false,
          refreshing: false,
          isServerWakingUp: isTimeoutOrColdStart,
          error: isTimeoutOrColdStart ? null : e.toString(),
        );
      } else {
        state = state.copyWith(
          loading: false,
          refreshing: false,
          isServerWakingUp: isTimeoutOrColdStart,
          error: e.toString(),
        );
      }
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    state = state.copyWith(refreshing: true, error: null);
    try {
      final feedFuture = _repo.getFeed(
        category: state.category,
        followingOnly: state.category == 'following',
        page: 1,
        limit: 20,
      );
      final roomsFuture = _roomRepo.getSalas(limit: 10);
      final page = await feedFuture;
      final allRooms = await roomsFuture;
      final rooms = allRooms
          .where((r) => r.status == RoomStatus.active)
          .toList();
      if (_disposed) return;
      state = state.copyWith(
        posts: page.posts,
        liveRooms: rooms,
        nextCursor: page.nextCursor,
        hasMore: page.nextCursor != null,
        refreshing: false,
        isServerWakingUp: false,
        error: null,
      );
      unawaited(FeedCache.save(page.posts, category: state.category));
    } catch (e) {
      if (_disposed) return;
      final errStr = e.toString().toLowerCase();
      final isTimeoutOrColdStart = errStr.contains('timeout') ||
          errStr.contains('iniciando') ||
          errStr.contains('reintentando') ||
          errStr.contains('502') ||
          errStr.contains('503') ||
          errStr.contains('504');

      if (state.posts.isNotEmpty) {
        state = state.copyWith(
          refreshing: false,
          isServerWakingUp: isTimeoutOrColdStart,
          error: isTimeoutOrColdStart ? null : e.toString(),
        );
      } else {
        state = state.copyWith(
          refreshing: false,
          isServerWakingUp: isTimeoutOrColdStart,
          error: e.toString(),
        );
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed) return;
    if (state.loadingMore || !state.hasMore || state.nextCursor == null) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repo.getFeed(
        category: state.category,
        followingOnly: state.category == 'following',
        limit: 20,
        cursor: state.nextCursor,
      );
      final merged = [...state.posts, ...page.posts];
      if (_disposed) return;
      state = state.copyWith(
        posts: merged,
        nextCursor: page.nextCursor,
        hasMore: page.nextCursor != null,
        loadingMore: false,
      );
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> switchCategory(String category) async {
    if (state.category == category) return;
    state = FeedState(category: category);
    await _initCacheAndLoad();
  }

  /// Aplica cambios locales a un post tras una reacción.
  void updatePost(Post post) {
    final index = state.posts.indexWhere((p) => p.id == post.id);
    if (index < 0) return;
    final updated = [...state.posts];
    updated[index] = post;
    state = state.copyWith(posts: updated);
  }

  void removePost(String postId) {
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != postId).toList(),
    );
  }

  void insertPostAtTop(Post post) {
    state = state.copyWith(posts: [post, ...state.posts]);
  }
}

final feedControllerProvider = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);
