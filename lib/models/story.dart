/// Historia efímera devuelta por `serializeStory` del backend.
class Story {
  const Story({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    this.createdAt,
    this.expiresAt,
    required this.seen,
    required this.author,
  });

  final String id;
  final String mediaUrl;
  final String mediaType; // IMAGE | VIDEO
  final String? caption;
  final String? createdAt;
  final String? expiresAt;
  final bool seen;
  final StoryAuthor author;

  bool get isVideo => mediaType.toUpperCase() == 'VIDEO';

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'] as String? ?? '',
      mediaUrl: json['mediaUrl'] as String? ?? '',
      mediaType: json['mediaType'] as String? ?? 'IMAGE',
      caption: json['caption'] as String?,
      createdAt: json['createdAt'] as String?,
      expiresAt: json['expiresAt'] as String?,
      seen: json['seen'] as bool? ?? false,
      author: StoryAuthor.fromJson(
        json['author'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

/// Autor embebido en la serialización de una historia.
class StoryAuthor {
  const StoryAuthor({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory StoryAuthor.fromJson(Map<String, dynamic> json) {
    return StoryAuthor(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

/// Grupo de historias de un mismo autor, tal como lo devuelve
/// `GET /stories/feed` (clave `groups`).
class StoryGroup {
  const StoryGroup({
    required this.author,
    required this.stories,
    required this.hasUnseen,
  });

  final StoryAuthor author;
  final List<Story> stories;
  final bool hasUnseen;

  factory StoryGroup.fromJson(Map<String, dynamic> json) {
    final rawStories = json['stories'];
    return StoryGroup(
      author: StoryAuthor.fromJson(
        json['author'] as Map<String, dynamic>? ?? const {},
      ),
      stories: rawStories is List
          ? rawStories
                .whereType<Map<String, dynamic>>()
                .map(Story.fromJson)
                .toList()
          : const [],
      hasUnseen: json['hasUnseen'] as bool? ?? false,
    );
  }
}
