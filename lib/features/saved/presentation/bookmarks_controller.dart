import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/post.dart';
import '../../../repositories/bookmarks_repository.dart';
import '../../../services/providers.dart';

/// Estado de las publicaciones guardadas con paginación por cursor.
class BookmarksState {
  const BookmarksState({
    this.posts = const [],
    this.savedIds = const {},
    this.loading = false,
    this.refreshing = false,
    this.loadingMore = false,
    this.error,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<Post> posts;
  final Set<String> savedIds;
  final bool loading;
  final bool refreshing;
  final bool loadingMore;
  final String? error;
  final String? nextCursor;
  final bool hasMore;

  bool isSaved(String postId) => savedIds.contains(postId);

  BookmarksState copyWith({
    List<Post>? posts,
    Set<String>? savedIds,
    bool? loading,
    bool? refreshing,
    bool? loadingMore,
    String? error,
    String? nextCursor,
    bool? hasMore,
  }) {
    return BookmarksState(
      posts: posts ?? this.posts,
      savedIds: savedIds ?? this.savedIds,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error ?? this.error,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Controlador de publicaciones guardadas (bookmarks).
///
/// Mantiene la lista de guardados y el conjunto de IDs guardados (`savedIds`)
/// para que el botón de guardado en `PostCard` refleje el estado en vivo,
/// independientemente de la pantalla desde la que se vea el post.
class BookmarksNotifier extends Notifier<BookmarksState> {
  BookmarksRepository get _repo => ref.read(bookmarksRepositoryProvider);

  bool _disposed = false;

  @override
  BookmarksState build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(_load);
    return const BookmarksState();
  }

  Future<void> _load() async {
    if (_disposed) return;
    if (state.loading || state.refreshing) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final page = await _repo.getBookmarks();
      if (_disposed) return;
      state = state.copyWith(
        posts: page.posts,
        savedIds: page.posts.map((p) => p.id).toSet(),
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
      final page = await _repo.getBookmarks();
      if (_disposed) return;
      state = state.copyWith(
        posts: page.posts,
        savedIds: page.posts.map((p) => p.id).toSet(),
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
      final page = await _repo.getBookmarks(cursor: state.nextCursor);
      final merged = [...state.posts, ...page.posts];
      if (_disposed) return;
      state = state.copyWith(
        posts: merged,
        savedIds: {...state.savedIds, ...page.posts.map((p) => p.id)},
        nextCursor: page.nextCursor,
        hasMore: page.nextCursor != null,
        loadingMore: false,
      );
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  /// Devuelve directamente desde la fuente para sincronizarse con cualquier
  /// pantalla (feed, perfil, ...) sin tocar el modelo [Post].
  bool isSaved(String postId) => state.savedIds.contains(postId);

  /// Alterna el guardado de una publicación con actualización optimista.
  ///
  /// Si se desguarda desde la propia lista de guardados, el post se elimina de
  /// la misma; en caso contrario solo se actualiza `savedIds`.
  Future<void> toggle(String postId) async {
    final current = state.savedIds.contains(postId);
    final next = !current;
    final savedIds = {...state.savedIds};
    if (next) {
      savedIds.add(postId);
    } else {
      savedIds.remove(postId);
    }

    var posts = state.posts;
    if (!next) {
      posts = posts.where((p) => p.id != postId).toList();
    }

    state = state.copyWith(posts: posts, savedIds: savedIds);

    try {
      await _repo.toggleBookmark(postId);
      if (_disposed) return;
      if (posts.isEmpty || posts.length != state.posts.length) {
        state = state.copyWith(posts: posts, savedIds: savedIds);
      } else {
        state = state.copyWith(savedIds: savedIds);
      }
    } catch (_) {
      if (_disposed) return;
      final revert = {...state.savedIds};
      if (current) {
        revert.add(postId);
      } else {
        revert.remove(postId);
      }
      state = state.copyWith(savedIds: revert);
    }
  }
}

final bookmarksControllerProvider =
    NotifierProvider<BookmarksNotifier, BookmarksState>(BookmarksNotifier.new);
