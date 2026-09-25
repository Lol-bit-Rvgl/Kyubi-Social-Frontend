import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/fullscreen_image_viewer.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/chat_animated_media.dart';
import '../../../../core/widgets/hexagon_avatar.dart';
import '../../../../features/feed/presentation/widgets/interactive_poll_card.dart';
import '../../../../models/role_character.dart';
import 'reply_preview.dart';
import 'voice_note_bubble.dart';

/// Burbuja de mensaje de chat con soporte completo de identidad de Rol / Personaje OC
/// y apertura fluida de Bottom Sheet de usuario (Ref: Imagen 1, 2, 3, 4, 5).
class RoleChatBubble extends StatelessWidget {
  const RoleChatBubble({
    super.key,
    required this.body,
    required this.senderName,
    this.userName,
    this.role,
    this.userAvatarUrl,
    this.adminBadge,
    this.isMine = false,
    this.timestamp,
    this.isDiceRoll = false,
    this.diceResult,
    this.diceEmoji,
    this.accentColor,
    this.isSticker = false,
    this.stickerAsset,
    this.stickerEmoji,
    this.replyToId,
    this.replyToName,
    this.replyToBody,
    this.replyToMediaUrl,
    this.replyToType,
    this.onReplyTap,
    this.isEdited = false,
    this.editedAt,
    this.onUserTap,
    this.messageType = 'message',
    this.contentUrl,
    this.metadata,
    this.onPollVote,
    this.isHighlighted = false,
  });

  final String body;
  final String senderName;

  /// @username real del autor: se muestra junto a la píldora del rol cuando
  /// el mensaje fue enviado con una identidad de rol activa.
  final String? userName;
  final RoleCharacter? role;
  final String? userAvatarUrl;
  final String? adminBadge; // 'Admin', 'Co-Admin', null
  final bool isMine;
  final String? timestamp;
  final bool isDiceRoll;
  final String? diceResult;
  final String? diceEmoji;

  /// Color de burbuja configurado por el usuario para este chat (opcional).
  final Color? accentColor;

  /// Cuando true, el cuerpo es un sticker animado (Lottie/WebP) en lugar de texto.
  final bool isSticker;
  final String? stickerAsset;
  final String? stickerEmoji;

  /// Callback de voto de encuesta: el consumidor (sala) actualiza la
  /// metadata persistida para que la tarjeta re-renderice userVotedOptionId.
  final void Function(String optionId)? onPollVote;

  /// Resaltado temporal (1s) de la burbuja destino al saltar al mensaje citado.
  final bool isHighlighted;

  /// Respuesta / Mensaje citado opcional (Ref: Imagen 1)
  final String? replyToId;
  final String? replyToName;
  final String? replyToBody;

  /// URL del medio citado (imagen): permite la miniatura limpia de la cita
  /// sin exponer la URL cruda de Supabase como texto.
  final String? replyToMediaUrl;

  /// Tipo wire del mensaje citado (`image`, `voice`, …).
  final String? replyToType;
  final VoidCallback? onReplyTap;

  /// Estado de edición
  final bool isEdited;
  final String? editedAt;

  /// Callback al tocar el avatar o nombre del autor para abrir la info rápida
  final VoidCallback? onUserTap;

  /// Tipo del contenido (wire del backend): `message` (TEXT), `voice`,
  /// `image` o `poll`. Determina el render condicional del cuerpo.
  final String messageType;

  /// URL de audio/imagen para mensajes `VOICE`/`IMAGE`.
  final String? contentUrl;

  /// Metadatos del mensaje (p. ej. `{question, options}` para encuestas).
  final Map<String, dynamic>? metadata;

  /// Color real del rol: 1) `metadata['roleColor']`/`roleColorHex` del mensaje,
  /// 2) `role.color` (parseado de su HEX), 3) color derivado del hash del
  /// nombre del rol (consistente entre renders). Nunca fuerza cian genérico
  /// excepto como último fallback vía [accentColor].
  Color _resolveRoleColor() {
    final r = role;
    if (r != null) {
      final fromMsg = _parseHexColor(
        metadata?['roleColorHex'] ?? metadata?['roleColor'],
      );
      if (fromMsg != null) return fromMsg;
      final parsed = _parseHexColor(r.colorHex);
      if (parsed != null) return parsed;
      return _colorFromHash(r.name);
    }
    return accentColor ?? AppColors.accentCyan;
  }

