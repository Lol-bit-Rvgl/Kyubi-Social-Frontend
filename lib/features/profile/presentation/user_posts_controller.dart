import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/post.dart';
import '../../../repositories/post_repository.dart';
import '../../../services/providers.dart';

/// Estado de las publicaciones de un usuario (pestaña "Publicaciones").
class UserPostsState {
  const UserPostsState({
    this.posts = const [],
    this.loading = false,
    this.refreshing = false,
    this.loadingMore = false,
    this.error,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<Post> posts;
  final bool loading;
  final bool refreshing;
  final bool loadingMore;
  final String? error;
  final String? nextCursor;
  final bool hasMore;

  UserPostsState copyWith({
    List<Post>? posts,
    bool? loading,
    bool? refreshing,
    bool? loadingMore,
    String? error,
    String? nextCursor,
    bool? hasMore,
  }) {
    return UserPostsState(
      posts: posts ?? this.posts,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error ?? this.error,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Publicaciones de un usuario. Como no existe endpoint dedicado, filtramos
/// el feed paginado y conservamos las del autor indicado por `userId`.
class UserPostsNotifier extends FamilyNotifier<UserPostsState, String> {
  PostRepository get _repo => ref.read(postRepositoryProvider);

  bool _disposed = false;
  late String _userId;

  @override
  UserPostsState build(String arg) {
    ref.onDispose(() => _disposed = true);
    _userId = arg;
    Future.microtask(_load);
    return const UserPostsState();
  }

  Future<void> _load() async {
    if (_disposed) return;
    if (state.loading || state.refreshing) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final page = await _repo.getFeed(category: 'para_ti', page: 1, limit: 30);
      if (_disposed) return;
      final mine = page.posts.where((p) => p.author.id == _userId).toList();
      state = state.copyWith(
        posts: mine,
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
      final page = await _repo.getFeed(category: 'para_ti', page: 1, limit: 30);
      if (_disposed) return;
      final mine = page.posts.where((p) => p.author.id == _userId).toList();
      state = state.copyWith(
        posts: mine,
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
        category: 'para_ti',
        limit: 30,
        cursor: state.nextCursor,
      );
      if (_disposed) return;
      final mine = page.posts.where((p) => p.author.id == _userId).toList();
      state = state.copyWith(
        posts: [...state.posts, ...mine],
        nextCursor: page.nextCursor,
        hasMore: page.nextCursor != null,
        loadingMore: false,
      );
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(loadingMore: false);
    }
  }
}

final userPostsProvider =
    NotifierProvider.family<UserPostsNotifier, UserPostsState, String>(
      UserPostsNotifier.new,
    );
