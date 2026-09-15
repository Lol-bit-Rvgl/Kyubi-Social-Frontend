import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/kyubi_shimmer.dart';
import '../../../../models/room.dart';

/// Tarjeta limpia y espaciosa de Sala en Vivo (Ref: Requisito 2).
/// Sin textos amontonados de "+N escuchando" ni badges toscos de "• Dentro".
class LiveRoomCard extends StatelessWidget {
  const LiveRoomCard({super.key, required this.room, this.onTap});

  final Room room;
  final VoidCallback? onTap;

  static const double _avatarSize = 22;
  static const double _avatarOverlap = 12;
  static const int _maxVisibleAvatars = 3;

  @override
  Widget build(BuildContext context) {
    final isActive = room.status == RoomStatus.active;
    final isVoice = room.tags.any(
      (t) =>
          t.toLowerCase().contains('voice') || t.toLowerCase().contains('voz'),
    );
    final isRp = room.tags.any(
      (t) =>
          t.toLowerCase().contains('rp') ||
          t.toLowerCase().contains('rol') ||
          t.toLowerCase().contains('roleplay'),
    );
    // Micrófono para salas de voz; máscara para roleplay; chat el resto.
    final (modeIcon, modeColor) = isVoice
        ? (Icons.mic_rounded, AppColors.accentTeal)
        : isRp
            ? (Icons.theater_comedy_rounded, const Color(0xFFFFD600))
            : (Icons.chat_bubble_rounded, const Color(0xFF7EC8E3));

    final participantAvatars = room.participants
        .take(_maxVisibleAvatars)
        .map((p) => p.user)
        .toList();

    final count = room.participantCount > 0
        ? room.participantCount
        : (room.participants.isNotEmpty ? room.participants.length : 1);

    return GestureDetector(
      onTap:
          onTap ??
          () => context.push(
            '/salas/${room.id}',
            extra: room.isParticipant || room.isHost,
          ),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF14141B),
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(
            color: isActive ? const Color(0xFF22222E) : const Color(0xFF1A1A24),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? AppColors.accentCrimson.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 1. Imagen de portada / Wallpaper con degradado inmersivo ──
            if (room.imageUrl != null && room.imageUrl!.isNotEmpty)
              Opacity(
                opacity: isActive ? 0.9 : 0.4,
                child: CachedNetworkImage(
                  imageUrl: room.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const KyubiShimmer(),
                  errorWidget: (_, _, _) => _buildFallbackGradient(),
                ),
              )
            else
              _buildFallbackGradient(),

            // Degradado oscuro para legibilidad
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0x660B0B10),
                    const Color(0xBB0B0B10),
                    const Color(0xF50B0B10),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // ── 2. Parte Superior: Título + Badge de Modo ──
            Positioned(
              top: 10,
              left: 12,
              right: 44, // Deja espacio al punto verde
              child: Row(
                children: [
                  // Badge Pequeño de Modo (icono vectorial)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC1A1A28),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: modeColor.withValues(alpha: 0.4),
                        width: 0.7,
                      ),
                    ),
                    child: isRp
                        ? Image.asset(
                            AppAssets.iconRoleplay,
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          )
                        : Icon(modeIcon, size: 12, color: modeColor),
                  ),
                  const SizedBox(width: 8),

                  // Título de la Sala
                  Expanded(
                    child: Text(
                      room.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 3. Esquina Superior Derecha: Únicamente Punto Neón Verde Pulsante ──
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? AppColors.accentTeal
                      : const Color(0xFF5A5A6A),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.accentTeal.withValues(alpha: 0.55),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ),

            // ── 4. Parte Inferior Izquierda: Tags o Avatares Solapados ──
            Positioned(
              bottom: 10,
              left: 12,
              right: 70, // Deja espacio al contador
              child: Row(
                children: [
                  if (participantAvatars.isNotEmpty) ...[
                    SizedBox(
                      height: _avatarSize,
                      width:
                          _avatarSize +
                          (participantAvatars.length - 1) * _avatarOverlap,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (int i = 0; i < participantAvatars.length; i++)
                            Positioned(
                              left: i * _avatarOverlap,
                              child: AppAvatar(
                                name: participantAvatars[i].displayName,
                                imageUrl: participantAvatars[i].avatarUrl,
                                radius: _avatarSize / 2,
                                borderColor: AppColors.backgroundBase,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (room.tags.isNotEmpty)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.accentCyan.withValues(alpha: 0.3),
                            width: 0.7,
                          ),
                        ),
                        child: Text(
                          '#${room.tags.first}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── 5. Esquina Inferior Derecha: Contador Compacto de Miembros (👥 N) ──
            Positioned(
              bottom: 10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xB3141422),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0x33FFFFFF),
                    width: 0.7,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.group_rounded,
                      size: 12,
                      color: Color(0xFFCAC8D8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF200B1A), Color(0xFF0F1424)],
        ),
      ),
    );
  }
}
