import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/post.dart';

/// Operaciones sobre publicaciones guardadas (bookmarks).
class BookmarksRepository {
  BookmarksRepository(this._api);

  final ApiClient _api;

  /// Lista de publicaciones guardadas del usuario, paginada por cursor.
  Future<FeedPage> getBookmarks({String? cursor, int limit = 20}) async {
    final json = await _api.getJson(
      AppConfig.bookmarksBase,
      query: {'limit': limit, 'cursor': ?cursor},
    );
    return FeedPage.fromJson(json);
  }

  /// Alterna el guardado de una publicación. Devuelve el nuevo estado.
  Future<bool> toggleBookmark(String postId) async {
    final json = await _api.postJson(AppConfig.postBookmark(postId));
    return json['saved'] as bool? ?? false;
  }
}
