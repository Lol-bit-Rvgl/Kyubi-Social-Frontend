import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/animated_sticker.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/fullscreen_image_viewer.dart';
import '../../../../core/widgets/kyubi_rich_text.dart';
import '../../../../core/widgets/sticker_catalog.dart';
import '../../../../models/media.dart';
import '../../../feed/presentation/widgets/interactive_poll_card.dart';
import '../../../salas/presentation/widgets/voice_note_bubble.dart';

/// Valida si el texto de un mensaje con imagen es simplemente la etiqueta
/// de reserva (" [Imagen adjunta] ") y debe ser suprimido.
bool isRedundantImageText(String text) {
  final t = text.trim();
  return t.isEmpty ||
      t == '[Imagen adjunta]' ||
      t == '📷 [Imagen adjunta]' ||
      t == '📷 Imagen adjunta' ||
      t == 'Imagen adjunta' ||
      t == '[Contenido multimedia]' ||
      t == '📷 [Contenido multimedia]';
}

/// Burbuja de chat moderna y multifuncional con soporte para:
/// 1. Ocultamiento de texto redundante "[Imagen adjunta]".
/// 2. Stickers animados flotantes sin contenedor opaco ni texto ✨.
/// 3. Encuestas interactivas con `InteractivePollCard`.
/// 4. Notas de voz con reproductor gráfico y temporizador.
/// 5. Tiradas de Dados y Morra con contenedor y borde dorado brillante (#FFD700).
class DirectChatMessageBubble extends StatelessWidget {
  const DirectChatMessageBubble({
    super.key,
    required this.body,
    required this.timestamp,
    required this.isMine,
    this.senderName = '',
    this.avatarUrl,
    this.avatarName = '',
    this.media,
    this.mediaUrl,
    this.mediaType,
    this.type,
    this.extensions,
    this.isDeleted = false,
    this.deletedLabel = 'Mensaje eliminado',
    this.isEdited = false,
    this.editedAt,
    this.isSending = false,
    this.accentColor,
    this.roleLabel,
    this.roleColor,
    this.replyToId,
    this.replyToName,
    this.replyToBody,
    this.replyToMediaUrl,
    this.onReplyTap,
    this.onAvatarTap,
    this.onPollVote,
    this.currentUserId,
  });

  final String body;
  final String timestamp;
  final bool isMine;
  final String senderName; // Opcional: vacio en chats 1:1, se muestra solo si no es vacio.
  final String? avatarUrl;
  final String avatarName;
  final Media? media;
  final String? mediaUrl;
  final String? mediaType;
  final String? type;
  final Map<String, dynamic>? extensions;
  final bool isDeleted;
  final String deletedLabel;
  final bool isEdited;
  final String? editedAt;
  final bool isSending;

  bool get _effectiveSending =>
      isSending ||
      (extensions?['status'] == 'sending') ||
      (extensions?['tempId'] != null && extensions?['status'] != 'sent');

  final Color? accentColor;
  final String? roleLabel;
  final Color? roleColor;
  final String? replyToId;
  final String? replyToName;
  final String? replyToBody;
  final String? replyToMediaUrl;
  final VoidCallback? onReplyTap;
  final VoidCallback? onAvatarTap;
  final void Function(String optionId)? onPollVote;
  final String? currentUserId;

  // ── Detecciones de tipo especial ──────────────────────────────────────────

  bool get _isSticker {
    if (type?.toUpperCase() == 'STICKER') return true;
    if (mediaType?.toLowerCase() == 'sticker') return true;
    if (extensions?['stickerId'] != null) return true;
    if (extensions?['isAnimated'] == true) return true;
    final t = body.trim();
    if (t.startsWith('✨') &&
        stickerCatalog.any((s) => t == '✨ ${s.name}' || t == s.emoji)) {
      return true;
    }
    if (t.startsWith(':') &&
        t.endsWith(':') &&
        stickerCatalog.any((s) => t == ':${s.name}:')) {
      return true;
    }
    return false;
  }

