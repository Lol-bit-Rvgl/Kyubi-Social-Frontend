import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Barra de pestañas sticky del perfil (SliverAppBar → SliverPersistentHeader).
///
/// Fondo "liquid glass" casi opaco (`0xFF0D0A14` @ α0.95 + blur 16) con borde
/// inferior glass e indicador en gradiente Nebulæ (#D100D1 → #7B2CBF)
/// redondeado de 3px. El blur + fondo opaco garantizan que el contenido del
/// feed NUNCA se lea a través de la barra al hacer scroll.
class ProfileTabsHeader extends StatelessWidget {
  const ProfileTabsHeader({super.key, required this.tabs});

  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabsHeaderDelegate(
        minHeight: 46,
        maxHeight: 46,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: const BoxDecoration(
                // Fondo neutro cósmico casi opaco: los posts pasan por debajo
                // del blur sin transliterse hacia las etiquetas de los tabs.
                color: Color(0xF20D0A14),
                border: Border(
                  bottom: BorderSide(color: AppColors.borderGlass, width: 0.8),
                ),
              ),
              child: TabBar(
                tabs: [for (final label in tabs) Tab(text: label)],
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF6E6E78),
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: const _GradientTabIndicator(),
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 24),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TabsHeaderDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  final Widget child;
  final double minHeight;
  final double maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _TabsHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.minHeight != minHeight ||
        oldDelegate.maxHeight != maxHeight;
  }
}

/// Indicador de pestaña: barra de 3px con gradiente Nebulæ y bordes redondeados.
class _GradientTabIndicator extends Decoration {
  const _GradientTabIndicator();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _GradientTabIndicatorPainter();
  }
}

class _GradientTabIndicatorPainter extends BoxPainter {
  static const double _height = 3;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size!;
    final rect = Rect.fromLTWH(
      offset.dx,
      offset.dy + size.height - _height,
      size.width,
      _height,
    );
    final paint = Paint()
      ..shader = AppColors.brandGradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
      paint,
    );
  }
}
