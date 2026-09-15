import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/notification_item.dart';
import '../../../models/post_author.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/list_pagination.dart';
import '../../../core/widgets/skeleton_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../../services/providers.dart';
import 'notifications_controller.dart';

/// Centro de notificaciones con datos reales (GET /notifications).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _tab = 0;

  List<NotificationItem> _filtered(List<NotificationItem> items) {
    if (_tab == 1) return items.where((n) => n.isMention).toList();
    return items;
  }

  Future<void> _onTap(NotificationItem n) async {
    final actor = n.actor;
    final isPostTarget = n.targetType == 'POST' && n.targetId != null;
    if (n.type == 'FOLLOW' && actor != null && actor.username.isNotEmpty) {
      context.push('/profile/${actor.username}');
    } else if ((n.type == 'REACTION' ||
            n.type == 'COMMENT' ||
            n.type == 'MENTION') &&
        isPostTarget) {
      context.push('/post/${n.targetId}');
    } else if ((n.type == 'WALL') ||
        (n.type == 'MENTION' && n.targetType == 'WALL_ENTRY')) {
      context.go('/app/profile');
    }
    if (!n.isRead) {
      try {
        await ref.read(notificationRepositoryProvider).markRead(n.id);
      } catch (_) {
        // Best effort: la lectura ya se sincroniza al marcar todo.
      }
    }
  }

  Future<void> _toggleFollowFromNotification(
    BuildContext context,
    PostAuthor actor,
  ) async {
    try {
      final repo = ref.read(userRepositoryProvider);
      if (actor.isFollowing) {
        await repo.unfollowUser(actor.id);
      } else {
        await repo.followUser(actor.id);
      }
      // Optimistic update: invertir el estado visualmente
      final notifier = ref.read(notificationsControllerProvider.notifier);
      notifier.updateActorFollowStatus(actor.id, !actor.isFollowing);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el seguimiento')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);
    final notifier = ref.read(notificationsControllerProvider.notifier);
    final items = _filtered(state.items);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividad'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _TabSelector(
            selected: _tab,
            onSelected: (index) => setState(() => _tab = index),
          ),
        ),
      ),
      body: _buildBody(state, notifier, items),
    );
  }

  Widget _buildBody(
    NotificationsState state,
    NotificationsNotifier notifier,
    List<NotificationItem> items,
  ) {
    if (state.loading && items.isEmpty) {
      return const SkeletonList();
    }
    if (state.error != null && items.isEmpty) {
      return ErrorView(message: state.error!, onRetry: notifier.refresh);
    }
    if (items.isEmpty) {
      return _tab == 0
          ? const EmptyView(
              icon: Icons.notifications_none_rounded,
              title: 'Aún no tienes notificaciones',
              message:
                  'Cuando alguien reaccione, comente o te mencione, aparecerá aquí.',
            )
          : const EmptyView(
              icon: Icons.alternate_email_rounded,
              title: 'Sin menciones todavía',
              message: 'Las menciones con @ aparecerán aquí.',
            );
    }
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: EndReachedNotifier(
        onEndReached: notifier.loadMore,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppDimens.pagePadding,
          itemCount: items.length + 1,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, indent: 72, endIndent: 16),
          itemBuilder: (context, index) {
            if (index >= items.length) {
              return ListEndIndicator(hasMore: state.hasMore);
            }
            final n = items[index];
            return _NotificationTile(
              item: n,
              onTap: () => _onTap(n),
              onToggleFollow: (actor) =>
                  _toggleFollowFromNotification(context, actor),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onToggleFollow,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final ValueChanged<PostAuthor> onToggleFollow;

  String get _actionText {
    final name = item.actor?.displayName ?? '';
    switch (item.type) {
      case 'FOLLOW':
        return '$name te siguió';
      case 'REACTION':
        return '$name reaccionó a tu publicación';
      case 'COMMENT':
        return '$name comentó tu publicación';
      case 'MENTION':
        return '$name te mencionó';
      case 'WALL':
        return '$name escribió en tu muro';
      default:
        return '$name interactuó contigo';
    }
  }

  IconData get _icon {
    switch (item.type) {
      case 'FOLLOW':
        return Icons.person_add_alt_1_rounded;
      case 'REACTION':
        return Icons.favorite_rounded;
      case 'COMMENT':
        return Icons.chat_bubble_rounded;
      case 'MENTION':
        return Icons.alternate_email_rounded;
      case 'WALL':
        return Icons.edit_note_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = !item.isRead;
    final actor = item.actor;
    final isFollow = item.type == 'FOLLOW';

    return Material(
      color: unread
          ? AppColors.primary.withValues(alpha: 0.05)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.xs,
            vertical: AppDimens.sm,
          ),
          child: Row(
            children: [
              AppAvatar(
                imageUrl: actor?.avatarUrl,
                name: actor?.displayName ?? '?',
                radius: AppDimens.avatarMd / 2,
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _actionText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                    if (item.text != null && item.text!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.text!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      item.timeAgo,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.xs),
              if (isFollow && actor != null)
                _FollowButton(
                  actor: actor,
                  isFollowing: actor.isFollowing,
                  onToggled: () => onToggleFollow(actor),
                )
              else
                _TypeBadge(icon: _icon),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.brandGradient,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }
}

/// Botón de seguir/dejar de seguir para notificaciones de tipo FOLLOW.
class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.actor,
    required this.isFollowing,
    required this.onToggled,
  });

  final PostAuthor actor;
  final bool isFollowing;
  final VoidCallback onToggled;

  @override
  Widget build(BuildContext context) {
    if (isFollowing) {
      return OutlinedButton(
        onPressed: onToggled,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(80, 32),
          visualDensity: VisualDensity.compact,
        ),
        child: const Text('Siguiendo', style: TextStyle(fontSize: 12)),
      );
    }
    return FilledButton(
      onPressed: onToggled,
      style: FilledButton.styleFrom(
        minimumSize: const Size(80, 32),
        visualDensity: VisualDensity.compact,
        backgroundColor: AppColors.primary,
      ),
      child: const Text('Seguir', style: TextStyle(fontSize: 12)),
    );
  }
}

/// Selector de pestañas en lenguaje visual del feed (chips redondeados),
/// evita el TabBar de Material por compatibilidad con renderizadores de
/// software en emuladores.
class _TabSelector extends StatelessWidget {
  const _TabSelector({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const _labels = ['Todo', 'Menciones'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0) const SizedBox(width: AppDimens.xs),
            Expanded(
              child: _TabChip(
                label: _labels[i],
                selected: selected == i,
                onTap: () => onSelected(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        child: AnimatedContainer(
          duration: AppDimens.motionBase,
          curve: AppDimens.curveStandard,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? AppColors.brandGradient : null,
            color: selected
                ? null
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
            border: selected
                ? null
                : Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: AppDimens.motionFast,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? Colors.white : scheme.onSurfaceVariant,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
