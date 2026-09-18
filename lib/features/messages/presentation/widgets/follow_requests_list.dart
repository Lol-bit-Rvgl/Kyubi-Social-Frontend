import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/list_pagination.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../models/user.dart';
import '../../../salas/presentation/room_invites_controller.dart';
import '../conversations_controller.dart';
import '../follow_requests_controller.dart';
import 'room_invites_list.dart';

/// Tab de invitaciones: solicitudes de seguimiento pendientes de aprobación y salas privadas.
class FollowRequestsList extends ConsumerWidget {
  const FollowRequestsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(followRequestsControllerProvider);
    final notifier = ref.read(followRequestsControllerProvider.notifier);
    final roomInvitesState = ref.watch(roomInvitesControllerProvider);
    final hasRoomInvites = roomInvitesState.invites.isNotEmpty;

    // Excluir remitentes con los cuales ya existe una conversación directa activa
    final convState = ref.watch(conversationsControllerProvider);
    final activeDirectUserIds = convState.conversations
        .where((c) => !c.isGroup)
        .map((c) => c.otherMember?.id)
        .whereType<String>()
        .toSet();

    final visibleItems = state.items
        .where((item) => !activeDirectUserIds.contains(item.requester.id))
        .toList();
    final hasFollowRequests = visibleItems.isNotEmpty;

    final isEitherLoading = (state.loading || roomInvitesState.loading) &&
        !hasRoomInvites &&
        !hasFollowRequests;

    if (isEitherLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!hasRoomInvites && !hasFollowRequests) {
      if (state.error != null || roomInvitesState.error != null) {
        return ErrorView(
          message: state.error ?? roomInvitesState.error ?? 'Error al cargar invitaciones',
          onRetry: () {
            notifier.refresh();
            ref.read(roomInvitesControllerProvider.notifier).refresh();
          },
        );
      }
      return EmptyView(
        imageWidget: Image.asset(
          AppAssets.iconSolicitudesChat,
          width: 90,
          height: 90,
          fit: BoxFit.contain,
        ),
        title: 'Sin invitaciones pendientes',
        message:
            'Las solicitudes de seguimiento e invitaciones a salas\nque recibas aparecerán aquí para que las aceptes o rechaces.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          notifier.refresh(),
          ref.read(roomInvitesControllerProvider.notifier).refresh(),
        ]);
      },
      child: EndReachedNotifier(
        onEndReached: notifier.loadMore,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
          children: [
            if (hasRoomInvites) const RoomInvitesList(),
            if (hasRoomInvites && visibleItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.md,
                  AppDimens.xs,
                  AppDimens.md,
                  AppDimens.xs,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_add_rounded,
                      size: 16,
                      color: AppColors.accentTeal,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Solicitudes de Seguimiento',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${visibleItems.length}',
                        style: const TextStyle(
                          color: AppColors.accentTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (visibleItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleItems.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppDimens.xs),
                  itemBuilder: (context, index) {
                    if (index >= visibleItems.length) {
                      return ListEndIndicator(hasMore: state.hasMore);
                    }
                    final item = visibleItems[index];
                    return _FollowRequestTile(
                      item: item,
                      busy: state.busyIds.contains(item.id),
                      onAccept: () => notifier.respond(item.id, accept: true),
                      onReject: () => notifier.respond(item.id, accept: false),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FollowRequestTile extends StatelessWidget {
  const _FollowRequestTile({
    required this.item,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  final FollowRequestItem item;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final requester = item.requester;
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      onTap: () => context.push('/profile/${requester.username}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.xs,
          vertical: AppDimens.sm,
        ),
        child: Row(
          children: [
            AppAvatar(
              imageUrl: requester.effectiveAvatarUrl,
              name: requester.displayName,
              showOnline: true,
              isOnline: requester.isOnline,
            ),
            const SizedBox(width: AppDimens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requester.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '@${requester.username}',
                    style: const TextStyle(
                      color: AppColors.textMutedNebulae,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.timeAgo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '· ${item.timeAgo}',
                      style: const TextStyle(
                        color: AppColors.gray500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            if (busy) ...[
              const SizedBox(
                width: 40,
                height: 40,
                child: Center(child: CircularProgressIndicator()),
              ),
            ] else ...[
              _IconButton(
                icon: Icons.check_rounded,
                color: AppColors.accentCyan,
                tooltip: 'Aceptar',
                onTap: onAccept,
              ),
              const SizedBox(width: AppDimens.xs),
              _IconButton(
                icon: Icons.close_rounded,
                color: AppColors.danger,
                tooltip: 'Rechazar',
                onTap: onReject,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}
