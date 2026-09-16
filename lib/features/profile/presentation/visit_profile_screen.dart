import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/liquid_glass_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../models/user.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';
import '../../messages/presentation/conversations_controller.dart';
import 'profile_metrics.dart';
import 'user_follow_controller.dart';
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
const _cardBg = AppColors.surfaceCards;
const _avatarRadius = 48.0;
const _border = AppColors.borderGlass;

/// Perfil de otro usuario con cabecera colapsable (SliverAppBar + parallax),
/// TabBar sticky y 3 pestañas (Publicaciones, Muro, Multimedia).
class VisitProfileScreen extends ConsumerStatefulWidget {
  const VisitProfileScreen({super.key, required this.username});

  final String username;

  @override
  ConsumerState<VisitProfileScreen> createState() => _VisitProfileScreenState();
}

class _VisitProfileScreenState extends ConsumerState<VisitProfileScreen> {
  User? _user;
  bool _loading = true;
  bool _busy = false;
  bool _visitRegistered = false;
  String? _error;
  int? _lastKnownVisitsCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (widget.username.trim().isEmpty) {
      setState(() {
        _error = 'No se encontró el perfil solicitado';
        _loading = false;
      });
      return;
    }
    try {
      final repo = ref.read(userRepositoryProvider);
      final user = await repo.getProfile(widget.username);
      if (!_visitRegistered) {
        _visitRegistered = true;
        await repo.registerVisit(widget.username);
      }
      if (!mounted) return;
      if (user.profileViews > 0) {
        _lastKnownVisitsCount = user.profileViews;
      }
      ref.read(userFollowNotifierProvider(user.id).notifier).initialize(
            isFollowing: user.isFollowing,
            followersCount: user.followersCount,
          );
      setState(() {
        _user = user;
        _loading = false;
      });
      await ref.read(userPostsProvider(user.id).notifier).refresh();
      await ref.read(userWallCommentsProvider(user.username).notifier).load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final user = _user;
    if (user == null) return;
    HapticFeedback.lightImpact();
    try {
      await ref
          .read(userFollowNotifierProvider(user.id).notifier)
          .toggleFollow();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el seguimiento')),
        );
      }
    }
  }

  Future<void> _openChat() async {
    final user = _user;
    if (user == null || _busy) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    try {
      final chat = ref.read(chatRepositoryProvider);
      final conversation = await chat.openOrCreateDirect(
        user.id,
        username: user.username,
      );
      if (!mounted) return;
      ref
          .read(conversationsControllerProvider.notifier)
          .upsertConversation(conversation);
      context.push('/conversation/${conversation.id}');
      setState(() => _busy = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo iniciar la conversación')),
      );
    }
  }

  void _shareProfile(User user) {
    HapticFeedback.selectionClick();
    final profileUrl = 'https://kyubi.app/profile/${user.username}';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCards,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.ios_share_rounded,
                color: Colors.white70,
              ),
              title: const Text(
                'Compartir perfil',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                Share.share(
                  '¡Descubre el perfil de ${user.displayName} (@${user.username}) en Kyubi! $profileUrl',
                  subject: 'Perfil de ${user.displayName} en Kyubi',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: Colors.white70),
              title: const Text(
                'Copiar enlace del perfil',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                Clipboard.setData(ClipboardData(text: profileUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enlace del perfil copiado'),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showBadgesModal(User user) {
    BadgesModalSheet.show(context, user);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _user == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentCrimson),
        ),
      );
    }

    if (_error != null || _user == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: ErrorView(
            message: _error ?? 'No se pudo cargar el perfil',
            onRetry: _load,
          ),
        ),
      );
    }

    final user = _user!;
    final metrics = ref.watch(profileMetricsProvider(user));
    final coins = user.level * 150 + 420;
    final wallpaperUrl = user.effectiveBannerUrl;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
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
            onRefresh: _load,
            displacement: 40.0,
            edgeOffset: 10.0,
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceCards,
            child: NestedScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                ProfileSliverAppBar(
                  user: user,
                  leading: IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                    ),
                  ),
                  actions: [
                    if (coins > 0) _buildCoinsChip(coins),
                    IconButton(
                      onPressed: () => _shareProfile(user),
                      icon: const Icon(
                        Icons.share_rounded,
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
                  tabs: ['Publicaciones', 'Muro', 'Multimedia'],
                ),
              ],
              body: Container(
                decoration: const BoxDecoration(
                  // Fondo semisólido: el wallpaper del perfil (fondo de la
                  // pantalla) NO debe translucirse tras las publicaciones ni
                  // volver ilegible su contenido al hacer scroll.
                  color: Color(0xF213101E),
                ),
                child: TabBarView(
                  children: [
                    PostsTabSection(userId: user.id),
                    WallTabSection(ownerId: user.username),
                    MediaGridTab(userId: user.id),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoinsChip(int coins) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC14141E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D2544), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.monetization_on_rounded,
            color: Color(0xFFFFD600),
            size: 15,
          ),
          const SizedBox(width: 4),
          Text(
            '$coins',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFFD600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWithStatus(User user) {
    final avatarUrl = user.effectiveAvatarUrl;
    final online = user.isOnline;
    final statusColor = online
        ? AppColors.accentCyan
        : const Color(0xFF8A8A98);
    final statusLabel = online
        ? 'Activo/a'
        : user.lastSeenAt != null
        ? 'Visto ${DateUtilsX.relative(user.lastSeenAt!)}'
        : 'Desconectado/a';
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x331E1540),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.7),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.3),
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
                      color: online
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
                    statusLabel,
                    style: const TextStyle(
                      fontSize: 10.5,
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
    );
  }

  Color _getTagColor(int index) {
    const colors = [
      Color(0xFFFFB300), // Amber / Gold
      Color(0xFF00E5FF), // Cyan / Neon
      Color(0xFF7C4DFF), // Deep Purple
      AppColors.accentTeal, // Bright Green
      Color(0xFFFF4081), // Pink / Magenta
      Color(0xFF448AFF), // Blue
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
        ? const Color(0xFFFF4081)
        : (isMale ? const Color(0xFF448AFF) : const Color(0xFFAB47BC));

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
                colors: [Color(0xFF8E0E00), Color(0xFF1F1C18)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accentCrimson.withValues(alpha: 0.6),
                width: 0.9,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 13,
                  color: Color(0xFFFFD600),
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
    final followState = ref.watch(userFollowNotifierProvider(user.id));
    if (user.profileViews > 0) {
      _lastKnownVisitsCount = user.profileViews;
    }
    final displayVisits = (user.profileViews > 0)
        ? user.profileViews
        : (_lastKnownVisitsCount ?? 0);
    final followers = followState.followersCount ?? user.followersCount;
    final levelName = metrics.levelName.isNotEmpty
        ? metrics.levelName
        : 'Lv. ${user.level} Novato';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: _border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final result =
                    await context.push<dynamic>('/profile/${user.username}/visitors');
                if (!context.mounted) return;
                if (result is int && result > 0) {
                  _lastKnownVisitsCount = result;
                  if (mounted) setState(() {});
                }
              },
              child: ProfileStatItem(
                value: '$displayVisits',
                label: 'Visitas',
                icon: Icons.visibility_outlined,
                color: AppColors.accentCyan,
              ),
            ),
          ),
          const ProfileStatDivider(),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/profile/${user.username}/connections?tab=followers'),
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
              onTap: () => context.push('/profile/${user.username}/connections?tab=following'),
              child: ProfileStatItem(
                value: '${user.followingCount}',
                label: 'Siguiendo',
                icon: Icons.person_add_alt_1_rounded,
                color: const Color(0xFFA594F9),
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
    final authUser = ref.watch(authControllerProvider).user;
    final isOwnProfile = authUser != null &&
        (authUser.id == user.id ||
         authUser.username.toLowerCase() == user.username.toLowerCase());

    if (isOwnProfile) {
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
            icon: Icons.share_outlined,
            onTap: () => _shareProfile(user),
            tooltip: 'Compartir',
          ),
        ],
      );
    }

    final followState = ref.watch(userFollowNotifierProvider(user.id));
    final isFollowing = followState.isFollowing;
    final isPending = followState.isPending;
    final isBusy = followState.isBusy;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: NebulaeActionButton(
            label: isPending
                ? 'Solicitado'
                : isFollowing
                ? 'Siguiendo'
                : 'Seguir',
            icon: isPending
                ? Icons.hourglass_top_rounded
                : isFollowing
                ? Icons.check_rounded
                : Icons.person_add_rounded,
            onTap: (isPending || isBusy) ? null : _toggleFollow,
            enabled: !isBusy && !isPending,
            variant: (isPending || isFollowing)
                ? NebulaeActionVariant.glass
                : NebulaeActionVariant.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: NebulaeActionButton(
            label: 'Chat',
            icon: Icons.chat_bubble_outline_rounded,
            onTap: _busy ? null : _openChat,
            enabled: !_busy,
            variant: NebulaeActionVariant.glass,
          ),
        ),
        const SizedBox(width: 10),
        NebulaeToolIconButton(
          icon: Icons.share_outlined,
          onTap: () => _shareProfile(user),
          tooltip: 'Compartir',
        ),
      ],
    );
  }

  Widget _buildSobreMi(User user) {
    final interests = user.interests;
    final displayedTags = interests.take(6).toList();
    final hasBio = user.bio != null && user.bio!.trim().isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/profile/${user.username}/bio', extra: user),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: _border, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      size: 17,
                      color: AppColors.accentCyan,
                    ),
                    SizedBox(width: 8),
                    Text(
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
                        color: AppColors.accentCyan.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.accentCyan,
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
                    color: AppColors.accentCyan,
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
