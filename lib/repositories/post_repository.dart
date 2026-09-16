import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../models/reaction.dart';

/// Operaciones sobre publicaciones, reacciones y comentarios.
class PostRepository {
  PostRepository(this._api);

  final ApiClient _api;

  /// Feed paginado por cursor.
  Future<FeedPage> getFeed({
    String category = 'para_ti',
    bool followingOnly = false,
    int page = 1,
    int limit = 20,
    String? cursor,
  }) async {
    final body = await _api.getJson(
      AppConfig.postsFeed,
      query: {
        'category': category,
        if (followingOnly) 'followingOnly': 'true',
        'page': page,
        'limit': limit,
        'cursor': ?cursor,
      },
    );
    return FeedPage.fromJson(body);
  }

  Future<Post> getPost(String id) async {
    final body = await _api.getJson(AppConfig.postDetail(id));
    return Post.fromJson(body);
  }

  Future<Post> createPost({
    required String body,
    String? title,
    String type = 'TEXT',
    String visibility = 'PUBLIC',
    List<String>? mediaUrls,
    List<String>? tags,
    List<String>? genres,
    String? coverImageUrl,
    String? bgImageUrl,
    double? bgOverlay,
    bool? bgBlur,
    String? audioUrl,
    bool? chapterMode,
    int? chapterNumber,
    String? fontFamily,
    String? themeBgColor,
    String? themeAccent,
    bool? warnViolence,
    bool? warnAdult,
    bool? warnDark,
    bool? warnSpoiler,
    bool? allowComments,
    bool? allowReactions,
    String? circleId,
  }) async {
    final json = await _api.postJson(
      AppConfig.postsBase,
      data: {
        'body': body,
        if (title != null && title.isNotEmpty) 'title': title,
        'type': type,
        'visibility': visibility,
        if (circleId != null && circleId.isNotEmpty) 'circleId': circleId,
        if (mediaUrls != null && mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
        if (genres != null && genres.isNotEmpty) 'genres': genres,
        'coverImageUrl': ?coverImageUrl,
        'bgImageUrl': ?bgImageUrl,
        'bgOverlay': ?bgOverlay,
        'bgBlur': ?bgBlur,
        'audioUrl': ?audioUrl,
        'chapterMode': ?chapterMode,
        'chapterNumber': ?chapterNumber,
        'fontFamily': ?fontFamily,
        'themeBgColor': ?themeBgColor,
        'themeAccent': ?themeAccent,
        'warnViolence': ?warnViolence,
        'warnAdult': ?warnAdult,
        'warnDark': ?warnDark,
        'warnSpoiler': ?warnSpoiler,
        'allowComments': ?allowComments,
        'allowReactions': ?allowReactions,
      },
    );
    return Post.fromJson(json);
  }

  Future<Post> updatePost(
    String id, {
    String? body,
    String? title,
    String? visibility,
    List<String>? mediaUrls,
  }) async {
    final json = await _api.patchJson(
      AppConfig.postDetail(id),
      data: {
        'body': ?body,
        'title': ?title,
        'visibility': ?visibility,
        'mediaUrls': ?mediaUrls,
      },
    );
    return Post.fromJson(json);
  }

  Future<void> deletePost(String id) async {
    await _api.deleteJson(AppConfig.postDetail(id));
  }

  /// Toggle de reacción. Devuelve el nuevo estado de conteos.
  Future<ReactionCounts> toggleReaction(String postId, String type) async {
    final json = await _api.postJson(
      AppConfig.postReact(postId),
      data: {'type': type},
    );
    return ReactionCounts.fromJson(
      json['reactionCounts'] as Map<String, dynamic>?,
    );
  }

  Future<ReactionList> getReactions(String postId) async {
    final json = await _api.getJson(AppConfig.postReactions(postId));
    return ReactionList.fromJson(json);
  }

  Future<CommentsPage> getComments(
    String postId, {
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _api.getJson(
      AppConfig.postComments(postId),
      query: {'page': page, 'limit': limit},
    );
    return CommentsPage.fromJson(json);
  }

  Future<void> reportPost(
    String postId, {
    required String reason,
    String? details,
  }) async {
    await _api.postJson(
      AppConfig.postReport(postId),
      data: {
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      },
    );
  }

  Future<Comment> createComment(
    String postId, {
    required String body,
    String? parentId,
    String? mediaUrl,
    String? mediaType,
  }) async {
    final json = await _api.postJson(
      AppConfig.postComments(postId),
      data: {
        'body': body,
        'parentId': ?parentId,
        'mediaUrl': ?mediaUrl,
        'mediaType': ?mediaType,
      },
    );
    return Comment.fromJson(json);
  }

  Future<void> deleteComment(String commentId) async {
    await _api.deleteJson(AppConfig.commentDetail(commentId));
  }

  /// Toggle de reacción a comentario.
  Future<Map<String, dynamic>> toggleCommentLike(
    String commentId,
    String type,
  ) async {
    return _api.postJson(
      AppConfig.commentLike(commentId),
      data: {'type': type},
    );
  }

  Future<String> translatePost(String id) async {
    final json = await _api.postJson(AppConfig.postTranslate(id));
    return json['translatedBody'] as String? ?? '';
  }

  Future<Map<String, dynamic>> autosaveDraft({
    required Map<String, dynamic> snapshot,
    String? postId,
  }) async {
    return _api.postJson(
      AppConfig.postsDraftsAutosave,
      data: {'snapshot': snapshot, 'postId': ?postId},
    );
  }

  Future<List<Map<String, dynamic>>> getDrafts() async {
    final json = await _api.getJson(AppConfig.postsDraftsMy);
    final raw = json['data'] ?? json['drafts'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Future<void> deleteDraft(String id) async {
    await _api.deleteJson(AppConfig.postsDraftsMy, query: {'id': id});
  }
}
