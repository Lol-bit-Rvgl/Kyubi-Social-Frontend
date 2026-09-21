import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/circle.dart';
import '../models/post.dart';

/// Operaciones sobre círculos (`GET|POST /circles`).
class CircleRepository {
  CircleRepository(this._api);

  final ApiClient _api;

  /// Círculos públicos (y los del usuario si `mine`).
  Future<List<Circle>> getCircles({
    int limit = 30,
    String? query,
    bool mine = false,
  }) async {
    final json = await _api.getJson(
      AppConfig.circlesBase,
      query: {
        'limit': limit,
        if (query != null && query.isNotEmpty) 'q': query,
        if (mine) 'mine': 'true',
      },
    );
    return _circleList(json);
  }

  /// Círculos del usuario actual (públicos y privados).
  Future<List<Circle>> getMyCircles({int limit = 50}) async {
    final json = await _api.getJson(
      AppConfig.circlesMine,
      query: {'limit': limit},
    );
    return _circleList(json);
  }

  /// Búsqueda de círculos por nombre/descripción.
  Future<List<Circle>> searchCircles(String query, {int limit = 30}) async {
    final json = await _api.getJson(
      AppConfig.circlesSearch,
      query: {'q': query, 'limit': limit},
    );
    return _circleList(json);
  }

  /// Detalle del círculo (incluye hasta 24 miembros).
  Future<Circle> getCircle(String id) async {
    final json = await _api.getJson(AppConfig.circleDetail(id));
    return Circle.fromJson(json);
  }

  /// Crea un círculo (el usuario pasa a ser OWNER).
  Future<Circle> createCircle({
    required String name,
    String? description,
    String? avatarUrl,
    String? bannerUrl,
    bool isPrivate = false,
  }) async {
    final json = await _api.postJson(
      AppConfig.circlesBase,
      data: {
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
        if (bannerUrl != null && bannerUrl.isNotEmpty) 'bannerUrl': bannerUrl,
        'isPrivate': isPrivate,
      },
    );
    return Circle.fromJson(json);
  }

  /// Actualiza el círculo (requiere rol OWNER/ADMIN).
  Future<Circle> updateCircle(
    String id, {
    String? name,
    String? description,
    String? avatarUrl,
    String? bannerUrl,
    bool? isPrivate,
  }) async {
    final json = await _api.patchJson(
      AppConfig.circleDetail(id),
      data: {
        if (name != null && name.isNotEmpty) 'name': name,
        'description': ?description,
        'avatarUrl': ?avatarUrl,
        'bannerUrl': ?bannerUrl,
        'isPrivate': ?isPrivate,
      },
    );
    return Circle.fromJson(json);
  }

  /// Elimina el círculo (requiere rol OWNER).
  Future<void> deleteCircle(String id) async {
    await _api.deleteJson(AppConfig.circleDetail(id));
  }

  /// Entra al círculo (público o ya miembro).
  Future<Circle> joinCircle(String id) async {
    final json = await _api.postJson(AppConfig.circleJoin(id));
    return Circle.fromJson(json);
  }

  /// Sale del círculo (el OWNER no puede salir).
  Future<Circle> leaveCircle(String id) async {
    final json = await _api.postJson(AppConfig.circleLeave(id));
    return Circle.fromJson(json);
  }

  /// Posts del círculo paginados por cursor.
  Future<CirclePostsPage> getCirclePosts(
    String id, {
    int limit = 20,
    String? cursor,
  }) async {
    final json = await _api.getJson(
      AppConfig.circlePosts(id),
      query: {'limit': limit, 'cursor': ?cursor},
    );
    return CirclePostsPage.fromJson(json);
  }

  /// Publica en el círculo (requiere ser miembro). Siempre CIRCLE.
  Future<Post> createCirclePost(
    String id, {
    required String body,
    String? title,
    List<String>? mediaUrls,
    List<String>? tags,
    String? bgImageUrl,
    double? bgOverlay,
    bool? bgBlur,
    bool? warnViolence,
    bool? warnAdult,
    bool? warnDark,
    bool? warnSpoiler,
  }) async {
    final json = await _api.postJson(
      AppConfig.circlePosts(id),
      data: {
        'body': body,
        if (title != null && title.isNotEmpty) 'title': title,
        if (mediaUrls != null && mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
        'bgImageUrl': ?bgImageUrl,
        'bgOverlay': ?bgOverlay,
        'bgBlur': ?bgBlur,
        'warnViolence': ?warnViolence,
        'warnAdult': ?warnAdult,
        'warnDark': ?warnDark,
        'warnSpoiler': ?warnSpoiler,
      },
    );
    return Post.fromJson(json);
  }

  static List<Circle> _circleList(Map<String, dynamic> json) {
    final raw = json['data'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(Circle.fromJson).toList();
  }
}
