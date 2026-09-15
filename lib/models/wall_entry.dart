/// Entrada del muro de perfil (`wallEntryToJson` del backend).
class WallEntry {
  const WallEntry({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.authorEmoji,
    required this.isAuthor,
    required this.text,
    required this.createdAt,
    this.imageUrl,
    this.parentId,
    this.replyToUsername,
    this.likes = 0,
    this.isLikedByMe = false,
    this.myReaction,
    this.repliesCount = 0,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String authorEmoji;
  final bool isAuthor;
  final String text;
  final String? imageUrl;
  final String? parentId;
  final String? replyToUsername;
  final int likes;
  final bool isLikedByMe;
  final String? myReaction;
  final int repliesCount;
  final String createdAt;

  factory WallEntry.fromJson(Map<String, dynamic> json) {
    return WallEntry(
      id: json['id'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      authorEmoji: json['authorEmoji'] as String? ?? '',
      isAuthor: json['isAuthor'] as bool? ?? false,
      text: json['text'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      parentId: json['parentId'] as String?,
      replyToUsername: json['replyToUsername'] as String?,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      isLikedByMe: json['isLikedByMe'] as bool? ?? false,
      myReaction: json['myReaction'] as String?,
      repliesCount: (json['repliesCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

/// Respuesta paginada del muro.
class WallPage {
  const WallPage({
    required this.entries,
    this.total = 0,
    this.pages = 1,
    this.page = 1,
  });

  final List<WallEntry> entries;
  final int total;
  final int pages;
  final int page;

  factory WallPage.fromJson(Map<String, dynamic> json) {
    final raw = json['data'];
    return WallPage(
      entries: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(WallEntry.fromJson)
                .toList()
          : const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
      page: (json['page'] as num?)?.toInt() ?? 1,
    );
  }
}
