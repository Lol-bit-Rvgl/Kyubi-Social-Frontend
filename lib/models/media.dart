// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'media.freezed.dart';
part 'media.g.dart';

/// Tipo de contenido de un [Media].
enum MediaType {
  image,
  video,
  audio,
  file;

  static MediaType fromValue(String? value) {
    if (value == null) return MediaType.file;
    final normalized = value.toLowerCase();
    if (normalized.contains('image') || normalized == 'img') {
      return MediaType.image;
    }
    if (normalized.contains('video') || normalized.contains('gif')) {
      return MediaType.video;
    }
    if (normalized.contains('audio')) return MediaType.audio;
    return MediaType.file;
  }
}

/// Recurso de medios reutilizable (avatares, portadas, adjuntos, audio).
///
/// - `url`: localización pública del recurso.
/// - `width`/`height`: dimensiones en píxeles (opcionales).
/// - `duration`: duración en segundos para audio/video (opcional).
/// - `blurhash`: placeholder de imagen (opcional).
/// - `extensions`: metadatos futuros sin romper el esquema.
@freezed
abstract class Media with _$Media {
  const factory Media({
    required String url,
    int? width,
    int? height,
    int? duration,
    String? blurhash,
    @Default(MediaType.image)
    @JsonKey(unknownEnumValue: MediaType.file)
    MediaType type,
    Map<String, dynamic>? extensions,
  }) = _Media;

  factory Media.fromJson(Map<String, dynamic> json) => _$MediaFromJson(json);
}
