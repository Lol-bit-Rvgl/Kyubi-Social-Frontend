import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/room.dart';
import '../../../../models/user.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';

/// Modal estilo Liquid Glass para invitar amigos o usuarios a una sala en tiempo real.
class RoomInviteFriendsSheet extends ConsumerStatefulWidget {
  const RoomInviteFriendsSheet({super.key, required this.room});

  final Room room;

  static Future<void> show(BuildContext context, {required Room room}) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoomInviteFriendsSheet(room: room),
    );
  }

  @override
  ConsumerState<RoomInviteFriendsSheet> createState() =>
      _RoomInviteFriendsSheetState();
}

class _RoomInviteFriendsSheetState
    extends ConsumerState<RoomInviteFriendsSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _invitedUserIds = <String>{};

  List<FollowItem> _friends = const <FollowItem>[];
  List<FollowItem> _filteredFriends = const <FollowItem>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Set<String> get _currentParticipantIds {
    final ids = widget.room.participants
        .map((p) => p.user.id)
        .where((id) => id.isNotEmpty)
        .toSet();
    if (widget.room.host.id.isNotEmpty) {
      ids.add(widget.room.host.id);
    }
    return ids;
  }

  Future<void> _fetchFriends() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = ref.read(authControllerProvider).user;
      final usernameOrId = user?.username ?? user?.id ?? 'me';
      final repo = ref.read(userRepositoryProvider);

      // Cargar seguidos y seguidores para armar lista de amigos
      final following = await repo.getFollowing(usernameOrId);
      final followers = await repo.getFollowers(usernameOrId);
      final currentParticipants = _currentParticipantIds;

      // Deduplicar por id excluyendo al usuario actual y a los que ya están en la sala
      final Map<String, FollowItem> map = <String, FollowItem>{};
      for (final item in following.items) {
        if (item.id != user?.id &&
            item.username != user?.username &&
            !currentParticipants.contains(item.id)) {
          map[item.id] = item;
        }
      }
      for (final item in followers.items) {
        if (item.id != user?.id &&
            item.username != user?.username &&
            !currentParticipants.contains(item.id)) {
          map.putIfAbsent(item.id, () => item);
        }
      }

      if (!mounted) return;
      setState(() {
        _friends = map.values.toList();
        _filteredFriends = _friends;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los contactos';
        _loading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredFriends = _friends);
      return;
    }

    setState(() {
      _filteredFriends = _friends.where((f) {
        final nameMatches = f.displayName.toLowerCase().contains(query);
        final usernameMatches = f.username.toLowerCase().contains(query);
        return nameMatches || usernameMatches;
      }).toList();
    });
  }

  void _inviteUser(FollowItem user) {
    if (_currentParticipantIds.contains(user.id)) return;
    if (_invitedUserIds.contains(user.id)) return;

    HapticFeedback.lightImpact();
    setState(() {
      _invitedUserIds.add(user.id);
    });

    ref.read(roomSocketProvider).emitInvite(
      roomId: widget.room.id,
      targetUserId: user.id,
      roomName: widget.room.name,
      roomBanner: widget.room.imageUrl,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.accentTeal,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Invitación enviada a @${user.username}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final maxHeight = mediaQuery.size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Color(0xFF13101E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF2C2542), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 28,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Tirador superior ──
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Cabecera ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invitar amigos a la sala',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.room.name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: () => Navigator.of(context).pop(),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Barra de Búsqueda ──
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1E192F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Buscar amigos o @usuario...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Colors.white54,
                          size: 16,
                        ),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Lista de Contactos ──
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white38,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _fetchFriends,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentTeal,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredFriends.isEmpty) {
      final isSearching = _searchController.text.trim().isNotEmpty;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching
                  ? Icons.search_off_rounded
                  : Icons.people_outline_rounded,
              color: Colors.white24,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              isSearching
                  ? 'No se encontraron amigos con ese nombre'
                  : 'Aún no tienes amigos o seguidos para invitar',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _filteredFriends.length,
      separatorBuilder: (context, index) => const Divider(
        color: Colors.white10,
        height: 1,
        indent: 56,
      ),
      itemBuilder: (context, index) {
        final friend = _filteredFriends[index];
        final isAlreadyInRoom = _currentParticipantIds.contains(friend.id);
        final isInvited = _invitedUserIds.contains(friend.id);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF2C2542),
                backgroundImage: (friend.avatarUrl != null &&
                        friend.avatarUrl!.isNotEmpty)
                    ? NetworkImage(friend.avatarUrl!)
                    : null,
                child: (friend.avatarUrl == null || friend.avatarUrl!.isEmpty)
                    ? Text(
                        friend.displayName.isNotEmpty
                            ? friend.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Nombre y @handle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${friend.username}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Botón Invitar / En la sala / Invitado
              if (isAlreadyInRoom)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.meeting_room_rounded,
                        color: Colors.white60,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'En la sala',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else if (isInvited)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.accentTeal.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.accentTeal,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Invitado',
                        style: TextStyle(
                          color: AppColors.accentTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: () => _inviteUser(friend),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Invitar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
