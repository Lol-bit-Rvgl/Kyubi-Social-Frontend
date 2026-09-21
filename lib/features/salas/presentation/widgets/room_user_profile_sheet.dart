import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/hexagon_avatar.dart';
import '../../../../models/role_character.dart';

/// Modal Bottom Sheet "Info de Usuario" / Perfil Rápido en Sala de Chat (Ref: Imagen 4).
///
/// Despliega un panel obsidiana (#14141E) con bordes redondeados (24px), avatar
/// con halo neón, estado en línea, rol activo, bio compacta y acciones directas.
class RoomUserProfileSheet extends StatelessWidget {
  const RoomUserProfileSheet({
    super.key,
    required this.displayName,
    this.username,
    this.userId,
    this.avatarUrl,
    this.role,
    this.adminBadge,
    this.isOnline = true,
    this.isHost = false,
    this.isSelf = false,
    this.canManage = false,
    this.isMuted = false,
    this.isVerified = false,
    this.onMute,
    this.onKick,
    this.onViewProfile,
    this.onStartDirectChat,
  });

  final String displayName;
  final String? username;

  /// ID real del usuario (user.id / senderId / participant.userId). Se usa
  /// para el chat directo y la navegación de perfil robusta.
  final String? userId;
  final String? avatarUrl;
  final RoleCharacter? role;
  final String? adminBadge;
  final bool isOnline;
  final bool isHost;
  final bool isSelf;
  final bool canManage;
  final bool isVerified;

  /// Estado actual de silencio del usuario en la sala: habilita el botón como
  /// toggle (silenciar ↔ desilenciar) en lugar de enviar eventos duplicados.
  final bool isMuted;
  final VoidCallback? onMute;
  final VoidCallback? onKick;
  final VoidCallback? onViewProfile;
  final VoidCallback? onStartDirectChat;

