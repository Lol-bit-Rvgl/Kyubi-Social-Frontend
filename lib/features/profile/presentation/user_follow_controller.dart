import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../repositories/user_repository.dart';
import '../../../../services/providers.dart';

class UserFollowState {
  const UserFollowState({
    required this.isFollowing,
    this.isPending = false,
    this.isBusy = false,
    this.followersCount,
  });

  final bool isFollowing;
  final bool isPending;
  final bool isBusy;
  final int? followersCount;

  UserFollowState copyWith({
    bool? isFollowing,
    bool? isPending,
    bool? isBusy,
    int? followersCount,
  }) {
    return UserFollowState(
      isFollowing: isFollowing ?? this.isFollowing,
      isPending: isPending ?? this.isPending,
      isBusy: isBusy ?? this.isBusy,
      followersCount: followersCount ?? this.followersCount,
    );
  }
}

class UserFollowNotifier extends StateNotifier<UserFollowState> {
  UserFollowNotifier(this._userRepo, this.userId)
      : super(const UserFollowState(isFollowing: false));

  final UserRepository _userRepo;
  final String userId;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  void initialize({
    required bool isFollowing,
    bool isPending = false,
    int? followersCount,
    bool force = false,
  }) {
    if ((!_initialized || force) && !state.isBusy) {
      _initialized = true;
      state = UserFollowState(
        isFollowing: isFollowing,
        isPending: isPending,
        followersCount: followersCount,
      );
    }
  }

  Future<bool> toggleFollow() async {
    if (state.isBusy || userId.isEmpty) return state.isFollowing;
    final wasFollowing = state.isFollowing;
    final targetFollowing = !wasFollowing;
    final currentCount = state.followersCount ?? 0;
    final delta = targetFollowing ? 1 : -1;

    state = state.copyWith(
      isBusy: true,
      isFollowing: targetFollowing,
      followersCount: (currentCount + delta) < 0 ? 0 : (currentCount + delta),
    );

    try {
      final result = wasFollowing
          ? await _userRepo.unfollowUser(userId)
          : await _userRepo.followUser(userId);

      state = state.copyWith(
        isBusy: false,
        isFollowing: result.isFollowing,
        isPending: result.isPending,
        followersCount: result.followersCount,
      );
      return result.isFollowing;
    } catch (_) {
      state = state.copyWith(
        isBusy: false,
        isFollowing: wasFollowing,
        followersCount: currentCount,
      );
      rethrow;
    }
  }
}

final userFollowNotifierProvider =
    StateNotifierProvider.family<UserFollowNotifier, UserFollowState, String>(
  (ref, userId) => UserFollowNotifier(ref.watch(userRepositoryProvider), userId),
);
