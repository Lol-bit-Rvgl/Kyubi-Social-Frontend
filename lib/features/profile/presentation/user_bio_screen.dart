import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/kyubi_rich_text.dart';
import '../../../../core/widgets/kyubi_shimmer.dart';
import '../../../../core/widgets/liquid_glass_container.dart';
import '../../../../models/user.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';
import 'profile_metrics.dart';

/// Pantalla completa dedicada a la Biografía extendida del usuario (Kubi-Space Bio).
class UserBioScreen extends ConsumerStatefulWidget {
  const UserBioScreen({
    super.key,
    this.user,
    this.username,
    this.isOwnProfile = false,
  });

  final User? user;
  final String? username;
  final bool isOwnProfile;

  @override
  ConsumerState<UserBioScreen> createState() => _UserBioScreenState();
}

class _UserBioScreenState extends ConsumerState<UserBioScreen> {
  User? _currentUser;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _currentUser = widget.user;
    } else {
      Future.microtask(_loadUser);
    }
  }

  Future<void> _loadUser() async {
    if (widget.isOwnProfile) {
      final authUser = ref.read(authControllerProvider).user;
      if (authUser != null) {
        if (mounted) setState(() => _currentUser = authUser);
        return;
      }
    }

    final uname = widget.username ?? '';
    if (uname.trim().isEmpty) {
      if (mounted) {
        setState(() => _error = 'No se especificó un usuario para la biografía');
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final repo = ref.read(userRepositoryProvider);
      final fetched = await repo.getProfile(uname);
      if (mounted) {
        setState(() {
          _currentUser = fetched;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No fue posible cargar el perfil del usuario';
          _loading = false;
        });
      }
    }
  }

  void _onSpecialTextTap(BuildContext context, String text) {
    if (text.startsWith('#')) {
      context.push('/search?q=${Uri.encodeComponent(text)}');
    } else if (text.startsWith('@')) {
      final username = text.substring(1);
      context.push('/profile/$username');
    }
  }

  Future<void> _openEditBioModal() async {
    HapticFeedback.selectionClick();
    final bioController = TextEditingController(text: _currentUser?.bio ?? '');
    final bannerController = TextEditingController(
      text: _currentUser?.bannerUrl ?? '',
    );
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14121F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
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
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        color: AppColors.accentCrimson,
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Editar Biografía Completa',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Biografía / Lore del Personaje',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B172B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF2C2542),
                        width: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: bioController,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 1000,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                      decoration: const InputDecoration(
                        hintText:
                            'Escribe tu historia, gustos, reglas de rol y frases...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6A6A7E),
                        ),
                        border: InputBorder.none,
                        counterStyle: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6A6A7E),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'URL de Imagen Decorativa / Banner',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B172B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF2C2542),
                        width: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: bannerController,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'https://...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6A6A7E),
                        ),
                        prefixIcon: Icon(
                          Icons.image_outlined,
                          size: 18,
                          color: AppColors.accentCyan,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setModalState(() => saving = true);
                              try {
                                final updated = await ref
                                    .read(userRepositoryProvider)
                                    .updateProfile(
                                      bio: bioController.text.trim(),
                                      bannerUrl:
                                          bannerController.text
                                              .trim()
                                              .isNotEmpty
                                          ? bannerController.text.trim()
                                          : null,
                                    );
                                ref
                                    .read(authControllerProvider.notifier)
                                    .updateUser(updated);
                                if (!mounted || !ctx.mounted) return;
                                setState(() => _currentUser = updated);
                                Navigator.of(ctx).pop();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Biografía actualizada'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (!ctx.mounted) return;
                                setModalState(() => saving = false);
                                String errorMsg = 'Error al guardar';
                                if (e is DioException) {
                                  final data = e.response?.data;
                                  if (data is Map && data['error'] is String) {
                                    errorMsg = data['error'] as String;
                                  } else if (data is Map && data['message'] is String) {
                                    errorMsg = data['message'] as String;
                                  } else if (e.response?.statusCode == 400) {
                                    errorMsg = 'Datos inválidos o la biografía excede el límite permitido (1000 caracteres).';
                                  } else {
                                    errorMsg = 'Error al conectar con el servidor (${e.response?.statusCode ?? 'red'}).';
                                  }
                                } else {
                                  errorMsg = e.toString();
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(errorMsg),
                                      backgroundColor: AppColors.accentCrimson,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCrimson,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Guardar Cambios',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _currentUser == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundBase,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundBase,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loadUser,
                      child: const Text('Reintentar'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final user = _currentUser!;
    final authUser = ref.watch(authControllerProvider).user;
    final isOwnProfile = widget.isOwnProfile ||
        (authUser != null &&
            (authUser.id == user.id ||
             authUser.username.toLowerCase() == user.username.toLowerCase()));
    final metrics = ref.watch(profileMetricsProvider(user));
    final bannerUrl = user.effectiveBannerUrl;
    final createdAtStr = DateUtilsX.formatFullDate(user.createdAt);

    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // ── SliverAppBar con Banner Panorámico ──
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.backgroundBase,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 18),
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (isOwnProfile)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 18,
                      color: AppColors.accentCrimson,
                    ),
                  ),
                  onPressed: _openEditBioModal,
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (bannerUrl != null && bannerUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: bannerUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          const KyubiShimmer(color: Color(0xFF14141B)),
                      errorWidget: (_, _, _) => _buildDefaultBanner(),
                    )
                  else
                    _buildDefaultBanner(),

                  // Sombra inferior de fusión
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x880B0B10),
                          AppColors.backgroundBase,
                        ],
                        stops: [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Contenido de la Biografía ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header de Identidad
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentCrimson,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentCrimson.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2),
                        child: AppAvatar(
                          imageUrl: user.effectiveAvatarUrl,
                          name: user.displayName,
                          radius: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.displayName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (user.isVerified) ...[
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFF00E5FF),
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.handle,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors.crimsonGlow,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Lv ${metrics.level} ${metrics.levelName}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Tarjeta Principal de Biografía ──
                  LiquidGlassContainer(
                    width: double.infinity,
                    borderRadius: 20,
                    style: user.themeSettings.glassStyle,
                    customBorderGradient: user.themeSettings.borderGradient,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_stories_rounded,
                              size: 18,
                              color: user.themeSettings.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Sobre Mí / Lore',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (user.bio != null && user.bio!.trim().isNotEmpty)
                          KyubiRichText(
                            text: user.bio!,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.55,
                              color: Color(0xFFD8D8E6),
                            ),
                            onTap: (text) => _onSpecialTextTap(context, text),
                          )
                        else
                          const Text(
                            'Este usuario aún no ha escrito su biografía.',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF7A7A8E),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Imagen a Ancho Completo Si Existe ──
                  if (bannerUrl != null && bannerUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF22222E),
                            width: 0.8,
                          ),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: bannerUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              const KyubiShimmer(color: Color(0xFF14141B)),
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Tags e Intereses ──
                  if (user.interests.isNotEmpty) ...[
                    LiquidGlassContainer(
                      borderRadius: 18,
                      style: user.themeSettings.glassStyle,
                      customBorderGradient: user.themeSettings.borderGradient,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.tag_rounded,
                                size: 16,
                                color: user.themeSettings.accent,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Intereses y Temáticas',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: user.interests.map((tag) {
                              return GestureDetector(
                                onTap: () =>
                                    _onSpecialTextTap(context, '#$tag'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: user.themeSettings.accent.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: user.themeSettings.accent.withValues(
                                        alpha: 0.35,
                                      ),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: user.themeSettings.accent,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Datos de Registro / Membresía ──
                  LiquidGlassContainer(
                    borderRadius: 18,
                    style: user.themeSettings.glassStyle,
                    customBorderGradient: user.themeSettings.borderGradient,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: user.themeSettings.primary,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fecha de Registro',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF7A7A8E),
                              ),
                            ),
                            Text(
                              createdAtStr,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
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
          ),
          const SliverToBoxAdapter(
            child: SafeArea(top: false, child: SizedBox(height: 32)),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primarySoftDark,
            AppColors.ink700,
            AppColors.backgroundBase,
          ],
        ),
      ),
    );
  }
}
