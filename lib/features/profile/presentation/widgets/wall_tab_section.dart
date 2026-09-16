import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/kyubi_rich_text.dart';
import '../../../../models/wall_entry.dart';
import '../../../../services/auth_controller.dart';
import '../user_wall_comments_controller.dart';

/// Pestaña de muro del perfil, alimentada por [userWallCommentsProvider].
///
/// Implementada como un [ListView] scrollable independiente con scroll physics
/// compatible con [NestedScrollView].
class WallTabSection extends ConsumerStatefulWidget {
  const WallTabSection({
    super.key,
    required this.ownerId,
    this.onSpecialTextTap,
  });

  /// Id o username del dueño del muro. Acepta 'me'.
  final String ownerId;
  final void Function(String text)? onSpecialTextTap;

  @override
  ConsumerState<WallTabSection> createState() => _WallTabSectionState();
}

class _WallTabSectionState extends ConsumerState<WallTabSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    HapticFeedback.mediumImpact();
    final ok = await ref
        .read(userWallCommentsProvider(widget.ownerId).notifier)
        .post(_controller.text);
    if (!mounted) return;
    if (ok) {
      _controller.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo firmar en el muro')),
      );
    }
  }

  Future<void> _toggleLike(WallEntry entry) async {
    HapticFeedback.lightImpact();
    await ref
        .read(userWallCommentsProvider(widget.ownerId).notifier)
        .toggleLike(entry);
  }

  Future<void> _confirmAndDelete(WallEntry entry) async {
    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: const Color(0xFF1E192E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: scheme.primary.withValues(alpha: 0.25),
            ),
          ),
          title: const Text(
            '¿Eliminar firma?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          content: const Text(
            'Esta firma se eliminará permanentemente de este muro.',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFFB3B0C7),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final ok = await ref
          .read(userWallCommentsProvider(widget.ownerId).notifier)
          .delete(entry);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Firma eliminada del muro'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo eliminar la firma'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userWallCommentsProvider(widget.ownerId));
    final me = ref.watch(authControllerProvider).user;
    final myId = me?.id;
    final myUsername = me?.username.toLowerCase().trim();
    final ownerLower = widget.ownerId.toLowerCase().trim();

    // Puede borrar si es el dueño del perfil del muro
    final isProfileOwner = (myId != null && ownerLower == myId.toLowerCase()) ||
        (myUsername != null && ownerLower == myUsername) ||
        ownerLower == 'me';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Card con el input/composer de firmas
        _buildComposerCard(state),
        const SizedBox(height: 14),

        // Estado del contenido
        if (state.loading && state.entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.accentCrimson,
                ),
              ),
            ),
          )
        else if (state.error != null && state.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  'No se pudieron cargar las publicaciones del muro',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => ref
                      .read(userWallCommentsProvider(widget.ownerId).notifier)
                      .load(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          )
        else if (state.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 32,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'El muro no tiene publicaciones aún.\n¡Sé el primero en firmar o comentar!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          for (final entry in state.entries) ...[
            Builder(
              builder: (ctx) {
                final isAuthor = (myId != null && entry.authorId == myId) ||
                    (myUsername != null &&
                        entry.authorName.toLowerCase().trim() == myUsername) ||
                    entry.isAuthor;
                final canDelete = isAuthor || isProfileOwner;

                return AnimatedSize(
                  key: ValueKey(entry.id),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _WallEntryTile(
                    entry: entry,
                    canDelete: canDelete,
                    onLike: () => _toggleLike(entry),
                    onDelete: () => _confirmAndDelete(entry),
                    onSpecialTextTap: widget.onSpecialTextTap,
                  ),
                );
              },
            ),
          ],
          if (state.loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentCrimson,
                  ),
                ),
              ),
            )
          else if (state.hasMore)
            Center(
              child: TextButton(
                onPressed: () => ref
                    .read(userWallCommentsProvider(widget.ownerId).notifier)
                    .loadMore(),
                child: const Text('Ver más'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildComposerCard(UserWallCommentsState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final primaryColor = scheme.primary;
    final secondaryColor = scheme.secondary;

    return Container(
      padding: const EdgeInsets.all(AppDimens.md),
      decoration: BoxDecoration(
        color: const Color(0xFF14141B).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.22),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
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
              style: const TextStyle(fontSize: 13.5, color: Colors.white),
              decoration: InputDecoration(
                hintText: '✍️ Escribe una firma en el muro...',
                hintStyle: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6A6A7A),
                ),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF1A1A26),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: primaryColor.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: primaryColor.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: primaryColor,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: state.posting ? null : _post,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    secondaryColor != primaryColor
                        ? secondaryColor
                        : primaryColor.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: state.posting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryColor.computeLuminance() > 0.5
                            ? const Color(0xFF0D0A14)
                            : Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      size: 16,
                      color: primaryColor.computeLuminance() > 0.5
                          ? const Color(0xFF0D0A14)
                          : Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WallEntryTile extends StatelessWidget {
  const _WallEntryTile({
    required this.entry,
    required this.canDelete,
    required this.onLike,
    required this.onDelete,
    this.onSpecialTextTap,
  });

  final WallEntry entry;
  final bool canDelete;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final void Function(String text)? onSpecialTextTap;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final primaryColor = scheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.22),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(1.5),
                child: AppAvatar(
                  name: entry.authorName,
                  imageUrl: entry.authorAvatarUrl,
                  radius: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.authorName,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.authorEmoji.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Text(
                            entry.authorEmoji,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _formatTime(entry.createdAt),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF7A7A8E),
                      ),
                    ),
                  ],
                ),
              ),
              if (canDelete)
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 15,
                      color: AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (entry.text.trim().isNotEmpty)
            KyubiRichText(
              text: entry.text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              onTap: onSpecialTextTap,
            ),

          if (hasImage) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: Colors.black,
                      appBar: AppBar(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      body: PhotoView(
                        imageProvider: NetworkImage(entry.imageUrl!),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: entry.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, _) => SizedBox(
                    height: 160,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          Row(
            children: [
              GestureDetector(
                onTap: onLike,
                child: Row(
                  children: [
                    Icon(
                      entry.isLikedByMe
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 16,
                      color: entry.isLikedByMe
                          ? primaryColor
                          : const Color(0xFF7A7A8E),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.likes}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: entry.isLikedByMe
                            ? primaryColor
                            : const Color(0xFF7A7A8E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 15,
                    color: Color(0xFF7A7A8E),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.repliesCount}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7A7A8E),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(String rawDate) {
    final date = DateTime.tryParse(rawDate);
    if (date == null) return rawDate;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateUtilsX.formatShortDate(date);
  }
}
