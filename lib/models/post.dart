// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/network/json_converters.dart';
import 'media.dart';
import 'paginated_response.dart';
import 'post_author.dart';
import 'reaction.dart';

part 'post.freezed.dart';
part 'post.g.dart';

/// Publicación serializada (`serializePost` del backend).
@freezed
abstract class Post with _$Post {
  const factory Post({
    required String id,
    required String type,
    required String title,
    required String body,
    required PostAuthor author,
    required ReactionCounts reactions,
    required PostStats stats,
    required bool isLiked,
    /// Visibilidad del post (`PUBLIC`, `FOLLOWERS`, `PRIVATE`, `CIRCLE`).
    @Default('PUBLIC') String visibility,
    String? myReaction,
    String? coverImageUrl,
    String? bgImageUrl,
    @Default(0.55) double bgOverlay,
    @Default(false) bool bgBlur,
    @Default(<String>[]) List<String> tags,
    @Default(<String>[]) List<String> genres,
    @Default(<String>[]) List<String> mediaUrls,
    @Default(<Media>[])
    @JsonKey(fromJson: mediaListFromJson, toJson: mediaListToJson)
    List<Media> media,
    @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? cover,
    String? audioUrl,
    @Default(false) bool chapterMode,
    int? chapterNumber,
    PostWarnings? warnings,
    @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)
    DateTime? publishedAt,
    String? themeBgColor,
    String? themeAccent,
    String? fontFamily,
    required String timeAgo,
    Map<String, dynamic>? extensions,
  }) = _Post;

  const Post._();

  bool get hasMedia => mediaUrls.isNotEmpty || media.isNotEmpty;
  bool get hasCover =>
      coverImageUrl != null && coverImageUrl!.isNotEmpty || cover != null;

  /// `true` cuando el post solo es visible para su autor.
  bool get isPrivate => visibility == 'PRIVATE';

  factory Post.fromJson(Map<String, dynamic> json) =>
      _$PostFromJson(<String, dynamic>{
        ...json,
        'id': json['id'] ?? '',
        'type': json['type'] ?? 'TEXT',
        'title': json['title'] ?? '',
        'body': json['body'] ?? '',
        'author': json['author'] ?? <String, dynamic>{},
        'reactions': json['reactions'] ?? <String, dynamic>{},
        'stats': json['stats'] ?? <String, dynamic>{},
        'isLiked': json['isLiked'] ?? false,
        'timeAgo': json['timeAgo'] ?? '',
      });
}

/// Respuesta paginada del feed.
class FeedPage {
  const FeedPage({
    required this.posts,
    this.nextCursor,
    this.total = 0,
    this.page = 1,
  });

  final List<Post> posts;
  final String? nextCursor;
  final int total;
  final int page;

  factory FeedPage.fromJson(Map<String, dynamic> json) {
    final page = PaginatedResponse<Post>.fromJson(
      json,
      Post.fromJson,
      itemKey: 'posts',
    );
    return FeedPage(
      posts: page.items,
      nextCursor: page.nextPageToken,
      total: page.total,
      page: (json['page'] as num?)?.toInt() ?? 1,
    );
  }
}
