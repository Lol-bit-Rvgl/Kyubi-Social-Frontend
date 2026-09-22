import 'package:test/test.dart';

import 'package:kyubi/features/salas/presentation/widgets/reply_preview_logic.dart';

void main() {
  group('resolveReplyPreview — previsualización limpia de citas', () {
    test('oculta la URL cruda de una imagen y expone la miniatura', () {
      const url =
          'https://xyz.supabase.co/storage/v1/object/public/media/foto.png';
      final preview = resolveReplyPreview(body: url, messageType: 'image');
      expect(preview.text, '📷 Foto');
      expect(preview.thumbnailUrl, url);
      expect(preview.text.contains('http'), isFalse);
    });

    test('soporta tipo desconocido (legacy) con URL pero sin type', () {
      final preview = resolveReplyPreview(
        body: 'https://cdn.test/media/legacy.jpg',
      );
      expect(preview.text, '📷 Foto');
      expect(preview.thumbnailUrl, 'https://cdn.test/media/legacy.jpg');
    });

    test('prioriza mediaUrl sobre un cuerpo que no es URL', () {
      final preview = resolveReplyPreview(
        body: 'Mi dibujo',
        mediaUrl: 'https://cdn.test/img/1.png',
        messageType: 'image',
      );
      expect(preview.text, 'Mi dibujo');
      expect(preview.thumbnailUrl, 'https://cdn.test/img/1.png');
    });

    test('etiqueta notas de voz sin exponer la URL de audio', () {
      final preview = resolveReplyPreview(
        body: 'https://x/media/nota.m4a',
        messageType: 'voice',
      );
      expect(preview.text, '🎤 Nota de voz');
      expect(preview.thumbnailUrl, isNull);
    });

    test('texto plano se conserva tal cual (1:1)', () {
      final preview = resolveReplyPreview(
        body: 'Hola mundo',
        messageType: 'message',
      );
      expect(preview.text, 'Hola mundo');
      expect(preview.thumbnailUrl, isNull);
    });

    test('contenido vacío usa marcador multimedia', () {
      expect(resolveReplyPreview().text, '[Contenido multimedia]');
    });
  });
}
