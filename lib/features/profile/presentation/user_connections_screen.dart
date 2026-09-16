import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/liquid_glass_container.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../models/user.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';

/// Pantalla unificada de Conexiones de Usuario ("Seguidores" y "Siguiendo") con pestañas interactuables.
class UserConnectionsScreen extends ConsumerStatefulWidget {
  const UserConnectionsScreen({
    super.key,
    required this.username,
    this.initialTab = 'followers',
  });

  final String username;
  final String initialTab; // 'followers' o 'following'

  @override
  ConsumerState<UserConnectionsScreen> createState() =>
      _UserConnectionsScreenState();
}

class _UserConnectionsScreenState extends ConsumerState<UserConnectionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab.toLowerCase() == 'following' ? 1 : 0;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF13101E),
        elevation: 0,
        title: Text(
          '@${widget.username}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Seguidores'),
            Tab(text: 'Siguiendo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ConnectionsListTab(
            username: widget.username,
            isFollowingTab: false,
          ),
          _ConnectionsListTab(
            username: widget.username,
            isFollowingTab: true,
          ),
        ],
      ),
    );
  }
}

class _ConnectionsListTab extends ConsumerStatefulWidget {
  const _ConnectionsListTab({
    required this.username,
    required this.isFollowingTab,
  });

  final String username;
  final bool isFollowingTab;

  @override
  ConsumerState<_ConnectionsListTab> createState() => _ConnectionsListTabState();
}

class _ConnectionsListTabState extends ConsumerState<_ConnectionsListTab> {
  final _scrollController = ScrollController();
  List<FollowItem> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextCursor;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _nextCursor != null) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(userRepositoryProvider);
      final result = widget.isFollowingTab
          ? await repo.getFollowing(widget.username)
          : await repo.getFollowers(widget.username);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _nextCursor = result.nextCursor;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_nextCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      final result = widget.isFollowingTab
          ? await repo.getFollowing(widget.username, cursor: _nextCursor)
          : await repo.getFollowers(widget.username, cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...result.items];
        _nextCursor = result.nextCursor;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleFollow(FollowItem item) async {
    final myId = ref.read(authControllerProvider).user?.id;
    if (myId == item.id) return; // No seguirse a uno mismo

    final repo = ref.read(userRepositoryProvider);
    try {
      final result = item.isFollowing
          ? await repo.unfollowUser(item.id)
          : await repo.followUser(item.id);
      if (!mounted) return;
      setState(() {
        _items = _items.map((i) {
          if (i.id != item.id) return i;
          return FollowItem(
            id: i.id,
            username: i.username,
            displayName: i.displayName,
            avatarUrl: i.avatarUrl,
            bio: i.bio,
            usernameColor: i.usernameColor,
            avatarFrame: i.avatarFrame,
            level: i.level,
            isOnline: i.isOnline,
            isFollowing: result.isFollowing,
            pendingFollow: result.isPending,
            followedAt: i.followedAt,
          );
        }).toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el seguimiento')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return EmptyView(
        icon: widget.isFollowingTab
            ? Icons.person_add_rounded
            : Icons.group_off_rounded,
        title: widget.isFollowingTab ? 'No sigue a nadie' : 'Sin seguidores',
        message: widget.isFollowingTab
            ? 'Este usuario aún no sigue a ningún panita.'
            : 'Este usuario aún no tiene seguidores en Kyubi.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.sm,
        ),
        itemCount: _items.length + (_nextCursor != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return _loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(AppDimens.md),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
          final item = _items[index];
          final myId = ref.watch(authControllerProvider).user?.id;
          final isMe = myId != null && myId == item.id;

          return LiquidGlassContainer(
            borderRadius: 14,
            padding: const EdgeInsets.all(12),
            child: InkWell(
              onTap: () => context.push('/profile/${item.username}'),
              child: Row(
                children: [
                  AppAvatar(
                    name: item.displayName,
                    imageUrl: item.avatarUrl,
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '@${item.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (item.bio != null && item.bio!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              item.bio!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9E9EAF),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isMe) ...[
                    const SizedBox(width: 8),
                    item.isFollowing
                        ? OutlinedButton(
                            onPressed: () => _toggleFollow(item),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Siguiendo', style: TextStyle(fontSize: 12)),
                          )
                        : FilledButton(
                            onPressed: () => _toggleFollow(item),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Seguir', style: TextStyle(fontSize: 12)),
                          ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
