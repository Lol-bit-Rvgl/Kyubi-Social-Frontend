import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/providers.dart';

/// Estado de la lista de amigos (seguimiento bilateral mutuo).
class FriendsState {
  const FriendsState({
    this.friends = const [],
    this.loading = false,
    this.refreshing = false,
    this.error,
  });

  final List<User> friends;
  final bool loading;
  final bool refreshing;
  final String? error;

  bool get isEmpty => friends.isEmpty;

  FriendsState copyWith({
    List<User>? friends,
    bool? loading,
    bool? refreshing,
    String? error,
    bool clearError = false,
  }) {
    return FriendsState(
      friends: friends ?? this.friends,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Gestiona la lista reactiva de amigos con estados `loading`/`error` y
/// refresco (pull-to-refresh).
class FriendsNotifier extends Notifier<FriendsState> {
  UserRepository get _repo => ref.read(userRepositoryProvider);

  bool _disposed = false;

  @override
  FriendsState build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(_load);
    return const FriendsState();
  }

  Future<void> _load() async {
    if (_disposed) return;
    if (state.loading) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final friends = await _repo.getFriends();
      if (_disposed) return;
      state = state.copyWith(friends: friends, loading: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Refresco manual (pull-to-refresh) preservando la lista actual.
  Future<void> refresh() async {
    if (_disposed) return;
    state = state.copyWith(refreshing: true, clearError: true);
    try {
      final friends = await _repo.getFriends();
      if (_disposed) return;
      state = state.copyWith(friends: friends, refreshing: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(refreshing: false, error: e.toString());
    }
  }

  /// Carga inicial forzada (reintento desde el estado de error).
  Future<void> load() => _load();
}

final friendsControllerProvider =
    NotifierProvider<FriendsNotifier, FriendsState>(FriendsNotifier.new);