import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/liquid_glass_container.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../models/circle.dart';
import '../../feed/presentation/widgets/post_card.dart';
import 'circle_detail_controller.dart';

/// Detalle del Círculo / Hub de Comunidad (Ref: IMG-20260630-WA0054).
class CircleDetailScreen extends ConsumerStatefulWidget {
  const CircleDetailScreen({super.key, required this.circleId});

  final String circleId;

  @override
  ConsumerState<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends ConsumerState<CircleDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(circleDetailControllerProvider(widget.circleId));
    final notifier = ref.read(
      circleDetailControllerProvider(widget.circleId).notifier,
    );
    final circle = state.circle;

    if (state.loading && circle == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0C15),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFA594F9)),
        ),
      );
    }
    if (state.error != null && circle == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0C15),
        body: ErrorView(
          message: state.error!,
          onRetry: notifier.refresh,
          title: 'No se pudo cargar el círculo',
        ),
      );
    }
    if (circle == null) return const SizedBox.shrink();

    final isMember = circle.isMember;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0C15),
      floatingActionButton: isMember
          ? FloatingActionButton.extended(
              onPressed: () => _createPost(context),
              backgroundColor: const Color(0xFF3B2D60),
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              label: const Text(
                'Publicar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              tooltip: 'Crear publicación en el círculo',
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: _buildHeader(context, circle, state, notifier),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _CircleTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFA594F9),
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF7A7A8A),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Inicio'),
                    Tab(text: 'Info'),
                    Tab(text: 'Salas'),
                    Tab(text: 'Normas'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTabInicio(context, circle, state, notifier),
            _buildTabInfo(context, circle),
            _buildTabSalas(context, circle),
            _buildTabNormas(context, circle),
          ],
        ),
      ),
    );
  }

  // ── 1. HEADER DEL CÍRCULO (Ref: IMG-20260630-WA0054) ──────────────────────

  Widget _buildHeader(
    BuildContext context,
    Circle circle,
    CircleDetailState state,
    CircleDetailNotifier notifier,
  ) {
    final circleIdCode = (circle.id.hashCode.abs() % 900000) + 100000;
    final isMember = circle.isMember;
    final isCreator = circle.isCreator;
    final liveOnline = (circle.memberCount * 0.15).ceil().clamp(1, 999);

    final roleLabel = isCreator
        ? '👑 Creador'
        : circle.role == CircleRole.admin
        ? '🛡️ Co-Admin'
        : isMember
        ? '👤 Miembro'
        : 'Explorador';

    final roleBadgeColor = isCreator
        ? const Color(0xFFFFB300)
        : circle.role == CircleRole.admin
        ? AppColors.accentTeal
        : isMember
        ? AppColors.accentCyan
        : const Color(0xFF6E6888);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF14121E),
        border: Border(
          bottom: BorderSide(color: Color(0xFF221E32), width: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Superior con Botón de Regreso y Acciones
          Stack(
            children: [
              // Banner Imagen / Gradiente
              Container(
                height: 130,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2A1535),
                      Color(0xFF13101E),
                      Color(0xFF0F1E2E),
                    ],
                  ),
                ),
                child: circle.bannerUrl != null && circle.bannerUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: circle.bannerUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      )
                    : null,
              ),

              // Capa oscura translúcida en banner
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                        const Color(0xFF14121E),
                      ],
                    ),
                  ),
                ),
              ),

              // Barra de Acciones Superior (Regreso, Compartir, Ajustes)
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enlace del Círculo copiado 🔗'),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.share_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _showCircleOptionsMenu(context, circle);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Avatar del Círculo superpuesto
              Positioned(
                bottom: 0,
                left: 16,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF14121E),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9B6FCB).withValues(alpha: 0.35),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: AppAvatar(
                      name: circle.name,
                      imageUrl: circle.avatarUrl,
                      radius: 36,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Información Principal del Círculo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre con Insignia Verificada
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        circle.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Image.asset(
                      AppAssets.iconVerificados,
                      width: 16,
                      height: 16,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Badges: ID, Idioma, Rol, Privacidad
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Badge ID
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1B2D),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF332B4C),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'ID: #$circleIdCode',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9E9EA8),
                        ),
                      ),
                    ),

                    // Badge Idioma
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1B2D),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF332B4C),
                          width: 0.8,
                        ),
                      ),
                      child: const Text(
                        'Español 🇪🇸',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9E9EA8),
                        ),
                      ),
                    ),

                    // Badge Rol de Usuario
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: roleBadgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: roleBadgeColor.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: roleBadgeColor,
                        ),
                      ),
                    ),

                    // Badge Privacidad
                    if (circle.isPrivate)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFF5252,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              size: 11,
                              color: Color(0xFFFF5252),
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Privado',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF5252),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Barra Superior de Anuncio Oficial: 📢 Announcement
                _buildAnnouncementCard(context, circle, isCreator),

                const SizedBox(height: 10),

                // Contador de Miembros en Vivo
                Row(
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${circle.memberCount} miembros',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.accentTeal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$liveOnline en línea',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentTeal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Botones de Acción: [ Unirse / Salir ] + [ 💬 Sala del Círculo ]
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: isMember
                            ? (isCreator
                                  ? null
                                  : () => _leave(context, notifier))
                            : () => _join(context, notifier),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: isMember ? null : AppColors.nightGradient,
                            color: isMember ? const Color(0xFF1E192D) : null,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isMember
                                  ? const Color(0xFF332B4F)
                                  : const Color(0xFF5B4A8C),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isMember
                                    ? (isCreator
                                          ? Icons.verified_user_rounded
                                          : Icons.check_circle_outline_rounded)
                                    : Icons.add_circle_outline_rounded,
                                size: 16,
                                color: isMember
                                    ? const Color(0xFF9E9EA8)
                                    : Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isMember
                                    ? (isCreator
                                          ? 'Eres el Creador'
                                          : 'Siguiendo')
                                    : 'Unirse al Círculo',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isMember
                                      ? const Color(0xFF9E9EA8)
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push('/salas/circle-${circle.id}');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F2B36),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accentCyan.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.theater_comedy_rounded,
                              color: AppColors.accentCyan,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Salas',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accentCyan,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildAnnouncementCard(
    BuildContext context,
    Circle circle,
    bool isCreator,
  ) {
    return LiquidGlassContainer(
      width: double.infinity,
      borderRadius: 10,
      blur: 10,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.campaign_rounded,
            color: Color(0xFF9B6FCB),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '¡Bienvenidos a ${circle.name}! Revisa las normativas del círculo y participa en las salas en vivo.',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFFCAC8DB),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCreator) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Editor de anuncios oficial abierto 📢'),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF9B6FCB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '+ Editar',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9B6FCB),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 2. SECCIONES CON BARRA ROJA VERTICAL (Ref: IMG-20260630-WA0054) ───────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF9B6FCB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. PESTAÑA: INICIO (POSTS & ACTIVIDAD) ────────────────────────────────

  Widget _buildTabInicio(
    BuildContext context,
    Circle circle,
    CircleDetailState state,
    CircleDetailNotifier notifier,
  ) {
    final isMember = circle.isMember;

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          _buildSectionTitle('Publicaciones y Momentos'),
          if (state.postsLoading && state.posts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFA594F9)),
              ),
            )
          else if (state.postsError != null && state.posts.isEmpty)
            ErrorView(
              message: state.postsError!,
              onRetry: notifier.refresh,
              title: 'No se pudieron cargar los posts',
            )
          else if (state.posts.isEmpty)
            _buildEmptyPosts(context, isMember)
          else ...[
            for (final post in state.posts) PostCard(post: post),
            if (state.loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.md),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFA594F9)),
                ),
              )
            else if (state.hasMore)
              Center(
                child: TextButton(
                  onPressed: notifier.loadMorePosts,
                  child: const Text(
                    'Cargar más publicaciones',
                    style: TextStyle(
                      color: AppColors.accentCyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── 4. PESTAÑA: INFO (ORGANIZACIÓN, VOLUNTARIOS, AYUDANTES) ───────────────

  Widget _buildTabInfo(BuildContext context, Circle circle) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _buildSectionTitle('Sobre el Círculo'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF14121E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF221E32), width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                circle.description?.isNotEmpty == true
                    ? circle.description!
                    : 'Círculo oficial de Kyubi dedicado a la interacción social, roleplay, creación de contenido y comunidad.',
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: Color(0xFFDCDAF0),
                ),
              ),
              if (circle.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: circle.tags.map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1A2F),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF332B4F),
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        '#$t',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentCyan,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),

        // Sección Voluntarios
        _buildSectionTitle('Voluntarios & Moderadores'),
        _buildVoluntariosSection(circle),

        // Sección Ayudantes
        _buildSectionTitle('Ayudantes & Soporte'),
        _buildAyudantesSection(),

        // Sección Enlaces Oficiales
        _buildSectionTitle('Enlaces y Redes'),
        _buildEnlacesSection(),
      ],
    );
  }

  Widget _buildVoluntariosSection(Circle circle) {
    final moderators = circle.members
        .where((m) => m.role == CircleRole.owner || m.role == CircleRole.admin)
        .toList();

    if (moderators.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF14121E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF221E32), width: 0.8),
        ),
        child: Row(
          children: [
            AppAvatar(
              name: circle.creator.displayName,
              imageUrl: circle.creator.avatarUrl,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    circle.creator.displayName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '@${circle.creator.username} · Creador Principal',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Líder',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFFB300),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF14121E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF221E32), width: 0.8),
      ),
      child: Column(
        children: moderators.map((m) {
          final isOwner = m.role == CircleRole.owner;
          return ListTile(
            dense: true,
            leading: AppAvatar(
              name: m.user.displayName,
              imageUrl: m.user.avatarUrl,
              radius: 18,
              showOnline: true,
              isOnline: m.user.isOnline,
            ),
            title: Text(
              m.user.displayName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              '@${m.user.username}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isOwner
                    ? const Color(0xFFFFB300).withValues(alpha: 0.15)
                    : AppColors.accentTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isOwner ? '👑 Líder' : '🛡️ Admin',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isOwner
                      ? const Color(0xFFFFB300)
                      : AppColors.accentTeal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAyudantesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14121E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF221E32), width: 0.8),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.support_agent_rounded,
            color: AppColors.accentCyan,
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Equipo de Guías & Eventos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Ayuda a nuevos miembros y organización de roles en vivo',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnlacesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14121E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF221E32), width: 0.8),
      ),
      child: Column(
        children: [
          _linkRow(
            icon: Icons.discord,
            label: 'Discord Oficial',
            value: 'discord.gg/kyubi-community',
          ),
          const Divider(color: Color(0xFF221E32), height: 16),
          _linkRow(
            icon: Icons.alternate_email_rounded,
            label: 'Twitter / X',
            value: '@KyubiSpace',
          ),
        ],
      ),
    );
  }

  Widget _linkRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF9E9EA8), size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.accentCyan,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── 5. PESTAÑA: SALAS (EN VIVO & VINCULADAS) ──────────────────────────────

  Widget _buildTabSalas(BuildContext context, Circle circle) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _buildSectionTitle('Salas en Vivo del Círculo'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF14121E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF221E32), width: 0.8),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1A30),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.theater_comedy_rounded,
                      color: AppColors.accentCyan,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5252),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${circle.name} Lounge',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          '🎙️ 6 en el stage · 🎭 Roleplay & Voice',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push('/salas/circle-${circle.id}');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.accentCyan,
                          width: 0.8,
                        ),
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
        ),
      ],
    );
  }

  // ── 6. PESTAÑA: NORMAS & REGLAS ───────────────────────────────────────────

  Widget _buildTabNormas(BuildContext context, Circle circle) {
    final rules = [
      (
        '1. Respeto y Convivencia',
        'No se toleran discursos de odio, insultos personales, discriminación o acoso a ningún miembro del círculo.',
      ),
      (
        '2. Contenido Temático & No Spam',
        'Mantén las publicaciones y temas de salas acordes a los objetivos e intereses de este círculo.',
      ),
      (
        '3. Políticas de Spoilers',
        'Marca como spoiler cualquier detalle crucial sobre animes, mangas, videojuegos o series recientes.',
      ),
      (
        '4. Convivencia en Salas de Roleplay',
        'En salas con Roleplay activo, respeta los turnos de juego, los personajes OCs creados y las decisiones del host.',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _buildSectionTitle('Normativas & Reglamento Oficial'),
        for (final (title, desc) in rules)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF14121E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF221E32), width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF9E9EA8),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildEmptyPosts(BuildContext context, bool isMember) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.article_outlined,
            size: 40,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 10),
          Text(
            isMember
                ? 'Sé el primero en compartir una publicación'
                : 'Aún no hay publicaciones en este círculo',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showCircleOptionsMenu(BuildContext context, Circle circle) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14121E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share_outlined, color: Colors.white),
                title: const Text(
                  'Compartir Círculo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enlace copiado 🔗')),
                  );
                },
              ),
              if (circle.isMember && !circle.isCreator)
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFFF5252),
                  ),
                  title: const Text(
                    'Salir del Círculo',
                    style: TextStyle(color: Color(0xFFFF5252)),
                  ),
                  subtitle: const Text(
                    'Dejas de seguir y ves las publicaciones de este círculo',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmLeaveCircle(context, circle);
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.report_problem_outlined,
                  color: Color(0xFFFF5252),
                ),
                title: const Text(
                  'Reportar Círculo',
                  style: TextStyle(color: Color(0xFFFF5252)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reporte enviado')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _join(BuildContext context, CircleDetailNotifier notifier) {
    notifier.join().catchError((e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo unir al círculo: $e')));
    });
  }

  void _confirmLeaveCircle(BuildContext context, Circle circle) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF14121E),
        title: const Text(
          '¿Salir del círculo?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Dejarás de seguir "${circle.name}" y ya no verás sus publicaciones.',
          style: const TextStyle(color: Color(0xFFC0BECE)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF9E9EA8)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _leaveFromOptionsMenu(context, circle);
            },
            child: const Text(
              'Salir',
              style: TextStyle(
                color: Color(0xFFFF5252),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _leaveFromOptionsMenu(BuildContext context, Circle circle) {
    final notifier = ref.read(
      circleDetailControllerProvider(widget.circleId).notifier,
    );
    notifier
        .leave()
        .then((_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Has salido del círculo')),
          );
          context.pop();
        })
        .catchError((e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo salir del círculo: $e')),
          );
        });
  }

  void _leave(BuildContext context, CircleDetailNotifier notifier) {
    notifier.leave().catchError((e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo salir del círculo: $e')),
      );
    });
  }

  void _createPost(BuildContext context) {
    context.push('/circles/${widget.circleId}/create-post');
  }
}

/// Header delegate para el TabBar pegajoso (Sticky TabBar).
class _CircleTabBarDelegate extends SliverPersistentHeaderDelegate {
  _CircleTabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: const Color(0xFF100E19), child: _tabBar);
  }

  @override
  bool shouldRebuild(_CircleTabBarDelegate oldDelegate) {
    return false;
  }
}
