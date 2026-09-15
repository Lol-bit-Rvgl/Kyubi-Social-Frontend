import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/circle.dart';
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
    id: json['id']?.toString() ?? '',
    content: json['content']?.toString() ?? '',
    title: json['title']?.toString(),
    coverImageUrl: json['coverImageUrl']?.toString(),
    authorName: json['authorName']?.toString() ?? 'Anónimo',
    authorUsername: json['authorUsername']?.toString() ?? '',
    authorAvatar: json['authorAvatar']?.toString(),
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
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString(),
    imageUrl: json['imageUrl']?.toString(),
    hostName: json['hostName']?.toString(),
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
    tag: json['tag']?.toString() ?? '',
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
    this.circles = const [],
  });

  static Map<String, dynamic>? _asMap(dynamic item) {
    if (item is Map<String, dynamic>) return item;
    if (item is Map) return Map<String, dynamic>.from(item);
    return null;
  }

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    final postsRaw = json['posts'] as List? ?? [];
    final usersRaw = json['users'] as List? ?? [];
    final roomsRaw = json['rooms'] as List? ?? [];
    final circlesRaw = json['circles'] as List? ?? [];

    final posts = <SearchPost>[];
    for (final p in postsRaw) {
      final map = _asMap(p);
      if (map != null) {
        try {
          posts.add(SearchPost.fromJson(map));
        } catch (_) {}
      }
    }

    final users = <FollowItem>[];
    for (final u in usersRaw) {
      final map = _asMap(u);
      if (map != null) {
        try {
          users.add(
            FollowItem(
              id: map['id']?.toString() ?? '',
              username: map['username']?.toString() ?? '',
              displayName:
                  map['displayName']?.toString() ??
                  map['username']?.toString() ??
                  '',
              avatarUrl: map['avatarUrl']?.toString(),
              bio: map['bio']?.toString(),
              usernameColor: map['usernameColor']?.toString(),
              avatarFrame: map['avatarFrame']?.toString(),
              level: (map['level'] as num?)?.toInt() ?? 1,
              isOnline: map['isOnline'] == true,
              isFollowing: map['isFollowing'] == true,
            ),
          );
        } catch (_) {}
      }
    }

    final rooms = <SearchRoom>[];
    for (final r in roomsRaw) {
      final map = _asMap(r);
      if (map != null) {
        try {
          rooms.add(SearchRoom.fromJson(map));
        } catch (_) {}
      }
    }

    final circles = <Circle>[];
    for (final c in circlesRaw) {
      final map = _asMap(c);
      if (map != null) {
        try {
          circles.add(Circle.fromJson(map));
        } catch (_) {}
      }
    }

    return SearchResults(
      posts: posts,
      users: users,
      rooms: rooms,
      circles: circles,
    );
  }

  final List<SearchPost> posts;
  final List<FollowItem> users;
  final List<SearchRoom> rooms;
  final List<Circle> circles;

  bool get isEmpty =>
      posts.isEmpty && users.isEmpty && rooms.isEmpty && circles.isEmpty;
  int get total => posts.length + users.length + rooms.length + circles.length;
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
