import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/user.dart';

/// Resultado de búsqueda de publicación (full-text).
class SearchPost {
  const SearchPost({
    required this.id,
    required this.content,
    this.title,
    this.coverImageUrl,
    required this.authorName,
    required this.authorUsername,
    this.authorAvatar,
    this.tags = const [],
  });

  factory SearchPost.fromJson(Map<String, dynamic> json) => SearchPost(
    id: json['id'] as String? ?? '',
    content: json['content'] as String? ?? '',
    title: json['title'] as String?,
    coverImageUrl: json['coverImageUrl'] as String?,
    authorName: (json['authorName'] as String?) ?? 'Anónimo',
    authorUsername: json['authorUsername'] as String? ?? '',
    authorAvatar: json['authorAvatar'] as String?,
    tags:
        (json['tags'] as List?)
            ?.whereType<Object>()
            .map((t) => t.toString())
            .toList() ??
        const [],
  );

  final String id;
  final String content;
  final String? title;
  final String? coverImageUrl;
  final String authorName;
  final String authorUsername;
  final String? authorAvatar;
  final List<String> tags;
}

/// Resultado de búsqueda de sala/room.
class SearchRoom {
  const SearchRoom({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.hostName,
    this.participantCount = 0,
  });

  factory SearchRoom.fromJson(Map<String, dynamic> json) => SearchRoom(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    imageUrl: json['imageUrl'] as String?,
    hostName: json['hostName'] as String?,
    participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? hostName;
  final int participantCount;
}

/// Tendencia (tag) activa en las últimas 48 horas.
class TrendingTag {
  const TrendingTag({required this.tag, required this.uses});

  factory TrendingTag.fromJson(Map<String, dynamic> json) => TrendingTag(
    tag: json['tag'] as String? ?? '',
    uses: (json['uses'] as num?)?.toInt() ?? 0,
  );

  final String tag;
  final int uses;
}

/// Resultado agregado de GET /search.
class SearchResults {
  const SearchResults({
    this.posts = const [],
    this.users = const [],
    this.rooms = const [],
  });

  factory SearchResults.fromJson(Map<String, dynamic> json) => SearchResults(
    posts: (json['posts'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SearchPost.fromJson)
        .toList(),
    users: (json['users'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(
          (u) => FollowItem(
            id: u['id'] as String? ?? '',
            username: u['username'] as String? ?? '',
            displayName:
                (u['displayName'] as String?) ?? u['username'] as String? ?? '',
            avatarUrl: u['avatarUrl'] as String?,
            bio: u['bio'] as String?,
            usernameColor: u['usernameColor'] as String?,
            avatarFrame: u['avatarFrame'] as String?,
            level: (u['level'] as num?)?.toInt() ?? 1,
            isOnline: u['isOnline'] as bool? ?? false,
            isFollowing: u['isFollowing'] as bool? ?? false,
          ),
        )
        .toList(),
    rooms: (json['rooms'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SearchRoom.fromJson)
        .toList(),
  );

  final List<SearchPost> posts;
  final List<FollowItem> users;
  final List<SearchRoom> rooms;

  bool get isEmpty => posts.isEmpty && users.isEmpty && rooms.isEmpty;
  int get total => posts.length + users.length + rooms.length;
}

/// Cliente del motor de búsqueda full-text (GET /search y /search/trending).
class SearchRepository {
  SearchRepository(this._api);

  final ApiClient _api;

  Future<SearchResults> search(
    String query, {
    String type = 'all',
    int limit = 20,
    int offset = 0,
  }) async {
    final json = await _api.getJson(
      AppConfig.searchBase,
      query: {'q': query, 'type': type, 'limit': limit, 'offset': offset},
    );
    return SearchResults.fromJson(json);
  }

  Future<List<TrendingTag>> trending({int limit = 15}) async {
    final json = await _api.getJson(
      AppConfig.searchTrending,
      query: {'limit': limit},
    );
    final raw = json['data'] ?? json['trends'] ?? json['trending'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(TrendingTag.fromJson)
        .toList();
  }
}
