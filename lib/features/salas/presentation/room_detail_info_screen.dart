import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/rules/room_permissions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/kyubi_rich_text.dart';
import '../../../../models/room.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';
import 'edit_room_screen.dart';
import 'sala_detail_controller.dart';
import 'salas_controller.dart';
import 'widgets/room_invite_friends_sheet.dart';

/// Handle mostrable del host de una sala, evitando el fallback vacío '@usuario'
/// cuando el username llega nulo o con espacios.
String _hostHandle(Room? r) {
  final username = (r?.host.username ?? '').trim();
  if (username.isNotEmpty) return username;
  final display = (r?.host.displayName ?? '').trim();
  if (display.isNotEmpty) return display.replaceAll(' ', '');
  return 'host';
}

/// Pantalla Completa de Información y Detalles de Sala en Vivo (Ref: Requisito 1).
class RoomDetailInfoScreen extends ConsumerWidget {
  const RoomDetailInfoScreen({
    super.key,
    required this.roomId,
    this.room,
    this.onEditRoom,
  });

  final String roomId;
  final Room? room;
  final VoidCallback? onEditRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(salaDetailControllerProvider(roomId));
    final r = detailState.room ?? room;
    final myId = ref.watch(authControllerProvider).user?.id ?? '';
    final isHostOrAdmin = r != null &&
        myId.isNotEmpty &&
        (r.host.id == myId ||
            r.participants.any((p) =>
                p.user.id == myId && RoomPermissions.canManageRole(p.role)));
    final isActive = r?.status == RoomStatus.active;
    final isPrivate = r?.access == RoomAccess.private;

    final coverUrl =
        r?.imageUrl ??
        r?.host.avatarUrl ??
        'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=800&auto=format&fit=crop&q=80';

