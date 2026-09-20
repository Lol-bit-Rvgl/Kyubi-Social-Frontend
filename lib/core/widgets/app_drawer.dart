import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user.dart';
import '../../routing/app_router.dart';
import '../../services/auth_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'user_preview_card.dart';

/// Helper defensivo para parsear cadenas de color hexadecimal (#RRGGBB o #AARRGGBB).
Color? _parseColor(String? hexString) {
  if (hexString == null || hexString.trim().isEmpty) return null;
  final hex = hexString.replaceAll('#', '').trim();
  try {
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// Panel lateral desplegable (Drawer) con fondo dinámico inmersivo.
///
/// Soporta renderizado multicapa:
/// 1. Banner del perfil o gradiente cósmico por defecto.
/// 2. Filtro de desenfoque Liquid/Frosted (BackdropFilter).
/// 3. Velo de degradado oscuro y translúcido para contraste.
/// 4. Contenido del menú lateral (perfil, accesos directos, logout).
class KyubiDrawer extends ConsumerWidget {
  const KyubiDrawer({
    super.key,
    this.user,
    this.onProfileTap,
  });

  final User? user;
  final VoidCallback? onProfileTap;

  Widget _buildDefaultCosmicBackground(
    BuildContext context, [
    Color? themeColor,
    Color? secondaryColor,
  ]) {
    final scheme = Theme.of(context).colorScheme;
    final primary = themeColor ?? scheme.primary;
    final secondary = secondaryColor ?? scheme.secondary;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0A14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.22),
            const Color(0xFF0D0A14),
            secondary.withValues(alpha: 0.18),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeUser = user ?? ref.watch(authControllerProvider).user;
    final bannerUrl = activeUser?.effectiveBannerUrl ?? activeUser?.bannerUrl;
    final userColorHex = activeUser?.themeColor ??
        activeUser?.nameColor ??
        activeUser?.usernameColor;
    final dynamicProfileColor =
        _parseColor(userColorHex) ?? const Color(0xFFE0E0E0);
    final themeColor = _parseColor(userColorHex);
    final dynamicLogoutColor =
        activeUser?.themeSettings.accent ?? dynamicProfileColor;

    final handleProfileTap = onProfileTap ??
        () {
          Navigator.pop(context);
          context.push('/profile');
        };

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Capa 1: Imagen de fondo del perfil o gradiente cósmico por defecto
            if (bannerUrl != null && bannerUrl.trim().isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  bannerUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _buildDefaultCosmicBackground(
                        context,
                        themeColor,
                        activeUser?.themeSettings.accent,
                      ),
                ),
              )
            else
              Positioned.fill(
                child: _buildDefaultCosmicBackground(
                  context,
                  themeColor,
                  activeUser?.themeSettings.accent,
                ),
              ),

            // Capa 2: Filtro de desenfoque Liquid/Frosted
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: const SizedBox.expand(),
              ),
            ),

            // Capa 3: Velo de degradado oscuro y translúcido para contraste
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      themeColor != null
                          ? Color.alphaBlend(
                              themeColor.withValues(alpha: 0.25),
                              const Color(0xFF0B0716).withValues(alpha: 0.72),
                            )
                          : const Color(0xFF0B0716).withValues(alpha: 0.72),
                      const Color(0xFF06040A).withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
            ),

            // Capa 4: Contenido del Drawer (Header, ListTiles, Footer)
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: AppDimens.md),

                  // ── Header: Tarjeta Decorada de Perfil Liquid Glass (Full Width) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                    ),
                    child: UserPreviewCard(
                      width: double.infinity,
                      user: activeUser ??
                          const User(
                            id: '',
                            username: 'kyubi',
                            displayName: 'Kyubi User',
                          ),
                      isCompact: true,
                      onViewProfile: handleProfileTap,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Balance compacto: monedas + gemas
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF140F24).withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: dynamicProfileColor.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: dynamicProfileColor.withValues(alpha: 0.08),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🪙 ${activeUser?.coins ?? 150}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          child: Container(
                            width: 1,
                            height: 12,
                            color: dynamicProfileColor.withValues(alpha: 0.3),
                          ),
                        ),
                        const Text(
                          '💎 20',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimens.md),
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Color(0x14FFFFFF),
                  ),
                  const SizedBox(height: 6),

                  // ── Lista de Accesos Directos ──
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      children: [
                        DrawerTile(
                          iconData: Icons.person_rounded,
                          label: 'Mi Perfil',
                          color: dynamicProfileColor,
                          onTap: handleProfileTap,
                        ),
                        DrawerTile(
                          iconData: Icons.bookmark_rounded,
                          label: 'Guardados',
                          color: dynamicProfileColor,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/saved');
                          },
                        ),
                        DrawerTile(
                          iconData: Icons.settings_rounded,
                          label: 'Ajustes & Cuenta',
                          color: dynamicProfileColor,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/settings');
                          },
                        ),
                      ],
                    ),
                  ),

                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Color(0x14FFFFFF),
                  ),

                  // ── Cerrar Sesión ──
                  DrawerTile(
                    iconData: Icons.logout_rounded,
                    label: 'Cerrar sesión',
                    color: dynamicLogoutColor,
                    isDanger: true,
                    onTap: () {
                      _confirmLogout(context, ref);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14141B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          '¿Estás seguro de que deseas salir de tu cuenta?',
          style: TextStyle(color: Color(0xFF9E9EA8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF7A7A8A)),
            ),
          ),
          FilledButton(
            onPressed: () async {
              // 1. Cerrar diálogo
              Navigator.of(ctx).pop();

              // 2. Cerrar el drawer si sigue abierto en el scaffold
              if (context.mounted &&
                  (Scaffold.maybeOf(context)?.isDrawerOpen ?? false)) {
                Navigator.of(context).pop();
              }

              // 3. Ejecutar logout
              await ref.read(authControllerProvider.notifier).logout();

              // 4. Redirigir de manera forzada y limpiar stack
              if (context.mounted) {
                context.go('/login');
              } else {
                ref.read(routerProvider).go('/login');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Salir',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

typedef AppDrawer = KyubiDrawer;

class DrawerTile extends StatelessWidget {
  const DrawerTile({
    super.key,
    this.iconData,
    this.iconWidget,
    required this.label,
    required this.onTap,
    this.color,
    this.isDanger = false,
  }) : assert(iconData != null || iconWidget != null);

  final IconData? iconData;
  final Widget? iconWidget;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color(0xFFE0E0E0);
    return ListTile(
      leading: iconWidget ??
          Icon(
            iconData,
            color: effectiveColor,
            size: 20,
          ),
      title: Text(
        label,
        style: TextStyle(
          color: effectiveColor,
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
      ),
      trailing: isDanger
          ? null
          : Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: effectiveColor.withValues(alpha: 0.6),
            ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.lg),
      onTap: onTap,
    );
  }
}
