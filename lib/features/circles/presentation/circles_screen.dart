import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/animated_fluid_background.dart';
import '../../../../core/widgets/kyubi_shimmer.dart';
import '../../../../core/widgets/liquid_glass_container.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../models/circle.dart';
import '../../../../models/room.dart';
import '../../../../models/user.dart';
import 'circles_controller.dart';

/// Hub de Descubrimiento de Comunidades, Salas en Vivo y Personas Sugeridas (Project Z Aesthetic).
class CirclesScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const CirclesScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends ConsumerState<CirclesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _filterTags = [
    '#Todos',
    '#Rol',
    '#Música',
    '#Anime',
    '#Charla',
    '#Gaming',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(circlesControllerProvider.notifier).setTab(widget.initialTab);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant CirclesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      ref.read(circlesControllerProvider.notifier).setTab(widget.initialTab);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(circlesControllerProvider);
    final notifier = ref.read(circlesControllerProvider.notifier);
    final canPop = Navigator.of(context).canPop();

    // Filtrado de salas según tag y búsqueda
    final filteredRooms = state.rooms.where((room) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = room.name.toLowerCase().contains(query);
        final matchesHost = room.host.displayName.toLowerCase().contains(query);
        if (!matchesName && !matchesHost) return false;
      }

      if (state.selectedTag == '#Todos' || state.selectedTag == 'Todos') {
        return true;
      }
      final tagClean = state.selectedTag.replaceAll('#', '').toLowerCase();
      final inCircle = (room.circle?.name ?? '').toLowerCase().contains(
        tagClean,
      );
      final inTags = room.tags.any((t) => t.toLowerCase().contains(tagClean));
      final inKind = room.kind.name.toLowerCase().contains(tagClean);
      final inDesc = (room.description ?? '').toLowerCase().contains(tagClean);
      return inCircle || inTags || inKind || inDesc;
    }).toList();

    // Filtrado de círculos según búsqueda
    final filteredCircles = state.circles.where((circle) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final inName = circle.name.toLowerCase().contains(query);
      final inDesc = (circle.description ?? '').toLowerCase().contains(query);
      final inTags = circle.tags.any((t) => t.toLowerCase().contains(query));
      return inName || inDesc || inTags;
    }).toList();

    // Filtrado de mis círculos según búsqueda
    final filteredMyCircles = state.myCircles.where((circle) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final inName = circle.name.toLowerCase().contains(query);
      final inDesc = (circle.description ?? '').toLowerCase().contains(query);
      final inTags = circle.tags.any((t) => t.toLowerCase().contains(query));
      return inName || inDesc || inTags;
    }).toList();

    // Filtrado de personas sugeridas
    final filteredUsers = state.suggestedUsers.where((user) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final inName = user.displayName.toLowerCase().contains(query);
      final inHandle = user.username.toLowerCase().contains(query);
      return inName || inHandle;
    }).toList();

    return AnimatedFluidBackground(
      assetPath: 'assets/images/bg_fluid_ambient.webp',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => notifier.refresh(),
            color: const Color(0xFFA594F9),
            backgroundColor: const Color(0xFF2E2850),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // ── Header Superior ──
                _buildTopBar(context, state, canPop),

                // ── Selector de Pestañas (Explorar / Mis Círculos) ──
                _buildTabsSelector(context, state, notifier),

                // ── Barra de Búsqueda Universal Estilizada ──
                _buildUniversalSearchBar(state),

                if (state.currentTab == 0) ...[
                  // ── BLOQUE 1: COMUNIDADES DESTACADAS (Circles) ──
                  _buildBlock1Circles(context, filteredCircles),

                  // Separación estricta de 24px entre bloques
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // ── BLOQUE 2: SALAS Y CHATS EN VIVO 🔴 LIVE (Rooms) ──
                  _buildBlock2LiveRooms(context, state, notifier, filteredRooms),

                  // Separación estricta de 24px entre bloques
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // ── BLOQUE 3: PERSONAS SUGERIDAS (NO OCs) ──
                  _buildBlock3SuggestedUsers(
                    context,
                    state,
                    notifier,
                    filteredUsers,
                  ),
                ] else ...[
                  // ── PESTAÑA: MIS CÍRCULOS (Públicos y Privados) ──
                  _buildMyCirclesSection(
                    context,
                    state,
                    notifier,
                    filteredMyCircles,
                  ),
                ],

                // Espacio inferior para navegación flotante
                const SliverPadding(
                  padding: EdgeInsets.only(
                    bottom: AppDimens.bottomNavHeight + 36,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header Superior ──────────────────────────────────────────────────────

  Widget _buildTopBar(
    BuildContext context,
    CirclesState state,
    bool canPop,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Row(
          children: [
            if (canPop)
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF22222E),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () => Scaffold.of(context).openDrawer(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF22222E),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.menu_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Text(
              state.currentTab == 0 ? 'Explorar' : 'Mis Círculos',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            // Botón Contextual (Crear en Mis Círculos / Salas Hub en Explorar)
            GestureDetector(
              onTap: () => state.currentTab == 1
                  ? context.push('/circles/create')
                  : context.push('/salas'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF22222E),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      state.currentTab == 1
                          ? Icons.add_rounded
                          : Icons.radio_button_checked_rounded,
                      size: 14,
                      color: state.currentTab == 1
                          ? const Color(0xFFA594F9)
                          : const Color(0xFF5BC8AF),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.currentTab == 1 ? 'Crear' : 'Salas Hub',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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

  // ── Selector Segmentado de Pestañas (Explorar / Mis Círculos) ──────────────

  Widget _buildTabsSelector(
    BuildContext context,
    CirclesState state,
    CirclesNotifier notifier,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF14141B).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildTabItem(
                  title: 'Explorar',
                  icon: Icons.explore_rounded,
                  isSelected: state.currentTab == 0,
                  onTap: () => notifier.setTab(0),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildTabItem(
                  title: 'Mis Círculos',
                  icon: Icons.groups_rounded,
                  isSelected: state.currentTab == 1,
                  badgeCount: state.myCircles.length,
                  onTap: () => notifier.setTab(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2A2440) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(
                  color: const Color(0xFFA594F9).withValues(alpha: 0.6),
                  width: 1,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFA594F9).withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFFA594F9) : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFA594F9)
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? const Color(0xFF14141B)
                        : Colors.white70,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Barra de Búsqueda Universal Estilizada ────────────────────────────────

  Widget _buildUniversalSearchBar(CirclesState state) {
    final hasQuery = _searchQuery.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            // Cápsula translúcida neutra: reacciona al tema vía scheme.primary.
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: scheme.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  cursorColor: scheme.primary,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: state.currentTab == 0
                        ? 'Buscar personas, comunidades, salas...'
                        : 'Buscar en mis círculos...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              if (hasQuery)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: scheme.primary.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── PESTAÑA: MIS CÍRCULOS (Públicos y Privados) ───────────────────────────

  Widget _buildMyCirclesSection(
    BuildContext context,
    CirclesState state,
    CirclesNotifier notifier,
    List<Circle> circles,
  ) {
    if (state.myCirclesLoading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildMyCircleSkeleton(),
            childCount: 4,
          ),
        ),
      );
    }

    if (circles.isEmpty) {
      final searching = _searchQuery.trim().isNotEmpty;
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: EmptyView(
            icon: Icons.groups_2_rounded,
            title: searching ? 'Sin resultados' : 'Aún no tienes círculos',
            message: searching
                ? 'No se encontraron comunidades que coincidan con "$_searchQuery".'
                : 'Explora y únete a comunidades afines o crea tu propio círculo.',
            actionLabel: searching ? null : 'Explorar comunidades',
            onAction: searching ? null : () => notifier.setTab(0),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final circle = circles[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildMyCircleCard(context, circle),
            );
          },
          childCount: circles.length,
        ),
      ),
    );
  }

  Widget _buildMyCircleCard(BuildContext context, Circle circle) {
    final isOwner = circle.isCreator || circle.role == CircleRole.owner;
    final isAdmin = circle.role == CircleRole.admin;

    return GestureDetector(
      onTap: () => context.push('/circles/${circle.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14141B).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: circle.isPrivate
                ? const Color(0xFFA594F9).withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar squircle de la comunidad (58x58)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 58,
                height: 58,
                child: circle.avatarUrl != null && circle.avatarUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: circle.avatarUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: const Color(0xFF1E1A2E),
                          child: const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFA594F9),
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, _, _) => _fallbackCircleAvatar(circle.name),
                      )
                    : _fallbackCircleAvatar(circle.name),
              ),
            ),
            const SizedBox(width: 14),

            // Contenido central
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título y Badges
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          circle.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Badge Privado (si corresponde)
                      if (circle.isPrivate) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E2248),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFA594F9).withValues(alpha: 0.6),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                size: 10,
                                color: Color(0xFFA594F9),
                              ),
                              SizedBox(width: 3.5),
                              Text(
                                'Privado',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFA594F9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],

                      // Badge de Rol: Creador / Admin / Miembro
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isOwner
                              ? const Color(0xFF332612)
                              : (isAdmin
                                  ? const Color(0xFF1E2838)
                                  : const Color(0xFF1C2230)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isOwner
                                ? const Color(0xFFFFB800).withValues(alpha: 0.6)
                                : (isAdmin
                                    ? const Color(0xFF4FA3E3).withValues(alpha: 0.6)
                                    : const Color(0xFF5BC8AF).withValues(alpha: 0.6)),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          isOwner
                              ? '👑 Creador'
                              : (isAdmin ? '🛡️ Admin' : '🛡️ Miembro'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isOwner
                                ? const Color(0xFFFFD166)
                                : (isAdmin
                                    ? const Color(0xFF70C2FF)
                                    : const Color(0xFF5BC8AF)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Descripción corta
                  if (circle.description != null &&
                      circle.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      circle.description!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.65),
                        height: 1.25,
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Métricas / Tags
                  Row(
                    children: [
                      Icon(
                        Icons.people_alt_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${circle.memberCount} ${circle.memberCount == 1 ? 'miembro' : 'miembros'}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      if (circle.roomCount > 0) ...[
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.radio_button_checked_rounded,
                          size: 13,
                          color: Color(0xFF5BC8AF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${circle.roomCount} ${circle.roomCount == 1 ? 'sala' : 'salas'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5BC8AF),
                          ),
                        ),
                      ],
                      if (circle.tags.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            circle.tags
                                .map((t) => t.startsWith('#') ? t : '#$t')
                                .take(2)
                                .join(' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFA594F9).withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyCircleSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: const Color(0xFF14141B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF22222E), width: 0.8),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            KyubiShimmer(
              width: 58,
              height: 58,
              borderRadius: BorderRadius.circular(16),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  KyubiShimmer(
                    width: 140,
                    height: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  KyubiShimmer(
                    width: 200,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackCircleAvatar(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E2850), Color(0xFF1B1730)],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFFA594F9),
          ),
        ),
      ),
    );
  }

  // ── BLOQUE 1: COMUNIDADES DESTACADAS (Circles) ───────────────────────────

  Widget _buildBlock1Circles(BuildContext context, List<Circle> circles) {
    // Estado vacío real: sin comunidades cargadas o sin coincidencias de búsqueda.
    if (circles.isEmpty) {
      final searching = _searchQuery.trim().isNotEmpty;
      return SliverToBoxAdapter(
        child: EmptyView(
          icon: Icons.groups_2_rounded,
          title: searching ? 'Sin resultados' : 'Aún no hay comunidades',
          message: searching
              ? 'No se encontraron comunidades que coincidan con tu búsqueda.'
              : 'Crea la primera comunidad o vuelve más tarde para descubrir nuevas.',
          actionLabel: 'Crear comunidad',
          onAction: () => context.push('/circles/create'),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bloque 1
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accentTeal,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentTeal,
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'COMUNIDADES',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/circles/create'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.nightGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Crear +',
                          style: TextStyle(
                            fontSize: 12,
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
          const SizedBox(height: 12),

          // Carrusel Horizontal Espacioso (~205px de alto)
          SizedBox(
            height: 205,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: circles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final circle = circles[index];
                return _buildCircleCard(context, circle);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleCard(BuildContext context, Circle circle) {
    final hasTags = circle.tags.isNotEmpty;
    final primaryTag = hasTags ? circle.tags.first : '🟢 Activa';

    return GestureDetector(
      onTap: () => context.push('/circles/${circle.id}'),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF14141B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF22222E), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cover inmersivo con degradado vertical
            if (circle.avatarUrl != null && circle.avatarUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: circle.avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => const KyubiShimmer(),
                errorWidget: (_, _, _) => _fallbackCircleCover(circle.name),
              )
            else
              _fallbackCircleCover(circle.name),

            // Gradiente vertical oscuro hacia #14141B en la base
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x220B0B10),
                    Color(0x880B0B10),
                    Color(0xF014141B),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),

            // Badge flotante translúcido superior
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12, width: 0.6),
                ),
                child: Text(
                  primaryTag,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Nombre y contador de miembros en la base
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    circle.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        size: 12,
                        color: Color(0xFF00E5FF),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${circle.memberCount} miembros',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9E9EA8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackCircleCover(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B1020), Color(0xFF101B2E)],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: Colors.white24,
          ),
        ),
      ),
    );
  }

  // ── BLOQUE 2: SALAS Y CHATS EN VIVO 🔴 LIVE (Rooms) ──────────────────────

  Widget _buildBlock2LiveRooms(
    BuildContext context,
    CirclesState state,
    CirclesNotifier notifier,
    List<Room> rooms,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bloque 2
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF1744),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFF1744),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'LIVE SALAS Y CHATS EN VIVO',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/salas/create'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B162B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF2C2544),
                        width: 0.8,
                      ),
                    ),
                    child: const Text(
                      'Crear Sala +',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentCyan,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Filtros Rápidos (#Todos, #Rol, #Música, #Anime, #Charla, #Gaming)
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _filterTags.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tag = _filterTags[index];
                  final isSelected =
                      state.selectedTag == tag ||
                      (tag == '#Todos' && state.selectedTag == 'Todos');
                  final primaryColor = Theme.of(context).colorScheme.primary;
                  final secondaryColor =
                      Theme.of(context).colorScheme.secondary;
                  return GestureDetector(
                    onTap: () => notifier.selectTag(tag),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : null,
                        color: isSelected ? null : const Color(0xFF14141B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? primaryColor.withValues(alpha: 0.4)
                              : const Color(0xFF22222E),
                          width: isSelected ? 1.2 : 0.8,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Lista Vertical de Salas
            if (rooms.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: EmptyView(
                  icon: Icons.sensors_off_rounded,
                  title: 'No hay salas en vivo',
                  message:
                      'Aún no hay salas activas para esta categoría. Crea la primera.',
                  actionLabel: 'Crear sala',
                  onAction: () => context.push('/salas/create'),
                ),
              )
            else
              ...rooms.map((room) => _buildRoomCard(context, room)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard(BuildContext context, Room room) {
    final isVoice = room.isVoice;
    final isScreening = room.isScreening;
    final isRoleplay = room.isRoleplay;

    final (badgeIcon, badgeColor) = isScreening
        ? (Icons.movie_creation_rounded, const Color(0xFFFF3366))
        : isRoleplay
            ? (Icons.theater_comedy_rounded, const Color(0xFFFFD600))
            : isVoice
                ? (Icons.mic_rounded, const Color(0xFF00E5FF))
                : (Icons.chat_bubble_rounded, const Color(0xFF8E8EA0));

    final hostName = room.host.displayName;
    final categoryName =
        room.circle?.name ??
        (room.tags.isNotEmpty ? room.tags.first : 'General');
    final tagDisplay = room.tags.isNotEmpty
        ? room.tags.take(2).map((t) => '#${t.replaceAll(' ', '')}').join(' ')
        : '#${categoryName.replaceAll(' ', '')}';

    return LiquidGlassContainer(
      width: double.infinity,
      borderRadius: 16,
      blur: 12,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Izquierda: Cover/Avatar squircle (56x56) con badge de modo
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF2C2542),
                      width: 0.8,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: room.imageUrl != null && room.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: room.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => const KyubiShimmer(),
                          errorWidget: (_, _, _) =>
                              _fallbackRoomCover(room),
                        )
                      : _fallbackRoomCover(room),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14141B),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: badgeColor.withValues(alpha: 0.25),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      badgeIcon,
                      size: 11,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Centro: Título, @HostName · Categoría y Tags en cian
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@$hostName · $categoryName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tagDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentCyan,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Derecha: Indicador de activos + Botón Entrar
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.accentTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${room.participantCount} activos',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentTeal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => context.push('/salas/${room.id}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3636),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accentCyan, width: 0.8),
                  ),
                  child: const Text(
                    'Entrar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentCyan,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fallbackRoomCover(Room room) {
    final iconData = room.isScreening
        ? Icons.movie_creation_rounded
        : room.isRoleplay
            ? Icons.theater_comedy_rounded
            : room.isVoice
                ? Icons.mic_rounded
                : Icons.forum_rounded;
    final iconColor = room.isScreening
        ? const Color(0xFFFF3366)
        : room.isRoleplay
            ? const Color(0xFFFFD600)
            : room.isVoice
                ? const Color(0xFF00E5FF)
                : AppColors.accentCyan;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1430), Color(0xFF0A222E)],
        ),
      ),
      child: Center(
        child: Icon(
          iconData,
          color: iconColor,
          size: 24,
        ),
      ),
    );
  }

  // ── BLOQUE 3: PERSONAS SUGERIDAS (NO OCs) ────────────────────────────────

  Widget _buildBlock3SuggestedUsers(
    BuildContext context,
    CirclesState state,
    CirclesNotifier notifier,
    List<FollowItem> users,
  ) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bloque 3
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.person_pin_rounded,
                  size: 16,
                  color: AppColors.accentCyan,
                ),
                SizedBox(width: 8),
                Text(
                  'PERSONAS SUGERIDAS',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Carrusel Horizontal de Perfiles de Usuarios Reales
          if (users.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: EmptyView(
                icon: Icons.person_search_rounded,
                title: 'No hay personas sugeridas',
                message:
                    'Vuelve más tarde para descubrir nuevos perfiles que seguir.',
              ),
            )
          else
            SizedBox(
              height: 188,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: users.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isFollowing = state.followedUserIds.contains(user.id);
                  return _buildUserCard(context, user, isFollowing, notifier);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    FollowItem user,
    bool isFollowing,
    CirclesNotifier notifier,
  ) {
    // Intereses basados en el usuario real (no OCs)
    final chipLabel = user.bio != null && user.bio!.isNotEmpty
        ? user.bio!
        : '✨ Miembro';

    return LiquidGlassContainer(
      width: 136,
      borderRadius: 18,
      blur: 12,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar circular centrado (52x52)
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2E2744), width: 1.5),
            ),
            child: ClipOval(
              child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: user.avatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const KyubiShimmer(),
                      errorWidget: (_, _, _) =>
                          _fallbackUserAvatar(user.displayName),
                    )
                  : _fallbackUserAvatar(user.displayName),
            ),
          ),
          const SizedBox(height: 8),

          // Nombre en negrita
          Text(
            user.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),

          // @handle
          Text(
            '@${user.username}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7A7A8E),
            ),
          ),
          const SizedBox(height: 4),

          // Chip de rol / interés
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1A2E),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              chipLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB0B0C4),
              ),
            ),
          ),
          const Spacer(),

          // Botón [ Seguir ] / [ Siguiendo ]
          GestureDetector(
            onTap: () => notifier.toggleFollow(user.id),
            child: Container(
              width: double.infinity,
              height: 28,
              decoration: BoxDecoration(
                color: isFollowing
                    ? const Color(0xFF1E1A2E)
                    : const Color(0xFF3B2D60),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFollowing
                      ? const Color(0xFF332B4F)
                      : const Color(0xFF5B4A8C),
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  isFollowing ? 'Siguiendo' : 'Seguir',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isFollowing ? AppColors.textSecondary : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackUserAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      color: const Color(0xFF1E1A2E),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.accentCyan,
          ),
        ),
      ),
    );
  }
}
