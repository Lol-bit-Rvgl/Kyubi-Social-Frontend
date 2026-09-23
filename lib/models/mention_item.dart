import 'post_author.dart';

/// Notificación de mención directa en chat o sala (@Mentions).
class MentionItem {
  const MentionItem({
    required this.id,
    required this.type,
    required this.timeAgo,
    required this.createdAt,
    this.actor,
    this.targetType,
    this.targetId,
    this.targetTitle,
    this.targetCoverUrl,
    this.text,
    this.readAt,
  });

  final String id;
  final String type;
  final PostAuthor? actor;
  final String? targetType;
  final String? targetId;
  final String? targetTitle;
  final String? targetCoverUrl;
  final String? text;
  final String? readAt;
  final String timeAgo;
  final String createdAt;

  bool get isRead => readAt != null;
  bool get isRoom => targetType == 'room' || targetType == 'sala';
  bool get isConversation => targetType == 'conversation';
  String? get preview => text;
  String? get actorUsername => actor?.username;
  String? get actorDisplayName => actor?.displayName;

  factory MentionItem.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : null;
    final actorJson = json['actor'] ?? data?['actor'];
    return MentionItem(
      id: json['id'] as String? ?? data?['id'] as String? ?? '',
      type: json['type'] as String? ?? data?['type'] as String? ?? 'MENTION',
      actor: actorJson is Map<String, dynamic>
          ? PostAuthor.fromJson(actorJson)
          : null,
      targetType: json['targetType'] as String? ?? data?['targetType'] as String?,
      targetId: json['targetId'] as String? ?? data?['targetId'] as String?,
      targetTitle: json['targetTitle'] as String? ??
          data?['targetTitle'] as String? ??
          data?['roomName'] as String? ??
          data?['conversationTitle'] as String?,
      targetCoverUrl: json['targetCoverUrl'] as String? ??
          data?['targetCoverUrl'] as String? ??
          data?['roomImage'] as String?,
      text: json['text'] as String? ??
          data?['text'] as String? ??
          data?['preview'] as String?,
      readAt: json['readAt'] as String? ??
          data?['readAt'] as String? ??
          ((json['isRead'] == true || data?['isRead'] == true)
              ? (json['createdAt'] as String? ??
                  DateTime.now().toIso8601String())
              : null),
      timeAgo: json['timeAgo'] as String? ?? data?['timeAgo'] as String? ?? '',
      createdAt: json['createdAt'] as String? ??
          data?['createdAt'] as String? ??
          '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    if (actor != null) 'actor': actor!.toJson(),
    if (targetType != null) 'targetType': targetType,
    if (targetId != null) 'targetId': targetId,
    if (targetTitle != null) 'targetTitle': targetTitle,
    if (targetCoverUrl != null) 'targetCoverUrl': targetCoverUrl,
    if (text != null) 'text': text,
    if (readAt != null) 'readAt': readAt,
    'timeAgo': timeAgo,
    'createdAt': createdAt,
  };

  MentionItem copyWith({
    String? id,
    String? type,
    PostAuthor? actor,
    String? targetType,
    String? targetId,
    String? targetTitle,
    String? targetCoverUrl,
    String? text,
    String? readAt,
    bool? isRead,
    String? timeAgo,
    String? createdAt,
  }) {
    final effectiveReadAt = isRead != null
        ? (isRead ? (readAt ?? DateTime.now().toIso8601String()) : null)
        : (readAt ?? this.readAt);
    return MentionItem(
      id: id ?? this.id,
      type: type ?? this.type,
      actor: actor ?? this.actor,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      targetTitle: targetTitle ?? this.targetTitle,
      targetCoverUrl: targetCoverUrl ?? this.targetCoverUrl,
      text: text ?? this.text,
      readAt: effectiveReadAt,
      timeAgo: timeAgo ?? this.timeAgo,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
