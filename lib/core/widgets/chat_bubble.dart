import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../../models/media.dart';
import 'app_avatar.dart';
import 'fullscreen_image_viewer.dart';
import 'kyubi_rich_text.dart';

/// Burbuja de chat reutilizable (DMs y salas) con avatar del autor, nombre,
/// insignia de rol y estilo translúcido con borde neón sutil.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.displayName,
    required this.body,
    required this.timestamp,
    this.avatarUrl,
    this.avatarName = '',
    this.isMine = false,
    this.roleLabel,
    this.roleColor,
    this.isDeleted = false,
    this.deletedLabel = 'Mensaje eliminado',
    this.isEdited = false,
    this.editedAt,
    this.accentColor,
    this.media,
    this.mediaUrl,
    this.mediaType,
    this.onAvatarTap,
  });

  final String displayName;
  final String body;
  final String timestamp;
  final String? avatarUrl;
  final String avatarName;
  final bool isMine;
  final String? roleLabel;
  final Color? roleColor;
  final bool isDeleted;
  final String deletedLabel;
  final bool isEdited;
  final String? editedAt;

  /// Adjunto del mensaje (imagen) para mostrarla dentro de la burbuja y
  /// abrir el visor a pantalla completa al tocarla.
  final Media? media;
  final String? mediaUrl;
  final String? mediaType;

  /// Callback al tocar el avatar o nombre
  final VoidCallback? onAvatarTap;

  /// Color de acento opcional (Color de Burbuja configurado en el chat).
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = _buildImage(context);
    final accent =
        accentColor ??
        (isMine ? AppColors.accentCrimson : AppColors.accentCyan);
    final bubbleColor = isMine
        ? accent.withValues(alpha: 0.25)
        : AppColors.surfaceGlass;
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(AppDimens.radiusMd),
      topRight: const Radius.circular(AppDimens.radiusMd),
      bottomLeft: Radius.circular(isMine ? AppDimens.radiusMd : 4),
      bottomRight: Radius.circular(isMine ? 4 : AppDimens.radiusMd),
    );

    final content = Flexible(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: bubbleRadius,
          border: Border.all(
            color: accent.withValues(alpha: isMine ? 0.4 : 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    isMine ? 'Tú' : displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
                if (roleLabel != null) ...[
                  const SizedBox(width: 6),
                  _RoleChip(label: roleLabel!, color: roleColor ?? accent),
                ],
              ],
            ),
            const SizedBox(height: 4),
            if (image != null) ...[
              image,
              const SizedBox(height: 6),
            ],
            if (isDeleted)
              Text(
                deletedLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                ),
              )
            else if (body.startsWith('**') &&
                body.endsWith('**') &&
                body.length > 4)
              Text(
                body.substring(2, body.length - 2),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  height: 1.35,
                  color: Colors.white,
                ),
              )
            else if (body.startsWith('*') &&
                body.endsWith('*') &&
                body.length > 2)
              Text(
                body.substring(1, body.length - 1),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                  color: AppColors.accentCyan,
                ),
              )
            else
              KyubiRichText(
                text: body,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: scheme.onSurface,
                ),
              ),
            const SizedBox(height: 4),
            Align(
              alignment:
                  isMine ? Alignment.bottomRight : Alignment.bottomLeft,
              child: Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    timestamp,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.85)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (isEdited)
                    Text(
                      _formatEditedTime(editedAt),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontStyle: FontStyle.italic,
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.75)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final avatar = GestureDetector(
      onTap: onAvatarTap,
      child: AppAvatar(
        name: avatarName.isEmpty ? displayName : avatarName,
        imageUrl: avatarUrl,
        radius: 18,
      ),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[avatar, const SizedBox(width: 8)],
            content,
            if (isMine) ...[const SizedBox(width: 8), avatar],
          ],
        ),
      ),
    );
  }

  static String _formatEditedTime(String? dtString) {
    if (dtString == null || dtString.isEmpty) return '(editado)';
    final dt = DateTime.tryParse(dtString)?.toLocal();
    if (dt == null) return '(editado)';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '(editado $h:$m)';
  }

  /// Renderiza la imagen del mensaje si la hay; al tocarla abre el visor
  /// fullscreen con `BoxFit.contain`.
  Widget? _buildImage(BuildContext context) {
    final url = media?.url ?? mediaUrl;
    if (url == null || url.isEmpty) return null;
    final type = media?.type ?? MediaType.fromValue(mediaType);
    if (type != MediaType.image) return null;
    return GestureDetector(
      onTap: () => showFullscreenImage(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 200,
          height: 220,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            width: 200,
            height: 220,
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (_, _, _) => Container(
            width: 200,
            height: 220,
            color: Colors.black26,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
