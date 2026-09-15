import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/story.dart';

/// Operaciones sobre historias efímeras (stories 24h).
class StoryRepository {
  StoryRepository(this._api);

  final ApiClient _api;

  /// Feed de historias activas agrupadas por autor.
  Future<List<StoryGroup>> getStoriesFeed() async {
    final json = await _api.getJson(AppConfig.storiesFeed);
    final raw = json['groups'];
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(StoryGroup.fromJson)
          .toList();
    }
    return const [];
  }

  /// Crea una nueva historia (expira a las 24 h).
  Future<Story> createStory({
    required String mediaUrl,
    String mediaType = 'IMAGE',
    String? caption,
  }) async {
    final json = await _api.postJson(
      AppConfig.storiesBase,
      data: {
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      },
    );
    return Story.fromJson(json['story'] as Map<String, dynamic>? ?? json);
  }

  /// Registra la visualización de una historia.
  Future<void> markStoryViewed(String storyId) async {
    await _api.postJson(AppConfig.storyView(storyId));
  }
}
