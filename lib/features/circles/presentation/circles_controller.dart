import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/circle.dart';
import '../../../models/room.dart';
import '../../../models/user.dart';
import '../../../repositories/circle_repository.dart';
import '../../../repositories/room_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/providers.dart';

/// Estado integral del Hub de Descubrimiento (Comunidades, Salas en Vivo y Personas Sugeridas).
class CirclesState {
  const CirclesState({
    this.circles = const [],
    this.rooms = const [],
    this.suggestedUsers = const [],
    this.followedUserIds = const {},
    this.selectedTag = 'Todos',
    this.loading = false,
    this.refreshing = false,
    this.error,
  });

  final List<Circle> circles;
  final List<Room> rooms;
  final List<FollowItem> suggestedUsers;
  final Set<String> followedUserIds;
  final String selectedTag;
  final bool loading;
  final bool refreshing;
  final String? error;

  CirclesState copyWith({
    List<Circle>? circles,
    List<Room>? rooms,
    List<FollowItem>? suggestedUsers,
    Set<String>? followedUserIds,
    String? selectedTag,
    bool? loading,
    bool? refreshing,
    String? error,
  }) {
    return CirclesState(
      circles: circles ?? this.circles,
      rooms: rooms ?? this.rooms,
      suggestedUsers: suggestedUsers ?? this.suggestedUsers,
      followedUserIds: followedUserIds ?? this.followedUserIds,
      selectedTag: selectedTag ?? this.selectedTag,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      error: error ?? this.error,
    );
  }
}

class CirclesNotifier extends Notifier<CirclesState> {
  CircleRepository get _circleRepo => ref.read(circleRepositoryProvider);
  RoomRepository get _roomRepo => ref.read(roomRepositoryProvider);
  UserRepository get _userRepo => ref.read(userRepositoryProvider);

  bool _disposed = false;

  @override
  CirclesState build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(_loadAll);
    return const CirclesState();
  }

  Future<void> _loadAll() async {
    if (_disposed) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final circlesFuture = _circleRepo.getCircles(limit: 15);
      final roomsFuture = _roomRepo.getSalas(limit: 15);
      final usersFuture = _userRepo.suggestPeople(limit: 15);

      final circles = await circlesFuture;
      final allRooms = await roomsFuture;
      final users = await usersFuture;

      final activeRooms = allRooms
          .where((r) => r.status == RoomStatus.active)
          .toList();

      if (_disposed) return;
      state = state.copyWith(
        circles: circles,
        rooms: activeRooms,
        suggestedUsers: users,
        followedUserIds: {
          for (final u in users)
            if (u.isFollowing) u.id,
        },
        loading: false,
      );
    } catch (_) {
      if (_disposed) return;
      // En caso de fallo de red se conserva el estado real previo (nunca fakes).
      state = state.copyWith(loading: false);
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    state = state.copyWith(refreshing: true, error: null);
    try {
      final circlesFuture = _circleRepo.getCircles(limit: 15);
      final roomsFuture = _roomRepo.getSalas(limit: 15);
      final usersFuture = _userRepo.suggestPeople(limit: 15);

      final circles = await circlesFuture;
      final allRooms = await roomsFuture;
      final users = await usersFuture;

      final activeRooms = allRooms
          .where((r) => r.status == RoomStatus.active)
          .toList();

      if (_disposed) return;
      state = state.copyWith(
        circles: circles,
        rooms: activeRooms,
        suggestedUsers: users,
        refreshing: false,
      );
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(refreshing: false);
    }
  }

  void selectTag(String tag) {
    state = state.copyWith(selectedTag: tag);
  }

  Future<void> toggleFollow(String userId) async {
    final currentlyFollowing = state.followedUserIds.contains(userId);
    final nextSet = Set<String>.from(state.followedUserIds);
    if (currentlyFollowing) {
      nextSet.remove(userId);
    } else {
      nextSet.add(userId);
    }
    state = state.copyWith(followedUserIds: nextSet);

    try {
      if (currentlyFollowing) {
        await _userRepo.unfollowUser(userId);
      } else {
        await _userRepo.followUser(userId);
      }
    } catch (_) {
      // Revertir si hay error de red
      if (!_disposed) {
        state = state.copyWith(followedUserIds: state.followedUserIds);
      }
    }
  }
}

final circlesControllerProvider =
    NotifierProvider<CirclesNotifier, CirclesState>(CirclesNotifier.new);
