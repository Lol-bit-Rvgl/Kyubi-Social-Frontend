// ignore_for_file: invalid_annotation_target

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/network/json_converters.dart';
import '../core/widgets/liquid_glass_container.dart';
import 'community_title.dart';
import 'media.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// Usuario serializado por el backend (`serializeUser` / `serializeMe`).
@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String username,
    required String displayName,
    String? email,
    String? avatarUrl,
    String? bannerUrl,
    String? bio,
    String? usernameColor,
    String? avatarFrame,
    @Default(1) int level,
    @Default(false) bool isOnline,
    String? gender,
    @Default(true) bool showGender,
    @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)
    DateTime? emailVerifiedAt,
    @Default(false) bool onboardingCompleted,
    @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)
    DateTime? createdAt,
    @Default(false) bool isFollowing,
    @Default(0) int followersCount,
    @Default(0) int followingCount,
    @Default(false) bool hasPaymentPassword,
    @Default(<String>[]) List<String> stickers,
    @Default(<String>[]) List<String> interests,

    /// Títulos comunitarios asignados por los administradores del círculo.
    @JsonKey(
      fromJson: communityTitleListFromJson,
      toJson: communityTitleListToJson,
    )
    @Default(<CommunityTitle>[])
    List<CommunityTitle> titles,
    Map<String, dynamic>? socialLinks,
    String? voiceBioUrl,
    Map<String, dynamic>? availability,
    @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? avatar,
    @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? banner,
    Map<String, dynamic>? extensions,
  }) = _User;

  const User._();

  bool get isVerified => emailVerifiedAt != null;
  String get handle => '@$username';

  /// Color temático configurado por el usuario (hexadecimal).
  String? get themeColor =>
      (extensions?['themeColor'] as String?) ?? usernameColor;

  /// Color de nombre o perfil configurado por el usuario (hexadecimal).
  String? get nameColor =>
      (extensions?['nameColor'] as String?) ?? usernameColor;

  /// Number of profile views, stored in extensions by the backend.
  int get profileViews {
    final raw = extensions?['profileViews'];
    return raw is num ? raw.toInt() : 0;
  }

  /// Insignias reales otorgadas (IDs). Empty si el backend no las reporta
  /// (extra via `extensions` para no romper el esquema freezed).
  List<String> get badges {
    final raw = extensions?['badges'];
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  /// Marca VIP real reportada por el backend. Hasta que el backend la envie,
  /// las insignias/chips VIP se muestran bloqueadas/ocultas.
  bool get isVip => extensions?['isVip'] == true;

  /// Ultima conexion reportada por el backend (null si se desconoce).
  DateTime? get lastSeenAt {
    final raw = extensions?['lastSeenAt'];
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  /// URL efectiva del avatar: usa `avatarUrl` si existe, si no
  /// recurre al campo anidado `avatar.url` (Media).  Así se cubre el
  /// caso en que el backend solo devuelve la URL dentro del objeto Media.
  String? get effectiveAvatarUrl => avatarUrl ?? avatar?.url;

  /// URL efectiva del banner: idéntica lógica que [effectiveAvatarUrl].
  String? get effectiveBannerUrl => bannerUrl ?? banner?.url;

  /// Configuración visual de estilo Liquid Glass y colores del usuario.
  UserThemeSettings get themeSettings {
    final raw = extensions?['themeSettings'];
    if (raw is Map<String, dynamic>) {
      return UserThemeSettings.fromJson(raw);
    }
    if (themeColor != null && themeColor!.isNotEmpty) {
      return UserThemeSettings(
        primaryColor: themeColor!,
        accentColor: null,
      );
    }
    return const UserThemeSettings();
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final extensionsMap = Map<String, dynamic>.from(
      (json['extensions'] as Map<String, dynamic>?) ?? {},
    );
    if (json['themeSettings'] != null && json['themeSettings'] is Map) {
      extensionsMap['themeSettings'] =
          Map<String, dynamic>.from(json['themeSettings'] as Map);
    }
    return _$UserFromJson(<String, dynamic>{
      ...json,
      'id': json['id'] ?? '',
      'username': json['username'] ?? '',
      'displayName':
          (json['displayName'] as String?) ??
          (json['username'] as String?) ??
          '',
      if (extensionsMap.isNotEmpty) 'extensions': extensionsMap,
    });
  }
}

Color _parseHexColor(String hex, {required Color fallback}) {
  final clean = hex.replaceAll('#', '').trim();
  if (clean.length == 6) {
    final val = int.tryParse(clean, radix: 16);
    if (val != null) return Color(0xFF000000 | val);
  }
  return fallback;
}

/// Deriva de forma armónica un color secundario rotando el matiz (hue) ~30° a partir del primario.
Color deriveHarmonicSecondary(Color primary) {
  final hsv = HSVColor.fromColor(primary);
  final newHue = (hsv.hue + 30.0) % 360.0;
  return hsv.withHue(newHue).toColor();
}

/// Configuración visual de colores y estilo Liquid Glass inspirada en Discord Nitro.
class UserThemeSettings {
  final String primaryColor;
  final String? accentColor;
  final GlassStyle glassStyle;

  const UserThemeSettings({
    this.primaryColor = '#BA68C8',
    this.accentColor = '#00E676',
    this.glassStyle = GlassStyle.frosted,
  });

  /// Indica si el usuario especificó un color de acento explícito.
  bool get hasExplicitAccent {
    final hex = accentColor;
    return hex != null && hex.trim().isNotEmpty;
  }

  factory UserThemeSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserThemeSettings();
    final primary = (json['primaryColor'] as String?) ?? '#BA68C8';
    final hasAccent =
        json.containsKey('accentColor') && json['accentColor'] != null;
    final accent = hasAccent ? (json['accentColor'] as String) : null;
    return UserThemeSettings(
      primaryColor: primary,
      accentColor: accent,
      glassStyle: GlassStyle.fromString(json['glassStyle'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'primaryColor': primaryColor,
    'accentColor': accentColor ?? '#00E676',
    'glassStyle': glassStyle.toValue(),
  };

  Color get primary =>
      _parseHexColor(primaryColor, fallback: const Color(0xFFBA68C8));

  Color get accent {
    final hex = accentColor;
    if (hex != null && hex.trim().isNotEmpty) {
      return _parseHexColor(
        hex,
        fallback: deriveHarmonicSecondary(primary),
      );
    }
    return deriveHarmonicSecondary(primary);
  }

  LinearGradient get borderGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primary.withValues(alpha: 0.55),
      primary.withValues(alpha: 0.25),
      accent.withValues(alpha: 0.40),
    ],
    stops: const [0.0, 0.65, 1.0],
  );
}

/// Elemento de seguidores / seguidos.
class FollowItem {
  const FollowItem({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.usernameColor,
    this.avatarFrame,
    this.level = 1,
    this.isOnline = false,
    this.isFollowing = false,
    this.pendingFollow = false,
    this.followedAt,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? usernameColor;
  final String? avatarFrame;
  final int level;
  final bool isOnline;
  final bool isFollowing;
  final bool pendingFollow;
  final String? followedAt;

  factory FollowItem.fromJson(Map<String, dynamic> json) {
    return FollowItem(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      usernameColor: json['usernameColor'] as String?,
      avatarFrame: json['avatarFrame'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      isOnline: json['isOnline'] as bool? ?? false,
      isFollowing: json['isFollowing'] as bool? ?? false,
      pendingFollow: json['pendingFollow'] as bool? ?? false,
      followedAt: json['followedAt'] as String?,
    );
  }

  User toUser() => User(
    id: id,
    username: username,
    displayName: displayName,
    avatarUrl: avatarUrl,
    bio: bio,
    usernameColor: usernameColor,
    avatarFrame: avatarFrame,
    level: level,
    isOnline: isOnline,
    isFollowing: isFollowing,
  );
}

/// Resultado paginado de listas de seguidores/seguidos.
class FollowListResult {
  const FollowListResult({required this.items, this.nextCursor});

  final List<FollowItem> items;
  final String? nextCursor;
}

/// Resultado de una acción de follow/unfollow (follow con aprobación).
class FollowActionResult {
  const FollowActionResult({
    required this.isFollowing,
    required this.isPending,
    this.followersCount,
  });

  final bool isFollowing;
  final bool isPending;
  final int? followersCount;

  factory FollowActionResult.fromJson(Map<String, dynamic> json) =>
      FollowActionResult(
        isFollowing: json['isFollowing'] as bool? ?? false,
        isPending: json['pendingFollow'] as bool? ?? false,
        followersCount: (json['followersCount'] as num?)?.toInt(),
      );
}

/// Solicitud de seguimiento entrante (tab Invites).
class FollowRequestItem {
  const FollowRequestItem({
    required this.id,
    required this.requester,
    this.createdAt,
    this.timeAgo,
  });

  final String id;
  final User requester;
  final String? createdAt;
  final String? timeAgo;

  factory FollowRequestItem.fromJson(Map<String, dynamic> json) =>
      FollowRequestItem(
        id: json['id'] as String? ?? '',
        requester: User.fromJson(
          (json['requester'] as Map<String, dynamic>?) ?? {},
        ),
        createdAt: json['createdAt'] as String?,
        timeAgo: json['timeAgo'] as String?,
      );
}

/// Visitante de un perfil.
class VisitItem {
  const VisitItem({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.usernameColor,
    this.avatarFrame,
    this.level = 1,
    this.isOnline = false,
    this.visitedAt,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? usernameColor;
  final String? avatarFrame;
  final int level;
  final bool isOnline;
  final String? visitedAt;

  factory VisitItem.fromJson(Map<String, dynamic> json) {
    return VisitItem(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      usernameColor: json['usernameColor'] as String?,
      avatarFrame: json['avatarFrame'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      isOnline: json['isOnline'] as bool? ?? false,
      visitedAt: json['visitedAt'] as String?,
    );
  }
}