  /// Abre el Bottom Sheet modal de forma fluida sin romper el scroll del chat de fondo.
  static Future<void> show(
    BuildContext context, {
    required String displayName,
    String? username,
    String? userId,
    String? avatarUrl,
    RoleCharacter? role,
    String? adminBadge,
    bool isOnline = true,
    bool isHost = false,
    bool isSelf = false,
    bool canManage = false,
    bool isMuted = false,
    bool isVerified = false,
    VoidCallback? onMute,
    VoidCallback? onKick,
    VoidCallback? onViewProfile,
    VoidCallback? onStartDirectChat,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => RoomUserProfileSheet(
        displayName: displayName,
        username: username,
        userId: userId,
        avatarUrl: avatarUrl,
        role: role,
        adminBadge: adminBadge,
        isOnline: isOnline,
        isHost: isHost,
        isSelf: isSelf,
        canManage: canManage,
        isMuted: isMuted,
        isVerified: isVerified,
        onMute: onMute,
        onKick: onKick,
        onViewProfile: onViewProfile,
        onStartDirectChat: onStartDirectChat,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Handle limpio: solo el username alfanumérico real. Nunca se fabrica uno
    // a partir del displayName (evita 404 al navegar a un perfil inexistente).
    final handle = _cleanHandle(username?.trim() ?? '');
    final roleColor = role?.color ?? AppColors.accentCyan;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCards,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF2C2542), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── 1. Barra de Arrastre Superior ──
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A4A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 2. Avatar con Halo Neón y Badge de Estado ──
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Halo brillante exterior
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: roleColor.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

                // Avatar
                if (role != null)
                  HexagonAvatar(
                    size: 78,
                    imageUrl: role!.avatarUrl ?? avatarUrl,
                    borderColor: roleColor,
                    borderWidth: 2.5,
                  )
                else
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E1A2E),
                      border: Border.all(color: roleColor, width: 2.2),
                    ),
                    child: ClipOval(
                      child: avatarUrl != null && avatarUrl!.isNotEmpty
                          ? Image.network(
                              avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person_rounded,
                                size: 38,
                                color: Colors.white70,
                              ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              size: 38,
                              color: Colors.white70,
                            ),
                    ),
                  ),

                // Indicador de conexión (Online Dot)
                Positioned(
                  bottom: 2,
                  right: 4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? AppColors.accentTeal
                          : const Color(0xFF7A7A8E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surfaceCards,
                        width: 2.5,
                      ),
                      boxShadow: isOnline
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF00E676,
                                ).withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── 3. Nombre de Usuario & Badges ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 5),
                  Image.asset(
                    AppAssets.iconVerificados,
                    width: 16,
                    height: 16,
                    fit: BoxFit.contain,
                  ),
                ],
                if (isHost) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD600).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFFFD600),
                        width: 0.8,
                      ),
                    ),
                    child: const Text(
                      'Host 👑',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFD600),
                      ),
                    ),
                  ),
                ] else if (adminBadge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF00E5FF),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      adminBadge!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 3),

            // Handle @username: solo se muestra si es un handle real y limpio
            // y no repite el nombre principal (evita duplicados decorativos).
            if (handle.isNotEmpty &&
                handle.toLowerCase() != displayName.toLowerCase() &&
                handle != displayName.replaceAll(' ', '_').toLowerCase())
              Text(
                '@$handle',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),

            const SizedBox(height: 10),

            // ── Biografía directamente bajo el nombre (sin etiquetas que
            // rompan el flujo) ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1728),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF28233C), width: 0.8),
              ),
              child: Text(
                role?.description.isNotEmpty == true
                    ? role!.description
                    : 'Explorando el multiverso de Kyubi • Participante de la sala en vivo ✨',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: Color(0xFFC0C0D4),
                ),
              ),
            ),

            // Píldora de Rol Activo
            if (role != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: roleColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.theater_comedy_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Rol: ${role!.name}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── 4. Botones de Acción Directa ──
            Row(
              children: [
                // Botón Principal: Chat / Perfil Completo (ocupa todo el ancho disponible)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      if (onStartDirectChat != null) {
                        onStartDirectChat!();
                      } else {
                        _openProfile(context);
                      }
                    },
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F3A3A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentCyan,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentCyan.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Chat / Perfil Completo',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Expulsar (Solo si el usuario actual es Admin/Host y no es a sí mismo)
                if (!isSelf && canManage) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showKickConfirmDialog(context);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A121E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentCrimson.withValues(
                            alpha: 0.6,
                          ),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_remove_rounded,
                        color: AppColors.accentCrimson,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // ── 5. Sección inferior: Actividad / Lobby ──
            // El estado de actividad (y, si el usuario es host, su lobby) va
            // siempre al final del modal, nunca entre el nombre y la bio.
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF28233C), height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? AppColors.accentTeal
                        : const Color(0xFF7A7A8E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isHost
                      ? 'Lobby activo · Anfitrión'
                      : (isOnline ? 'Activo/a ahora' : 'Desconectado/a'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isOnline
                        ? AppColors.accentTeal
                        : const Color(0xFF7A7A8E),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Devuelve un handle alfanumérico limpio (sin `@`, espacios ni caracteres
  /// decorativos). Vacío si el valor recibido no parece un usuario real.
  String _cleanHandle(String raw) {
    var h = raw.replaceAll('@', '').trim();
    if (h.isEmpty) return '';
    // Username válido: letras, números, guion bajo y punto, sin espacios.
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(h)) return '';
    return h;
  }

  /// Navega al perfil completo. Usa siempre el username real; si no hay un
  /// handle navegable muestra un SnackBar informativo en lugar de lanzar una
  /// ruta con un identificador falso (DioException 404).
  void _openProfile(BuildContext context) {
    HapticFeedback.selectionClick();
    if (onViewProfile != null) {
      onViewProfile!();
      return;
    }
    final h = _cleanHandle(username?.trim() ?? '');
    if (h.isNotEmpty) {
      context.push('/profile/$h');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Perfil no disponible para este usuario'),
        backgroundColor: Color(0xFF1E1A2E),
      ),
    );
  }

  void _showKickConfirmDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161224),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF2E2744), width: 0.8),
        ),
        title: const Text(
          '¿Expulsar usuario?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        content: Text(
          '¿Estás seguro de que deseas expulsar a $displayName de esta sala?',
          style: const TextStyle(fontSize: 13, color: Color(0xFFC0C0D4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCrimson,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onKick?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$displayName ha sido expulsado/a'),
                  backgroundColor: const Color(0xFF3A121E),
                ),
              );
            },
            child: const Text(
              'Expulsar',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
