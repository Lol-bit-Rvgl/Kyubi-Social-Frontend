import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/kyubi_shimmer.dart';

/// Avatar de perfil con halo Nebulæ de doble capa (borde interior magenta y
/// glow exterior teal cibernético) e indicador de presencia online/offline.
///
/// Reutilizado en `profile_screen`, `visit_profile_screen` y `profile_hero`
/// para garantizar una identidad visual unificada en todo el perfil.
class NebulaeProfileAvatar extends StatelessWidget {
  const NebulaeProfileAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 48,
    this.showStatus = true,
    this.isOnline = false,
    this.cacheVersion,
    this.onTap,
    this.overlay,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final bool showStatus;
  final bool isOnline;
  final int? cacheVersion;
  final VoidCallback? onTap;

  /// Elemento superpuesto opcional (p. ej. badge de cámara del perfil propio).
  final Widget? overlay;

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = radius * 2;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Halo de doble capa: anillo interior magenta + glow teal exterior.
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.accentTeal],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.42),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: AppColors.accentTeal.withValues(alpha: 0.28),
                  blurRadius: 26,
                  spreadRadius: -1,
                ),
              ],
            ),
            padding: const EdgeInsets.all(3.2),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.obsidianBg,
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl:
                          '$imageUrl${cacheVersion != null && cacheVersion != 0 ? '?v=$cacheVersion' : ''}',
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const KyubiShimmer(),
                      errorWidget: (_, _, _) => _fallback(),
                    )
                  : _fallback(),
            ),
          ),
          ?overlay,
          if (showStatus) Positioned(right: 2, bottom: 2, child: _statusDot()),
        ],
      ),
    );
  }

  Widget _statusDot() {
    return Container(
      width: radius * 0.36,
      height: radius * 0.36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Online: verde teal con brillo neón. Offline: borde translúcido
        // atenuado sobre fondo oscuro.
        color: isOnline
            ? AppColors.success
            : Colors.white.withValues(alpha: 0.22),
        border: Border.all(color: AppColors.obsidianBg, width: 2.5),
        boxShadow: isOnline
            ? [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.55),
                  blurRadius: 8,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.surfaceAlt],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
