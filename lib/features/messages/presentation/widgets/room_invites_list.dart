import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/system_toast.dart';
import '../../../../models/room.dart';
import '../../../salas/presentation/room_invites_controller.dart';
import '../../../salas/presentation/sala_detail_screen.dart';

/// Lista de invitaciones a salas privadas pendientes (rol INVITED).
class RoomInvitesList extends ConsumerWidget {
  const RoomInvitesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(roomInvitesControllerProvider);
    final notifier = ref.read(roomInvitesControllerProvider.notifier);

    if (state.invites.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.md,
            AppDimens.sm,
            AppDimens.md,
            AppDimens.xs,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.meeting_room_rounded,
                size: 16,
                color: AppColors.accentCyan,
              ),
              const SizedBox(width: 8),
              const Text(
                'Invitaciones a Salas',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${state.invites.length}',
                  style: const TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md,
            vertical: AppDimens.xs,
          ),
          itemCount: state.invites.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppDimens.xs),
          itemBuilder: (context, index) {
            final room = state.invites[index];
            final busy = state.busyIds.contains(room.id);
            return _RoomInviteTile(
              room: room,
              busy: busy,
              onAccept: () async {
                HapticFeedback.lightImpact();
                final acceptedRoom = await notifier.acceptInvite(room.id);
                if (acceptedRoom != null && context.mounted) {
                  showSystemToast(
                    context,
                    emoji: '🎉',
                    message: '¡Te has unido a "${acceptedRoom.name}"!',
                    accentColor: AppColors.accentTeal,
                  );
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SalaDetailScreen(
                        roomId: acceptedRoom.id,
                        forceConnected: true,
                      ),
                    ),
                  );
                }
              },
              onReject: () {
                HapticFeedback.lightImpact();
                notifier.rejectInvite(room.id);
              },
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: 8),
          child: Divider(color: Color(0xFF222035), height: 1),
        ),
      ],
    );
  }
}

class _RoomInviteTile extends StatelessWidget {
  const _RoomInviteTile({
    required this.room,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  final Room room;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final host = room.host;
    final coverUrl = room.imageUrl ?? host.avatarUrl;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14121F),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: const Color(0xFF2A283E), width: 0.8),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.sm,
        vertical: AppDimens.sm,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 46,
              height: 46,
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _buildFallback(room.name),
                    )
                  : _buildFallback(room.name),
            ),
          ),
          const SizedBox(width: AppDimens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Invitado por @${host.username.isNotEmpty ? host.username : host.displayName}',
                  style: const TextStyle(
                    color: AppColors.textMutedNebulae,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.sm),
          if (busy)
            const SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            _ActionIconButton(
              icon: Icons.check_rounded,
              color: AppColors.accentCyan,
              tooltip: 'Aceptar e ingresar',
              onTap: onAccept,
            ),
            const SizedBox(width: AppDimens.xs),
            _ActionIconButton(
              icon: Icons.close_rounded,
              color: AppColors.danger,
              tooltip: 'Rechazar invitación',
              onTap: onReject,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallback(String name) {
    final initials =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';
    return Container(
      color: AppColors.surfaceCards,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
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