  static Color? _parseHexColor(Object? raw) {
    if (raw is! String) return null;
    var hex = raw.trim().replaceAll('#', '');
    if (hex.isEmpty) return null;
    try {
      if (hex.length == 6) return Color(int.parse('0xFF$hex'));
      if (hex.length == 8) return Color(int.parse('0x$hex'));
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Color HSL derivado del nombre del rol: misma entrada → mismo color.
  static Color _colorFromHash(String name) {
    var hash = 0;
    for (final code in name.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.65, 0.55).toColor();
  }

  /// Color de texto que contrasta sobre fondos de chip (luminancia).
  static Color _contrastOn(Color bg) {
    return bg.computeLuminance() > 0.45 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _resolveRoleColor();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar Hexagonal del Rol / Usuario con Halo al tocar ──
          GestureDetector(
            onTap: onUserTap,
            child: role != null
                ? HexagonAvatar(
                    size: 42,
                    imageUrl: role!.avatarUrl ?? userAvatarUrl,
                    borderColor: roleColor,
                    borderWidth: 1.8,
                  )
                : Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: roleColor.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      color: const Color(0xFF1E1A2E),
                      boxShadow: [
                        BoxShadow(
                          color: roleColor.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: userAvatarUrl != null && userAvatarUrl!.isNotEmpty
                          ? Image.network(
                              userAvatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person_rounded,
                                size: 20,
                                color: Colors.white70,
                              ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              size: 20,
                              color: Colors.white70,
                            ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),

          // ── Contenido: Header de Rol/Usuario + Burbuja ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: [ Píldora del Rol ] + Nombre de usuario real + Badges
                GestureDetector(
                  onTap: onUserTap,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (role != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: roleColor.withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            role!.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: _contrastOn(roleColor),
                            ),
                          ),
                        ),
                      if (role != null)
                        Text(
                          '@${userName != null && userName!.isNotEmpty ? userName : senderName}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        )
                      else
                        Text(
                          senderName,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (adminBadge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: adminBadge == 'Admin'
                                ? const Color(
                                    0xFF00E676,
                                  ).withValues(alpha: 0.15)
                                : const Color(
                                    0xFF00E5FF,
                                  ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: adminBadge == 'Admin'
                                  ? AppColors.accentTeal
                                  : const Color(0xFF00E5FF),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            adminBadge!,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: adminBadge == 'Admin'
                                  ? AppColors.accentTeal
                                  : const Color(0xFF00E5FF),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),

                // ── Cuerpo de la Burbuja (condicional por tipo) + timestamp
                // pegado a su esquina inferior derecha: la columna se ajusta
                // al ancho de la burbuja, así el timestamp no "flota" a la
                // derecha de la fila sino pegado al borde del contenido.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isMine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    _buildBubbleContent(context),
                    // Las notas de voz ya muestran la hora dentro de la propia
                    // burbuja (fila inferior spaceBetween) → se suprime aquí
                    // para no duplicar números.
                    if (timestamp != null &&
                        messageType.toUpperCase() != 'VOICE')
                      Padding(
                        padding: EdgeInsets.only(
                          top: 2,
                          left: isMine ? 0 : 3,
                          right: isMine ? 3 : 0,
                        ),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            Text(
                              timestamp!,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                            if (isEdited)
                              Text(
                                _formatEditedTime(editedAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                          ],
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

  /// Selecciona el contenido según el tipo de mensaje:
  /// TEXT (mensaje), VOICE (audio), IMAGE (imagen), POLL (encuesta) o DICE/RPS;
  /// conservando los comportamientos previos de dados y stickers.
  Widget _buildBubbleContent(BuildContext context) {
    final type = messageType.toUpperCase();
    if (isDiceRoll || type == 'DICE' || type == 'RPS') {
      return _buildDiceRollCard();
    }
    if (isSticker) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ChatBubbleAnimatedMedia(
          assetPath: stickerAsset ?? '',
          emoji: stickerEmoji,
          width: 140,
          height: 140,
        ),
      );
    }

    final isVoice = type == 'VOICE' ||
        type == 'AUDIO' ||
        type == 'VOICE_NOTE' ||
        (contentUrl != null &&
            (contentUrl!.endsWith('.m4a') ||
                contentUrl!.endsWith('.mp3') ||
                contentUrl!.endsWith('.aac') ||
                contentUrl!.contains('/audio/'))) ||
        body.startsWith('🎤');
    if (isVoice) return _buildVoiceCard();

    final isImage = type == 'IMAGE' ||
        (contentUrl != null &&
            (contentUrl!.endsWith('.jpg') ||
                contentUrl!.endsWith('.jpeg') ||
                contentUrl!.endsWith('.png') ||
                contentUrl!.endsWith('.webp') ||
                contentUrl!.endsWith('.gif') ||
                contentUrl!.contains('/images/')));
    if (isImage) return _buildImageCard(context);
    if (type == 'POLL') {
      final poll = _buildPollCard();
      if (poll != null) return poll;
    }

    return _buildTextBubble();
  }

  Widget _buildTextBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // Fondo estándar de chat: siempre oscuro uniforme (nunca el color del
        // rol). El acento del rol vive SOLO en el chip/tag del nombre.
        color: const Color(0xFF161324),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(
          color: isHighlighted
              ? AppColors.accentCyan.withValues(alpha: 0.9)
              : (accentColor ?? const Color(0xFF2C2642)),
          width: isHighlighted ? 1.6 : 0.9,
        ),
        boxShadow: [
          // Destello temporal cuando la burbuja es el destino del scroll.
          if (isHighlighted)
            BoxShadow(
              color: AppColors.accentCyan.withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: 1.5,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Builder(
        builder: (context) {
          // El acento del rol solo se permite en detalles pequeños internos
          // (cita), nunca en el fondo/borde principal de la burbuja.
          final roleColor = _resolveRoleColor();
          final replyPreview = resolveReplyPreview(
            body: replyToBody,
            mediaUrl: replyToMediaUrl,
            messageType: replyToType,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cita / Reply contextual (Ref: Imagen 1)
              if ((replyToBody?.isNotEmpty ?? false) ||
                  (replyToMediaUrl?.isNotEmpty ?? false)) ...[
                GestureDetector(
                  onTap: onReplyTap,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: roleColor, width: 3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (replyPreview.thumbnailUrl != null) ...[
                          buildReplyThumbnail(
                            replyPreview.thumbnailUrl!,
                            size: 32,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (replyToName != null)
                                Text(
                                  replyToName!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: roleColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Text(
                                replyPreview.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFD0D0E0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              _buildFormattedText(body),
            ],
          );
        },
      ),
    );
  }

  /// Reproductor de voz integrado (barra de progreso, play/pause y duración)
  /// usando la URL de audio guardada en el mensaje.
  Widget _buildVoiceCard() {
    final metaUrl = metadata?['mediaUrl'] as String? ??
        metadata?['audioUrl'] as String? ??
        metadata?['contentUrl'] as String?;
    final url = contentUrl != null && contentUrl!.isNotEmpty
        ? contentUrl!
        : (metaUrl != null && metaUrl.isNotEmpty
            ? metaUrl
            : (body.startsWith('http') ? body : ''));
    if (url.isEmpty) {
      return Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF161324),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2C2642), width: 0.9),
        ),
        child: const Row(
          children: [
            Icon(Icons.mic_off_rounded, color: Colors.white38, size: 18),
            SizedBox(width: 8),
            Text(
              'Audio no disponible',
              style: TextStyle(color: Color(0xFF7A7A8A), fontSize: 12),
            ),
          ],
        ),
      );
    }
    // Nota de voz compacta: play/pausa + progreso + duración total arriba;
    // fila inferior [remitente · duración · hora] con espacio delimitado.
    // Solo se invoca desde la rama VOICE de _buildBubbleContent.
    return VoiceNoteBubble(
      url: url,
      senderName: senderName,
      sendTime: timestamp,
    );
  }

  /// Vista previa de imagen con `CachedNetworkImage`; al tocarla abre la
  /// imagen en pantalla completa con zoom (PhotoView).
  Widget _buildImageCard(BuildContext context) {
    final url = contentUrl != null && contentUrl!.isNotEmpty
        ? contentUrl!
        : (metadata?['mediaUrl'] as String? ??
              (metadata?['imageUrl'] as String? ??
                  (body.startsWith('http') ? body : '')));
    return GestureDetector(
      onTap: () => _openFullscreenImage(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 220,
          height: 180,
          color: const Color(0xFF161324),
          child: url.isEmpty
              ? const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white38,
                    size: 28,
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white24,
                      size: 28,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  void _openFullscreenImage(BuildContext context, String url) {
    if (url.isEmpty) return;
    HapticFeedback.lightImpact();
    showFullscreenImage(context, url);
  }

  /// Encuesta interactiva con opciones y porcentajes, construida a partir de
  /// `metadata` (`{question, options: [{id, text, votes}]}`). Devuelve null
  /// si no hay datos de encuesta válidos para renderizar.
  InteractivePollCard? _buildPollCard() {
    final data = metadata;
    if (data == null) return null;
    final rawOptions = data['options'];
    if (rawOptions is! List || rawOptions.isEmpty) return null;

    final options = <PollOptionData>[
      for (final o in rawOptions)
        if (o is Map<String, dynamic>)
          PollOptionData(
            id: o['id'] as String? ?? o['text'] as String? ?? '',
            text: o['text'] as String? ?? '',
            votes: (o['votes'] as num?)?.toInt() ?? 0,
          )
        else
          PollOptionData(id: o.toString(), text: o.toString()),
    ];
    if (options.isEmpty) return null;

    return InteractivePollCard(
      question: data['question'] as String? ?? body,
      options: options,
      userVotedOptionId:
          (data['userVotedOptionId'] as String?)?.isNotEmpty == true
          ? data['userVotedOptionId'] as String
          : null,
      totalVotesCount: (data['totalVotes'] as num?)?.toInt(),
      onVote: onPollVote,
    );
  }

  Widget _buildDiceRollCard() {
    final effectiveEmoji =
        diceEmoji ??
        metadata?['diceEmoji'] as String? ??
        (body.toLowerCase().contains('morra') ? '✊' : '🎲');
    final effectiveResult =
        diceResult ??
        metadata?['diceResult'] as String? ??
        metadata?['result'] as String? ??
        '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1730),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB300), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(effectiveEmoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                body,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD0D0E0),
                ),
              ),
              Text(
                'Resultado: $effectiveResult',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Renderiza el texto enriquecido del turno. Soporta:
  /// - `**negrita**`, `*cursiva/acción*`, `«diálogo»`
  /// - Encabezados de línea `#` (T³) y `##` (T²)
  /// - Marcadores de alineación `[left]` `[center]` `[right]` `[justify]`
  Widget _buildFormattedText(String text) {
    // ── Alineación global del bloque según marcador de primera línea ──
    final alignRe = RegExp(r'^\[(left|center|right|justify)\]\s*');
    final alignMatch = alignRe.firstMatch(text);
    TextAlign textAlign = TextAlign.start;
    if (alignMatch != null) {
      switch (alignMatch[1]) {
        case 'center':
          textAlign = TextAlign.center;
        case 'right':
          textAlign = TextAlign.right;
        case 'justify':
          textAlign = TextAlign.justify;
      }
      text = text.substring(alignMatch[0]!.length);
    }

    final spans = <TextSpan>[];
    final pattern = RegExp(
      r'(^|\n)(#{1,6})\s+([^\n]*)|(\*\*[^*]+\*\*)|(\*[^*]+\*)|(«[^»]*»)|(==[^=]+==)|(\{color:#[0-9a-fA-F]{6}\}[^{]*\{/color\})',
      multiLine: true,
    );

    var lastMatchEnd = 0;

    void addPlain(String s) {
      if (s.isEmpty) return;
      spans.add(
        TextSpan(
          text: s,
          style: TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
        ),
      );
    }

    for (final match in pattern.allMatches(text)) {
      final start = match.start;
      if (start > lastMatchEnd) {
        addPlain(text.substring(lastMatchEnd, start));
      }
      lastMatchEnd = match.end;

      // Encabezado de línea (# Título / ## Subtítulo)
      final isHeading = match.group(3) != null;
      final headingLevel = match.group(2) != null ? match.group(2)!.length : 0;
      if (isHeading) {
        final leading = match.group(1)!;
        final content = match.group(3)!;
        if (leading == '\n') {
          spans.add(const TextSpan(text: '\n'));
        }
        spans.add(
          TextSpan(
            text: content,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontSize: headingLevel >= 2 ? 20 : 16,
              height: 1.3,
            ),
          ),
        );
        continue;
      }

      final bold = match.group(4);
      final italic = match.group(5);
      final dialog = match.group(6);
      final highlight = match.group(7);
      final colored = match.group(8);
      if (bold != null) {
        final content = bold.substring(2, bold.length - 2);
        spans.add(
          TextSpan(
            text: content,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        );
      } else if (italic != null) {
        final content = italic.substring(1, italic.length - 1);
        spans.add(
          TextSpan(
            text: content,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              color: AppColors.accentCyan,
              fontSize: 13.5,
            ),
          ),
        );
      } else if (dialog != null) {
        final content = dialog.substring(1, dialog.length - 1);
        spans.add(
          TextSpan(
            text: content,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: AppColors.accentTeal,
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
            ),
          ),
        );
      } else if (highlight != null) {
        final content = highlight.substring(2, highlight.length - 2);
        spans.add(
          TextSpan(
            text: content,
            style: TextStyle(
              backgroundColor: const Color(0xFFFFD600).withValues(alpha: 0.28),
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        );
      } else if (colored != null) {
        final closeIdx = colored.indexOf('}');
        final content = colored.substring(
          closeIdx + 1,
          colored.length - '{/color}'.length,
        );
        Color color;
        try {
          color = Color(
            0xFF000000 |
                int.parse(
                  colored.substring(7, closeIdx).replaceFirst('#', ''),
                  radix: 16,
                ),
          );
        } catch (_) {
          color = Colors.white;
        }
        spans.add(
          TextSpan(
            text: content,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        );
      }
    }

    if (lastMatchEnd < text.length) {
      addPlain(text.substring(lastMatchEnd));
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: textAlign,
    );
  }

  static String _formatEditedTime(String? editedAt) {
    if (editedAt == null || editedAt.isEmpty) return '(editado)';
    final dt = DateTime.tryParse(editedAt)?.toLocal();
    if (dt == null) return '(editado)';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '(editado $h:$m)';
  }
}
