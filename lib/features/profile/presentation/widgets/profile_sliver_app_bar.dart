import 'package:flutter/material.dart';

import '../../../../models/user.dart';

/// Cabecera colapsable de perfil compacta (`SliverAppBar`).
///
/// - [expandedHeight] ≈ 112px, `pinned` + `stretch`.
/// - `FlexibleSpaceBar` con fondo 100% TRANSPARENTE para que el wallpaper del
///   perfil —pintado por la pantalla— abarque toda la cabecera hasta el borde
///   superior (detrás del status bar / AppBar). No proyecta títulos flotantes
///   sobre el avatar al hacer scroll o pull-to-refresh.
class ProfileSliverAppBar extends StatelessWidget {
  const ProfileSliverAppBar({
    super.key,
    this.user,
    this.leading,
    this.actions = const [],
    this.pinned = false,
    this.floating = false,
  });

  final User? user;
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
      flexibleSpace: const FlexibleSpaceBar(
        stretchModes: [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: SizedBox.expand(),
        title: null,
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
