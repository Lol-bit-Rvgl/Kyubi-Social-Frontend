import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/animated_fluid_background.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/liquid_glass_container.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../models/chat_conversation.dart';
import '../../../../services/auth_controller.dart';
import '../../salas/presentation/room_invites_controller.dart';
import '../../salas/presentation/salas_controller.dart';
import '../../salas/presentation/widgets/live_room_card.dart';
import 'conversations_controller.dart';
import 'follow_requests_controller.dart';
import 'widgets/follow_requests_list.dart';
import 'widgets/new_chat_sheet.dart';

enum _MessageSection { private, rooms, invites, mentions }

/// Centro de Mensajes y Salas en Vivo estilo Project Z.
/// 4 pestañas: Private, Rooms, Invites, @Mentions.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _MessageSection.values.length,
      vsync: this,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<Conversation> _filterDirects(
    List<Conversation> conversations,
    String query,
  ) {
    final directs = conversations.where((c) => !c.isGroup).toList();
    if (query.trim().isEmpty) return directs;
    final q = query.toLowerCase();
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    // Filtro local en memoria (sin navegación): nombre visible, username
    // del otro miembro o contenido del último mensaje.
    return directs.where((c) {
      final other = c.resolveOtherMember(myId);
      final nameHit =
          c.displayName.toLowerCase().contains(q) ||
          (other?.displayName.toLowerCase().contains(q) ?? false) ||
          (other?.username.toLowerCase().contains(q) ?? false);
      final messageHit =
          (c.lastMessage?.body ?? '').toLowerCase().contains(q);
      return nameHit || messageHit;
    }).toList();
  }

  int _totalUnread(ConversationsState state) {
    return state.conversations.fold(0, (sum, c) => sum + c.unreadCount);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsControllerProvider);
    final salasState = ref.watch(salasControllerProvider);
    final totalUnread = _totalUnread(state);

    return AnimatedFluidBackground(
      assetPath: 'assets/images/bg_fluid_ambient.webp',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (_tabController.index == 1) {
              context.push('/salas/create');
            } else {
              // Flujo estándar "Nuevo chat": sheet de contactos, sin pasar
              // por la búsqueda global de seguimiento.
              NewChatSheet.show(context);
            }
          },
          backgroundColor: const Color(0xFF3B2D60),
          child: Icon(
            _tabController.index == 1 ? Icons.add_rounded : Icons.edit_rounded,
            color: Colors.white,
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(totalUnread),
              _buildSearchBar(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPrivateTab(state),
                    _buildRoomsTab(salasState),
                    _buildInvitesTab(),
                    _buildMentionsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _buildHeader(int totalUnread) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final avatarUrl = user?.effectiveAvatarUrl;
    final displayName = user?.displayName ?? 'Lolbit';

    return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.md,
          AppDimens.sm,
          AppDimens.md,
          AppDimens.xs,
        ),
        child: Row(
          children: [
            // ── Avatar con estado y tap para drawer ──
            GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1E1E2A),
                    ),
                    padding: const EdgeInsets.all(1.5),
                    child: AppAvatar(
                      imageUrl: avatarUrl,
                      name: displayName,
                      radius: 19,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: user?.isOnline ?? true
                            ? AppColors.success
                            : const Color(0xFF7A7A8A),
                        border: Border.all(
                          color: AppColors.backgroundBase,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Título ──
            const Expanded(
              child: Text(
                'My Chats',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // ── Botón: Marcar todo como leído ──
            if (totalUnread > 0)
              GestureDetector(
                onTap: _markAllRead,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141B),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    border: Border.all(
                      color: const Color(0xFF22222E),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.done_all_rounded,
                    size: 20,
                    color: Color(0xFF9E9EA8),
                  ),
                ),
              ),
            if (totalUnread > 0) const SizedBox(width: 8),

            // ── Botón: Crear sala (acceso directo, sin intermedios) ──
            GestureDetector(
              onTap: () => context.push('/salas/create'),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF14141B),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  border: Border.all(
                    color: const Color(0xFF22222E),
                    width: 0.8,
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
  }

  // ── Search bar ────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: 8,
      ),
      child: LiquidGlassContainer(
        borderRadius: 16,
        blur: 14,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF6A6A7A)),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFF6A6A7A),
            ),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                      _searchFocusNode.unfocus();
                    },
                  )
                : null,
            isDense: true,
            filled: true,
            fillColor: Colors.transparent,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF9E8CD9), width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDimens.md,
              vertical: 11,
            ),
          ),
        ),
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final state = ref.watch(conversationsControllerProvider);
    final totalUnread = _totalUnread(state);
    final currentUserId = ref.watch(authControllerProvider).user?.id ?? '';
    final activeDirectUserIds = state.conversations
        .where((c) => !c.isGroup)
        // Resolución dinámica: otherMember puede venir nulo (socket/caché).
        .map((c) => c.resolveOtherMember(currentUserId)?.id)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final roomInvitesCount =
        ref.watch(roomInvitesControllerProvider).invites.length;
    final followInvitesCount = ref
        .watch(followRequestsControllerProvider)
        .items
        .where((req) => !activeDirectUserIds.contains(req.requester.id))
        .length;
    final inviteCount = roomInvitesCount + followInvitesCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDimens.md, 8, AppDimens.md, 8),
      child: LiquidGlassContainer(
        borderRadius: 20,
        blur: 12,
        padding: const EdgeInsets.all(3),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: const Color(0xFFA594F9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA594F9).withValues(alpha: 0.3),
                blurRadius: 8,
              ),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF8A8A9A),
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            _buildTabWithBadge('Private', totalUnread),
            const Tab(text: 'Rooms'),
            _buildTabWithBadge('Invites', inviteCount),
            const Tab(text: '@Mentions'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabWithBadge(String label, int badgeCount) {
    if (badgeCount == 0) return Tab(text: label);
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Container(
            constraints: const BoxConstraints(minWidth: 16),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF9B6FCB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeCount > 99 ? '99+' : '$badgeCount',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab: Private (DMs) ──────────────────────────────────────────────

  Widget _buildPrivateTab(ConversationsState state) {
    final directs = _filterDirects(state.conversations, _query);
    final currentUserId = ref.watch(authControllerProvider).user?.id ?? '';

    if (state.loading && state.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.conversations.isEmpty) {
      return ErrorView(
        message: state.error!,
        onRetry: () =>
            ref.read(conversationsControllerProvider.notifier).refresh(),
        title: 'No se pudieron cargar los mensajes',
      );
    }
    if (directs.isEmpty) {
      return EmptyView(
        imageWidget: Image.asset(
          AppAssets.iconMensajesVacios,
          width: 90,
          height: 90,
          fit: BoxFit.contain,
        ),
        title: 'Sin conversaciones directas',
        message:
            'Inicia un chat desde el perfil de cualquier usuario\no busca amigos en la comunidad.',
        actionLabel: 'Buscar usuarios',
        onAction: () => context.push('/search'),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(conversationsControllerProvider.notifier).refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.xs,
        ),
        itemCount: directs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final conversation = directs[index];
          return _ConversationCard(
            conversation: conversation,
            currentUserId: currentUserId,
            pinned: state.pinnedIds.contains(conversation.id),
            onTap: () => _open(conversation),
          );
        },
      ),
    );
  }

  // ── Tab: Rooms ─────────────────────────────────────────────────────

  Widget _buildRoomsTab(SalasState state) {
    final currentUserId = ref.watch(authControllerProvider).user?.id ?? '';
    final rooms = state.activeRoomsForUser(currentUserId);
    if (state.loading && rooms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && rooms.isEmpty) {
      return ErrorView(
        message: state.error!,
        onRetry: () => ref.read(salasControllerProvider.notifier).refresh(),
        title: 'No se pudieron cargar las salas',
      );
    }
    if (rooms.isEmpty) {
      return EmptyView(
        imageWidget: Image.asset(
          AppAssets.iconSalasVacias,
          width: 90,
          height: 90,
          fit: BoxFit.contain,
        ),
        title: 'No estás en ninguna sala',
        message:
            'Únete o crea una sala para verla aquí.\nLas salas públicas solo aparecen una vez que entres.',
        actionLabel: 'Crear Sala',
        onAction: () => context.push('/salas/create'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(salasControllerProvider.notifier).refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.xs,
        ),
        itemCount: rooms.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final room = rooms[index];
          return LiveRoomCard(room: room);
        },
      ),
    );
  }

  // ── Tab: Invites ───────────────────────────────────────────────────

  Widget _buildInvitesTab() {
    // Solicitudes de seguimiento pendientes de aprobación (follow con aprobación).
    return const FollowRequestsList();
  }

  // ── Tab: Mentions ──────────────────────────────────────────────────

  Widget _buildMentionsTab() {
    // Pestaña de menciones pendientes con asset oficial
    return EmptyView(
      imageWidget: Image.asset(
        AppAssets.iconMenciones,
        width: 90,
        height: 90,
        fit: BoxFit.contain,
      ),
      title: 'No tienes menciones pendientes',
      message:
          'Cuando alguien te mencione en un chat grupal\no sala, aparecerá aquí.',
    );
  }

  // ── Actions ────────────────────────────────────────────────────────

  void _open(Conversation conversation) {
    ref
        .read(conversationsControllerProvider.notifier)
        .markRead(conversation.id);
    // DMs van a ChatDirectoScreen, group conversations a ConversationScreen.
    if (conversation.isGroup) {
      context.push('/conversation/${conversation.id}');
    } else {
      context.push('/dm/${conversation.id}');
    }
  }

  void _markAllRead() {
    final conversations = ref
        .read(conversationsControllerProvider)
        .conversations;
    for (final c in conversations) {
      if (c.unreadCount > 0) {
        ref.read(conversationsControllerProvider.notifier).markRead(c.id);
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Tarjeta de conversación estilo Project Z
// ─────────────────────────────────────────────────────────────

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
    this.pinned = false,
  });

  final Conversation conversation;
  final String currentUserId;
  final VoidCallback onTap;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Resolución dinámica del destinatario: otherMember → members. Evita los
    // fallbacks quemados ('Conversación', avatar 'C', '@usuario').
    final otherUser = conversation.resolveOtherMember(currentUserId);
    final otherName = otherUser?.displayName.isNotEmpty == true
        ? otherUser!.displayName
        : otherUser?.username;
    final title = (otherName != null && otherName.isNotEmpty)
        ? otherName
        : conversation.displayName;
    final otherHandle = otherUser?.username ?? '';
    final lastMessage = conversation.lastMessage;
    final preview = lastMessage == null
        ? 'Nueva conversación'
        : lastMessage.isDeleted
        ? 'Mensaje eliminado'
        : lastMessage.body;
    final hasUnread = conversation.unreadCount > 0;
    final streakDays = conversation.streakDays;
    final streakIcon = AppFriendshipIcons.iconForStreakDays(streakDays);
    final streakLevel = AppFriendshipIcons.levelForStreakDays(streakDays);

    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassContainer(
        width: double.infinity,
        borderRadius: AppDimens.radiusCard,
        blur: 12,
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            if (hasUnread)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9B6FCB), Color(0xFF5BC8AF)],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppDimens.radiusCard),
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                AppAvatar(
                  imageUrl: otherUser?.avatarUrl ?? conversation.avatarUrl,
                  name: title,
                  radius: 24,
                  showOnline: true,
                  isOnline: otherUser?.isOnline ?? false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: hasUnread
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: 15,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (streakDays >= 1 && streakIcon != null) ...[
                                  const SizedBox(width: 5),
                                  Tooltip(
                                    message:
                                        'Racha de amistad: $streakDays días (Nivel $streakLevel)',
                                    child: Image.asset(
                                      streakIcon,
                                      width: 16,
                                      height: 16,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (conversation.lastMessage?.createdAt != null)
                            Text(
                              _formatTime(conversation.lastMessage!.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: hasUnread
                                    ? const Color(0xFF9B6FCB)
                                    : const Color(0xFF7A7A8A),
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                      if (otherHandle.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          '@$otherHandle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF7A7A8A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: hasUnread
                                    ? Colors.white
                                    : const Color(0xFF8A8A9A),
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (streakDays >= 1 && streakIcon != null) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message:
                                  'Racha de amistad: $streakDays días (Nivel $streakLevel)',
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E172F),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFA594F9)
                                        .withValues(alpha: 0.35),
                                    width: 0.7,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      streakIcon,
                                      width: 14,
                                      height: 14,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$streakDays d',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFA594F9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              constraints: const BoxConstraints(minWidth: 18),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF9B6FCB),
                                    Color(0xFF7A5AA6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${conversation.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          if (pinned) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.push_pin_rounded,
                              size: 15,
                              color: AppColors.accentCyan,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.day}/${date.month}';
  }
}
