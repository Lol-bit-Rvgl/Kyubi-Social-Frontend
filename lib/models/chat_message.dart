// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/network/json_converters.dart';
import 'media.dart';

part 'chat_message.freezed.dart';
part 'chat_message.g.dart';

/// Mensaje de una conversación (`serializeMessage` del backend).
@freezed
abstract class Message with _$Message {
  const factory Message({
    required String id,
    required String conversationId,
    required String senderId,
    required ChatAuthor sender,
    required String body,
    @JsonKey(fromJson: dateFromJson, toJson: dateToJson)
    required DateTime createdAt,
    String? mediaUrl,
    String? mediaType,
    @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? media,
    String? replyToId,
    String? editedAt,
    String? deletedAt,
    Map<String, dynamic>? extensions,
  }) = _Message;

  const Message._();

  bool get isDeleted => deletedAt != null && deletedAt!.isNotEmpty;
  bool get isEdited => editedAt != null;
  String get status =>
      (extensions?['status'] as String?) ??
      (id.startsWith('temp-') || id.startsWith('local-') ? 'sending' : 'sent');
  bool get isSending => status == 'sending';

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(<String, dynamic>{
        ...json,
        'id': json['id'] ?? '',
        'conversationId': json['conversationId'] ?? '',
        'senderId': json['senderId'] ?? '',
        'sender': json['sender'] ?? <String, dynamic>{},
        'body': json['body'] ?? '',
      });
}

/// Autor de un mensaje (subconjunto de `serializeAuthor`).
class ChatAuthor {
  const ChatAuthor({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.usernameColor,
    this.level = 1,
    this.isOnline = false,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? usernameColor;
  final int level;
  final bool isOnline;

  factory ChatAuthor.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ChatAuthor(id: '', username: '', displayName: '');
    }
    return ChatAuthor(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName:
          json['displayName'] as String? ?? json['username'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      usernameColor: json['usernameColor'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (usernameColor != null) 'usernameColor': usernameColor,
      'level': level,
      'isOnline': isOnline,
    };
  }

  ChatAuthor copyWith({bool? isOnline}) {
    return ChatAuthor(
      id: id,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      usernameColor: usernameColor,
      level: level,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