  bool get _isDiceOrMorra {
    if (mediaType == 'dice' || extensions?['dice'] != null) return true;
    final lower = body.toLowerCase();
    return lower.contains('ha lanzado') &&
        (lower.contains('d') || lower.contains('morra'));
  }

  bool get _isPoll {
    if (type?.toUpperCase() == 'POLL' || mediaType == 'poll') return true;
    if (extensions?['poll'] != null) return true;
    return body.trim().startsWith('📊 Encuesta:');
  }

  bool get _isVoiceNote {
    final t = type?.toUpperCase();
    if (t == 'VOICE' ||
        t == 'VOICE_NOTE' ||
        t == 'AUDIO' ||
        mediaType == 'audio' ||
        mediaType == 'voice') {
      return true;
    }
    if (extensions?['voice'] == true || extensions?['audioUrl'] != null) {
      return true;
    }
    final cleanBody = body.trim();
    if (cleanBody.startsWith('🎤 [Nota de voz') ||
        cleanBody.startsWith('🎤') ||
        cleanBody.contains('[Nota de voz')) {
      return true;
    }
    final effectiveUrl =
        (media?.url ?? mediaUrl ?? '').toLowerCase().split('?').first;
    if (effectiveUrl.endsWith('.m4a') ||
        effectiveUrl.endsWith('.mp3') ||
        effectiveUrl.endsWith('.aac') ||
        effectiveUrl.endsWith('.wav') ||
        effectiveUrl.endsWith('.ogg') ||
        effectiveUrl.contains('/audio/')) {
      return true;
    }
    return false;
  }

  static bool isLikelyImageUrl(String s) {
    if (s.isEmpty) return false;
    final clean = s.toLowerCase().split('?').first.trim();
    return clean.endsWith('.png') ||
        clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.webp') ||
        clean.endsWith('.gif') ||
        clean.contains('/images/') ||
        clean.contains('/media/') ||
        clean.contains('supabase.co/storage/v1/object/public/');
  }

  bool get _hasImage {
    final url = media?.url ?? mediaUrl;
    if (url == null || url.isEmpty) {
      return body.startsWith('http') && isLikelyImageUrl(body);
    }
    final mType = media?.type ?? MediaType.fromValue(mediaType);
    return mType == MediaType.image || isLikelyImageUrl(url);
  }

