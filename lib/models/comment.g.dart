// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Comment _$CommentFromJson(Map<String, dynamic> json) => _Comment(
  id: json['id'] as String,
  postId: json['postId'] as String,
  body: json['body'] as String,
  author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
  mediaUrl: json['mediaUrl'] as String?,
  mediaType: json['mediaType'] as String?,
  media: mediaFromJson(json['media']),
  likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
  isLiked: json['isLiked'] as bool? ?? false,
  myReaction: json['myReaction'] as String?,
  isAuthor: json['isAuthor'] as bool? ?? false,
  replies:
      (json['replies'] as List<dynamic>?)
          ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Comment>[],
  parentId: json['parentId'] as String?,
  isEdited: json['isEdited'] as bool? ?? false,
  timeAgo: json['timeAgo'] as String,
  createdAt: dateFromJson(json['createdAt']),
  extensions: json['extensions'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$CommentToJson(_Comment instance) => <String, dynamic>{
  'id': instance.id,
  'postId': instance.postId,
  'body': instance.body,
  'author': instance.author,
  'mediaUrl': instance.mediaUrl,
  'mediaType': instance.mediaType,
  'media': mediaToJson(instance.media),
  'likeCount': instance.likeCount,
  'isLiked': instance.isLiked,
  'myReaction': instance.myReaction,
  'isAuthor': instance.isAuthor,
  'replies': instance.replies,
  'parentId': instance.parentId,
  'isEdited': instance.isEdited,
  'timeAgo': instance.timeAgo,
  'createdAt': dateToJson(instance.createdAt),
  'extensions': instance.extensions,
};
