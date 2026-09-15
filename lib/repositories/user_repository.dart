import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/user.dart';

/// Acceso a usuarios, perfil y relaciones sociales.
class UserRepository {
  UserRepository(this._api);

  final ApiClient _api;

  Future<User> getMe() async {
    final body = await _api.getJson(AppConfig.usersMe);
    return User.fromJson(body);
  }

  /// PATCH /users/me con un mapa exacto de campos (permite limpiar con null).
  Future<User> updateMe(Map<String, dynamic> data) async {
    final body = await _api.patchJson(AppConfig.usersMe, data: data);
    return User.fromJson(body);
  }

  Future<User> getProfile(String usernameOrId) async {
    final body = await _api.getJson(AppConfig.userProfile(usernameOrId));
    return User.fromJson(body);
  }

  Future<User> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? bannerUrl,
    String? usernameColor,
    String? nameColor,
    String? avatarFrame,
    String? gender,
    bool? showGender,
    List<String>? stickers,
    List<String>? interests,
    String? voiceBioUrl,
    bool? onboardingCompleted,
    Map<String, dynamic>? themeSettings,
  }) async {
    final effectiveColor = usernameColor ?? nameColor;
    final body = await _api.patchJson(
      AppConfig.usersMe,
      data: {
        'displayName': ?displayName,
        'bio': ?bio,
        'avatarUrl': ?avatarUrl,
        'bannerUrl': ?bannerUrl,
        'usernameColor': ?effectiveColor,
        'nameColor': ?effectiveColor,
        'themeSettings': ?themeSettings,
        'avatarFrame': ?avatarFrame,
        'gender': ?gender,
        'showGender': ?showGender,
        'stickers': ?stickers,
        'interests': ?interests,
        'voiceBioUrl': ?voiceBioUrl,
        'onboardingCompleted': ?onboardingCompleted,
      },
    );
    return User.fromJson(body);
  }

  Future<User> setupProfile({
    String? username,
    Uint8List? avatarBytes,
    String? avatarFilename,
  }) async {
    final fields = <String, dynamic>{
      if (username != null && username.isNotEmpty) 'username': username,
      if (avatarBytes != null)
        'avatar': MultipartFile.fromBytes(
          avatarBytes,
          filename: avatarFilename ?? 'avatar.png',
        ),
    };
    final body = await _api.patchForm(AppConfig.usersMeSetup, fields: fields);
    return User.fromJson(body);
  }

  Future<User> completeOnboarding({
    String? username,
    String? displayName,
    String? gender,
    List<String>? interests,
    bool onboardingCompleted = false,
  }) async {
    final body = await _api.postJson(
      AppConfig.usersOnboarding,
      data: {
        'username': ?username,
        'displayName': ?displayName,
        'gender': ?gender,
        'interests': ?interests,
        if (onboardingCompleted) 'onboardingCompleted': true,
      },
    );
    return User.fromJson(body);
  }

  Future<User> setInterests(List<String> interests) async {
    final body = await _api.postJson(
      AppConfig.usersSetupInterests,
      data: {'interests': interests},
    );
    return User.fromJson(body);
  }

  Future<Map<String, dynamic>> checkUsername(String username) async {
    return _api.getJson(AppConfig.checkUsername(username));
  }

  Future<FollowActionResult> followUser(String userId) async {
    final body = await _api.postJson(AppConfig.userFollow(userId));
    return FollowActionResult.fromJson(body);
  }

  Future<FollowActionResult> unfollowUser(String userId) async {
    final body = await _api.deleteJson(AppConfig.userUnfollow(userId));
    return FollowActionResult.fromJson(body);
  }

  Future<FollowListResult> getFollowers(
    String usernameOrId, {
    String? cursor,
    int limit = 20,
  }) async {
    final body = await _api.getJson(
      '${AppConfig.userFollowers(usernameOrId)}?limit=$limit${cursor != null ? '&cursor=$cursor' : ''}',
    );
    return _parseFollowList(body);
  }

  Future<FollowListResult> getFollowing(
    String usernameOrId, {
    String? cursor,
    int limit = 20,
  }) async {
    final body = await _api.getJson(
      '${AppConfig.userFollowing(usernameOrId)}?limit=$limit${cursor != null ? '&cursor=$cursor' : ''}',
    );
    return _parseFollowList(body);
  }

  FollowListResult _parseFollowList(Map<String, dynamic> body) {
    final raw =
        body['items'] ?? body['data'] ?? body['results'] ?? body['users'];
    final nextCursor = body['nextCursor'] as String?;
    if (raw is List) {
      return FollowListResult(
        items: raw
            .whereType<Map<String, dynamic>>()
            .map(FollowItem.fromJson)
            .toList(),
        nextCursor: nextCursor,
      );
    }
    return FollowListResult(items: const [], nextCursor: null);
  }

  /// Búsqueda de personas por username o displayName (GET /search/people).
  Future<List<FollowItem>> searchPeople(String query) async {
    final trimmed = query.replaceFirst('@', '').trim();
    final body = await _api.getJson(
      '${AppConfig.searchPeople}?q=${Uri.encodeQueryComponent(trimmed)}',
    );
    return _parseList(body);
  }

  /// Personas sugeridas para seguir (GET /search/suggest).
  Future<List<FollowItem>> suggestPeople({int limit = 20}) async {
    final body = await _api.getJson('${AppConfig.searchSuggest}?limit=$limit');
    return _parseList(body);
  }

  Future<List<VisitItem>> getVisits(String usernameOrId) async {
    final body = await _api.getJson(AppConfig.userVisits(usernameOrId));
    final raw = body['data'] ?? body['items'] ?? body['visits'] ?? body;
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(VisitItem.fromJson)
          .toList();
    }
    return const [];
  }

  Future<void> registerVisit(String usernameOrId) async {
    await _api.postJson(AppConfig.userVisit(usernameOrId));
  }

  Future<void> blockUser(String usernameOrId, {String? reason}) async {
    await _api.postJson(
      AppConfig.userBlock(usernameOrId),
      data: {'reason': ?reason},
    );
  }

  Future<void> reportUser(
    String usernameOrId, {
    String? reason,
    String? details,
  }) async {
    await _api.postJson(
      AppConfig.userReport(usernameOrId),
      data: {'reason': ?reason, 'details': ?details},
    );
  }

  List<FollowItem> _parseList(Map<String, dynamic> body) {
    final raw =
        body['data'] ?? body['items'] ?? body['results'] ?? body['users'];
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(FollowItem.fromJson)
          .toList();
    }
    return const [];
  }
}