    final rules = r?.rules ?? const [];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0C15),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 1. Encabezado con Cover/Banner y AppBar Colapsable ──
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF13101E),
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0x99000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (isHostOrAdmin) ...[
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0x99000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: AppColors.accentCrimson,
                      size: 20,
                    ),
                  ),
                  tooltip: 'Editar sala',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    if (onEditRoom != null) {
                      Navigator.pop(context);
                      onEditRoom!();
                    } else {
                      _editAndPersist(context, ref, r);
                    }
                  },
                ),
              ],
              if (r != null)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0x99000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  tooltip: 'Invitar amigos',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    RoomInviteFriendsSheet.show(context, room: r);
                  },
                ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0x99000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.share_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                tooltip: 'Compartir',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enlace de la sala copiado 🔗'),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF260D18), Color(0xFF0F0B14)],
                        ),
                      ),
                    ),
                  ),
                  // Degradado inferior
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x880D0C15),
                          Color(0xFF0D0C15),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 2. Información Principal y Jerarquía Visual Espaciosa ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges de Estado y Acceso
                  Row(
                    children: [
                      // Badge En Vivo / Pausada
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.success.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? AppColors.success
                                : const Color(0xFF5A5A6A),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6.5,
                              height: 6.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive
                                    ? AppColors.success
                                    : const Color(0xFF7A7A8A),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isActive ? 'En vivo' : 'Pausada',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isActive
                                    ? AppColors.success
                                    : const Color(0xFF9E9EA8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Badge Pública / Privada
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isPrivate
                              ? AppColors.accentPurple.withValues(alpha: 0.15)
                              : AppColors.accentCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isPrivate
                                ? AppColors.accentPurple
                                : AppColors.accentCyan,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPrivate
                                  ? Icons.lock_rounded
                                  : Icons.public_rounded,
                              size: 12,
                              color: isPrivate
                                  ? AppColors.accentPurple
                                  : AppColors.accentCyan,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPrivate ? 'Privada' : 'Pública',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isPrivate
                                    ? AppColors.accentPurple
                                    : AppColors.accentCyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Nombre de la Sala
                  Text(
                    r?.name ?? 'Sala de Kyubi',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Descripción / Lore de la sala
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14121F),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF251F36),
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DESCRIPCIÓN Y LORE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accentCyan,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        KyubiRichText(
                          text:
                              r?.description != null &&
                                  r!.description!.isNotEmpty
                              ? r.description!
                              : 'Bienvenidos a esta sala interactiva de Kyubi. Participa en el chat y disfruta de la experiencia temática.',
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: Color(0xFFE0DFEA),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tags temáticos
                  if (r?.tags != null && r!.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: r.tags.map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.accentCyan.withValues(
                                alpha: 0.35,
                              ),
                              width: 0.7,
                            ),
                          ),
                          child: Text(
                            '#$t',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentCyan,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 22),

                  // ── 3. Anfitrión / Host ──
                  _sectionHeader('Anfitrión de la Sala'),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      final currentUserId =
                          ref.read(authControllerProvider).user?.id;
                      final isOwnHost = (currentUserId != null &&
                          currentUserId == r?.host.id);

                      if (isOwnHost) {
                        context.push('/profile-bio');
                      } else if (r?.host.username != null &&
                          r!.host.username.isNotEmpty) {
                        context.push(
                          '/profile/${r.host.username}/bio',
                          extra: r.host,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14121F),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF251F36),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.accentCrimson,
                                width: 1.5,
                              ),
                            ),
                            child: AppAvatar(
                              imageUrl: r?.host.avatarUrl,
                              name: r?.host.displayName ?? 'Host',
                              radius: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        r?.host.displayName.isNotEmpty == true
                                            ? r!.host.displayName
                                            : (r?.host.username ?? 'Host'),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentCrimson,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '👑 Host',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${_hostHandle(r)}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF7A7A8E),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── 4. Bloque de Reglas de la Sala ──
                  _sectionHeader('Reglas Oficiales'),
                  const SizedBox(height: 10),
                  if (rules.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14121F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF251F36),
                          width: 0.8,
                        ),
                      ),
                      child: const Text(
                        'Sin reglas definidas para esta sala',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF7A7A8E),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ...rules.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final rule = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14121F),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF251F36),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.accentCrimson.withValues(
                                  alpha: 0.2,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.accentCrimson,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '$index',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.accentCrimson,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                rule,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  color: Color(0xFFCAC8D8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 22),

                  // ── 5. Participantes Activos ──
                  _sectionHeader(
                    'Participantes Activos (${r?.participants.length ?? 0})',
                  ),
                  const SizedBox(height: 10),
                  if (r?.participants != null && r!.participants.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: r.participants.length,
                        itemBuilder: (context, idx) {
                          final p = r.participants[idx];
                          return GestureDetector(
                            onTap: () {
                              final currentUserId =
                                  ref.read(authControllerProvider).user?.id;
                              final isOwn = (currentUserId != null &&
                                  currentUserId == p.user.id);
                              if (isOwn) {
                                context.push('/profile-bio');
                              } else if (p.user.username.isNotEmpty) {
                                context.push(
                                  '/profile/${p.user.username}/bio',
                                  extra: p.user,
                                );
                              }
                            },
                            child: Container(
                              width: 60,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppAvatar(
                                    imageUrl: p.user.avatarUrl,
                                    name: p.user.displayName,
                                    radius: 22,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.user.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14121F),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Sé el primero en unirte a esta sala',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),

                  // Botón de Volver al Chat / Entrar
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentCrimson,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Volver a la Sala',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Edición directa con persistencia (respaldo cuando no hay `onEditRoom`):
  /// guarda vía PATCH y actualiza el provider de detalle para que la
  /// descripción no se pierda al volver.
  Future<void> _editAndPersist(
    BuildContext context,
    WidgetRef ref,
    Room? r,
  ) async {
    final liveRoom = ref.read(salaDetailControllerProvider(roomId)).room ?? r;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditRoomScreen(room: liveRoom)),
    );
    if (result == null || !context.mounted) return;
    try {
      final updated = await ref.read(roomRepositoryProvider).updateSala(
            roomId,
            name: result['name'] as String?,
            description: result['description'] as String?,
            imageUrl: result['coverUrl'] as String?,
            chatBackgroundUrl: result['bgUrl'] as String?,
            rules: (result['rules'] as List?)?.cast<String>(),
            tags: (result['tags'] as List?)?.cast<String>(),
          );
      ref.read(salaDetailControllerProvider(roomId).notifier).applyRoom(updated);
      ref.read(salasControllerProvider.notifier).applyRoom(updated);
      await ref.read(salaDetailControllerProvider(roomId).notifier).refresh();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar la configuración de la sala'),
          ),
        );
      }
    }
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.accentCrimson,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
