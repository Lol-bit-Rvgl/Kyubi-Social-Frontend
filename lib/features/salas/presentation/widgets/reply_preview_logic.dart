/// Lógica pura (sin dependencias de Flutter) para la previsualización de citas.
///
/// Separada para poder ejecutar unit tests con `dart test` sin arrancar el
/// framework de Flutter y evitar problemas de memoria (OOM) del harness de
/// `flutter test`.
class ReplyPreview {
  const ReplyPreview({required this.text, this.thumbnailUrl});

  final String text;
  final String? thumbnailUrl;
}

bool _isRawUrl(String value) {
  final v = value.toLowerCase();
  return v.startsWith('http://') || v.startsWith('https://');
}

bool _looksLikeImageUrl(String url) {
  final clean = url.toLowerCase().split('?').first.trim();
  return clean.endsWith('.png') ||
      clean.endsWith('.jpg') ||
      clean.endsWith('.jpeg') ||
      clean.endsWith('.webp') ||
      clean.endsWith('.gif') ||
      clean.contains('/images/') ||
      clean.contains('/media/') ||
      clean.contains('supabase.co/storage/v1/object/');
}

bool _looksLikeAudioUrl(String url) {
  final clean = url.toLowerCase().split('?').first.trim();
  return clean.endsWith('.mp3') ||
      clean.endsWith('.m4a') ||
      clean.endsWith('.aac') ||
      clean.endsWith('.wav') ||
      clean.endsWith('.ogg') ||
      clean.endsWith('.oga') ||
      clean.endsWith('.opus') ||
      clean.contains('/audio/');
}

/// Resuelve la previsualización de una cita.
///
/// Reglas:
/// * Nota de voz → `🎤 Nota de voz` (jamás la URL de audio).
/// * Imagen (por tipo, por `mediaUrl` o porque el cuerpo es una URL cruda,
///   caso de los mensajes legados) → `📷 Foto` o el pie de foto si existe,
///   más la URL para la miniatura.
/// * Texto normal → tal cual; vacío → `[Contenido multimedia]`.
ReplyPreview resolveReplyPreview({
  String? body,
  String? mediaUrl,
  String? messageType,
}) {
  final rawBody = (body ?? '').trim();
  final rawMedia = (mediaUrl ?? '').trim();
  final type = (messageType ?? '').trim().toLowerCase();

  final bodyIsUrl = _isRawUrl(rawBody);
  final mediaIsUrl = _isRawUrl(rawMedia);
  final audioLike =
      type == 'voice' ||
      type == 'audio' ||
      type == 'voice_note' ||
      (bodyIsUrl && _looksLikeAudioUrl(rawBody)) ||
      (mediaIsUrl && _looksLikeAudioUrl(rawMedia)) ||
      rawBody.startsWith('🎤') ||
      rawBody.contains('[Nota de voz');
  if (audioLike) {
    return const ReplyPreview(text: '🎤 Nota de voz');
  }

  final imageLike =
      type == 'image' ||
      (mediaIsUrl && _looksLikeImageUrl(rawMedia)) ||
      (bodyIsUrl && _looksLikeImageUrl(rawBody));
  final thumbnailUrl = rawMedia.isNotEmpty
      ? rawMedia
      : (bodyIsUrl ? rawBody : null);

  if (imageLike || thumbnailUrl != null) {
    final caption = (rawBody.isNotEmpty && !bodyIsUrl) ? rawBody : '';
    return ReplyPreview(
      text: caption.isNotEmpty ? caption : '📷 Foto',
      thumbnailUrl: thumbnailUrl,
    );
  }

  return ReplyPreview(
    text: rawBody.isNotEmpty ? rawBody : '[Contenido multimedia]',
  );
}
