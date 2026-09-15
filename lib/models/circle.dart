import 'paginated_response.dart';
import 'post.dart';
import 'post_author.dart';

/// Rol de un miembro dentro de un círculo (`CircleRole` del backend).
enum CircleRole {
  owner,
  admin,
  member,
  unknown;

  static CircleRole fromJson(String? value) {
    switch (value) {
      case 'OWNER':
        return CircleRole.owner;
      case 'ADMIN':
        return CircleRole.admin;
      case 'MEMBER':
        return CircleRole.member;
      default:
        return CircleRole.unknown;
    }
  }
}

/// Miembro de un círculo (`serializeCircleMember` del backend).
class CircleMember {
  const CircleMember({
    required this.user,
    required this.role,
    required this.joinedAt,
  });

  final PostAuthor user;
  final CircleRole role;
  final String joinedAt;

  factory CircleMember.fromJson(Map<String, dynamic> json) {
    return CircleMember(
      user: PostAuthor.fromJson(json),
      role: CircleRole.fromJson(json['role'] as String?),
      joinedAt: json['joinedAt'] as String? ?? '',
    );
  }
}

/// Círculo de intereses (`serializeCircle` del backend).
class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.creator,
    this.description,
    this.avatarUrl,
    this.bannerUrl,
    this.isPrivate = false,
    this.isCreator = false,
    this.isMember = false,
    this.role = CircleRole.unknown,
    this.memberCount = 0,
    this.postCount = 0,
    this.roomCount = 0,
    this.tags = const [],
    this.createdAt,
    this.members = const [],
  });

  final String id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String? bannerUrl;
  final bool isPrivate;
  final PostAuthor creator;
  final bool isCreator;
  final bool isMember;
  final CircleRole role;
  final int memberCount;
  final int postCount;
  final int roomCount;
  final List<String> tags;
  final String? createdAt;
  final List<CircleMember> members;

  factory Circle.fromJson(Map<String, dynamic> json) {
    return Circle(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      isPrivate: json['isPrivate'] as bool? ?? false,
      creator: PostAuthor.fromJson(
        json['creator'] as Map<String, dynamic>? ?? const {},
      ),
      isCreator: json['isCreator'] as bool? ?? false,
      isMember: json['isMember'] as bool? ?? false,
      role: CircleRole.fromJson(json['role'] as String?),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      postCount: (json['postCount'] as num?)?.toInt() ?? 0,
      roomCount: (json['roomCount'] as num?)?.toInt() ?? 0,
      tags: _strings(json['tags']),
      createdAt: json['createdAt'] as String?,
      members: _members(json['members']),
    );
  }

  static List<CircleMember> _members(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(CircleMember.fromJson)
        .toList();
  }

  static List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }

  Circle copyWith({
    bool? isMember,
    CircleRole? role,
    int? memberCount,
    int? postCount,
    int? roomCount,
    List<String>? tags,
    List<CircleMember>? members,
  }) {
    return Circle(
      id: id,
      name: name,
      description: description,
      avatarUrl: avatarUrl,
      bannerUrl: bannerUrl,
      isPrivate: isPrivate,
      creator: creator,
      isCreator: isCreator,
      isMember: isMember ?? this.isMember,
      role: role ?? this.role,
      memberCount: memberCount ?? this.memberCount,
      postCount: postCount ?? this.postCount,
      roomCount: roomCount ?? this.roomCount,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      members: members ?? this.members,
    );
  }
}

/// Posts de un círculo paginados por cursor (`GET /circles/:id/posts`).
class CirclePostsPage {
  const CirclePostsPage({required this.posts, this.nextCursor, this.total = 0});

  final List<Post> posts;
  final String? nextCursor;
  final int total;

  factory CirclePostsPage.fromJson(Map<String, dynamic> json) {
    final page = PaginatedResponse<Post>.fromJson(
      json,
      Post.fromJson,
      itemKey: 'data',
    );
    return CirclePostsPage(
      posts: page.items,
      nextCursor: page.nextPageToken,
      total: page.total,
    );
  }
}