  bool get _hasReplyPreview {
    final rName =
        replyToName ?? extensions?['replyTo']?['senderName'] as String?;
    final rBody = replyToBody ?? extensions?['replyTo']?['body'] as String?;
    final rMedia =
        replyToMediaUrl ?? extensions?['replyTo']?['mediaUrl'] as String?;
    return (rName?.isNotEmpty ?? false) ||
        (rBody?.isNotEmpty ?? false) ||
        (rMedia?.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = GestureDetector(
      onTap: onAvatarTap,
      child: AppAvatar(
        name: avatarName.isEmpty ? senderName : avatarName,
        imageUrl: avatarUrl,
        radius: 17,
      ),
    );

    // 1. Sticker animado: Flotante, sin fondo de burbuja ni texto ✨
    if (_isSticker && !isDeleted) {
      return _wrapAlignment(
        context,
        avatar: avatar,
        child: _buildStickerContent(context),
      );
    }

    // 2. Tirada de dados o morra: Contenedor dorado brillante
    if (_isDiceOrMorra && !isDeleted) {
      return _wrapAlignment(
        context,
        avatar: avatar,
        child: _buildDiceOrMorraCard(context),
      );
    }

    // 3. Encuesta interactiva
    if (_isPoll && !isDeleted) {
      return _wrapAlignment(
        context,
        avatar: avatar,
        child: _buildPollCard(context),
      );
    }

    // 4. Nota de voz con reproductor
    if (_isVoiceNote && !isDeleted) {
      return _wrapAlignment(
        context,
        avatar: avatar,
        child: _buildVoiceNoteCard(context),
      );
    }

    // 5. Burbuja estándar / imagen
    return _wrapAlignment(
      context,
      avatar: avatar,
      child: _buildStandardBubble(context),
    );
  }

  Widget _wrapAlignment(
    BuildContext context, {
    required Widget avatar,
    required Widget child,
  }) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine) ...[avatar, const SizedBox(width: 8)],
            Flexible(child: child),
            if (isMine) ...[const SizedBox(width: 8), avatar],
          ],
        ),
      ),
    );
  }

  // ── Renderizadores Especiales ─────────────────────────────────────────────

  Widget _buildStickerContent(BuildContext context) {
    String? assetPath = extensions?['assetPath'] as String?;
    String? emoji = extensions?['emoji'] as String?;
    final stickerId = extensions?['stickerId'] as String?;

    if (stickerId != null) {
      final item = stickerById(stickerId);
      if (item != null) {
        assetPath ??= item.assetPath;
        emoji ??= item.emoji;
      }
    }

    if (assetPath == null) {
      final url = mediaUrl;
      if (url != null) {
        final cleanUrl = url.toLowerCase().split('?').first;
        if (cleanUrl.endsWith('.json') ||
            cleanUrl.endsWith('.webp') ||
            cleanUrl.endsWith('.png') ||
            cleanUrl.endsWith('.gif') ||
            cleanUrl.contains('/stickers/')) {
          assetPath = url;
        }
      }
    }

    if (assetPath == null) {
      for (final s in stickerCatalog) {
        if (body.contains(s.name) ||
            body.contains(s.emoji) ||
            body == ':${s.name}:' ||
            (mediaUrl != null && mediaUrl!.contains(s.id))) {
          assetPath = s.assetPath;
          emoji ??= s.emoji;
          break;
        }
      }
    }

    final resolvedAsset = assetPath ?? 'assets/stickers/sparkle.json';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        AnimatedSticker(
          assetPath: resolvedAsset,
          emoji: emoji ?? '✨',
          width: 120,
          height: 120,
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            timestamp,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiceOrMorraCard(BuildContext context) {
    final isMorra = body.toLowerCase().contains('morra');
    final title = isMorra ? 'JUEGO DE MORRA' : 'TIRADA DE DADOS';
    final defaultIcon = isMorra ? '✋' : '🎲';

    final diceExt = extensions?['dice'] as Map<String, dynamic>?;
    final emoji = diceExt?['emoji'] as String? ?? defaultIcon;
    final diceName = diceExt?['name'] as String? ?? (isMorra ? 'Morra' : 'Dado');
    final result = diceExt?['result'] as String? ?? '';

    String displayText = body;
    if (result.isNotEmpty) {
      displayText = 'Ha lanzado $diceName: $result';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2206).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 0.5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFFD700),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              timestamp,
              style: TextStyle(
                fontSize: 9.5,
                color: const Color(0xFFFFD700).withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollCard(BuildContext context) {
    String question = 'Encuesta';
    List<PollOptionData> options = [];

    final pollExt = extensions?['poll'] as Map<String, dynamic>?;
    if (pollExt != null) {
      question = pollExt['question'] as String? ?? question;
      final rawOptions = pollExt['options'] as List<dynamic>? ?? [];
      options = rawOptions.map((o) {
        if (o is Map<String, dynamic>) {
          return PollOptionData(
            id: o['id'] as String? ?? '',
            text: o['text'] as String? ?? '',
            votes: (o['votes'] as num?)?.toInt() ?? 0,
          );
        }
        return PollOptionData(id: o.toString(), text: o.toString(), votes: 0);
      }).toList();
    } else {
      final lines = body.split('\n');
      if (lines.isNotEmpty) {
        question = lines.first.replaceFirst('📊 Encuesta:', '').trim();
      }
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          final optText = line.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim();
          if (optText.isNotEmpty) {
            options.add(PollOptionData(id: 'opt_$i', text: optText, votes: 0));
          }
        }
      }
    }

    if (options.isEmpty) {
      options = const [
        PollOptionData(id: 'opt_1', text: 'Sí', votes: 0),
        PollOptionData(id: 'opt_2', text: 'No', votes: 0),
      ];
    }

    final votesMap = (pollExt?['votes'] ?? extensions?['votes']) as Map<String, dynamic>?;
    final userVotedOptionId = currentUserId != null
        ? (votesMap?[currentUserId] as String?)
        : null;

    return Container(
      constraints: const BoxConstraints(maxWidth: 310),
      child: InteractivePollCard(
        question: question,
        options: options,
        totalVotesCount: (pollExt?['totalVotes'] ?? extensions?['totalVotes']) as int?,
        userVotedOptionId: userVotedOptionId,
        onVote: onPollVote,
      ),
    );
  }

  Widget _buildVoiceNoteCard(BuildContext context) {
    final audioUrl = media?.url ??
        mediaUrl ??
        extensions?['audioUrl'] as String? ??
        (body.startsWith('http') ? body.trim() : null);
    if (audioUrl != null &&
        (audioUrl.startsWith('http://') || audioUrl.startsWith('https://'))) {
      return VoiceNoteBubble(
        url: audioUrl,
        senderName: isMine ? 'Tú' : senderName,
        sendTime: timestamp,
      );
    }

    return _InlineVoiceNotePlayer(
      body: body,
      timestamp: timestamp,
      isMine: isMine,
    );
  }

  Widget _buildStandardBubble(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final imageWidget = _buildImage(context);
    final isRedundant = _hasImage && isRedundantImageText(body);

    final accent = accentColor ??
        (isMine ? const Color(0xFF9E8CD9) : AppColors.accentCyan);

    final bubbleColor = isMine
        ? const Color(0xFF231B38)
        : AppColors.surfaceCards;

    final bubbleBorder = isMine
        ? Border.all(
            color: const Color(0xFF9E8CD9).withValues(alpha: 0.35),
            width: 0.9,
          )
        : Border.all(color: const Color(0xFF2A2640), width: 0.9);

    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMine ? 16 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 16),
    );

    return Container(
      constraints: BoxConstraints(maxWidth: screenWidth * 0.78),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: bubbleRadius,
        border: bubbleBorder,
        boxShadow: [
          BoxShadow(
            color: isMine
                ? const Color(0xFF9B6FCB).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Nombre + rol SOLO si hay nombre (en chats 1:1 no hay nombre y la
          // burbuja queda compacta sin filas ni espaciados fantasma).
          if (!isMine && senderName.isNotEmpty) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    senderName,
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
                  _RoleBadge(label: roleLabel!, color: roleColor ?? accent),
                ],
              ],
            ),
            const SizedBox(height: 4),
          ],

          if (isDeleted)
            Text(
              deletedLabel,
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            if (_hasReplyPreview) ...[
              _buildReplyPreviewCard(context),
              const SizedBox(height: 6),
            ],
            if (imageWidget != null) ...[
              imageWidget,
              if (!isRedundant && body.trim().isNotEmpty)
                const SizedBox(height: 6),
            ],
            if (!isRedundant && body.trim().isNotEmpty)
              _buildFormattedText(body, isMine: isMine),
          ],

          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timestamp,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isMine
                      ? const Color(0xFFD4A0B0)
                      : AppColors.textSecondary,
                ),
              ),
              if (isEdited) ...[
                const SizedBox(width: 4),
                Text(
                  _formatEditedTime(editedAt),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontStyle: FontStyle.italic,
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.75)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
              if (isMine) ...[
                const SizedBox(width: 4),
                if (_effectiveSending)
                  const Icon(
                    Icons.access_time_rounded,
                    size: 11,
                    color: Color(0xFFD4A0B0),
                  )
                else
                  const Icon(
                    Icons.done_all_rounded,
                    size: 13,
                    color: Color(0xFF00E5FF),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreviewCard(BuildContext context) {
    final rName =
        replyToName ?? extensions?['replyTo']?['senderName'] as String? ?? 'Mensaje';
    final rBody = replyToBody ?? extensions?['replyTo']?['body'] as String? ?? '';
    final rMedia =
        replyToMediaUrl ?? extensions?['replyTo']?['mediaUrl'] as String?;
    final hasImg = rMedia != null && rMedia.isNotEmpty;

    return GestureDetector(
      onTap: onReplyTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (isMine ? Colors.white : Colors.black).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: accentColor ??
                  (isMine ? const Color(0xFF9E8CD9) : AppColors.accentCyan),
              width: 3.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accentColor ??
                          (isMine
                              ? const Color(0xFFD4A0B0)
                              : AppColors.accentCyan),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    hasImg && rBody.trim().isEmpty
                        ? '📷 [Imagen]'
                        : (rBody.trim().isEmpty ? '...' : rBody),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            if (hasImg) ...[
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: rMedia,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const Icon(
                    Icons.image,
                    size: 20,
                    color: Colors.white54,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _buildImage(BuildContext context) {
    String? url = media?.url ?? mediaUrl;
    if (url == null || url.isEmpty) {
      if (body.startsWith('http') && isLikelyImageUrl(body)) {
        url = body.trim();
      } else {
        return null;
      }
    } else {
      final mType = media?.type ?? MediaType.fromValue(mediaType);
      if (mType != MediaType.image && !isLikelyImageUrl(url)) return null;
    }

    final finalUrl = url;
    return GestureDetector(
      onTap: () => showFullscreenImage(context, finalUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: finalUrl,
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

  Widget _buildFormattedText(String text, {required bool isMine}) {
    if (text.startsWith('**') && text.endsWith('**') && text.length > 4) {
      return Text(
        text.substring(2, text.length - 2),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          height: 1.35,
          color: Colors.white,
        ),
      );
    } else if (text.startsWith('*') && text.endsWith('*') && text.length > 2) {
      return Text(
        text.substring(1, text.length - 1),
        style: const TextStyle(
          fontSize: 13.5,
          fontStyle: FontStyle.italic,
          height: 1.35,
          color: AppColors.accentCyan,
        ),
      );
    }
    return KyubiRichText(
      text: text,
      style: const TextStyle(fontSize: 14, height: 1.35, color: Colors.white),
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
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label, required this.color});

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

/// Reproductor de nota de voz con Play/Pause, forma de onda y duración
class _InlineVoiceNotePlayer extends StatefulWidget {
  const _InlineVoiceNotePlayer({
    required this.body,
    required this.timestamp,
    required this.isMine,
  });

  final String body;
  final String timestamp;
  final bool isMine;

  @override
  State<_InlineVoiceNotePlayer> createState() => _InlineVoiceNotePlayerState();
}

class _InlineVoiceNotePlayerState extends State<_InlineVoiceNotePlayer> {
  bool _isPlaying = false;

  String _parseDuration(String text) {
    final match = RegExp(r'\((\d+)\s*s\)').firstMatch(text);
    if (match != null) {
      final sec = int.tryParse(match.group(1) ?? '0') ?? 0;
      final m = (sec ~/ 60).toString().padLeft(2, '0');
      final s = (sec % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }
    return '00:04';
  }

  @override
  Widget build(BuildContext context) {
    final durationLabel = _parseDuration(widget.body);

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2138),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF9E8CD9).withValues(alpha: 0.35),
          width: 0.9,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isPlaying = !_isPlaying);
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFBA68C8), Color(0xFF7B1FA2)],
                    ),
                  ),
                  child: Icon(
                    _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(14, (i) {
                        final heights = [
                          8.0, 14.0, 20.0, 12.0, 18.0, 24.0, 16.0,
                          22.0, 14.0, 18.0, 12.0, 16.0, 10.0, 6.0,
                        ];
                        final active = _isPlaying && (i < 8);
                        return Container(
                          width: 3.5,
                          height: heights[i % heights.length],
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.accentCyan
                                : const Color(0xFF7A7090),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          durationLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.timestamp,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
