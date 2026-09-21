import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/circle.dart';
import '../../../models/post.dart';
import '../../../models/room.dart';
import '../../../repositories/circle_repository.dart';
import '../../../services/providers.dart';

/// Estado del detalle de un círculo: datos + posts paginados + salas activas.
class CircleDetailState {
  const CircleDetailState({
    this.circle,
    this.posts = const [],
    this.rooms = const [],
    this.loading = false,
    this.error,
    this.postsLoading = false,
    this.postsError,
    this.roomsLoading = false,
    this.roomsError,
    this.loadingMore = false,
    this.nextCursor,
    this.hasMore = false,
    this.acting = false,
  });

  final Circle? circle;
  final List<Post> posts;
  final List<Room> rooms;
  final bool loading;
  final String? error;
  final bool postsLoading;
  final String? postsError;
  final bool roomsLoading;
  final String? roomsError;
  final bool loadingMore;
  final String? nextCursor;
  final bool hasMore;
  final bool acting;

  CircleDetailState copyWith({
    Circle? circle,
    List<Post>? posts,
    List<Room>? rooms,
    bool? loading,
    String? error,
    bool? postsLoading,
    String? postsError,
    bool? roomsLoading,
    String? roomsError,
    bool? loadingMore,
    String? nextCursor,
    bool? hasMore,
    bool? acting,
  }) {
    return CircleDetailState(
      circle: circle ?? this.circle,
      posts: posts ?? this.posts,
      rooms: rooms ?? this.rooms,
      loading: loading ?? this.loading,
      error: error ?? this.error,
      postsLoading: postsLoading ?? this.postsLoading,
      postsError: postsError ?? this.postsError,
      roomsLoading: roomsLoading ?? this.roomsLoading,
      roomsError: roomsError ?? this.roomsError,
      loadingMore: loadingMore ?? this.loadingMore,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      acting: acting ?? this.acting,
    );
  }
}

class CircleDetailNotifier extends FamilyNotifier<CircleDetailState, String> {
  CircleRepository get _repo => ref.read(circleRepositoryProvider);

  bool _disposed = false;

  @override
  CircleDetailState build(String arg) {
    ref.onDispose(() => _disposed = true);
    _circleId = arg;
    Future.microtask(_load);
    return const CircleDetailState();
  }

  late String _circleId;

  Future<void> _load() async {
    if (_disposed) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final circle = await _repo.getCircle(_circleId);
      if (_disposed) return;
      state = state.copyWith(circle: circle, loading: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
    await _loadPosts();
    await _loadRooms();
  }

  Future<void> _loadRooms() async {
    if (_disposed) return;
    state = state.copyWith(roomsLoading: true, roomsError: null);
    try {
      final roomRepo = ref.read(roomRepositoryProvider);
      final rooms = await roomRepo.getSalas(circleId: _circleId, limit: 50);
      if (_disposed) return;
      state = state.copyWith(rooms: rooms, roomsLoading: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(roomsLoading: false, roomsError: e.toString());
    }
  }

  Future<void> _loadPosts() async {
    if (_disposed) return;
    state = state.copyWith(postsLoading: true, postsError: null);
    try {
      final page = await _repo.getCirclePosts(_circleId, limit: 20);
      if (_disposed) return;
      state = state.copyWith(
        posts: page.posts,
        nextCursor: page.nextCursor,
        hasMore: page.nextCursor != null,
        postsLoading: false,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(postsLoading: false, postsError: e.toString());
    }
  }

  Future<void> refresh() async {
    await _load();
  }

  Future<void> loadMorePosts() async {
    if (_disposed) return;
    if (state.loadingMore || !state.hasMore || state.nextCursor == null) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repo.getCirclePosts(
        _circleId,
        limit: 20,
        cursor: state.nextCursor,
      );
      if (_disposed) return;
      state = state.copyWith(
        posts: [...state.posts, ...page.posts],
        nextCursor: page.nextCursor,
        hasMore: page.nextCursor != null,
        loadingMore: false,
      );
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  /// Une al usuario al círculo; el OWNER no puede salir.
  Future<void> join() async {
    if (_disposed) return;
    if (state.acting) return;
    state = state.copyWith(acting: true);
    try {
      final circle = await _repo.joinCircle(_circleId);
      if (_disposed) return;
      state = state.copyWith(circle: circle, acting: false);
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(acting: false);
      rethrow;
    }
  }

  Future<void> leave() async {
    if (_disposed) return;
    if (state.acting) return;
    state = state.copyWith(acting: true);
    try {
      final circle = await _repo.leaveCircle(_circleId);
      if (_disposed) return;
      state = state.copyWith(circle: circle, acting: false);
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(acting: false);
      rethrow;
    }
  }

  /// Inserta un post recién creado en el inicio de la lista.
  void insertPostAtTop(Post post) {
    state = state.copyWith(posts: [post, ...state.posts]);
  }

  void updatePost(Post post) {
    state = state.copyWith(
      posts: [for (final p in state.posts) p.id == post.id ? post : p],
    );
  }
}

final circleDetailControllerProvider =
    NotifierProvider.family<CircleDetailNotifier, CircleDetailState, String>(
      CircleDetailNotifier.new,
    );
