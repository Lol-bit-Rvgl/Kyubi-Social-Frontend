import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/skeleton_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/user.dart';
import '../../../services/providers.dart';
import '../../messages/presentation/conversations_controller.dart';
import 'friends_controller.dart';

/// Abre (o crea) la conversación directa con un amigo y navega a ella.
Future<void> openFriendChat(BuildContext context, WidgetRef ref, User friend) async {
  HapticFeedback.selectionClick();
  try {
    final conversation = await ref
        .read(chatRepositoryProvider)
        .openOrCreateDirect(friend.id, username: friend.username);
    ref
        .read(conversationsControllerProvider.notifier)
        .upsertConversation(conversation);
    if (!context.mounted) return;
    context.push('/conversation/${conversation.id}');
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la conversación')),
      );
  }
}

/// Contenido reutilizable de la lista de amigos (hoja modal y pantalla).
///
/// - [RefreshIndicator] para pull-to-refresh.
/// - [EmptyView] cuando aún no hay amigos mutuos.
/// - Soporta [shrinkWrap] para encajar dentro de una hoja inferior.
class FriendsListView extends ConsumerWidget {
  const FriendsListView({
    super.key,
    this.onFriendTap,
    this.shrinkWrap = false,
  });

  /// Acción al tocar un amigo. Si es null se abre el chat directo.
  final ValueChanged<User>? onFriendTap;

  /// `true` dentro de hojas modales (la lista se ajusta a su contenido).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(friendsControllerProvider);
    final notifier = ref.read(friendsControllerProvider.notifier);

    if (state.loading && state.friends.isEmpty) {
      return const SkeletonList(itemCount: 5);
    }

    if (state.error != null && state.friends.isEmpty) {
      return ErrorView(message: state.error!, onRetry: notifier.load);
    }

    final physics = const AlwaysScrollableScrollPhysics(
      parent: ClampingScrollPhysics(),
    );

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      displacement: 32,
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: const Color(0xFF0D0A14),
      child: state.friends.isEmpty
          ? ListView(
              shrinkWrap: shrinkWrap,
              physics: physics,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                const SizedBox(height: 28),
                EmptyView(
                  icon: Icons.group_outlined,
                  title: 'Aún no tienes amigos',
                  message:
                      'Sigue a personas que te sigan de vuelta para convertirlos en amigos.',
                  actionLabel: 'Buscar personas',
                  onAction: () {
                    HapticFeedback.selectionClick();
                    context.push('/search');
                  },
                ),
              ],
            )
          : ListView.separated(
              shrinkWrap: shrinkWrap,
              physics: physics,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
              itemCount: state.friends.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final friend = state.friends[index];
                return _FriendTile(
                  friend: friend,
                  onTap: () {
                    final handler = onFriendTap;
                    if (handler != null) {
                      handler(friend);
                      return;
                    }
                    openFriendChat(context, ref, friend);
                  },
                );
              },
            ),
    );
  }
}
/// Fila de amigo: avatar con estado, nombre, @username y acción de chat.
class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onTap});

  final User friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nameColor = friend.usernameColor != null
        ? AppColors.fromHex(friend.usernameColor)
        : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.primary.withValues(alpha: 0.10),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF14141B).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF22222E),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              AppAvatar(
                imageUrl: friend.effectiveAvatarUrl,
                name: friend.displayName,
                radius: 22,
                showOnline: true,
                isOnline: friend.isOnline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      friend.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: nameColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      friend.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMutedNebulae,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _OnlineBadge(isOnline: friend.isOnline),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Enviar mensaje',
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 19,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicador textual de conexión (punto + etiqueta) del amigo.
class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.success : const Color(0xFF6A6A7A);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          isOnline ? 'En línea' : 'Desconectado',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
/// Hoja modal inferior con la lista de amigos del usuario autenticado.
class FriendsListSheet extends ConsumerWidget {
  const FriendsListSheet({super.key});

  /// Presenta la hoja con el estilo Liquid Glass de Kyubi.
  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FriendsListSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;
    final friends = ref.watch(friendsControllerProvider).friends;

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
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Tirador superior ──
            Padding(
              padding: const EdgeInsets.only(top: 12),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.group_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Amigos',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          friends.isEmpty
                              ? 'Seguimiento mutuo'
                              : '${friends.length} ${friends.length == 1 ? 'amigo' : 'amigos'} con seguimiento mutuo',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMutedNebulae,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Lista de amigos ──
            Flexible(
              fit: FlexFit.loose,
              child: const FriendsListView(shrinkWrap: true),
            ),
          ],
        ),
      ),
    );
  }
}
