import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/wall_entry.dart';
import '../../../repositories/wall_repository.dart';
import '../../../services/providers.dart';

/// Estado del muro de un perfil (pestaña "Muro").
class UserWallCommentsState {
  const UserWallCommentsState({
    this.entries = const [],
    this.loading = false,
    this.posting = false,
    this.loadingMore = false,
    this.error,
    this.page = 0,
    this.hasMore = true,
  });

  final List<WallEntry> entries;
  final bool loading;
  final bool posting;
  final bool loadingMore;
  final String? error;
  final int page;
  final bool hasMore;

  UserWallCommentsState copyWith({
    List<WallEntry>? entries,
    bool? loading,
    bool? posting,
    bool? loadingMore,
    String? error,
    int? page,
    bool? hasMore,
  }) {
    return UserWallCommentsState(
      entries: entries ?? this.entries,
      loading: loading ?? this.loading,
      posting: posting ?? this.posting,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error ?? this.error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Comentarios del muro de un perfil (`/wall/[ownerId]`).
///
/// Consolida la lógica que antes vivía suelta en los widgets: carga paginada,
/// publicación, reacción y borrado.
class UserWallCommentsNotifier
    extends FamilyNotifier<UserWallCommentsState, String> {
  WallRepository get _repo => ref.read(wallRepositoryProvider);

  bool _disposed = false;
  late String _ownerId;

  @override
  UserWallCommentsState build(String arg) {
    ref.onDispose(() => _disposed = true);
    _ownerId = arg;
    Future.microtask(load);
    return const UserWallCommentsState();
  }

  Future<void> load() async {
    if (_disposed) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final page = await _repo.getWall(_ownerId, page: 1);
      if (_disposed) return;
      state = state.copyWith(
        entries: page.entries,
        page: 1,
        hasMore: page.entries.length >= 20 && page.pages > 1,
        loading: false,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (_disposed) return;
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repo.getWall(_ownerId, page: state.page + 1);
      if (_disposed) return;
      state = state.copyWith(
        entries: [...state.entries, ...page.entries],
        page: state.page + 1,
        hasMore: page.entries.isNotEmpty && page.pages > state.page + 1,
        loadingMore: false,
      );
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<bool> post(String text) async {
    if (_disposed) return false;
    final content = text.trim();
    if (content.isEmpty) return false;
    state = state.copyWith(posting: true);
    try {
      final entry = await _repo.createEntry(_ownerId, text: content);
      if (_disposed) return false;
      state = state.copyWith(
        entries: [entry, ...state.entries],
        posting: false,
      );
      return true;
    } catch (_) {
      if (_disposed) return false;
      state = state.copyWith(posting: false);
      return false;
    }
  }

  Future<void> toggleLike(WallEntry entry) async {
    if (_disposed) return;
    try {
      final counts = await _repo.toggleReaction(entry.id, 'like');
      if (_disposed) return;
      state = state.copyWith(
        entries: [
          for (final e in state.entries)
            if (e.id == entry.id)
              WallEntry(
                id: e.id,
                authorId: e.authorId,
                authorName: e.authorName,
                authorAvatarUrl: e.authorAvatarUrl,
                authorEmoji: e.authorEmoji,
                isAuthor: e.isAuthor,
                text: e.text,
                createdAt: e.createdAt,
                imageUrl: e.imageUrl,
                parentId: e.parentId,
                replyToUsername: e.replyToUsername,
                likes: counts.total,
                isLikedByMe: !e.isLikedByMe,
                myReaction: e.isLikedByMe ? null : 'like',
                repliesCount: e.repliesCount,
              )
            else
              e,
        ],
      );
    } catch (_) {
      // Se mantiene silencioso; el widget muestra la notificación.
      if (_disposed) return;
    }
  }

  Future<void> delete(WallEntry entry) async {
    if (_disposed) return;
    try {
      await _repo.deleteEntry(entry.id);
      if (_disposed) return;
      state = state.copyWith(
        entries: state.entries.where((e) => e.id != entry.id).toList(),
      );
    } catch (_) {
      if (_disposed) return;
    }
  }
}

final userWallCommentsProvider =
    NotifierProvider.family<
      UserWallCommentsNotifier,
      UserWallCommentsState,
      String
    >(UserWallCommentsNotifier.new);
