// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Media _$MediaFromJson(Map<String, dynamic> json) => _Media(
  url: json['url'] as String,
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
  duration: (json['duration'] as num?)?.toInt(),
  blurhash: json['blurhash'] as String?,
  type:
      $enumDecodeNullable(
        _$MediaTypeEnumMap,
        json['type'],
        unknownValue: MediaType.file,
      ) ??
      MediaType.image,
  extensions: json['extensions'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$MediaToJson(_Media instance) => <String, dynamic>{
  'url': instance.url,
  'width': instance.width,
  'height': instance.height,
  'duration': instance.duration,
  'blurhash': instance.blurhash,
  'type': _$MediaTypeEnumMap[instance.type]!,
  'extensions': instance.extensions,
};

const _$MediaTypeEnumMap = {
  MediaType.image: 'image',
  MediaType.video: 'video',
  MediaType.audio: 'audio',
  MediaType.file: 'file',
};
