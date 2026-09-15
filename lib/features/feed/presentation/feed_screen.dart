import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/animated_fluid_background.dart';
import '../../../../core/widgets/list_pagination.dart';
import '../../../../core/widgets/liquid_glass_container.dart';
import '../../../../core/widgets/skeleton_list.dart';
import '../../../../core/widgets/state_views.dart';
import '../../home/presentation/widgets/header_profile.dart';
import 'feed_controller.dart';
import 'widgets/kyubi_fox_hero_animation.dart';
import 'widgets/post_card.dart';

/// Pantalla principal (Inicio / Feed) idéntica a la maqueta oficial de Kyubi.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  int _selectedTab = 0; // 0: Para ti, 1: Siguiendo, 2: Tendencias

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedControllerProvider);
    final notifier = ref.read(feedControllerProvider.notifier);

    if (feed.loading && feed.posts.isEmpty) {
      return const AnimatedFluidBackground(
        assetPath: 'assets/images/bg_fluid_ambient.webp',
        child: ColoredBox(
          color: Colors.transparent,
          child: SafeArea(child: SkeletonList()),
        ),
      );
    }

    if (feed.error != null && feed.posts.isEmpty) {
      return AnimatedFluidBackground(
        assetPath: 'assets/images/bg_fluid_ambient.webp',
        child: ColoredBox(
          color: Colors.transparent,
          child: SafeArea(
            child: ErrorView(message: feed.error!, onRetry: notifier.refresh),
          ),
        ),
      );
    }

    return AnimatedFluidBackground(
      assetPath: 'assets/images/bg_fluid_ambient.webp',
      child: ColoredBox(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: notifier.refresh,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: const Color(0xFF0D0A14),
            child: EndReachedNotifier(
              onEndReached: notifier.loadMore,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // 1. Cabecera superior (Avatar + Notificaciones)
                  const HeaderProfile(),

                  // 2. Buscador horizontal
                  _buildSearchBar(context),

                  // 3. Mascota Heroica Kyubi (Zorro real con aura y partículas)
                  _buildHeroKyubiMascot(context),

                  // Espaciador vertical a las tarjetas de acción (24px)
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // 4. Tarjetas de Acción Rápida (Match / Buscar & Tirar una Botella)
                  _buildDualActionCards(context),

                  // Espaciador vertical antes del banner panorámico (20px)
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // 5. Banner Promocional Panorámico (¡Bienvenido a Kyubi!)
                  _buildWelcomeBanner(context),

                  // Espaciador vertical antes de los tabs horizontales (22px)
                  const SliverToBoxAdapter(child: SizedBox(height: 22)),

                  // 6. Tabs Horizontales (Para ti, Siguiendo, Tendencias)
                  _buildTabsSelector(context, feed, notifier),

                  // Espaciador vertical para bajar la posición del feed (18px)
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),

                  // 7. Lista vertical de publicaciones (Feed Posts)
                  _buildPostList(feed, notifier),

                  // Espaciador inferior para no solapar el bottom navigation bar
                  const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 2. Barra de búsqueda horizontal ──────────────────────────────────────

  // ── 3. Mascota Heroica Kyubi con animación MP4 en bucle y aura ──────────

  Widget _buildHeroKyubiMascot(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: const [
              // Partículas flotantes sutiles (puntos carmesí y cian)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _ParticlePainter()),
                ),
              ),
              // Animación heroica del zorro Kyubi en bucle con aura violeta/cian
              KyubiFoxHeroAnimation(
                width: 195,
                height: 175,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 4. Tarjetas Duales de Acción Rápida ──────────────────────────────────

  // ── 2. Barra de búsqueda horizontal ──────────────────────────────────────

  Widget _buildSearchBar(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppDimens.md, 8, AppDimens.md, 14),
        child: GestureDetector(
          onTap: () => context.push('/search'),
          child: LiquidGlassContainer(
            borderRadius: 16,
            blur: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: const Row(
              children: [
                Icon(Icons.search_rounded, size: 19, color: Color(0xFF7A7A8A)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Buscar usuarios, salas, círculos...',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF6A6A7A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 4. Tarjetas Duales de Acción Rápida ──────────────────────────────────

  Widget _buildDualActionCards(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
        child: Row(
          children: [
            // ── Tarjeta 1: Match / Buscar ──
            Expanded(
              child: _buildActionCard(
                context,
                iconWidget: Image.asset(
                  AppAssets.iconMatching,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                ),
                circleColor: const Color(0xFF141E26),
                glowColor: AppColors.accentCyan,
                lines: const ['Match /', 'Buscar'],
                onTap: () => context.push('/matchmaking'),
              ),
            ),
            const SizedBox(width: 12),

            // ── Tarjeta 2: Tirar una Botella ──
            Expanded(
              child: _buildActionCard(
                context,
                iconWidget: Image.asset(
                  AppAssets.iconTirarBotella,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                ),
                circleColor: const Color(0xFF241218),
                glowColor: AppColors.accentCrimson,
                lines: const ['Tirar una', 'Botella'],
                onTap: () => _openDriftingBottleSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    IconData? icon,
    Widget? iconWidget,
    Color? iconColor,
    required Color circleColor,
    required Color glowColor,
    required List<String> lines,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassContainer(
        width: double.infinity,
        borderRadius: 18,
        blur: 12,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleColor,
                  border: Border.all(
                    color: glowColor.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: iconWidget ??
                      Icon(icon, size: 21, color: iconColor ?? Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < lines.length; i++)
                      Text(
                        lines[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF7A7A8A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 5. Banner Promocional Panorámico con asset real ───────────────────────

  Widget _buildWelcomeBanner(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
        child: LiquidGlassContainer(
          borderRadius: 22,
          padding: EdgeInsets.zero,
          blur: 12,
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Banner oficial inicial panorámico
              Image.asset(
                AppAssets.bannerInicial,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const CustomPaint(painter: _ToriiBannerPainter()),
              ),
              // Gradiente de contraste para legibilidad
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x11000000),
                      Color(0x770B0B10),
                      Color(0xEB0B0B10),
                    ],
                    stops: [0.0, 0.40, 1.0],
                  ),
                ),
              ),
              // Textos del banner
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¡Bienvenido a Kyubi!',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Explora el universo social del roleplay',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 5b. Barra de historias efímeras ─────────────────────────────────────

  // ── 6. Selector de Pestañas (Para ti, Siguiendo, Tendencias) ──────────────

  Widget _buildTabsSelector(
    BuildContext context,
    FeedState feed,
    FeedNotifier notifier,
  ) {
    const tabs = ['Para ti', 'Siguiendo', 'Tendencias'];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusFull),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceCards.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                border: Border.all(
                  color: AppColors.borderNight.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: List.generate(tabs.length, (index) {
                  final isSelected = _selectedTab == index;
                  final primaryColor = Theme.of(context).colorScheme.primary;
                  final secondaryColor =
                      Theme.of(context).colorScheme.secondary;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedTab = index);
                        if (index == 0) {
                          notifier.switchCategory('para_ti');
                        } else if (index == 1) {
                          notifier.switchCategory('following');
                        } else {
                          notifier.switchCategory('trending');
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [primaryColor, secondaryColor],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : null,
                          color: isSelected
                              ? null
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            tabs[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF9E9EA8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 7. Lista vertical de publicaciones (Feed) ────────────────────────────

  Widget _buildPostList(FeedState feed, FeedNotifier notifier) {
    if (feed.posts.isEmpty && !feed.loading) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Column(
          children: [
            const SizedBox(height: 50),
            EmptyView(
              illustration: AppAssets.emptyFeed,
              illustrationWidth: 160,
              illustrationHeight: 160,
              icon: Icons.dynamic_feed_outlined,
              title: 'Aún no hay publicaciones',
              message: 'Sé el primero en compartir un momento o historia.',
            ),
          ],
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= feed.posts.length) {
            return ListEndIndicator(hasMore: feed.hasMore);
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: PostCard(post: feed.posts[index]),
          );
        }, childCount: feed.posts.length + 1),
      ),
    );
  }

  // ── Modal de "Tirar una Botella" ─────────────────────────────────────────

  void _openDriftingBottleSheet(BuildContext context) {
    final textController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Image.asset(
                    AppAssets.iconTirarBotella,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Tirar una Botella al Mar',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Escribe un mensaje anónimo o una propuesta de rol. Un viajero aleatorio lo encontrará en la orilla.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textController,
                maxLines: 4,
                maxLength: 300,
                style: const TextStyle(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  hintText: '¿Qué mensaje deseas lanzar al océano de Kyubi?...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6A6A7A),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A1A26),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF2E2E3E),
                      width: 0.8,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF2E2E3E),
                      width: 0.8,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.accentCrimson,
                      width: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {
                  final text = textController.text.trim();
                  if (text.isEmpty) return;
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🌊 ¡Botella lanzada al mar con éxito!'),
                      backgroundColor: AppColors.accentCrimson,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppColors.nightGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9B6FCB).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Lanzar Botella',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Painter para partículas/estrellas flotantes ─────────────────────────────

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paintRed = Paint()
      ..color = AppColors.accentCrimson.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final paintCyan = Paint()
      ..color = AppColors.accentCyan.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.3),
      2.2,
      paintRed,
    );
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.65),
      1.8,
      paintCyan,
    );
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.8),
      2.0,
      paintRed,
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.25),
      2.2,
      paintCyan,
    );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.6),
      1.8,
      paintRed,
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.85),
      2.0,
      paintCyan,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Painter fallback para el Banner Torii ──────────────────────────────────

class _ToriiBannerPainter extends CustomPainter {
  const _ToriiBannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bgRect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2A0D15), Color(0xFF14080D), Color(0xFF1E0A12)],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: '¡BIENVENIDO A KYUBI!',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Color(0x38FFFFFF),
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height * 0.28),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
