// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Message _$MessageFromJson(Map<String, dynamic> json) => _Message(
  id: json['id'] as String,
  conversationId: json['conversationId'] as String,
  senderId: json['senderId'] as String,
  sender: ChatAuthor.fromJson(json['sender'] as Map<String, dynamic>?),
  body: json['body'] as String,
  createdAt: dateFromJson(json['createdAt']),
  mediaUrl: json['mediaUrl'] as String?,
  mediaType: json['mediaType'] as String?,
  media: mediaFromJson(json['media']),
  replyToId: json['replyToId'] as String?,
  editedAt: json['editedAt'] as String?,
  deletedAt: json['deletedAt'] as String?,
  extensions: json['extensions'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
  'id': instance.id,
  'conversationId': instance.conversationId,
  'senderId': instance.senderId,
  'sender': instance.sender,
  'body': instance.body,
  'createdAt': dateToJson(instance.createdAt),
  'mediaUrl': instance.mediaUrl,
  'mediaType': instance.mediaType,
  'media': mediaToJson(instance.media),
  'replyToId': instance.replyToId,
  'editedAt': instance.editedAt,
  'deletedAt': instance.deletedAt,
  'extensions': instance.extensions,
};
