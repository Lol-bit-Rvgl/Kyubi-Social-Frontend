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
      ref.read(authControllerProvider.notifier).updateUser(me);
      await ref.read(userPostsProvider(me.id).notifier).refresh();
      await ref.read(userWallCommentsProvider(me.username).notifier).load();
    } catch (_) {
      // Mantiene sesión local si la red falla
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
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
    HapticFeedback.selectionClick();
    final badges = [
      {
        'id': 'pioneer',
        'icon': '🌟',
        'title': 'Pionero Kyubi',
        'desc': 'Miembro de la primera generación',
      },
      {
        'id': 'streak',
        'icon': '🔥',
        'title': 'Racha Legendaria',
        'desc': 'Más de 7 días consecutivos',
      },
      {
        'id': 'roleplay',
        'icon': '🎭',
        'title': 'Maestro de Rol',
        'desc': 'Participante activo en salas',
      },
      if (user.isVip) ...[
        {
          'id': 'vip',
          'icon': '👑',
          'title': 'Rango VIP',
          'desc': 'Membresía premium activa',
        },
      ],
    ];
    final ownedBadges = user.badges;

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
                'Insignias',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              ...badges.map(
                (b) {
                  final owned = ownedBadges.contains(b['id']);
                  final titleColor = owned
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B172B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: owned
                            ? const Color(0xFF2C2542)
                            : Colors.white12,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Opacity(
                          opacity: owned ? 1 : 0.3,
                          child: Text(
                            b['icon']!,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b['title']!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                              Text(
                                b['desc']!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (!owned) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  'Bloqueada',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: Color(0xFF9E9EA8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (owned)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.accentCyan,
                            size: 18,
                          )
                        else
                          const Icon(
                            Icons.lock_outline_rounded,
                            color: Color(0xFF6E6E78),
                            size: 18,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
                  leading: IconButton(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  ),
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
                    IconButton(
                      onPressed: () => context.push('/settings'),
                      icon: const Icon(
                        Icons.settings_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildAvatarWithStatus(user),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.md,
                      12,
                      AppDimens.md,
                      0,
                    ),
                    child: _buildIdentity(user),
                  ),
                ),
                if (user.titles.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.md,
                        12,
                        AppDimens.md,
                        0,
                      ),
                      child: _buildCircleTitles(user),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.md,
                      16,
                      AppDimens.md,
                      0,
                    ),
                    child: _buildStats(user, metrics),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.md,
                      16,
                      AppDimens.md,
                      16,
                    ),
                    child: _buildActionButtons(user),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.md,
                      0,
                      AppDimens.md,
                      16,
                    ),
                    child: _buildSobreMi(user),
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
    final visits = user.profileViews;
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
              onTap: () => context.push('/profile/${user.username}/visitors'),
              child: ProfileStatItem(
                value: '$visits',
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
