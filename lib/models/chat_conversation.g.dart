// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_conversation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Conversation _$ConversationFromJson(Map<String, dynamic> json) =>
    _Conversation(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String?,
      createdAt: nullableDateFromJson(json['createdAt']),
      updatedAt: nullableDateFromJson(json['updatedAt']),
      members:
          (json['members'] as List<dynamic>?)
              ?.map((e) => ChatMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ChatMember>[],
      otherMember: json['otherMember'] == null
          ? null
          : ChatAuthor.fromJson(json['otherMember'] as Map<String, dynamic>?),
      isGroup: json['isGroup'] as bool? ?? false,
      lastMessage: json['lastMessage'] == null
          ? null
          : Message.fromJson(json['lastMessage'] as Map<String, dynamic>),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      lastReadMessageId: json['lastReadMessageId'] as String?,
      muted: json['muted'] as bool? ?? false,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ConversationToJson(_Conversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'title': instance.title,
      'createdAt': nullableDateToJson(instance.createdAt),
      'updatedAt': nullableDateToJson(instance.updatedAt),
      'members': instance.members,
      'otherMember': instance.otherMember,
      'isGroup': instance.isGroup,
      'lastMessage': instance.lastMessage,
      'unreadCount': instance.unreadCount,
      'lastReadMessageId': instance.lastReadMessageId,
      'muted': instance.muted,
      'extensions': instance.extensions,
    };
