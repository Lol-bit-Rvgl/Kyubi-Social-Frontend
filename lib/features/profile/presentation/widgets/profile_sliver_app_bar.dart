import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/user.dart';

/// Cabecera colapsable de perfil compacta (`SliverAppBar`).
///
/// - [expandedHeight] ≈ 112px, `pinned` + `stretch`.
/// - `FlexibleSpaceBar` con fondo 100% TRANSPARENTE para que el wallpaper del
///   perfil —pintado por la pantalla— abarque toda la cabecera hasta el borde
///   superior (detrás del status bar / AppBar). Solo conserva la fusión
///   inferior y el título (nombre + @handle) al colapsar.
class ProfileSliverAppBar extends StatelessWidget {
  const ProfileSliverAppBar({
    super.key,
    required this.user,
    this.leading,
    this.actions = const [],
    this.pinned = false,
    this.floating = false,
  });

  final User user;
  final Widget? leading;
  final List<Widget> actions;
  final bool pinned;
  final bool floating;

  static const double expandedHeight = 112;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: pinned,
      floating: floating,
      stretch: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: leading != null,
      leadingWidth: leading != null ? 44 : 0,
      leading: leading != null
          ? Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Center(
                child: _WithIconShadow(child: leading!),
              ),
            )
          : null,
      actions: actions.isEmpty
          ? null
          : [
              for (final action in actions) _WithIconShadow(child: action),
              const SizedBox(width: 8),
            ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: const SizedBox.expand(),
        title: _CollapsedTitle(user: user),
        titlePadding: const EdgeInsets.only(bottom: 12),
      ),
    );
  }
}

/// Aplica un ligero halo oscuro difuminado detrás del icono para mantener la
/// legibilidad de los iconos que flotan directamente sobre el wallpaper
/// transparente, sin alterar su color ni su aspecto.
class _WithIconShadow extends StatelessWidget {
  const _WithIconShadow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Halo difuminado detrás del icono (sombreado de legibilidad).
        IgnorePointer(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Título (nombre + handle) visible solo cuando la cabecera está colapsada.
class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    if (settings == null) return const SizedBox.shrink();

    final delta = settings.maxExtent - settings.minExtent;
    if (delta <= 0) return const SizedBox.shrink();
    final t = ((settings.currentExtent - settings.minExtent) / delta).clamp(
      0.0,
      1.0,
    );

    // Fade-in del título solo en el último 30% del colapso.
    final opacity = ((1 - t) - 0.7) / 0.3;
    if (opacity <= 0) return const SizedBox.shrink();

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 4),
                    Shadow(color: Colors.black54, blurRadius: 2),
                  ],
                ),
              ),
              Text(
                user.handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
