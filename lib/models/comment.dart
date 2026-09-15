// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/network/json_converters.dart';
import 'media.dart';
import 'paginated_response.dart';
import 'post_author.dart';

part 'comment.freezed.dart';
part 'comment.g.dart';

/// Comentario serializado (`serializeComment`).
@freezed
abstract class Comment with _$Comment {
  const factory Comment({
    required String id,
    required String postId,
    required String body,
    required PostAuthor author,
    String? mediaUrl,
    String? mediaType,
    @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? media,
    @Default(0) int likeCount,
    @Default(false) bool isLiked,
    String? myReaction,
    @Default(false) bool isAuthor,
    @Default(<Comment>[]) List<Comment> replies,
    String? parentId,
    @Default(false) bool isEdited,
    required String timeAgo,
    @JsonKey(fromJson: dateFromJson, toJson: dateToJson)
    required DateTime createdAt,
    Map<String, dynamic>? extensions,
  }) = _Comment;

  factory Comment.fromJson(Map<String, dynamic> json) =>
      _$CommentFromJson(<String, dynamic>{
        ...json,
        'id': json['id'] ?? '',
        'postId': json['postId'] ?? '',
        'body': json['body'] ?? '',
        'author': json['author'] ?? <String, dynamic>{},
        'timeAgo': json['timeAgo'] ?? '',
        'replies': json['replies'] is List ? json['replies'] : <Object>[],
      });
}

/// Respuesta paginada de comentarios.
class CommentsPage {
  const CommentsPage({
    required this.comments,
    this.total = 0,
    this.hasMore = false,
    this.page = 1,
  });

  final List<Comment> comments;
  final int total;
  final bool hasMore;
  final int page;

  factory CommentsPage.fromJson(Map<String, dynamic> json) {
    final page = PaginatedResponse<Comment>.fromJson(
      json,
      Comment.fromJson,
      itemKey: 'comments',
    );
    return CommentsPage(
      comments: page.items,
      total: page.total,
      hasMore: page.hasMore || page.hasNextPage,
      page: (json['page'] as num?)?.toInt() ?? 1,
    );
  }
}
