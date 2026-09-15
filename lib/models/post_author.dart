import 'user.dart';

/// Autor de una publicación/comentario (serialización del backend).
class PostAuthor {
  const PostAuthor({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.usernameColor,
    this.avatarFrame,
    this.level = 1,
    this.isOnline = false,
    this.showOnline = true,
    this.gender,
    this.showGender = true,
    this.isFollowing = false,
    this.isVerified = false,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? usernameColor;
  final String? avatarFrame;
  final int level;
  final bool isOnline;
  final bool showOnline;
  final String? gender;
  final bool showGender;
  final bool isFollowing;
  final bool isVerified;

  String get handle => '@$username';

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    return PostAuthor(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName:
          (json['displayName'] as String?) ??
          (json['username'] as String?) ??
          '',
      avatarUrl: json['avatarUrl'] as String?,
      usernameColor: json['usernameColor'] as String?,
      avatarFrame: json['avatarFrame'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      isOnline: json['isOnline'] as bool? ?? false,
      showOnline: json['showOnline'] as bool? ?? true,
      gender: json['gender'] as String?,
      showGender: json['showGender'] as bool? ?? true,
      isFollowing: json['isFollowing'] as bool? ?? false,
      isVerified:
          (json['isVerified'] as bool?) ??
          (json['emailVerifiedAt'] != null),
    );
  }

  User toUser() => User(
    id: id,
    username: username,
    displayName: displayName,
    avatarUrl: avatarUrl,
    usernameColor: usernameColor,
    avatarFrame: avatarFrame,
    level: level,
    isOnline: isOnline,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (usernameColor != null) 'usernameColor': usernameColor,
    if (avatarFrame != null) 'avatarFrame': avatarFrame,
    'level': level,
    'isOnline': isOnline,
    'showOnline': showOnline,
    'gender': gender,
    'showGender': showGender,
    'isFollowing': isFollowing,
  };
}
