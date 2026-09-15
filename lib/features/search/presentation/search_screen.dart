import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/asset_frame.dart';
import '../../../../core/widgets/kyubi_blob.dart';
import '../../../../core/widgets/kyubi_shimmer.dart';
import '../../../../models/circle.dart';
import '../../../../models/user.dart';
import '../../../../repositories/search_repository.dart';
import '../../../../services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Explorar: búsqueda unificada de usuarios, salas, publicaciones y
/// círculos (GET /search + GET /circles/search). Incluye debounce y
/// estados de carga, vacío y error. Las tendencias requieren backend de
/// agregación (GET /search/trending sigue siendo stub).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const Duration _debounceDuration = Duration(milliseconds: 400);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  bool _loading = false;
  bool _hasSearched = false;
  String? _error;
  List<FollowItem> _results = const [];

  // Resultados del motor full-text unificado (GET /search).
  List<SearchPost> _postResults = const [];
  List<SearchRoom> _roomResults = const [];
  List<Circle> _circleResults = const [];
  List<TrendingTag> _trendingTags = const [];
  List<String> _recentSearches = const [];
  static const String _recentKey = 'kyubi_recent_searches';

  List<FollowItem> _suggestions = const [];
  bool _loadingSuggestions = true;
  int _selectedCategoryIndex = 0; // 0: Todo, 1: Usuarios, 2: Salas, 3: Círculos
  bool _discoverRows = false; // Vista de Descubre: lista (rows) o cuadrícula.

  final Set<String> _busyFollow = {};

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
    _loadTrendingTags();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _loadingSuggestions = true);
    try {
      final suggestions = await ref
          .read(userRepositoryProvider)
          .suggestPeople(limit: 20);
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _loadTrendingTags() async {
    try {
      final tags = await ref.read(searchRepositoryProvider).trending();
      if (!mounted) return;
      setState(() => _trendingTags = tags);
    } catch (_) {
      // Silencioso: las tendencias son opcionales.
    }
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(
        () => _recentSearches = prefs.getStringList(_recentKey) ?? const [],
      );
    } catch (_) {}
  }

  Future<void> _saveRecentSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = [
        query,
        ..._recentSearches.where((s) => s != query),
      ].take(8).toList();
      await prefs.setStringList(_recentKey, updated);
      if (!mounted) return;
      setState(() => _recentSearches = updated);
    } catch (_) {}
  }

  Future<void> _clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentKey);
      if (!mounted) return;
      setState(() => _recentSearches = const []);
    } catch (_) {}
  }

  /// Índice de pestaña → tipo del backend: Todo/Usuarios/Salas/Círculos.
  String get _selectedType => switch (_selectedCategoryIndex) {
    1 => 'users',
    2 => 'rooms',
    3 => 'all',
    _ => 'all',
  };

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _clearSearch();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _debounce = Timer(_debounceDuration, () => _search(query));
  }

  /// Limpia el término de búsqueda y restablece el estado inicial.
  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _hasSearched = false;
      _results = const [];
      _postResults = const [];
      _roomResults = const [];
      _circleResults = const [];
      _error = null;
      _loading = false;
    });
  }

  Future<void> _search([String? forcedQuery]) async {
    final query = (forcedQuery ?? _controller.text).trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _hasSearched = true;
    });
    try {
      final results = await ref
          .read(searchRepositoryProvider)
          .search(query, type: _selectedType);
      // Comunidades/Círculos: endpoint separado (/circles/search); si falla
      // se ignoran y el resto de resultados sigue mostrándose.
      List<Circle> circles = const [];
      try {
        circles = await ref
            .read(circleRepositoryProvider)
            .searchCircles(query, limit: 20);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _postResults = results.posts;
        _roomResults = results.rooms;
        // Usuarios compatibles con el render existente (seguir/dejar de seguir).
        _results = results.users;
        _circleResults = circles;
        _loading = false;
      });
      await _saveRecentSearch(query);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Hubo un problema al buscar. Inténtalo de nuevo.';
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow(FollowItem item) async {
    if (_busyFollow.contains(item.id)) return;
    setState(() => _busyFollow.add(item.id));
    try {
      final repo = ref.read(userRepositoryProvider);
      final result = item.isFollowing
          ? await repo.unfollowUser(item.id)
          : await repo.followUser(item.id);
      if (!mounted) return;
      setState(() {
        FollowItem updated(FollowItem r) {
          if (r.id != item.id) return r;
          return FollowItem(
            id: r.id,
            username: r.username,
            displayName: r.displayName,
            avatarUrl: r.avatarUrl,
            bio: r.bio,
            usernameColor: r.usernameColor,
            avatarFrame: r.avatarFrame,
            level: r.level,
            isOnline: r.isOnline,
            isFollowing: result.isFollowing,
            pendingFollow: result.isPending,
            followedAt: r.followedAt,
          );
        }

        _results = [for (final r in _results) updated(r)];
        _suggestions = [for (final r in _suggestions) updated(r)];
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el seguimiento')),
      );
    } finally {
      if (mounted) setState(() => _busyFollow.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianBg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            _buildSliverSearchBar(),
            _buildCategoryPills(),
            if (!_hasSearched && !_loading) ...[
              if (_recentSearches.isNotEmpty) _buildRecentSearches(),
              _buildSuggestionsHeader(),
              _buildSuggestionsList(),
              _buildDiscoverHeader(),
              _buildDiscoverGrid(),
              _buildTrendingBanner(),
            ] else if (_loading)
              SliverPadding(
                padding: const EdgeInsets.only(top: AppDimens.md),
                sliver: SliverToBoxAdapter(child: _buildLoadingSkeleton()),
              )
            else if (_error != null)
              SliverFillRemaining(child: _buildError())
            else if (_hasSearched &&
                _results.isEmpty &&
                _postResults.isEmpty &&
                _roomResults.isEmpty &&
                _circleResults.isEmpty)
              SliverFillRemaining(child: _buildNoResults())
            else ...[
              _buildResultsHeader(),
              _buildResultsList(),
            ],
            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────

  Widget _buildSliverSearchBar() {
    final scheme = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();

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
            if (canPop) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: (_) => _search(),
                style: TextStyle(color: scheme.onSurface, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Buscar usuarios, salas, círculos...',
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      AppAssets.search,
                      width: 20,
                      height: 20,
                      color: scheme.onSurfaceVariant,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.search_rounded,
                        color: scheme.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: scheme.onSurfaceVariant,
                            size: 20,
                          ),
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF14141B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    borderSide: const BorderSide(
                      color: Color(0xFF22222E),
                      width: 0.8,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    borderSide: const BorderSide(
                      color: Color(0xFF22222E),
                      width: 0.8,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    borderSide: const BorderSide(
                      color: AppColors.accentCrimson,
                      width: 1.2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.md,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category pills ────────────────────────────────────────────────────

  Widget _buildCategoryPills() {
    final categories = ['Todo', 'Usuarios', 'Salas', 'Círculos'];
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppDimens.xs),
          itemBuilder: (context, index) {
            final scheme = Theme.of(context).colorScheme;
            final isSelected = index == _selectedCategoryIndex;
            return GestureDetector(
              onTap: () {
                if (_selectedCategoryIndex == index) return;
                setState(() => _selectedCategoryIndex = index);
                // Re-buscar con el nuevo filtro si ya hay término activo.
                if (_hasSearched && _controller.text.trim().length >= 2) {
                  _debounce?.cancel();
                  _debounce = Timer(_debounceDuration, () => _search());
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.md,
                  vertical: AppDimens.xs,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentCrimson.withValues(alpha: 0.15)
                      : AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentCrimson.withValues(alpha: 0.4)
                        : AppColors.borderGlow,
                  ),
                ),
                child: Center(
                  child: Text(
                    categories[index],
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.accentCrimson
                          : scheme.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Suggestions ───────────────────────────────────────────────────────

  Widget _buildSuggestionsHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.md,
          AppDimens.lg,
          AppDimens.md,
          AppDimens.sm,
        ),
        child: Row(
          children: [
            Text(
              'Sugerencias para ti',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _loadSuggestions,
              child: Text(
                'Actualizar',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if (_loadingSuggestions) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_suggestions.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptySuggestions());
    }

    // Filter suggestions based on selected category
    final filteredSuggestions = _selectedCategoryIndex == 0
        ? _suggestions
        : _suggestions
              .where((s) => _matchesCategory(s, _selectedCategoryIndex))
              .toList();

    if (filteredSuggestions.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptySuggestions());
    }

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 170,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
          itemCount: filteredSuggestions.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppDimens.sm),
          itemBuilder: (context, index) =>
              _buildSuggestionCard(filteredSuggestions[index]),
        ),
      ),
    );
  }

  bool _matchesCategory(FollowItem user, int categoryIndex) {
    // Por ahora las sugerencias son solo personas.
    switch (categoryIndex) {
      case 1: // Usuarios — sugerencias de personas
        return true;
      case 2: // Salas — no hay sugerencias de personas
        return false;
      case 3: // Círculos — no hay sugerencias de personas
        return false;
      default:
        return true;
    }
  }

  Widget _buildEmptySuggestions() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.md),
      padding: AppDimens.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: AppColors.borderGlow),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_add_alt_1_rounded,
            color: AppColors.accentCrimson,
          ),
          SizedBox(width: AppDimens.md),
          Expanded(
            child: Text(
              'Todavía no hay sugerencias. ¡Vuelve más tarde!',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(FollowItem user) {
    final scheme = Theme.of(context).colorScheme;
    final nameColor = AppColors.fromHex(user.usernameColor);
    return Container(
      width: 132,
      padding: const EdgeInsets.all(AppDimens.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: AppColors.borderGlow),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppAvatar(
            imageUrl: user.avatarUrl,
            name: user.displayName,
            radius: 24,
            onTap: () => context.push('/profile/${user.username}'),
          ),
          const SizedBox(height: AppDimens.xs),
          Text(
            user.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: nameColor,
            ),
          ),
          Text(
            '@${user.username}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppDimens.xs),
          _buildFollowButton(user),
        ],
      ),
    );
  }

  // ── Discover ──────────────────────────────────────────────────────────

  Widget _buildDiscoverHeader() {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppDimens.md,
          AppDimens.xl,
          AppDimens.md,
          AppDimens.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Descubre',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: scheme.onSurface,
                ),
              ),
            ),
            // Alterna entre cuadrícula (3 columnas) y lista de filas.
            IconButton(
              icon: const Icon(Icons.swap_vert_rounded, size: 18),
              color: scheme.onSurfaceVariant,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: () => setState(() => _discoverRows = !_discoverRows),
            ),
            // Acceso rápido a la creación de un círculo.
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 20),
              color: AppColors.accentCyan,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: () => context.push('/circles/create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverGrid() {
    final discoverItems = _getDiscoverItemsForCategory(_selectedCategoryIndex);
    if (_discoverRows) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
        sliver: SliverList.separated(
          itemCount: discoverItems.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppDimens.sm),
          itemBuilder: (context, index) =>
              _buildDiscoverRow(discoverItems[index]),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
      sliver: SliverGrid.count(
        crossAxisCount: 3,
        mainAxisSpacing: AppDimens.sm,
        crossAxisSpacing: AppDimens.sm,
        childAspectRatio: 0.72,
        children: discoverItems
            .map(
              (item) => _buildDiscoverTile(
                asset: item['asset'],
                icon: item['icon'],
                label: item['label'],
                subtitle: item['subtitle'],
                onTap: item['onTap'],
              ),
            )
            .toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _getDiscoverItemsForCategory(int categoryIndex) {
    switch (categoryIndex) {
      case 0: // Todo
        return [
          {
            'asset': AppAssets.meetings,
            'label': 'Salas',
            'subtitle': 'Reuniones y chats en vivo',
            'onTap': () => context.push('/salas'),
          },
          {
            'asset': AppAssets.groups,
            'label': 'Círculos',
            'subtitle': 'Grupos de intereses',
            'onTap': () => context.push('/circles'),
          },
          {
            'icon': Icons.history_rounded,
            'label': 'Historias',
            'subtitle': 'Momentos efímeros',
          },
        ];
      case 1: // Usuarios
        return [
          {
            'icon': Icons.person_search_rounded,
            'label': 'Buscar amigos',
            'subtitle': 'Encuentra usuarios por nombre',
          },
          {
            'icon': Icons.people_alt_rounded,
            'label': 'Recomendados',
            'subtitle': 'Usuarios sugeridos para ti',
          },
          {
            'icon': Icons.group_add_rounded,
            'label': 'Contactos',
            'subtitle': 'Invita a tus contactos',
          },
        ];
      case 2: // Salas
        return [
          {
            'asset': AppAssets.meetings,
            'label': 'Salas en vivo',
            'subtitle': 'Únete a conversaciones ahora',
            'onTap': () => context.push('/salas'),
          },
          {
            'icon': Icons.schedule_rounded,
            'label': 'Programadas',
            'subtitle': 'Próximas salas agendadas',
          },
          {
            'icon': Icons.mic_rounded,
            'label': 'Crear sala',
            'subtitle': 'Inicia tu propia conversación',
            'onTap': () => context.push('/salas/create'),
          },
        ];
      case 3: // Círculos
        return [
          {
            'asset': AppAssets.groups,
            'label': 'Explorar círculos',
            'subtitle': 'Grupos de intereses',
            'onTap': () => context.push('/circles'),
          },
          {
            'icon': Icons.add_circle_rounded,
            'label': 'Nuevo círculo',
            'subtitle': 'Crea tu propia comunidad',
            'onTap': () => context.push('/circles/create'),
          },
          {
            'icon': Icons.star_rounded,
            'label': 'Destacados',
            'subtitle': 'Círculos recomendados',
          },
        ];
      default:
        return [];
    }
  }

  Widget _buildDiscoverTile({
    String? asset,
    IconData? icon,
    required String label,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap:
          onTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label llegará próximamente'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
      child: Container(
        padding: const EdgeInsets.all(AppDimens.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.borderGlow),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _discoverBadge(asset, icon),
            const SizedBox(height: AppDimens.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverRow(Map<String, dynamic> item) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap:
          item['onTap'] as VoidCallback? ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${item['label']} llegará próximamente'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
      child: Container(
        padding: const EdgeInsets.all(AppDimens.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.borderGlow),
        ),
        child: Row(
          children: [
            _discoverBadge(item['asset'], item['icon']),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['label'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['subtitle'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _discoverBadge(String? asset, IconData? icon) {
    if (asset != null) return _AssetBadge(asset: asset);
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.brandGradient,
      ),
      child: Icon(icon, size: 22, color: Colors.white),
    );
  }

  // ── Trending ──────────────────────────────────────────────────────────

  /// Búsquedas recientes locales (SharedPreferences).
  Widget _buildRecentSearches() {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.md,
          AppDimens.md,
          AppDimens.md,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Búsquedas recientes',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _clearRecentSearches,
                  child: Text(
                    'Limpiar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.xs),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final search in _recentSearches)
                  GestureDetector(
                    onTap: () {
                      _controller.text = search;
                      _search(search);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGlass,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusFull,
                        ),
                        border: Border.all(color: AppColors.borderGlow),
                      ),
                      child: Text(
                        search,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingBanner() {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppDimens.md,
          AppDimens.xl,
          AppDimens.md,
          0,
        ),
        padding: const EdgeInsets.all(AppDimens.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accentCrimson.withValues(alpha: 0.12),
              AppColors.surfaceGlass,
            ],
          ),
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(
            color: AppColors.accentCrimson.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  color: AppColors.accentCrimson,
                  size: 28,
                ),
                SizedBox(width: AppDimens.md),
                Text(
                  'Tendencias · 48h',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.xs),
            if (_trendingTags.isEmpty)
              Text(
                'Aún no hay temas calientes. ¡Publica con tags para encenderlos!',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final trend in _trendingTags.take(10))
                    GestureDetector(
                      onTap: () {
                        _controller.text = trend.tag;
                        _search(trend.tag);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentCrimson.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusFull,
                          ),
                          border: Border.all(
                            color: AppColors.accentCrimson.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Text(
                          '#${trend.tag}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentCrimson,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ── Results ───────────────────────────────────────────────────────────

  Widget _buildResultsHeader() {
    final scheme = Theme.of(context).colorScheme;
    final query = _controller.text.trim();
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.md,
          AppDimens.sm,
          AppDimens.md,
          AppDimens.xs,
        ),
        child: Text(
          _totalResults == 1
              ? '1 resultado para "$query"'
              : '$_totalResults resultados para "$query"',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  int get _totalResults =>
      _results.length +
      _postResults.length +
      _roomResults.length +
      _circleResults.length;

  Widget _buildResultsList() {
    // Filtra por pestaña activa: Todo | Usuarios | Salas | Círculos.
    final showPosts = _selectedCategoryIndex == 0;
    final showUsers =
        _selectedCategoryIndex == 0 || _selectedCategoryIndex == 1;
    final showRooms =
        _selectedCategoryIndex == 0 || _selectedCategoryIndex == 2;
    final showCircles =
        _selectedCategoryIndex == 0 || _selectedCategoryIndex == 3;

    final items = <Widget>[
      if (showUsers && _results.isNotEmpty) ...[
        _sectionHeader('Usuarios', _results.length, Icons.people_alt_rounded),
        for (final user in _results) _buildUserCard(user),
      ],
      if (showRooms && _roomResults.isNotEmpty) ...[
        _sectionHeader('Salas', _roomResults.length, Icons.meeting_room_rounded),
        for (final room in _roomResults) _buildRoomResultCard(room),
      ],
      if (showCircles && _circleResults.isNotEmpty) ...[
        _sectionHeader(
          'Círculos',
          _circleResults.length,
          Icons.groups_rounded,
        ),
        for (final circle in _circleResults) _buildCircleResultCard(circle),
      ],
      if (showPosts && _postResults.isNotEmpty) ...[
        _sectionHeader(
          'Publicaciones',
          _postResults.length,
          Icons.article_rounded,
        ),
        for (final post in _postResults) _buildPostResultCard(post),
      ],
    ];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.xs,
      ),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppDimens.xs),
        itemBuilder: (context, index) => items[index],
      ),
    );
  }

  /// Encabezado de sección para los resultados agrupados por tipo.
  Widget _sectionHeader(String title, int count, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppDimens.sm, 4, AppDimens.xs),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              letterSpacing: 0.4,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de resultado de publicación (render limpio → /post/:id).
  Widget _buildPostResultCard(SearchPost post) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.borderGlow),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                  imageUrl: post.authorAvatar,
                  name: post.authorName,
                  radius: 14,
                ),
                const SizedBox(width: AppDimens.xs),
                Expanded(
                  child: Text(
                    '${post.authorName} · @${post.authorUsername}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.xs),
            if (post.title != null && post.title!.isNotEmpty)
              Text(
                post.title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentCrimson,
                ),
              ),
            Text(
              post.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: scheme.onSurface),
            ),
            if (post.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppDimens.xs),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final tag in post.tags.take(3))
                      Text(
                        '#$tag',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta de resultado de sala (→ /salas/:id).
  Widget _buildRoomResultCard(SearchRoom room) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.push('/salas/${room.id}'),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.borderGlow),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.brandGradient,
              ),
              child: const Icon(
                Icons.groups_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${room.hostName != null ? 'Host: ${room.hostName} · ' : ''}'
                    '${room.participantCount} participantes',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta de resultado de círculo (→ /circles/:id).
  Widget _buildCircleResultCard(Circle circle) {
    final scheme = Theme.of(context).colorScheme;
    final hasAvatar = circle.avatarUrl != null && circle.avatarUrl!.isNotEmpty;
    return GestureDetector(
      onTap: () => context.push('/circles/${circle.id}'),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: AppColors.borderGlow),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF1D1A2E),
              backgroundImage: hasAvatar ? NetworkImage(circle.avatarUrl!) : null,
              child: hasAvatar
                  ? null
                  : const Icon(
                      Icons.groups_rounded,
                      size: 22,
                      color: AppColors.accentCyan,
                    ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    circle.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${circle.isPrivate ? 'Privado · ' : ''}'
                    '${circle.memberCount} miembros'
                    '${circle.isMember ? ' · Eres miembro' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(FollowItem user) {
    final scheme = Theme.of(context).colorScheme;
    final nameColor = AppColors.fromHex(user.usernameColor);
    return Container(
      padding: const EdgeInsets.all(AppDimens.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: AppColors.borderGlow),
      ),
      child: Row(
        children: [
          AppAvatar(
            imageUrl: user.avatarUrl,
            name: user.displayName,
            radius: 24,
            onTap: () => context.push('/profile/${user.username}'),
          ),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/profile/${user.username}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: nameColor,
                    ),
                  ),
                  Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildFollowButton(user),
        ],
      ),
    );
  }

  // ── Shared ────────────────────────────────────────────────────────────

  /// Esqueleto con shimmer Nebulæ para el estado de carga.
  Widget _buildLoadingSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.xs),
            child: Row(
              children: [
                KyubiShimmer(
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.circular(24),
                ),
                const SizedBox(width: AppDimens.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KyubiShimmer(
                        height: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 6),
                      KyubiShimmer(
                        height: 14,
                        width: 120,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFollowButton(FollowItem user) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _busyFollow.contains(user.id);
    if (busy) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    }
    return user.isFollowing
        ? GestureDetector(
            onTap: () => _toggleFollow(user),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                border: Border.all(color: AppColors.borderGlow),
              ),
              child: Text(
                'Siguiendo',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        : GestureDetector(
            onTap: () => _toggleFollow(user),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                gradient: AppColors.crimsonGlow,
                borderRadius: BorderRadius.all(
                  Radius.circular(AppDimens.radiusFull),
                ),
              ),
              child: const Text(
                'Seguir',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
  }

  Widget _buildError() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: AppDimens.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  KyubiBlob(
                    size: 96,
                    color: AppColors.primary.withValues(alpha: 0.12),
                    tail: true,
                  ),
                  const Icon(Icons.cloud_off_rounded, size: 40),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.md),
            Text(
              _error!,
              style: TextStyle(color: AppColors.danger),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.md),
            GestureDetector(
              onTap: _search,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  border: Border.all(color: AppColors.borderGlow),
                ),
                child: Text(
                  'Reintentar',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    final scheme = Theme.of(context).colorScheme;
    final query = _controller.text.trim();
    return Center(
      child: Padding(
        padding: AppDimens.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AssetFrame(asset: AppAssets.emptySearch, width: 180, height: 180),
            const SizedBox(height: AppDimens.md),
            Text(
              'No encontramos resultados para "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppDimens.sm),
            Text(
              'Prueba con otros términos o revisa la ortografía.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppDimens.md),
            GestureDetector(
              onTap: _clearSearch,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  border: Border.all(color: AppColors.borderGlow),
                ),
                child: const Text(
                  'Limpiar búsqueda',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetBadge extends StatelessWidget {
  const _AssetBadge({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(asset, fit: BoxFit.contain),
      ),
    );
  }
}
