import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'reply_preview_logic.dart' show ReplyPreview, resolveReplyPreview;

/// Previsualización limpia de un mensaje citado (reply).
///
/// Centraliza la regla de UI de las salas: nunca mostrar URLs crudas de
/// almacenamiento (Supabase) en el banner del compositor ni en la cita de la
/// burbuja; en su lugar se muestra `📷 Foto` (o el pie de foto) junto a una
/// miniatura compacta.
///
/// Re-exporta la lógica pura ([resolveReplyPreview], [ReplyPreview]) para
/// que los tests de unidad puedan importar este archivo (o el lógico) sin
/// dependencias de UI.
export 'reply_preview_logic.dart' show ReplyPreview, resolveReplyPreview;

/// Miniatura compacta con esquinas redondeadas (28x28 por defecto) para la
/// previsualización de citas con imagen.
Widget buildReplyThumbnail(String url, {double size = 28}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      width: size,
      height: size,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, _) => const ColoredBox(color: Color(0xFF2A2440)),
        errorWidget: (_, _, _) => const ColoredBox(
          color: Color(0xFF2A2440),
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 16,
            color: Color(0xFF8E889D),
          ),
        ),
      ),
    ),
  );
}
