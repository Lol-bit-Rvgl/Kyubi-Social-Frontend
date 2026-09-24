import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/utils/animated_emoji_manager.dart';
import '../../../../../core/widgets/app_avatar.dart';
import '../../../../../core/widgets/kyubi_rich_text.dart';
import '../../../../../core/widgets/kyubi_shimmer.dart';
import '../../../../../core/widgets/liquid_glass_container.dart';
import '../../../../../core/widgets/media/kyubi_audio_player.dart';
import '../../../../../core/widgets/media/kyubi_video_player.dart';
import '../../../../../models/post.dart';
import '../../../../../models/reaction.dart';
import '../../../../../services/auth_controller.dart';
import '../../../../../services/providers.dart';
import '../feed_controller.dart';
import '../../../profile/presentation/user_posts_controller.dart';
import '../../../../features/saved/presentation/bookmarks_controller.dart';
import 'edit_post_modal.dart';
import 'floating_reaction_menu.dart';
import 'interactive_poll_card.dart';
import 'reaction_picker_popup.dart';

void _onSpecialTextTap(BuildContext context, String text) {
  if (text.startsWith('#')) {
    context.push('/search?q=${Uri.encodeComponent(text)}');
  } else if (text.startsWith('@')) {
    final username = text.substring(1);
    context.push('/profile/$username');
  }
}

/// Formatea contadores grandes de forma compacta para que numeros de 3+ cifras
/// no desborden la fila de acciones (ej. 1.2k, 12.5k).
String _compactCount(int n) {
  if (n < 1000) return '$n';
  if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '${n ~/ 1000}k';
}

