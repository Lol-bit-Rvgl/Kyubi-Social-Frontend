import 'package:freezed_annotation/freezed_annotation.dart';

import '../../models/community_title.dart';
import '../../models/media.dart';

/// Convierte fechas en múltiples formatos de forma robusta.
///
/// Acepta ISO-8601 (con/sin fracciones y zona horaria), milisegundos Unix,
/// segundos Unix y objetos [DateTime] ya construidos. Para valores no válidos
/// o nulos devuelve un fallback seguro en lugar de lanzar.
class DateTimeConverter implements JsonConverter<DateTime, Object?> {
  const DateTimeConverter();

  @override
  DateTime fromJson(Object? json) =>
      _parseDateTime(json) ?? DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Object? toJson(DateTime date) => date.toUtc().toIso8601String();
}

/// Variante que tolera nulos (devuelve `null` si el valor no es una fecha).
class NullableDateTimeConverter implements JsonConverter<DateTime?, Object?> {
  const NullableDateTimeConverter();

  @override
  DateTime? fromJson(Object? json) => _parseDateTime(json);

  @override
  Object? toJson(DateTime? date) => date?.toUtc().toIso8601String();
}

DateTime? _parseDateTime(Object? json) {
  if (json == null) return null;
  if (json is DateTime) return json;
  if (json is int) return DateTime.fromMillisecondsSinceEpoch(json);
  if (json is num) return DateTime.fromMillisecondsSinceEpoch(json.toInt());
  if (json is String) {
    final value = json.trim();
    if (value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
    // Segundos Unix (10 dígitos) o milisegundos (13 dígitos).
    final digits = int.tryParse(value);
    if (digits != null) {
      if (digits.abs() < 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(digits * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(digits);
    }
  }
  return null;
}

/// Helpers top-level para usar directamente en `@JsonKey(fromJson/toJson)`.
DateTime dateFromJson(Object? json) => const DateTimeConverter().fromJson(json);

Object? dateToJson(DateTime date) => const DateTimeConverter().toJson(date);

DateTime? nullableDateFromJson(Object? json) =>
    const NullableDateTimeConverter().fromJson(json);

Object? nullableDateToJson(DateTime? date) =>
    const NullableDateTimeConverter().toJson(date);

// ---------------------------------------------------------------------------
// Media
// ---------------------------------------------------------------------------

/// Deserializa un adjunto que puede venir como String (solo URL), como Map
/// completo o como JSON codificado en string. Devuelve `null` si no es válido.
Media? mediaFromJson(dynamic json) {
  if (json == null) return null;
  if (json is String) {
    final trimmed = json.trim();
    return trimmed.isEmpty ? null : Media(url: trimmed);
  }
  if (json is Map) {
    try {
      final map = Map<String, dynamic>.from(json);
      if (map['url'] == null && map['src'] != null) {
        map['url'] = map['src'];
      }
      final url = map['url']?.toString();
      if (url == null || url.isEmpty) return null;
      return Media.fromJson(map);
    } catch (_) {
      final url = json['url']?.toString();
      return url == null || url.isEmpty ? null : Media(url: url);
    }
  }
  return null;
}

Object? mediaToJson(Media? media) => media?.toJson();

/// Deserializa una lista de adjuntos tolerando elementos no válidos.
List<Media> mediaListFromJson(dynamic json) {
  if (json is! List) return const [];
  return json.map(mediaFromJson).whereType<Media>().toList(growable: false);
}

Object? mediaListToJson(List<Media>? list) =>
    list?.map((media) => media.toJson()).toList(growable: false);

// ---------------------------------------------------------------------------
// Community titles
// ---------------------------------------------------------------------------

/// Deserializa una lista de títulos comunitarios tolerando elementos inválidos.
List<CommunityTitle> communityTitleListFromJson(dynamic json) {
  if (json is! List) return const [];
  return json
      .whereType<Map>()
      .map((e) => CommunityTitle.fromJson(Map<String, dynamic>.from(e)))
      .toList(growable: false);
}

Object? communityTitleListToJson(List<CommunityTitle>? list) =>
    list?.map((t) => t.toJson()).toList(growable: false);
