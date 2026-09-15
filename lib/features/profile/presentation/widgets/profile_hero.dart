import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/open_url.dart';
import '../../../../core/widgets/liquid_glass_container.dart';
import '../../../../models/user.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';
import 'nebulae_profile_avatar.dart';

/// Encabezado de perfil: banner de marca, avatar, nombre, bio, estadísticas,
/// intereses y enlaces sociales. Backend real: /users/[username] y /users/me.
class ProfileHero extends ConsumerStatefulWidget {
  const ProfileHero({super.key, required this.user, this.isOwnProfile = false});

  final User user;
  final bool isOwnProfile;

  @override
  ConsumerState<ProfileHero> createState() => _ProfileHeroState();
}

class _ProfileHeroState extends ConsumerState<ProfileHero> {
  Uint8List? _bannerBytes;
  String? _bannerFilename;
  bool _uploadingBanner = false;

  // Local fallback for cache busting within current session.
  // Once the backend is updated to include avatarUpdatedAt/bannerUpdatedAt in the profile response,
  // the _cacheKeyFromServer and _cacheKeyForBanner getters can be uncommented and used
  // to achieve persistent cache busting across sessions.
  int _localCacheVersion = 0;

  Future<void> _pickBanner() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bannerBytes = bytes;
        _bannerFilename = picked.name;
        _uploadingBanner = true;
      });
      await _uploadBanner();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar la imagen')),
      );
    } finally {
      if (mounted) setState(() => _uploadingBanner = false);
    }
  }

  Future<void> _uploadBanner() async {
    if (_bannerBytes == null) return;
    try {
      final repo = ref.read(uploadRepositoryProvider);
      final url = await repo.uploadFile(
        'banner',
        bytes: _bannerBytes!,
        filename: _bannerFilename ?? 'banner.jpg',
      );
      // Update user profile with new banner URL
      final userRepo = ref.read(userRepositoryProvider);
      final updated = await userRepo.updateProfile(bannerUrl: url);
      if (!mounted) return;
      ref.read(authControllerProvider.notifier).updateUser(updated);
      // Use server-provided updatedAt timestamp for persistent cache busting.
      // Falls back to local epoch millis if backend hasn't been updated yet.
      _localCacheVersion = DateTime.now().millisecondsSinceEpoch;
      if (mounted) setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fondo actualizado')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo subir el fondo')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nameColor = AppColors.fromHex(widget.user.usernameColor);
    final effectiveBannerUrl = _bannerBytes != null
        ? null
        : widget.user.bannerUrl;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildBanner(effectiveBannerUrl),
        Padding(
          padding: EdgeInsets.only(top: AppDimens.profileBannerHeight - 52),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    // Avatar con halo Nebulæ unificado y estado online.
                    NebulaeProfileAvatar(
                      name: widget.user.displayName,
                      imageUrl: widget.user.effectiveAvatarUrl,
                      radius: 48,
                      isOnline: widget.user.isOnline,
                      cacheVersion: _localCacheVersion,
                    ),
                    if (widget.isOwnProfile)
                      GestureDetector(
                        onTap: () => context.push('/edit-profile'),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF44507A),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.obsidianBg,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      widget.user.displayName,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: nameColor,
                      ),
                    ),
                  ),
                  if (widget.user.isVerified) ...[
                    const SizedBox(width: 6),
                    Image.asset(
                      AppAssets.iconVerificados,
                      width: 16,
                      height: 16,
                      fit: BoxFit.contain,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.user.handle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (widget.user.bio != null && widget.user.bio!.isNotEmpty) ...[
                const SizedBox(height: AppDimens.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
                  child: Text(
                    widget.user.bio!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
              const SizedBox(height: AppDimens.lg),
              _buildStats(context),
              if (_socialLinks.isNotEmpty) ...[
                const SizedBox(height: AppDimens.md),
                _buildSocialLinks(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBanner(String? bannerUrl) {
    return Container(
      height: AppDimens.profileBannerHeight,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B2D60), Color(0xFF233554)],
        ),
      ),
      child: Stack(
        children: [
          if (bannerUrl != null && bannerUrl.isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl:
                    '$bannerUrl${_localCacheVersion != 0 ? '?v=$_localCacheVersion' : ''}',
                fit: BoxFit.cover,
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          if (_bannerBytes != null)
            Positioned.fill(
              child: Image.memory(_bannerBytes!, fit: BoxFit.cover),
            ),
          // Gradient fade to obsidianBg at bottom
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.obsidianBg],
                  stops: [0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            right: -32,
            top: -40,
            child: _Blob(
              size: 150,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            left: -24,
            bottom: -36,
            child: _Blob(
              size: 130,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            right: 70,
            bottom: -18,
            child: _Blob(size: 80, color: Colors.black.withValues(alpha: 0.14)),
          ),
          // Acentos de identidad: corte diagonal y cola curva.
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _BannerDecorPainter()),
            ),
          ),
          if (widget.isOwnProfile)
            Positioned(
              top: AppDimens.md,
              right: AppDimens.md,
              child: _uploadingBanner
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: _pickBanner,
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white70,
                      ),
                      tooltip: 'Cambiar fondo',
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
      child: LiquidGlassContainer(
        borderRadius: AppDimens.radiusCard,
        padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
        child: Row(
          children: [
            Expanded(
              child: _HeroStat(
                value: '${widget.user.level}',
                label: 'Nivel',
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFA594F9), // lavanda suave
              ),
            ),
            Container(width: 1, height: 32, color: AppColors.borderGlow),
            Expanded(
              child: InkWell(
                onTap: () =>
                    context.push('/profile/${widget.user.username}/followers'),
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                child: _HeroStat(
                  value: '${widget.user.followersCount}',
                  label: 'Seguidores',
                  icon: Icons.group_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Container(width: 1, height: 32, color: AppColors.borderGlow),
            Expanded(
              child: InkWell(
                onTap: () =>
                    context.push('/profile/${widget.user.username}/following'),
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                child: _HeroStat(
                  value: '${widget.user.followingCount}',
                  label: 'Siguiendo',
                  icon: Icons.person_add_alt_1_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<(IconData, String)> get _socialLinks {
    final links = widget.user.socialLinks;
    if (links == null || links.isEmpty) return const [];
    final mapping = <String, IconData>{
      'instagram': Icons.camera_alt_outlined,
      'x': Icons.alternate_email_rounded,
      'twitter': Icons.alternate_email_rounded,
      'tiktok': Icons.music_note_outlined,
      'youtube': Icons.play_circle_outline_rounded,
      'discord': Icons.forum_outlined,
      'twitch': Icons.live_tv_outlined,
      'github': Icons.code_rounded,
      'website': Icons.language_rounded,
    };
    final result = <(IconData, String)>[];
    for (final entry in links.entries) {
      final key = entry.key.toLowerCase();
      final icon = mapping[key] ?? Icons.link_rounded;
      result.add((icon, entry.value.toString()));
    }
    return result;
  }

  Widget _buildSocialLinks(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final (icon, url) in _socialLinks)
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceGlass,
              border: Border.all(color: AppColors.borderGlow),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () async {
                final ok = await openUrl(url);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No se pudo abrir el enlace')),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Acentos de identidad del banner: corte diagonal y cola curva.
class _BannerDecorPainter extends CustomPainter {
  const _BannerDecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Corte diagonal en la esquina superior derecha.
    final diagonal = Path()
      ..moveTo(w, 0)
      ..lineTo(w, h * 0.22)
      ..lineTo(w - h * 0.22, 0)
      ..close();
    canvas.drawPath(
      diagonal,
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );

    // Cola curva hacia la esquina inferior derecha.
    final baseX = w * 0.74;
    final baseY = h * 0.58;
    void stroke(Path path, double alpha) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.4,
      );
    }

    stroke(
      Path()
        ..moveTo(baseX, baseY)
        ..cubicTo(
          baseX + w * 0.05,
          baseY + h * 0.05,
          baseX + w * 0.11,
          baseY + h * 0.12,
          baseX + w * 0.15,
          baseY + h * 0.26,
        ),
      0.18,
    );
    stroke(
      Path()
        ..moveTo(baseX + w * 0.03, baseY + h * 0.10)
        ..cubicTo(
          baseX + w * 0.09,
          baseY + h * 0.14,
          baseX + w * 0.14,
          baseY + h * 0.19,
          baseX + w * 0.17,
          baseY + h * 0.30,
        ),
      0.11,
    );
  }

  @override
  bool shouldRepaint(covariant _BannerDecorPainter oldDelegate) => false;
}
