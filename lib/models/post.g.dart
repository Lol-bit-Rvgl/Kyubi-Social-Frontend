// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Post _$PostFromJson(Map<String, dynamic> json) => _Post(
  id: json['id'] as String,
  type: json['type'] as String,
  title: json['title'] as String,
  body: json['body'] as String,
  author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
  reactions: ReactionCounts.fromJson(
    json['reactions'] as Map<String, dynamic>?,
  ),
  stats: PostStats.fromJson(json['stats'] as Map<String, dynamic>?),
  isLiked: json['isLiked'] as bool,
  visibility: json['visibility'] as String? ?? 'PUBLIC',
  myReaction: json['myReaction'] as String?,
  coverImageUrl: json['coverImageUrl'] as String?,
  bgImageUrl: json['bgImageUrl'] as String?,
  bgOverlay: (json['bgOverlay'] as num?)?.toDouble() ?? 0.55,
  bgBlur: json['bgBlur'] as bool? ?? false,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  genres:
      (json['genres'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  mediaUrls:
      (json['mediaUrls'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  media: json['media'] == null
      ? const <Media>[]
      : mediaListFromJson(json['media']),
  cover: mediaFromJson(json['cover']),
  audioUrl: json['audioUrl'] as String?,
  chapterMode: json['chapterMode'] as bool? ?? false,
  chapterNumber: (json['chapterNumber'] as num?)?.toInt(),
  warnings: json['warnings'] == null
      ? null
      : PostWarnings.fromJson(json['warnings'] as Map<String, dynamic>?),
  isEdited: json['isEdited'] as bool? ?? false,
  createdAt: nullableDateFromJson(json['createdAt']),
  updatedAt: nullableDateFromJson(json['updatedAt']),
  publishedAt: nullableDateFromJson(json['publishedAt']),
  themeBgColor: json['themeBgColor'] as String?,
  themeAccent: json['themeAccent'] as String?,
  fontFamily: json['fontFamily'] as String?,
  timeAgo: json['timeAgo'] as String,
  extensions: json['extensions'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$PostToJson(_Post instance) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'title': instance.title,
  'body': instance.body,
  'author': instance.author,
  'reactions': instance.reactions,
  'stats': instance.stats,
  'isLiked': instance.isLiked,
  'visibility': instance.visibility,
  'myReaction': instance.myReaction,
  'coverImageUrl': instance.coverImageUrl,
  'bgImageUrl': instance.bgImageUrl,
  'bgOverlay': instance.bgOverlay,
  'bgBlur': instance.bgBlur,
  'tags': instance.tags,
  'genres': instance.genres,
  'mediaUrls': instance.mediaUrls,
  'media': mediaListToJson(instance.media),
  'cover': mediaToJson(instance.cover),
  'audioUrl': instance.audioUrl,
  'chapterMode': instance.chapterMode,
  'chapterNumber': instance.chapterNumber,
  'warnings': instance.warnings,
  'isEdited': instance.isEdited,
  'createdAt': nullableDateToJson(instance.createdAt),
  'updatedAt': nullableDateToJson(instance.updatedAt),
  'publishedAt': nullableDateToJson(instance.publishedAt),
  'themeBgColor': instance.themeBgColor,
  'themeAccent': instance.themeAccent,
  'fontFamily': instance.fontFamily,
  'timeAgo': instance.timeAgo,
  'extensions': instance.extensions,
};
