import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/kyubi_shimmer.dart';
import '../../../../core/widgets/media/kyubi_audio_player.dart';
import '../../../../core/widgets/media/kyubi_video_player.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../models/comment.dart';
import '../../../../models/post.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';
import '../../feed/presentation/widgets/interactive_poll_card.dart';
import '../../feed/presentation/widgets/reaction_picker_popup.dart';
import '../../feed/presentation/widgets/floating_reaction_menu.dart';

/// Detalle de una publicación con comentarios.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();

  /// Ancla para posicionar el [FloatingReactionMenu] sobre el botón de like.
  final GlobalKey _reactionAnchorKey = GlobalKey();
  Post? _post;
  List<Comment> _comments = [];
  Comment? _replyTarget;
  bool _loading = true;
  bool _sendingComment = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(postRepositoryProvider);
      final post = await repo.getPost(widget.postId);
      final comments = await repo.getComments(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _comments = comments.comments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final apiError = mapDioException(e);
      final isForbidden = apiError.statusCode == 403;
      setState(() {
        _error = isForbidden
            ? 'Esta publicación solo es visible para los miembros del '
                  'círculo. Únete al círculo para poder verla.'
            : apiError.message;
        _loading = false;
      });
    }
  }

  Future<void> _sendComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty || _sendingComment) return;
    final replyTarget = _replyTarget;
    setState(() => _sendingComment = true);
    try {
      final comment = await ref
          .read(postRepositoryProvider)
          .createComment(widget.postId, body: body, parentId: replyTarget?.id);
      if (!mounted) return;
      setState(() {
        if (replyTarget != null) {
          final updated = _insertReply(_comments, replyTarget.id, comment);
          if (updated != null) _comments = updated;
        } else {
          _comments = [comment, ..._comments];
        }
        _commentController.clear();
        _replyTarget = null;
        _sendingComment = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sendingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el comentario')),
      );
    }
  }

  /// Activa el modo respuesta para [comment]. Si ya es la misma, lo cancela.
  void _toggleReply(Comment comment) {
    if (_replyTarget?.id == comment.id) {
      _cancelReply();
      return;
    }
    setState(() {
      _replyTarget = comment;
      // Antepone la mención @usuario como base del mensaje en modo respuesta.
      _commentController.text = '@${comment.author.username} ';
    });
    _commentController.selection = TextSelection.collapsed(
      offset: _commentController.text.length,
    );
    _commentFocus.requestFocus();
  }

  /// Cancela el modo respuesta y limpia la mención prellenada.
  void _cancelReply() {
    setState(() {
      _replyTarget = null;
      _commentController.clear();
    });
  }

  /// Toggle optimista de "me gusta" en un comentario (y sus réplicas).
  Future<void> _toggleCommentLike(Comment comment) async {
    HapticFeedback.lightImpact();
    final nowLiked = !comment.isLiked;
    _applyCommentLike(comment.id, nowLiked, nowLiked ? 1 : -1);
    try {
      await ref
          .read(postRepositoryProvider)
          .toggleCommentLike(comment.id, nowLiked ? 'like' : 'love');
    } catch (_) {
      if (!mounted) return;
      _applyCommentLike(comment.id, !nowLiked, nowLiked ? -1 : 1);
    }
  }

  /// Aplica un cambio de like ([isLiked], [delta]) a un comentario en el
  /// árbol completo de comentarios, de forma recursiva.
  void _applyCommentLike(String commentId, bool isLiked, int delta) {
    List<Comment> go(List<Comment> comments) {
      return [
        for (final c in comments)
          if (c.id == commentId)
            c.copyWith(
              isLiked: isLiked,
              likeCount: (c.likeCount + delta).clamp(0, 1 << 31),
            )
          else
            c.copyWith(replies: c.replies.isEmpty ? c.replies : go(c.replies)),
      ];
    }

    setState(() => _comments = go(_comments));
  }

  /// Inserta [reply] bajo el comentario con [parentId] en el árbol de
  /// comentarios (recorre también las respuestas anidadas). Devuelve `null`
  /// si no se encontró el padre.
  List<Comment>? _insertReply(
    List<Comment> comments,
    String parentId,
    Comment reply,
  ) {
    final result = <Comment>[];
    var didInsert = false;
    for (final c in comments) {
      if (c.id == parentId) {
        result.add(c.copyWith(replies: [...c.replies, reply]));
        didInsert = true;
        continue;
      }
      if (c.replies.isNotEmpty) {
        final nested = _insertReply(c.replies, parentId, reply);
        if (nested != null) {
          result.add(c.copyWith(replies: nested));
          didInsert = true;
          continue;
        }
      }
      result.add(c);
    }
    return didInsert ? result : null;
  }

  /// Indica si el comentario con [targetId] pertenece al árbol de [comment]
  /// (para resaltar la rama que se está respondiendo).
  bool _isReplyInTree(Comment comment, String? targetId) {
    if (targetId == null) return false;
    if (comment.id == targetId) return true;
    return comment.replies.any((r) => _isReplyInTree(r, targetId));
  }

  void _openReactionPicker() {
    FloatingReactionMenu.show(
      context,
      anchorKey: _reactionAnchorKey,
      onSelect: (type) {
        _toggleReaction(type);
      },
    );
  }

  Future<void> _toggleReaction([String type = 'like']) async {
    final post = _post;
    if (post == null) return;
    // Gamefeel: respuesta háptica ligera al dar like / reaccionar.
    HapticFeedback.lightImpact();
    final currentReaction = post.myReaction;
    final isUnreacting = currentReaction == type;
    final newReaction = isUnreacting ? null : type;
    final isLikedNow = newReaction == 'like' || newReaction == 'love';

    var newReactions = post.reactions;
    if (currentReaction != null) {
      newReactions = newReactions.increment(currentReaction, -1);
    }
    if (newReaction != null) {
      newReactions = newReactions.increment(newReaction, 1);
    }

    // Actualización optimista inmediata
    setState(() {
      _post = post.copyWith(
        isLiked: isLikedNow,
        myReaction: newReaction,
        reactions: newReactions,
      );
    });
    try {
      final counts = await ref
          .read(postRepositoryProvider)
          .toggleReaction(post.id, type);
      if (!mounted) return;
      setState(() {
        _post = post.copyWith(
          reactions: counts,
          isLiked: isLikedNow,
          myReaction: newReaction,
        );
      });
    } catch (_) {
      // Revertir en caso de error
      if (!mounted) return;
      setState(() => _post = post);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No se pudo reaccionar')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Publicación')),
      body: _buildBody(),
      bottomNavigationBar: _post == null
          ? null
          : SafeArea(child: _buildComposer()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView(message: 'Cargando publicación...');
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    final post = _post!;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: AppDimens.pagePadding,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Row(
          children: [
            AppAvatar(
              imageUrl: post.author.avatarUrl,
              name: post.author.displayName,
              radius: 22,
              onTap: () => context.push('/profile/${post.author.username}'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () =>
                        context.push('/profile/${post.author.username}'),
                    child: Text(
                      post.author.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${post.author.handle} · ${post.timeAgo}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (post.title.isNotEmpty) ...[
          const SizedBox(height: AppDimens.md),
          Text(
            post.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
        if (post.body.isNotEmpty) ...[
          const SizedBox(height: AppDimens.sm),
          Text(post.body, style: Theme.of(context).textTheme.bodyLarge),
        ],
        if (post.mediaUrls.isNotEmpty || post.audioUrl != null) ...[
          const SizedBox(height: AppDimens.md),
          _buildMediaDetail(context, post),
        ],
        if (post.tags.isNotEmpty) ...[
          const SizedBox(height: AppDimens.sm),
          Wrap(
            spacing: 6,
            children: post.tags
                .map(
                  (tag) => Text(
                    '#$tag',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        if (post.extensions?['poll'] is Map<String, dynamic>) ...[
          const SizedBox(height: AppDimens.sm),
          InteractivePollCard(
            question:
                (post.extensions!['poll'] as Map<String, dynamic>)['question']
                    as String? ??
                'Encuesta',
            options:
                ((post.extensions!['poll'] as Map<String, dynamic>)['options']
                            as List<dynamic>? ??
                        [])
                    .map((o) {
                      if (o is Map<String, dynamic>) {
                        return PollOptionData(
                          id: o['id'] as String? ?? '',
                          text: o['text'] as String? ?? '',
                          votes: (o['votes'] as num?)?.toInt() ?? 0,
                        );
                      }
                      return PollOptionData(
                        id: o.toString(),
                        text: o.toString(),
                      );
                    })
                    .toList(),
            userVotedOptionId:
                (post.extensions!['poll']
                        as Map<String, dynamic>)['userVotedOptionId']
                    as String?,
          ),
        ],
        const SizedBox(height: AppDimens.md),
        Row(
          children: [
            KeyedSubtree(
              key: _reactionAnchorKey,
              child: _ActionChip(
                icon: post.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: post.isLiked
                    ? AppColors.primary
                    : AppColors.textSecondary,
                count: post.reactions.total,
                onTap: () => _toggleReaction('like'),
                onLongPress: _openReactionPicker,
              ),
            ),
            const SizedBox(width: 8),
            _ActionChip(
              icon: Icons.visibility_outlined,
              count: post.stats.views,
            ),
            const Spacer(),
            Text(
              '${post.stats.shares} compartidos',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        if (post.reactions.activeList.isNotEmpty)
          ReactionChipsRow(
            activeList: post.reactions.activeList,
            myReaction: post.myReaction,
            onTapReaction: (key) => _toggleReaction(key),
            onSelectReaction: (key) => _toggleReaction(key),
          ),
        const SizedBox(height: AppDimens.lg),
        Text(
          'Comentarios (${_comments.length})',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppDimens.xs),
        if (_comments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: EmptyView(
              icon: Icons.forum_outlined,
              title: 'Sin comentarios',
              message: 'Sé el primero en comentar.',
            ),
          )
        else
          for (final comment in _comments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _CommentTile(
                comment: comment,
                onReply: _toggleReply,
                onLike: _toggleCommentLike,
                replying:
                    _replyTarget?.id == comment.id ||
                    _isReplyInTree(comment, _replyTarget?.id),
              ),
            ),
      ],
    );
  }

  Widget _buildMediaDetail(BuildContext context, Post post) {
    final media = post.mediaUrls;
    final audioUrl = post.audioUrl;

    // Audio del post
    if (audioUrl != null && audioUrl.isNotEmpty) {
      return KyubiAudioPlayer(url: audioUrl);
    }

    if (media.isEmpty) return const SizedBox.shrink();

    final firstUrl = media.first;
    if (_isAudioUrl(firstUrl)) {
      return KyubiAudioPlayer(url: firstUrl);
    }
    if (_isVideoUrl(firstUrl)) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: KyubiVideoPlayer(url: firstUrl),
        ),
      );
    }

    // Múltiples imágenes
    if (media.length > 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 240,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.4,
            ),
            itemCount: media.take(4).length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openFullscreenImage(context, media[index]),
                child: CachedNetworkImage(
                  imageUrl: media[index],
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const KyubiShimmer(),
                  errorWidget: (_, _, _) => Container(
                    color: AppColors.surfaceAlt,
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
      );
    }

    // Imagen individual
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () => _openFullscreenImage(context, firstUrl),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 320),
          child: CachedNetworkImage(
            imageUrl: firstUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) => const KyubiShimmer(),
            errorWidget: (_, _, _) => Container(
              height: 180,
              color: AppColors.surfaceAlt,
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.white24),
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
          body: Center(
            child: InteractiveViewer(child: CachedNetworkImage(imageUrl: url)),
          ),
        ),
      ),
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

  Widget _buildComposer() {
    final replyTarget = _replyTarget;
    final currentUser = ref.read(authControllerProvider).user;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimens.md,
        8,
        AppDimens.md,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyTarget != null) _buildReplyBanner(replyTarget),
          Row(
            children: [
              if (currentUser != null) ...[
                AppAvatar(
                  imageUrl: currentUser.effectiveAvatarUrl,
                  name: currentUser.displayName,
                  radius: 16,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocus,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendComment(),
                  maxLines: 1,
                  maxLength: 2000,
                  buildCounter: (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) =>
                      currentLength > 1800
                          ? Text(
                              '$currentLength/$maxLength',
                              style: const TextStyle(
                                color: Color(0xFF9E9EAF),
                                fontSize: 10,
                              ),
                            )
                          : null,
                  decoration: const InputDecoration(
                    hintText: 'Escribe un comentario...',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sendingComment ? null : _sendComment,
                icon: _sendingComment
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBanner(Comment replyTarget) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.borderNight.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.borderNight.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.reply_rounded,
            size: 16,
            color: AppColors.borderNight,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Respondiendo a ${replyTarget.author.displayName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          InkWell(
            onTap: _cancelReply,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatefulWidget {
  const _ActionChip({
    required this.icon,
    this.color,
    required this.count,
    this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final Color? color;
  final int count;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..value = 1.0;
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );

  @override
  void didUpdateWidget(covariant _ActionChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pulso únicamente cuando el corazón se activa (pasa a carmesí neón).
    if (widget.color != oldWidget.color && widget.color == AppColors.primary) {
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
    final color =
        widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Icon(widget.icon, size: 20, color: color),
            ),
            const SizedBox(width: 5),
            Text(
              '${widget.count}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onReply,
    this.onLike,
    this.replying = false,
    this.indented = false,
  });

  final Comment comment;
  final ValueChanged<Comment> onReply;
  final ValueChanged<Comment>? onLike;
  final bool replying;
  final bool indented;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connectorColor = AppColors.borderNight.withValues(alpha: 0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (indented) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 7, right: 6),
                  child: Container(width: 2, color: connectorColor),
                ),
              ],
              Expanded(child: _buildCommentCard(context, scheme)),
            ],
          ),
        ),
        _buildReplyActions(context),
        if (comment.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Column(
              children: [
                for (final reply in comment.replies)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _CommentTile(
                      comment: reply,
                      onReply: onReply,
                      onLike: onLike,
                      replying: replying,
                      indented: true,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCommentCard(BuildContext context, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(
          alpha: replying ? 0.55 : 0.35,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: replying
            ? Border.all(
                color: AppColors.borderNight.withValues(alpha: 0.6),
                width: 1,
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(
            imageUrl: comment.author.avatarUrl,
            name: comment.author.displayName,
            radius: 18,
            onTap: comment.author.username.isEmpty
                ? null
                : () => context.push('/profile/${comment.author.username}'),
          ),
          const SizedBox(width: AppDimens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.author.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '· ${comment.timeAgo}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.body,
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyActions(BuildContext context) {
    final actionColor = AppColors.borderNight.withValues(alpha: 0.9);
    return Padding(
      padding: EdgeInsets.only(left: indented ? 75 : 60, top: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onLike == null ? null : () => onLike!(comment),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    comment.isLiked
                        ? Icons.thumb_up_alt_rounded
                        : Icons.thumb_up_alt_outlined,
                    size: 13,
                    color: comment.isLiked
                        ? AppColors.accentCyan
                        : actionColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${comment.likeCount}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: comment.isLiked
                          ? AppColors.accentCyan
                          : actionColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => onReply(comment),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                'Responder',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: actionColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
