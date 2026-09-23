import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/user.dart';
import '../theme/app_colors.dart';
import 'app_avatar.dart';
import 'liquid_glass_container.dart';

/// Tarjeta decorada de previsualización de perfil (User Mini-Card / Preview Card).
///
/// Diseñada con estética Liquid Glass:
/// - Fondo dinámico (banner/portada o degradado cósmico morado/verde).
/// - Marco Liquid Glass con gradiente perimetral y desenfoque.
/// - Avatar destacado con halo degradado neón.
/// - Nombre con `usernameColor`, handle, nivel y estado de actividad.
/// - Biografía breve / Lore (hasta 2 líneas con elipsis).
/// - Acciones rápidas (Ver perfil completo, Mencionar, Enviar mensaje).
class UserPreviewCard extends StatelessWidget {
  const UserPreviewCard({
    super.key,
    required this.user,
    this.onViewProfile,
    this.onMention,
    this.onSendMessage,
    this.activityStatus,
    this.showActivityStatus = true,
    this.isCompact = false,
    this.width,
    this.margin,
  });

  final User user;
  final VoidCallback? onViewProfile;
  final VoidCallback? onMention;
  final VoidCallback? onSendMessage;
  final String? activityStatus;
  final bool showActivityStatus;
  final bool isCompact;
  final double? width;
  final EdgeInsetsGeometry? margin;

  Color get _nameColor {
    if (user.usernameColor != null && user.usernameColor!.trim().isNotEmpty) {
      return AppColors.fromHex(user.usernameColor);
    }
    return Colors.white;
  }

  Widget _buildDefaultCosmicBackground() {
    final primaryColor = user.themeSettings.primary;
    final secondaryColor = user.themeSettings.accent;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0A14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withValues(alpha: 0.22),
            const Color(0xFF0D0A14),
            secondaryColor.withValues(alpha: 0.18),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banner = user.effectiveBannerUrl ?? user.bannerUrl;
    final hasBanner = banner != null && banner.trim().isNotEmpty;
    final hasBio = user.bio != null && user.bio!.trim().isNotEmpty;

    final themeSettings = user.themeSettings;
    final isTransparent = themeSettings.glassStyle == GlassStyle.transparent;

    return Container(
      width: width,
      margin: margin,
      child: LiquidGlassContainer(
        borderRadius: 22.0,
        padding: EdgeInsets.zero,
        blur: isTransparent ? 2.0 : 14.0,
        style: themeSettings.glassStyle,
        primaryColor: themeSettings.primary,
        accentColor: themeSettings.accent,
        customBorderGradient: themeSettings.borderGradient,
        onTap: onViewProfile,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.8),
          child: Stack(
            children: [
              // ── Capa 1: Portada/Banner o degradado cósmico ──
              Positioned.fill(
                child: hasBanner
                    ? Image.network(
                        banner,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _buildDefaultCosmicBackground(),
                      )
                    : _buildDefaultCosmicBackground(),
              ),

              // ── Capa 2: Velo oscuro translúcido para contraste y legibilidad ──
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF0D0A14).withValues(
                          alpha: isTransparent ? 0.20 : 0.65,
                        ),
                        const Color(0xFF05030A).withValues(
                          alpha: isTransparent ? 0.35 : 0.92,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Capa 3: Contenido de la tarjeta ──
              Padding(
                padding: EdgeInsets.all(isCompact ? 12.0 : 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabecera: Avatar destacado + Datos del usuario
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar circular con halo degradado neón (58px)
                        Container(
                          width: isCompact ? 52 : 58,
                          height: isCompact ? 52 : 58,
                          padding: const EdgeInsets.all(2.2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                themeSettings.primary,
                                themeSettings.accent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: themeSettings.primary.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: AppAvatar(
                            imageUrl: user.effectiveAvatarUrl,
                            name: user.displayName.isNotEmpty
                                ? user.displayName
                                : user.username,
                            radius: isCompact ? 24 : 27,
                            isOnline: user.isOnline,
                            showOnline: false,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Nombre, Handle e Insignias
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName
                                    : user.username,
                                style: TextStyle(
                                  fontSize: isCompact ? 15.5 : 17,
                                  fontWeight: FontWeight.w900,
                                  color: _nameColor,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (user.handle.isNotEmpty && user.handle != '@') ...[
                                const SizedBox(height: 2),
                                Text(
                                  user.handle,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFFA594F9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 6),

                              // Fila de Insignias: Actividad + Nivel
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Píldora de actividad (opcional)
                                  if (showActivityStatus)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.success.withValues(
                                            alpha: 0.35,
                                          ),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.success,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            activityStatus ??
                                                (user.isOnline
                                                    ? 'Activo'
                                                    : 'En sala'),
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Píldora de nivel
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentCrimson.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.accentCrimson
                                            .withValues(alpha: 0.35),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '🔥',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Nv. ${user.level}',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.accentCrimson,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ── Biografía breve o Lore (hasta 2 líneas con elipsis) ──
                    if (hasBio) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF140F24).withValues(alpha: 0.60),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          user.bio!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFC0B8D8),
                            fontStyle: FontStyle.italic,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],

                    // ── Acciones Rápidas (Botón primario + secundario) ──
                    if (!isCompact ||
                        onMention != null ||
                        onSendMessage != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (!isCompact)
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: onViewProfile ??
                                    () {
                                      context.push(
                                        '/profile/${user.username}/bio',
                                        extra: user,
                                      );
                                    },
                                icon: const Icon(
                                  Icons.person_outline_rounded,
                                  size: 17,
                                ),
                                label: const Text(
                                  'Ver perfil completo',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFA594F9),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          if (onMention != null || onSendMessage != null) ...[
                            if (!isCompact) const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: onMention ?? onSendMessage,
                              icon: Icon(
                                onMention != null
                                    ? Icons.alternate_email_rounded
                                    : Icons.chat_bubble_outline_rounded,
                                size: 18,
                              ),
                              tooltip: onMention != null
                                  ? 'Mencionar'
                                  : 'Enviar mensaje',
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF241C38,
                                ).withValues(alpha: 0.8),
                                foregroundColor: AppColors.accentCyan,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: AppColors.accentCyan.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Muestra un modal/diálogo flotante inmersivo con la tarjeta [UserPreviewCard].
void showUserPreviewDialog(
  BuildContext context,
  User user, {
  VoidCallback? onViewProfile,
  VoidCallback? onMention,
  VoidCallback? onSendMessage,
}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Material(
          color: Colors.transparent,
          child: UserPreviewCard(
            user: user,
            onViewProfile: () {
              Navigator.pop(ctx);
              if (onViewProfile != null) {
                onViewProfile();
              } else {
                ctx.push('/profile/${user.username}/bio', extra: user);
              }
            },
            onMention: onMention != null
                ? () {
                    Navigator.pop(ctx);
                    onMention();
                  }
                : null,
            onSendMessage: onSendMessage != null
                ? () {
                    Navigator.pop(ctx);
                    onSendMessage();
                  }
                : null,
          ),
        ),
      ),
    ),
  );
}
