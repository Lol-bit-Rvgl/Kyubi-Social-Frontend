import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/liquid_glass_button.dart';
import '../../../../core/widgets/liquid_glass_container.dart';
import '../../../../features/saved/presentation/widgets/saved_posts_list.dart';
import '../../../../models/user.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';
import 'profile_metrics.dart';
import 'user_posts_controller.dart';
import 'user_wall_comments_controller.dart';
import 'widgets/badges_modal_sheet.dart';
import 'widgets/media_grid_tab.dart';
import 'widgets/nebulae_buttons.dart';
import 'widgets/nebulae_profile_avatar.dart';
import 'widgets/posts_tab_section.dart';
import 'widgets/profile_sliver_app_bar.dart';
import 'widgets/profile_stat_item.dart';
import 'widgets/profile_tabs_header.dart';
import 'widgets/wall_tab_section.dart';

const _bg = AppColors.obsidianBg;
const _avatarRadius = 48.0;

/// Mi Perfil con cabecera colapsable (SliverAppBar + parallax), TabBar sticky
/// y 4 pestañas (Publicaciones, Muro, Multimedia, Guardados).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _refreshing = false;

  /// Último conteo conocido y positivo de visitas. Evita que la estadística
  /// caiga transitoriamente a 0 al volver de la lista o durante refrescos.
  int? _lastKnownVisitsCount;

  /// Estado editable solo si el usuario lo configuró manualmente. Cuando está
  /// vacío se refleja la presencia real (`user.isOnline` / `lastSeenAt`).
  String _currentStatus = '';
  bool _statusCustomized = false;

  @override
  void initState() {
    super.initState();
    _refreshMe();
  }

  Future<void> _refreshMe() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) return;
    setState(() => _refreshing = true);
    try {
      final me = await ref.read(userRepositoryProvider).getMe();
      if (!mounted) return;
      // Guardia anti-cero: nunca sobreescribir un conteo válido con 0 por un
      // refresco transitorio. Se conserva el valor previo en memoria.
      final previousViews = ref.read(authControllerProvider).user?.profileViews ?? 0;
      final fallbackViews = previousViews > 0
          ? previousViews
          : (_lastKnownVisitsCount ?? 0);
      var effectiveMe = me;
      if (me.profileViews == 0 && fallbackViews > 0) {
        effectiveMe = me.copyWith(
          extensions: {
            ...?me.extensions,
            'profileViews': fallbackViews,
            'visitorsCount': fallbackViews,
          },
        );
      }
      if (effectiveMe.profileViews > 0) {
        _lastKnownVisitsCount = effectiveMe.profileViews;
      }
      ref.read(authControllerProvider.notifier).updateUser(effectiveMe);
      await ref.read(userPostsProvider(me.id).notifier).refresh();
      await ref.read(userWallCommentsProvider(me.username).notifier).load();
      // Sincronización defensiva: si el contador de visitas del backend resuelve
      // a 0 pero tenemos visitas en caché (o las cargamos), cross-check con la
      // lista real para evitar la discrepancia reportada.
      final visits = await ref.read(userRepositoryProvider).getVisits(me.username);
      final backendViews = me.profileViews;
      if (backendViews == 0 && visits.isNotEmpty) {
        // El backend no reportó visitas correctamente; usar el conteo real de la lista.
        final realCount = visits.length;
        _lastKnownVisitsCount = realCount;
        ref.read(authControllerProvider.notifier).updateUser(
          effectiveMe.copyWith(
            extensions: {
              ...?effectiveMe.extensions,
              'profileViews': realCount,
              'visitorsCount': realCount,
            },
          ),
        );
        if (mounted) setState(() {});
      } else if (backendViews != 0 && visits.isNotEmpty) {
        // Cross-check: si el backend reporta menos visitas de las que tenemos en lista,
        // priorizar el conteo más reciente (la lista viene de /users/[username]/visits).
        final realCount = visits.length;
        final bestCount = realCount > backendViews ? realCount : backendViews;
        _lastKnownVisitsCount = bestCount;
        if (realCount > backendViews) {
          ref.read(authControllerProvider.notifier).updateUser(
            effectiveMe.copyWith(
              extensions: {
                ...?effectiveMe.extensions,
                'profileViews': realCount,
                'visitorsCount': realCount,
              },
            ),
          );
        }
        if (mounted) {
          setState(() {});
        }
      } else if (backendViews > 0) {
        _lastKnownVisitsCount = backendViews;
        if (mounted) setState(() {});
      }
    } catch (_) {
      // Mantiene sesión local si la red falla
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// Refresca el perfil tras regresar de la pantalla de visitantes para mantener
  /// el contador alineado con la lista de visitas (evita discrepancia 0 vs N).
  Future<void> _refreshAfterVisitors() async {
    await _refreshMe();
  }

  void _showStatusSelectorModal() {
    HapticFeedback.selectionClick();
    final statuses = [
      {'icon': '🟢', 'label': 'Activo/a'},
      {'icon': '💬', 'label': 'Charlando'},
      {'icon': '⚔️', 'label': 'En Rol'},
      {'icon': '✨', 'label': 'Creativo/a'},
      {'icon': '🎮', 'label': 'Jugando'},
      {'icon': '🔥', 'label': 'On Fire'},
      {'icon': '🎧', 'label': 'Escuchando'},
      {'icon': '💤', 'label': 'Ausente'},
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Seleccionar Estado / Mood',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: statuses.map((st) {
                  final text = '${st['icon']} ${st['label']}';
                  final isSelected = _currentStatus == text;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _currentStatus = text;
                        _statusCustomized = true;
                      });
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFA594F9).withValues(alpha: 0.15)
                            : const Color(0xFF1C172B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFA594F9)
                              : const Color(0xFF2C2542),
                          width: isSelected ? 1.2 : 0.8,
                        ),
                      ),
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFFA594F9)
                              : Colors.white,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBadgesModal(User user) {
    BadgesModalSheet.show(context, user);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    if (user == null) {
      if (auth.error != null) {
        return Scaffold(
          backgroundColor: _bg,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 56,
                    color: Color(0xFFFF5252),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No se pudo cargar el perfil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    auth.error ?? 'Error de conexión',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => ref
                        .read(authControllerProvider.notifier)
                        .loadCurrentUser(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reintentar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B2D60),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFA594F9)),
        ),
      );
    }

    final metrics = ref.watch(profileMetricsProvider(user));
    final wallpaperUrl = user.effectiveBannerUrl;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            context.push('/create-post');
          },
          backgroundColor: const Color(0xFF3B2D60),
          tooltip: 'Crear publicación',
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
        body: Container(
          // Fondo: wallpaper personalizado con tinte sutil (darken 0.35) o
          // fondo nativo Nebulæ limpio si no hay wallpaper. Ocupa TODO el
          // espacio (incluida el área tras la AppBar / status bar) gracias a
          // `extendBodyBehindAppBar` y las constraints expand.
          constraints: const BoxConstraints.expand(),
          decoration: BoxDecoration(
            color: _bg,
            image: (wallpaperUrl != null && wallpaperUrl.isNotEmpty)
                ? DecorationImage(
                    image: CachedNetworkImageProvider(wallpaperUrl),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.35),
                      BlendMode.darken,
                    ),
                  )
                : null,
          ),
          child: RefreshIndicator(
            onRefresh: _refreshMe,
            color: const Color(0xFF8A7EB8),
            backgroundColor: const Color(0xFF1E1B2E),
            child: NestedScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                ProfileSliverAppBar(
                  user: user,
                  actions: [
                    if (_refreshing)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(
                          Icons.settings_rounded,
                          color: Colors.white,
                        ),
                        tooltip: 'Ajustes',
                      ),
                    ),
                  ],
                ),
                SliverPersistentHeader(
                  pinned: false,
                  floating: false,
                  delegate: _ProfileHeroHeaderDelegate(
                    maxHeight: _calculateHeroHeight(user),
                    child: _buildProfileHero(user, metrics),
                  ),
                ),
                const ProfileTabsHeader(
                  tabs: ['Publicaciones', 'Muro', 'Multimedia', 'Guardados'],
                ),
              ],
              body: Container(
                decoration: const BoxDecoration(
                  // Fondo semisólido para que el wallpaper del perfil NUNCA
                  // se transluzca tras las publicaciones/muro ni las vuelva
                  // ilegibles al hacer scroll.
                  color: Color(0xF213101E),
                ),
                child: TabBarView(
                  children: [
                    PostsTabSection(userId: user.id, withCreateOption: true),
                    WallTabSection(
                      ownerId: user.username,
                      onSpecialTextTap: null,
                    ),
                    MediaGridTab(userId: user.id),
                    _buildSavedTab(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSavedTab() {
    return const SavedPostsList();
  }

  double _calculateHeroHeight(User user) {
    // 1. Avatar con estado: padding (12) + diámetro avatar (96) + status offset (~12) = 120
    double h = 120;
    // 2. Identidad: padding (12) + nombre (26) + handle (16) + fecha (15) + badge (26) + espacios (14) = 109
    h += 109;
    // 3. Títulos de círculos (si existen): padding (12) + chip wrap (~28) = 40
    if (user.titles.isNotEmpty) {
      h += 40;
    }
    // 4. Estadísticas (visitas, seguidores, nivel): padding (16) + contenedor glass (~76) = 92
    h += 92;
    // 5. Botones de acción: padding (16) + botón (44) + padding inferior (16) = 76
    h += 76;
    // 6. Sobre mí (bio y tags de intereses)
    final hasBio = user.bio != null && user.bio!.trim().isNotEmpty;
    final tags = user.interests;
    double sobreMi = 92;
    if (hasBio) {
      final bioLength = user.bio!.trim().length;
      sobreMi += bioLength > 80 ? 60 : 36;
    } else {
      sobreMi += 24;
    }
    if (tags.isNotEmpty) {
      sobreMi += tags.length > 3 ? 72 : 36;
    }
    h += sobreMi;
    return h;
  }

  Widget _buildProfileHero(User user, ProfileMetrics metrics) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _buildAvatarWithStatus(user),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.md,
            12,
            AppDimens.md,
            0,
          ),
          child: _buildIdentity(user),
        ),
        if (user.titles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.md,
              12,
              AppDimens.md,
              0,
            ),
            child: _buildCircleTitles(user),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.md,
            16,
            AppDimens.md,
            0,
          ),
          child: _buildStats(user, metrics),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.md,
            16,
            AppDimens.md,
            16,
          ),
          child: _buildActionButtons(user),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.md,
            0,
            AppDimens.md,
            16,
          ),
          child: _buildSobreMi(user),
        ),
      ],
    );
  }

  Widget _buildAvatarWithStatus(User user) {
    final avatarUrl = user.effectiveAvatarUrl;
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          NebulaeProfileAvatar(
            name: user.displayName,
            imageUrl: avatarUrl,
            radius: _avatarRadius,
            isOnline: user.isOnline,
            onTap: avatarUrl == null || avatarUrl.isEmpty
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          backgroundColor: Colors.black,
                          appBar: AppBar(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          body: PhotoView(
                            imageProvider: NetworkImage(avatarUrl),
                            minScale: PhotoViewComputedScale.contained,
                            maxScale: PhotoViewComputedScale.covered * 2,
                            backgroundDecoration: const BoxDecoration(
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
          ),
          Positioned(
            top: -2,
            right: -14,
            child: GestureDetector(
              onTap: _showStatusSelectorModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x331E1540),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFA594F9).withValues(alpha: 0.55),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA594F9).withValues(alpha: 0.18),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: user.isOnline
                            ? AppColors.accentCyan
                            : const Color(0xFF6E6E78),
                        border: Border.all(
                          color: AppColors.surfaceCards,
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _statusCustomized
                          ? _currentStatus
                          : user.isOnline
                          ? 'Activo/a'
                          : user.lastSeenAt != null
                          ? 'Visto ${DateUtilsX.relative(user.lastSeenAt!)}'
                          : 'Desconectado/a',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.edit_rounded,
                      size: 10,
                      color: Color(0xFFA594F9),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTagColor(int index) {
    // Paleta calmada: lavanda, azul acero, ciruela, cobre, verde suave.
    const colors = [
      Color(0xFFA594F9), // lavanda suave
      Color(0xFF64B5F6), // azul acero
      Color(0xFF9B59B6), // ciruela
      Color(0xFF5BC8AF), // verde suave
      Color(0xFFBBA39A), // cobre suave
      Color(0xFF8E8EA5), // grafito
    ];
    return colors[index % colors.length];
  }

  Widget? _buildGenderBadge(User user) {
    if (!user.showGender ||
        user.gender == null ||
        user.gender!.trim().isEmpty) {
      return null;
    }
    final g = user.gender!.trim().toLowerCase();
    final isFemale =
        g.contains('fem') || g.contains('mujer') || g.contains('chica');
    final isMale =
        g.contains('masc') ||
        g.contains('hombre') ||
        g.contains('chico') ||
        g.contains('varon');
    final icon = isFemale ? '♀' : (isMale ? '♂' : '⚧');
    final color = isFemale
        ? const Color(0xFFB388EB) // lavanda
        : (isMale ? const Color(0xFF64B5F6) : const Color(0xFF9B59B6));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Text(
        icon,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildIdentity(User user) {
    final scheme = Theme.of(context).colorScheme;
    final nameColor =
        user.usernameColor != null && user.usernameColor!.isNotEmpty
        ? AppColors.fromHex(user.usernameColor)
        : const Color(0xFFFFB300);

    final rankTitle = rankTitleForLevel(user.level);
    final genderBadge = _buildGenderBadge(user);
    final createdAtStr = DateUtilsX.formatMemberDate(user.createdAt);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                user.displayName,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: nameColor,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (genderBadge != null) ...[const SizedBox(width: 6), genderBadge],
            if (user.isVerified) ...[
              const SizedBox(width: 5),
              Image.asset(
                AppAssets.iconVerificados,
                width: 16,
                height: 16,
                fit: BoxFit.contain,
              ),
            ],
            if (user.isVip) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      size: 11,
                      color: Colors.black,
                    ),
                    SizedBox(width: 2),
                    Text(
                      'VIP',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          user.handle,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
            shadows: const [
              Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
              Shadow(color: Colors.black45, blurRadius: 10),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          createdAtStr,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF9EA0B8),
            shadows: const [
              Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showBadgesModal(user),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3A2A5E), Color(0xFF23203A)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFA594F9).withValues(alpha: 0.5),
                width: 0.9,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 13,
                  color: Color(0xFFA594F9),
                ),
                const SizedBox(width: 4),
                Text(
                  'Lv ${user.level} $rankTitle',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleTitles(User user) {
    final titles = user.titles;
    if (titles.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: titles.map((t) {
          final color = AppColors.fromHex(t.colorHex);
          final label = t.name;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStats(User user, ProfileMetrics metrics) {
    if (user.profileViews > 0) {
      _lastKnownVisitsCount = user.profileViews;
    }
    // Erradicar el 0 transitorio: nunca mostrar 0 si previamente había un conteo positivo.
    final displayVisits = (user.profileViews > 0)
        ? user.profileViews
        : (_lastKnownVisitsCount ?? 0);
    final followers = user.followersCount;
    final levelName = metrics.levelName.isNotEmpty
        ? metrics.levelName
        : 'Lv. ${user.level} Novato';

    return LiquidGlassContainer(
      borderRadius: AppDimens.radiusCard,
      style: user.themeSettings.glassStyle,
      customBorderGradient: user.themeSettings.borderGradient,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final result =
                    await context.push<dynamic>('/profile/${user.username}/visitors');
                if (!context.mounted) return;
                // Retorno seguro: la lista devuelve su conteo real; alinear en
                // silencio sin parpadeos a cero antes del refresco de red.
                if (result is int && result > 0) {
                  _lastKnownVisitsCount = result;
                  setState(() {});
                  final current = ref.read(authControllerProvider).user;
                  if (current != null && current.profileViews != result) {
                    ref.read(authControllerProvider.notifier).updateUser(
                          current.copyWith(
                            extensions: {
                              ...?current.extensions,
                              'profileViews': result,
                              'visitorsCount': result,
                            },
                          ),
                        );
                  }
                }
                if (context.mounted) _refreshAfterVisitors();
              },
              child: ProfileStatItem(
                value: '$displayVisits',
                label: 'Visitas',
                icon: Icons.visibility_outlined,
                color: const Color(0xFF64B5F6), // azul acero
              ),
            ),
          ),
          const ProfileStatDivider(),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/profile/${user.username}/followers'),
              child: ProfileStatItem(
                value: '$followers',
                label: 'Seguidores',
                icon: Icons.people_outline_rounded,
                color: Colors.white,
              ),
            ),
          ),
          const ProfileStatDivider(),
          Expanded(
            child: GestureDetector(
              onTap: () => _showBadgesModal(user),
              child: ProfileStatItem(
                value: 'Lv ${user.level}',
                label: levelName,
                icon: Icons.bolt_rounded,
                color: const Color(0xFFFFD600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(User user) {
    return Row(
      children: [
        Expanded(
          child: LiquidGlassButton(
            label: 'Editar perfil',
            icon: Icons.edit_rounded,
            borderColor: user.themeSettings.primary,
            onTap: () => context.push('/edit-profile'),
          ),
        ),
        const SizedBox(width: 10),
        NebulaeToolIconButton(
          icon: Icons.settings_outlined,
          onTap: () => context.push('/settings'),
          tooltip: 'Configuración',
        ),
      ],
    );
  }

  Widget _buildSobreMi(User user) {
    final interests = user.interests;
    final displayedTags = interests.take(6).toList();
    final hasBio = user.bio != null && user.bio!.trim().isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/profile-bio', extra: user),
      child: LiquidGlassContainer(
        width: double.infinity,
        borderRadius: AppDimens.radiusCard,
        style: user.themeSettings.glassStyle,
        customBorderGradient: user.themeSettings.borderGradient,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      size: 17,
                      color: user.themeSettings.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Sobre mí',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Ver todo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFA594F9).withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFFA594F9),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFA594F9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Bio',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hasBio ? user.bio!.trim() : 'Aún no hay Biografía',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontStyle: hasBio ? FontStyle.normal : FontStyle.italic,
                color: hasBio
                    ? const Color(0xFFC0C0D2)
                    : const Color(0xFF7A7A8E),
              ),
            ),
            if (displayedTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(displayedTags.length, (idx) {
                  final tag = displayedTags[idx];
                  final label = tag.startsWith('#') ? tag : '#$tag';
                  final color = _getTagColor(idx);

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: color.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Delegate para el colapso fluido del hero del perfil con desvanecimiento de opacidad suave
/// y protección contra desbordes (`OverflowBox` + `ClipRect` + `SingleChildScrollView`).
class _ProfileHeroHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileHeroHeaderDelegate({
    required this.maxHeight,
    required this.child,
  });

  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => 0.0;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    if (shrinkOffset >= maxExtent) {
      return const SizedBox.shrink();
    }
    final rawOpacity = 1.0 - (shrinkOffset / maxExtent);
    final opacity = rawOpacity.clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: ClipRect(
        child: OverflowBox(
          minHeight: 0,
          maxHeight: maxExtent,
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              height: maxExtent,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileHeroHeaderDelegate oldDelegate) {
    return oldDelegate.maxHeight != maxHeight || oldDelegate.child != child;
  }
}
