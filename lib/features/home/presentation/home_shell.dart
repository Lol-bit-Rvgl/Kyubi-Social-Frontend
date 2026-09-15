import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../services/auth_controller.dart';

/// Destinos de la barra inferior canónica (4 tabs: Inicio, Comunidades, Mensajes, Perfil).
const _shellDestinations = [
  (
    icon: Icons.explore_rounded,
    iconOutline: Icons.explore_outlined,
    label: 'Inicio',
  ),
  (
    icon: Icons.grid_view_rounded,
    iconOutline: Icons.grid_view_outlined,
    label: 'Comunidades',
  ),
  (
    icon: Icons.chat_bubble_rounded,
    iconOutline: Icons.chat_bubble_outline_rounded,
    label: 'Mensajes',
  ),
  (
    icon: Icons.person_rounded,
    iconOutline: Icons.person_outline_rounded,
    label: 'Perfil',
  ),
];

/// Contenedor principal estilo Clover Space / Kubi-Space con 4 tabs directas.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _exitWindow = Duration(seconds: 2);

  DateTime? _lastBackPress;

  /// Control de "doble tap para salir": en la raíz del shell, el primer toque
  /// de atrás solo muestra un SnackBar; el segundo dentro de 2s cierra la app
  /// con [SystemNavigator.pop]. Evita que el sistema haga pop de la ruta base
  /// y reinicie/crashee Flutter.
  void _onPopInvoked(bool didPop) {
    if (didPop) return;

    // Por seguridad, si el router puede desapilar (ruta empujada encima),
    // dejamos que lo haga de forma limpia.
    if (context.canPop()) {
      context.pop();
      return;
    }

    final now = DateTime.now();
    final withinWindow =
        _lastBackPress != null && now.difference(_lastBackPress!) < _exitWindow;

    if (withinWindow) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPress = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Presiona de nuevo para salir'),
          duration: Duration(milliseconds: 1800),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.navigationShell.currentIndex;
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: Scaffold(
        backgroundColor: AppColors.obsidianBg,
        drawer: KyubiDrawer(
          user: user,
          onProfileTap: () {
            Navigator.pop(context);
            widget.navigationShell.goBranch(3);
          },
        ),
        body: widget.navigationShell,
        bottomNavigationBar: _KyubiNavBar(
          currentIndex: index,
          onSelect: (i) =>
              widget.navigationShell.goBranch(i, initialLocation: i == index),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BARRA INFERIOR CANÓNICA CLOVER SPACE (4 TABS)
// ─────────────────────────────────────────────────────────────

class _KyubiNavBar extends StatelessWidget {
  const _KyubiNavBar({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundBase.withValues(alpha: 0.78),
            border: const Border(
              top: BorderSide(color: Color(0xFF1E1E28), width: 0.8),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  for (int i = 0; i < _shellDestinations.length; i++)
                    Expanded(
                      child: _NavItem(
                        index: i,
                        selected: currentIndex == i,
                        onTap: () => onSelect(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final destination = _shellDestinations[index];
    final color = selected ? const Color(0xFFA594F9) : const Color(0xFF6A6A7A);

    return InkWell(
      onTap: onTap,
      splashColor: const Color(0xFFA594F9).withValues(alpha: 0.12),
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: AppDimens.motionFast,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? const Color(0xFFA594F9).withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: destination.label == 'Comunidades'
                ? Image.asset(
                    AppAssets.iconComunidades,
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    color: color,
                  )
                : destination.label == 'Mensajes'
                    ? Image.asset(
                        AppAssets.iconMensajes,
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                        color: color,
                      )
                    : destination.label == 'Salas'
                        ? Image.asset(
                            AppAssets.iconSalas,
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                            color: color,
                          )
                        : Icon(
                            selected ? destination.icon : destination.iconOutline,
                            size: 22,
                            color: color,
                          ),
          ),
          const SizedBox(height: 2),
          Text(
            destination.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: color,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