/// Tarjeta de publicación de Momentos estilo Clover Space / Project Z.
class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return LiquidGlassContainer(
      borderRadius: 18.0,
      blur: 14.0,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.md,
              AppDimens.md,
              AppDimens.md,
              0,
            ),
            child: _buildHeader(context, scheme, ref),
          ),
          InkWell(
            onTap: () => context.push('/post/${post.id}'),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.md,
                8,
                AppDimens.md,
                AppDimens.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.warnings != null && post.warnings!.hasAny)
                    _buildWarnings(scheme),
                  if (post.title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  if (post.body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: KyubiRichText(
                        text: post.body,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: scheme.onSurface.withValues(alpha: 0.85),
                        ),
                        onTap: (text) => _onSpecialTextTap(context, text),
                      ),
                    ),
                  if (post.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: post.tags
                            .take(5)
                            .map(
                              (tag) => GestureDetector(
                                onTap: () =>
                                    _onSpecialTextTap(context, '#$tag'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentCyan.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.accentCyan.withValues(
                                        alpha: 0.25,
                                      ),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: const TextStyle(
                                      color: AppColors.accentCyan,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (post.hasMedia) _buildMedia(context),
          if (_hasPoll)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
              child: _buildPoll(context, ref),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimens.md),
            child: Divider(
              height: 16,
              thickness: 0.8,
              color: Color(0x14FFFFFF),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.md,
              0,
              AppDimens.md,
              2,
            ),
            child: _buildActions(context, scheme, ref),
          ),
          if (post.reactions.activeList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.md,
                2,
                AppDimens.md,
                AppDimens.sm,
              ),
              child: ReactionChipsRow(
                activeList: post.reactions.activeList,
                myReaction: post.myReaction,
                onTapReaction: (key) => _toggleReaction(context, ref, key),
                onSelectReaction: (key) => _toggleReaction(context, ref, key),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme scheme, WidgetRef ref) {
    final nameColor = AppColors.fromHex(post.author.usernameColor);
    return Row(
      children: [
        AppAvatar(
          imageUrl: post.author.avatarUrl,
          name: post.author.displayName,
          radius: 20,
          showOnline: post.author.showOnline,
          isOnline: post.author.isOnline,
          onTap: () => context.push('/profile/${post.author.username}'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: InkWell(
                      onTap: () =>
                          context.push('/profile/${post.author.username}'),
                      child: Text(
                        post.author.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: nameColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _LevelPill(level: post.author.level),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '${post.author.handle} · ${post.timeAgo}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF7A7A8A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (post.wasEdited) ...[
                    const SizedBox(width: 4),
                    const Text(
                      '· (editado)',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF8E88A8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  // Insignia de privacidad: distingue los posts que solo ve
                  // su autor del resto del muro.
                  if (post.isPrivate) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Visible solo para ti',
                      child: Icon(
                        Icons.lock_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _showPostMenu(context, ref),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(
              Icons.more_horiz_rounded,
              size: 20,
              color: Color(0xFF7A7A8A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarnings(ColorScheme scheme) {
    final warnings = post.warnings!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          if (warnings.violence) _warningChip('Violencia', Icons.warning_amber),
          if (warnings.adult) _warningChip('Adultos', Icons.eighteen_mp),
          if (warnings.dark) _warningChip('Oscuro', Icons.dark_mode),
          if (warnings.spoiler) _warningChip('Spoiler', Icons.block),
        ],
      ),
    );
  }

  Widget _warningChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.danger),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(BuildContext context) {
    final media = post.mediaUrls;
    if (media.isEmpty) return const SizedBox.shrink();

    // Check for single media item type
    final firstUrl = media.first;
    final isAudio = _isAudioUrl(firstUrl);
    final isVideo = _isVideoUrl(firstUrl);

    if (isAudio) {
      return _buildAudio(context, firstUrl);
    }
    if (isVideo) {
      return _buildVideo(context, firstUrl);
    }

    // Handle multiple images with GridView
    if (media.length > 1) {
      return _buildImageGrid(context, media);
    }

    // Default to single image display
    return _buildSingleImage(context, firstUrl);
  }

  Widget _buildImageGrid(BuildContext context, List<String> mediaUrls) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 220,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: mediaUrls.length == 2 ? 2 : 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: mediaUrls.length == 2 ? 1.4 : 1.6,
            ),
            itemCount: mediaUrls.take(4).length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openFullscreenImage(context, mediaUrls[index]),
                child: CachedNetworkImage(
                  imageUrl: mediaUrls[index],
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const KyubiShimmer(),
                  errorWidget: (_, _, _) => Container(
                    color: const Color(0xFF1E1E2A),
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.white24,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAudio(BuildContext context, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
      child: KyubiAudioPlayer(url: url),
    );
  }

  Widget _buildVideo(BuildContext context, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: KyubiVideoPlayer(url: url),
        ),
      ),
    );
  }

  Widget _buildSingleImage(BuildContext context, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () => _openFullscreenImage(context, url),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 280),
            color: Colors.black,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => const KyubiShimmer(),
              errorWidget: (_, _, _) => Container(
                height: 180,
                color: const Color(0xFF1E1E2A),
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.white24),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openFullscreenImage(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: PhotoView(
            imageProvider: NetworkImage(url),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.5,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
        ),
      ),
    );
  }

  bool get _hasPoll => post.extensions?['poll'] is Map<String, dynamic>;

  Widget _buildPoll(BuildContext context, WidgetRef ref) {
    final pollMap = post.extensions!['poll'] as Map<String, dynamic>;
    final question = pollMap['question'] as String? ?? 'Encuesta';
    final rawOptions = pollMap['options'] as List<dynamic>? ?? [];
    final userVotedId = pollMap['userVotedOptionId'] as String?;
    final options = rawOptions.map((o) {
      if (o is Map<String, dynamic>) {
        return PollOptionData(
          id: o['id'] as String? ?? '',
          text: o['text'] as String? ?? '',
          votes: (o['votes'] as num?)?.toInt() ?? 0,
        );
      }
      return PollOptionData(id: o.toString(), text: o.toString());
    }).toList();

    return InteractivePollCard(
      question: question,
      options: options,
      userVotedOptionId: userVotedId,
      onVote: (optionId) {
        // Callback para registrar voto en la encuesta
      },
    );
  }

  Widget _buildActions(
    BuildContext context,
    ColorScheme scheme,
    WidgetRef ref,
  ) {
    // FittedBox escala el conjunto en pantallas estrechas y evita
    // desbordamientos (RenderFlex overflow) incluso con contadores de 3+ cifras.
    final bookmarks = ref.watch(bookmarksControllerProvider);
    final saved = bookmarks.isSaved(post.id);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReactionActionButton(
            isLiked: post.isLiked,
            myReaction: post.myReaction,
            count: post.reactions.total,
            onToggleLike: () => _toggleReaction(context, ref, 'like'),
            onSelectReaction: (type) => _toggleReaction(context, ref, type),
          ),
          const SizedBox(width: 10),
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: _compactCount(post.stats.comments),
            onTap: () => context.push('/post/${post.id}'),
          ),
          const SizedBox(width: 10),
          _ActionButton(
            icon: saved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            label: '',
            active: saved,
            activeColor: AppColors.accentCyan,
            onTap: () => _toggleBookmark(context, ref),
          ),
          const SizedBox(width: 10),
          _ActionButton(
            icon: Icons.visibility_outlined,
            label: _compactCount(post.stats.views),
            onTap: null,
          ),
          const SizedBox(width: 10),
          _ActionButton(
            icon: Icons.share_outlined,
            label: '',
            onTap: () => _sharePost(context),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleReaction(
    BuildContext context,
    WidgetRef ref, [
    String type = 'like',
  ]) async {
    // Normalizar: WebP paths → key estándar para el backend.
    final normalizedType = emojiToKey(type);
    final currentReaction = post.myReaction;
    final isUnreacting = currentReaction == normalizedType;
    final newReaction = isUnreacting ? null : normalizedType;
    final isLikedNow = newReaction == 'like' || newReaction == 'love';

    var newReactions = post.reactions;
    if (currentReaction != null) {
      newReactions = newReactions.increment(currentReaction, -1);
    }
    if (newReaction != null) {
      newReactions = newReactions.increment(newReaction, 1);
    }

    final optimistic = post.copyWith(
      isLiked: isLikedNow,
      myReaction: newReaction,
      reactions: newReactions,
    );
    ref.read(feedControllerProvider.notifier).updatePost(optimistic);

    // Gamefeel: respuesta háptica ligera al dar like / reaccionar.
    if (newReaction != null) {
      HapticFeedback.lightImpact();
    }

    try {
      final counts = await ref
          .read(postRepositoryProvider)
          .toggleReaction(post.id, normalizedType);
      final updated = post.copyWith(
        reactions: counts,
        isLiked: isLikedNow,
        myReaction: newReaction,
      );
      ref.read(feedControllerProvider.notifier).updatePost(updated);
    } catch (_) {
      ref.read(feedControllerProvider.notifier).updatePost(post);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No se pudo reaccionar')));
    }
  }

  Future<void> _toggleBookmark(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    await ref.read(bookmarksControllerProvider.notifier).toggle(post.id);
  }

  void _showPostMenu(BuildContext context, WidgetRef ref) {
    final myId = ref.read(authControllerProvider).user?.id ?? '';
    final isOwner = myId.isNotEmpty && post.author.id == myId;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14141B),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwner) ...[
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.accentCyan,
                ),
                title: const Text(
                  'Editar publicación',
                  style: TextStyle(color: AppColors.accentCyan),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  EditPostModal.show(context, post: post);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Eliminar publicación',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showDeleteConfirmation(context, ref);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(
                  Icons.report_outlined,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Reportar publicación',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/report-post/${post.id}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: Colors.white),
                title: const Text(
                  'Compartir',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _sharePost(context);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Eliminar publicación',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta publicación? Esta acción no se puede deshacer.',
          style: TextStyle(color: Color(0xFFB0B0C0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF6E6888)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deletePost(context, ref);
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(postRepositoryProvider);
    // Eliminación optimista inmediata tanto en el feed como en publicaciones de perfil
    ref.read(feedControllerProvider.notifier).removePost(post.id);
    ref.read(userPostsProvider(post.author.id).notifier).removePost(post.id);
    try {
      await repo.deletePost(post.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Publicación eliminada')));
      }
    } catch (_) {
      ref.read(feedControllerProvider.notifier).refresh();
      ref.read(userPostsProvider(post.author.id).notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar la publicación')),
        );
      }
    }
  }

  void _sharePost(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado al portapapeles')),
    );
  }

  bool _isAudioUrl(String url) {
    final clean = url.toLowerCase().split('?').first;
    return clean.endsWith('.mp3') ||
        clean.endsWith('.m4a') ||
        clean.endsWith('.ogg') ||
        clean.endsWith('.wav');
  }

  bool _isVideoUrl(String url) {
    final clean = url.toLowerCase().split('?').first;
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.webm') ||
        clean.endsWith('.avi');
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFA594F9).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 11,
            color: Color(0xFFA594F9),
          ),
          const SizedBox(width: 2),
          Text(
            '$level',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFFA594F9),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón de like con menú flotante de reacciones al mantener presionado.
///
/// Gestiona su propia llave de anclaje para posicionar el [FloatingReactionMenu]
/// justo encima del botón cuando el usuario lo mantiene pulsado.
class _ReactionActionButton extends StatefulWidget {
  const _ReactionActionButton({
    required this.isLiked,
    required this.myReaction,
    required this.count,
    required this.onToggleLike,
    required this.onSelectReaction,
  });

  final bool isLiked;
  final String? myReaction;
  final int count;
  final VoidCallback onToggleLike;
  final ValueChanged<String> onSelectReaction;

  @override
  State<_ReactionActionButton> createState() => _ReactionActionButtonState();
}

class _ReactionActionButtonState extends State<_ReactionActionButton> {
  final GlobalKey _anchorKey = GlobalKey();

  Future<void> _showReactionMenu() async {
    HapticFeedback.selectionClick();
    await FloatingReactionMenu.show(
      context,
      anchorKey: _anchorKey,
      onSelect: widget.onSelectReaction,
    );
  }

  @override
  Widget build(BuildContext context) {
    final countLabel = widget.count > 0 ? _compactCount(widget.count) : '';
    // Halo de neón según la reacción activa: Teal para Fuego/Energía,
    // Magenta para corazón/zorro y el resto.
    final activeColor = switch (widget.myReaction) {
      'fire' || 'sparkles' || 'energy' => AppColors.accentTeal,
      _ => const Color(0xFFA594F9),
    };
    return KeyedSubtree(
      key: _anchorKey,
      child: _ActionButton(
        icon: widget.isLiked
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        label: countLabel,
        active: widget.isLiked,
        activeColor: activeColor,
        onTap: widget.onToggleLike,
        onLongPress: _showReactionMenu,
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.onLongPress,
    this.active = false,
    this.activeColor = const Color(0xFFA594F9),
  });

  final Object icon;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool active;
  final Color activeColor;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  static const _inactiveColor = AppColors.textSecondary;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..value = 1.0;
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );

  @override
  void didUpdateWidget(covariant _ActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El corazón hace "pum" al activarse (like optimista).
    if (!oldWidget.active && widget.active) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? widget.activeColor : _inactiveColor;

    return InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: AppDimens.motionFast,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: widget.active
            ? BoxDecoration(
                color: widget.activeColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.activeColor.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: -1,
                  ),
                ],
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.icon is IconData)
              ScaleTransition(
                scale: _scale,
                child: Icon(widget.icon as IconData, size: 19, color: color),
              )
            else if (widget.icon is String)
              _renderIcon(widget.icon as String, color),
            if (widget.label.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _renderIcon(String value, Color color) {
    if (value.endsWith('.webp') || value.contains('/')) {
      return ScaleTransition(
        scale: _scale,
        child: AnimatedEmojiManager.renderEmoji(value, size: 19),
      );
    }
    return Text(value, style: const TextStyle(fontSize: 16));
  }
}
