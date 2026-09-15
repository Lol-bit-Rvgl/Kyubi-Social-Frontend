import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../models/user.dart';
import '../../../../services/providers.dart';

enum FollowListType { followers, following }

class FollowListScreen extends ConsumerStatefulWidget {
  const FollowListScreen({
    super.key,
    required this.username,
    required this.type,
  });

  final String username;
  final FollowListType type;

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> {
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
      final result = widget.type == FollowListType.followers
          ? await repo.getFollowers(widget.username)
          : await repo.getFollowing(widget.username);
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
      final result = widget.type == FollowListType.followers
          ? await repo.getFollowers(widget.username, cursor: _nextCursor)
          : await repo.getFollowing(widget.username, cursor: _nextCursor);
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
    final title = widget.type == FollowListType.followers
        ? 'Seguidores'
        : 'Siguiendo';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView(message: 'Cargando...');
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return EmptyView(
        icon: widget.type == FollowListType.followers
            ? Icons.group_off_rounded
            : Icons.person_add_rounded,
        title: widget.type == FollowListType.followers
            ? 'Sin seguidores'
            : 'No sigue a nadie',
        message: widget.type == FollowListType.followers
            ? 'Este usuario aún no tiene seguidores.'
            : 'Este usuario aún no sigue a nadie.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        padding: AppDimens.pagePadding,
        itemCount: _items.length + (_nextCursor != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppDimens.xs),
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
          return _FollowTile(
            item: item,
            onTap: () => context.push('/profile/${item.username}'),
            onFollowToggle: () => _toggleFollow(item),
          );
        },
      ),
    );
  }
}

class _FollowTile extends StatelessWidget {
  const _FollowTile({
    required this.item,
    required this.onTap,
    required this.onFollowToggle,
  });

  final FollowItem item;
  final VoidCallback onTap;
  final VoidCallback onFollowToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nameColor = AppColors.fromHex(item.usernameColor);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: AppAvatar(
          imageUrl: item.avatarUrl,
          name: item.displayName,
          radius: AppDimens.avatarMd / 2,
          showOnline: true,
          isOnline: item.isOnline,
          onTap: onTap,
        ),
        title: Text(
          item.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700, color: nameColor),
        ),
        subtitle: Text(
          '@${item.username}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        trailing: item.isFollowing
            ? OutlinedButton(
                onPressed: onFollowToggle,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Siguiendo', style: TextStyle(fontSize: 12)),
              )
            : FilledButton(
                onPressed: onFollowToggle,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Seguir', style: TextStyle(fontSize: 12)),
              ),
        onTap: onTap,
      ),
    );
  }
}
