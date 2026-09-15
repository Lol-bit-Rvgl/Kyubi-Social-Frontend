import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    Future.microtask(_load);
    return const FeedState();
  }

  Future<void> _load() async {
    if (_disposed) return;
    if (state.loading || state.refreshing) return;
    state = state.copyWith(loading: true, error: null);
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
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: e.toString());
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
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(refreshing: false, error: e.toString());
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
    await _load();
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
