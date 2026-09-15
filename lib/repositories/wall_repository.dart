import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/reaction.dart';
import '../models/wall_entry.dart';

/// Muro de perfil.
class WallRepository {
  WallRepository(this._api);

  final ApiClient _api;

  Future<WallPage> getWall(String userId, {int page = 1}) async {
    final json = await _api.getJson(
      AppConfig.wall(userId),
      query: {'page': page},
    );
    return WallPage.fromJson(json);
  }

  Future<WallEntry> createEntry(
    String ownerId, {
    required String text,
    String? imageUrl,
    String? parentId,
  }) async {
    final json = await _api.postJson(
      AppConfig.wall(ownerId),
      data: {'text': text, 'imageUrl': ?imageUrl, 'parentId': ?parentId},
    );
    return WallEntry.fromJson(json);
  }

  Future<void> deleteEntry(String entryId) async {
    await _api.deleteJson(AppConfig.wall(entryId));
  }

  Future<ReactionCounts> toggleReaction(String entryId, String type) async {
    final json = await _api.postJson(
      AppConfig.wallReact(entryId),
      data: {'type': type},
    );
    return ReactionCounts.fromJson(
      json['reactionCounts'] as Map<String, dynamic>?,
    );
  }
}
