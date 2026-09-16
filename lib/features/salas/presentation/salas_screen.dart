import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/kyubi_shimmer.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../models/post_author.dart';
import '../../../../models/room.dart';
import 'salas_controller.dart';

/// Pantalla oficial de Salas / Chats en Vivo estilo Project Z (Referencia: project-z-31828-8.jpg).
class SalasScreen extends ConsumerStatefulWidget {
  const SalasScreen({super.key, this.circleId});

  final String? circleId;

  @override
  ConsumerState<SalasScreen> createState() => _SalasScreenState();
}

class _SalasScreenState extends ConsumerState<SalasScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearchVisible = false;

  // Filtros de navegación superior
  int _selectedFilterTab = 0; // 0: Recommended, 1: Popular, 2: Latest
  String? _selectedCategoryTag; // null, 'voice', 'screening', 'roleplay'

  @override
  void initState() {
    super.initState();
    if (widget.circleId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(salasControllerProvider.notifier)
            .filterByCircle(widget.circleId);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salasControllerProvider);

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/main');
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.obsidianBg,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () => ref.read(salasControllerProvider.notifier).refresh(),
            // Indicador temático Nebulæ: spinner #D100D1 sobre #2B0D3A.
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceCards,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // ── 1. Header Superior "Rooms" ──
                _buildHeader(context),

                // ── Barra de Búsqueda Desplegable ──
                if (_isSearchVisible) _buildSearchBar(),

                // ── 2. Píldoras de Filtro (Fila 1: Recommended, Popular, Latest / Fila 2: Modos de Sala) ──
                _buildFilterChips(),

                // ── 3. Grid de Salas (2 Columnas) ──
                _buildRoomsGrid(state),

                // Espacio inferior
                const SliverPadding(
                  padding: EdgeInsets.only(
                    bottom: AppDimens.bottomNavHeight + 30,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. Header Superior ───────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.md,
          AppDimens.sm,
          AppDimens.md,
          AppDimens.xs,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/main');
                }
              },
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
            ),
            const Expanded(
              child: Text(
                'Rooms',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            // Botón de búsqueda
            GestureDetector(
              onTap: () {
                setState(() => _isSearchVisible = !_isSearchVisible);
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _isSearchVisible
                      ? AppColors.accentCyan.withValues(alpha: 0.15)
                      : const Color(0xFF14141B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSearchVisible
                        ? AppColors.accentCyan
                        : const Color(0xFF22222E),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: _isSearchVisible ? AppColors.accentCyan : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Botón crear sala [+]
            GestureDetector(
              onTap: () => context.push('/salas/create'),
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
                  Icons.add_rounded,
                  size: 22,
                  color: AppColors.accentCrimson,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Barra de Búsqueda Desplegable ────────────────────────────────────────

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppDimens.md, 6, AppDimens.md, 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF14141B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF22222E), width: 0.8),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () {
                ref.read(salasControllerProvider.notifier).search(value);
              });
            },
            style: const TextStyle(fontSize: 13.5, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar salas por nombre o temática...',
              hintStyle: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF7A7A8A),
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 18,
                color: Color(0xFF7A7A8A),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(salasControllerProvider.notifier).search('');
                      },
                    )
                  : null,
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimens.md,
                vertical: 10,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 2. Píldoras de Filtro (Fila 1 & Fila 2) ───────────────────────────────

  Widget _buildFilterChips() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppDimens.md, 8, AppDimens.md, 14),
        child: Column(
          children: [
            // Fila 1: Recommended, Popular, Latest
            Row(
              children: [
                _buildPill(
                  index: 0,
                  emoji: '👍',
                  label: 'Recommended',
                  accentColor: const Color(0xFF00E5FF),
                  isSelected: _selectedFilterTab == 0,
                  onTap: () => setState(() => _selectedFilterTab = 0),
                ),
                const SizedBox(width: 8),
                _buildPill(
                  index: 1,
                  emoji: '🔥',
                  label: 'Popular',
                  accentColor: const Color(0xFFFF9100),
                  isSelected: _selectedFilterTab == 1,
                  onTap: () => setState(() => _selectedFilterTab = 1),
                ),
                const SizedBox(width: 8),
                _buildPill(
                  index: 2,
                  emoji: '🆕',
                  label: 'Latest',
                  accentColor: const Color(0xFF2979FF),
                  isSelected: _selectedFilterTab == 2,
                  onTap: () => setState(() => _selectedFilterTab = 2),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Fila 2: Voice Chat, Screening Room, Roleplay
            Row(
              children: [
                _buildCategoryPill(
                  tag: 'voice',
                  icon: Icons.graphic_eq_rounded,
                  iconColor: AppColors.accentTeal,
                  label: 'Voice Chat',
                ),
                const SizedBox(width: 8),
                _buildCategoryPill(
                  tag: 'screening',
                  icon: Icons.live_tv_rounded,
                  iconColor: const Color(0xFFD500F9),
                  label: 'Screening Room',
                ),
                const SizedBox(width: 8),
                _buildCategoryPill(
                  tag: 'roleplay',
                  icon: Icons.theater_comedy_rounded,
                  iconColor: const Color(0xFFFFD600),
                  label: 'Roleplay',
                ),
              ],
            ),

            const SizedBox(height: 6),
            // Chevron indicador sutil
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill({
    required int index,
    required String emoji,
    required String label,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: isSelected ? null : const Color(0xFF14141B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? primaryColor.withValues(alpha: 0.4)
                  : const Color(0xFF22222E),
              width: 0.8,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPill({
    required String tag,
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    final isSelected = _selectedCategoryTag == tag;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          final nextTag = _selectedCategoryTag == tag ? null : tag;
          setState(() {
            _selectedCategoryTag = nextTag;
          });
          ref.read(salasControllerProvider.notifier).setCategory(nextTag);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: isSelected ? null : const Color(0xFF14141B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? primaryColor.withValues(alpha: 0.4)
                  : const Color(0xFF22222E),
              width: 0.8,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : iconColor,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 3. Grid de Salas (2 Columnas) ────────────────────────────────────────

  Widget _buildRoomsGrid(SalasState state) {
    if (state.loading && state.rooms.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 50),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.accentCrimson),
          ),
        ),
      );
    }
    if (state.error != null && state.rooms.isEmpty) {
      return SliverToBoxAdapter(
        child: ErrorView(
          message: state.error!,
          onRetry: () => ref.read(salasControllerProvider.notifier).refresh(),
          title: 'No se pudieron cargar las salas',
        ),
      );
    }

    final allRooms = state.rooms.isNotEmpty ? state.rooms : _getDemoRooms();

    // Filtrar por categoría seleccionada si aplica
    final filteredRooms = _selectedCategoryTag == null
        ? allRooms
        : allRooms
            .where((r) => r.matchesCategory(_selectedCategoryTag!))
            .toList();

    if (filteredRooms.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md,
            vertical: 40,
          ),
          child: Center(
            child: Column(
              children: [
                Image.asset(
                  AppAssets.iconTransmisionesApagadas,
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No hay salas activas en esta categoría',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => context.push('/salas/create'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.crimsonGlow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Crear Sala',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.88,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final room = filteredRooms[index];
          return _ProjectZRoomCard(room: room);
        }, childCount: filteredRooms.length),
      ),
    );
  }

  List<Room> _getDemoRooms() {
    return const [
      Room(
        id: 'r_peaceful',
        name: 'peaceful place 🌿',
        host: PostAuthor(id: 'u1', username: 'flora', displayName: 'Flora'),
        participantCount: 8,
        currentMode: 'voice',
        tags: ['Voice', 'Chill', 'Small Talk'],
        imageUrl:
            'https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?w=500&auto=format&fit=crop&q=60',
      ),
      Room(
        id: 'r_reino',
        name: '༺•*•El reino infinito•*•༻',
        host: PostAuthor(id: 'u2', username: 'shogun', displayName: 'Shogun'),
        participantCount: 16,
        currentMode: 'roleplay',
        tags: ['Videojuegos', 'Rol', 'Anime'],
        imageUrl:
            'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=500&auto=format&fit=crop&q=60',
      ),
      Room(
        id: 'r_cafe',
        name: '🥖 Family~Friends~Cafe 🥐',
        host: PostAuthor(id: 'u3', username: 'baker', displayName: 'Barista'),
        participantCount: 12,
        currentMode: 'screening',
        cinemaVideoId: 'dQw4w9WgXcQ',
        tags: ['Screening', 'Café', 'Charla'],
        imageUrl:
            'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&auto=format&fit=crop&q=60',
      ),
      Room(
        id: 'r_crimson',
        name: 'Guild Crimson ⚔️',
        host: PostAuthor(
          id: 'u4',
          username: 'valerius',
          displayName: 'Valerius',
        ),
        participantCount: 24,
        currentMode: 'roleplay',
        tags: ['Small Talk', 'Roleplay', 'Medieval'],
        imageUrl:
            'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&auto=format&fit=crop&q=60',
      ),
      Room(
        id: 'r_wonderland',
        name: 'wonderland ❄️',
        host: PostAuthor(id: 'u5', username: 'alice', displayName: 'Alice'),
        participantCount: 10,
        currentMode: 'voice',
        tags: ['Voice', 'Nieve', 'Música'],
        imageUrl:
            'https://images.unsplash.com/photo-1517048676732-d65bc937f952?w=500&auto=format&fit=crop&q=60',
      ),
      Room(
        id: 'r_survivors',
        name: 'Zver survivors',
        host: PostAuthor(id: 'u6', username: 'klaus', displayName: 'Klaus'),
        participantCount: 19,
        currentMode: 'roleplay',
        tags: ['Z Survivor', 'Anime', 'Roleplay'],
        imageUrl:
            'https://images.unsplash.com/photo-1563089145-599997674d42?w=500&auto=format&fit=crop&q=60',
      ),
      Room(
        id: 'r_academy',
        name: '⟫⟫Academy Kingdom⟪⟪',
        host: PostAuthor(id: 'u7', username: 'rector', displayName: 'Director'),
        participantCount: 29,
        currentMode: 'roleplay',
        tags: ['Roleplay', 'Fantasía', 'Magia'],
        imageUrl:
            'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=500&auto=format&fit=crop&q=60',
      ),
      Room(
        id: 'r_insomnia',
        name: 'Insomnia 🌙',
        host: PostAuthor(
          id: 'u8',
          username: 'nocturne',
          displayName: 'Nocturne',
        ),
        participantCount: 14,
        currentMode: 'screening',
        cinemaVideoId: '9bZkp7q19f0',
        tags: ['Anime & Manga', 'Screening', 'Late Night'],
        imageUrl:
            'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=500&auto=format&fit=crop&q=60',
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────
// Tarjeta Squircle de Sala estilo Project Z (2 Columnas)
// ─────────────────────────────────────────────────────────────

class _ProjectZRoomCard extends StatelessWidget {
  const _ProjectZRoomCard({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final isVoice = room.isVoice;
    final isScreening = room.isScreening;
    final isRoleplay = room.isRoleplay;

    final displayTag = room.tags.isNotEmpty
        ? '#${room.tags.first}'
        : '#General';

    return GestureDetector(
      onTap: () => context.push('/salas/${room.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cover Cuadrangular con badges ──
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF22222E), width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Imagen de portada con fallback de degradado elegante
                  if (room.imageUrl != null && room.imageUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: room.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const KyubiShimmer(),
                      errorWidget: (_, _, _) =>
                          _fallbackCover(isVoice, isScreening, isRoleplay),
                    )
                  else
                    _fallbackCover(isVoice, isScreening, isRoleplay),

                  // Gradiente vertical para contraste inferior
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x22000000),
                          Color(0x88000000),
                          Color(0xDD0B0B10),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),

                  // Badge de modo en la esquina superior derecha
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4.5),
                      decoration: BoxDecoration(
                        color: const Color(0xCC14141B),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (isScreening
                                  ? const Color(0xFFFF3366)
                                  : isRoleplay
                                      ? const Color(0xFFFFD600)
                                      : isVoice
                                          ? const Color(0xFF00E5FF)
                                          : const Color(0xFF8E8EA0))
                              .withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: isScreening
                          ? const Icon(
                              Icons.movie_creation_rounded,
                              size: 11,
                              color: Color(0xFFFF3366),
                            )
                          : isRoleplay
                              ? const Icon(
                                  Icons.theater_comedy_rounded,
                                  size: 11,
                                  color: Color(0xFFFFD600),
                                )
                              : isVoice
                                  ? const Icon(
                                      Icons.mic_rounded,
                                      size: 11,
                                      color: Color(0xFF00E5FF),
                                    )
                                  : const Icon(
                                      Icons.chat_bubble_rounded,
                                      size: 11,
                                      color: Color(0xFF8E8EA0),
                                    ),
                    ),
                  ),

                  // Badge de Hashtag sobre la imagen
                  Positioned(
                    bottom: 26,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        displayTag,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Avatares solapados en la parte inferior izquierda de la imagen
                  Positioned(
                    bottom: 6,
                    left: 8,
                    child: _buildOverlappingAvatars(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // ── Título de la Sala ──
          Text(
            room.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlappingAvatars() {
    return SizedBox(
      width: 46,
      height: 16,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _avatarCircle(0, AppColors.accentCrimson),
          _avatarCircle(10, AppColors.accentCyan),
          _avatarCircle(20, AppColors.accentPurple),
          _avatarCircle(30, const Color(0xFF4A4A5A)),
        ],
      ),
    );
  }

  Widget _avatarCircle(double left, Color color) {
    return Positioned(
      left: left,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: AppColors.backgroundBase, width: 1.2),
        ),
      ),
    );
  }

  Widget _fallbackCover(bool isVoice, bool isScreening, bool isRoleplay) {
    final (iconData, iconColor) = isScreening
        ? (Icons.movie_creation_rounded, const Color(0xFFFF3366))
        : isRoleplay
            ? (Icons.theater_comedy_rounded, const Color(0xFFFFD600))
            : isVoice
                ? (Icons.mic_rounded, const Color(0xFF00E5FF))
                : (Icons.chat_bubble_rounded, const Color(0xFF8E8EA0));
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF26101E), Color(0xFF101428)],
        ),
      ),
      child: Center(
        child: Icon(
          iconData,
          size: 32,
          color: iconColor.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
