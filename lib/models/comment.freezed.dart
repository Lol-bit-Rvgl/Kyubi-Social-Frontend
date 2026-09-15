// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'comment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Comment {

 String get id; String get postId; String get body; PostAuthor get author; String? get mediaUrl; String? get mediaType;@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? get media; int get likeCount; bool get isLiked; String? get myReaction; bool get isAuthor; List<Comment> get replies; String? get parentId; bool get isEdited; String get timeAgo;@JsonKey(fromJson: dateFromJson, toJson: dateToJson) DateTime get createdAt; Map<String, dynamic>? get extensions;
/// Create a copy of Comment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommentCopyWith<Comment> get copyWith => _$CommentCopyWithImpl<Comment>(this as Comment, _$identity);

  /// Serializes this Comment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Comment&&(identical(other.id, id) || other.id == id)&&(identical(other.postId, postId) || other.postId == postId)&&(identical(other.body, body) || other.body == body)&&(identical(other.author, author) || other.author == author)&&(identical(other.mediaUrl, mediaUrl) || other.mediaUrl == mediaUrl)&&(identical(other.mediaType, mediaType) || other.mediaType == mediaType)&&(identical(other.media, media) || other.media == media)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.isLiked, isLiked) || other.isLiked == isLiked)&&(identical(other.myReaction, myReaction) || other.myReaction == myReaction)&&(identical(other.isAuthor, isAuthor) || other.isAuthor == isAuthor)&&const DeepCollectionEquality().equals(other.replies, replies)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.isEdited, isEdited) || other.isEdited == isEdited)&&(identical(other.timeAgo, timeAgo) || other.timeAgo == timeAgo)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other.extensions, extensions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,postId,body,author,mediaUrl,mediaType,media,likeCount,isLiked,myReaction,isAuthor,const DeepCollectionEquality().hash(replies),parentId,isEdited,timeAgo,createdAt,const DeepCollectionEquality().hash(extensions));

@override
String toString() {
  return 'Comment(id: $id, postId: $postId, body: $body, author: $author, mediaUrl: $mediaUrl, mediaType: $mediaType, media: $media, likeCount: $likeCount, isLiked: $isLiked, myReaction: $myReaction, isAuthor: $isAuthor, replies: $replies, parentId: $parentId, isEdited: $isEdited, timeAgo: $timeAgo, createdAt: $createdAt, extensions: $extensions)';
}


}

/// @nodoc
abstract mixin class $CommentCopyWith<$Res>  {
  factory $CommentCopyWith(Comment value, $Res Function(Comment) _then) = _$CommentCopyWithImpl;
@useResult
$Res call({
 String id, String postId, String body, PostAuthor author, String? mediaUrl, String? mediaType,@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? media, int likeCount, bool isLiked, String? myReaction, bool isAuthor, List<Comment> replies, String? parentId, bool isEdited, String timeAgo,@JsonKey(fromJson: dateFromJson, toJson: dateToJson) DateTime createdAt, Map<String, dynamic>? extensions
});


$MediaCopyWith<$Res>? get media;

}
/// @nodoc
class _$CommentCopyWithImpl<$Res>
    implements $CommentCopyWith<$Res> {
  _$CommentCopyWithImpl(this._self, this._then);

  final Comment _self;
  final $Res Function(Comment) _then;

/// Create a copy of Comment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? postId = null,Object? body = null,Object? author = null,Object? mediaUrl = freezed,Object? mediaType = freezed,Object? media = freezed,Object? likeCount = null,Object? isLiked = null,Object? myReaction = freezed,Object? isAuthor = null,Object? replies = null,Object? parentId = freezed,Object? isEdited = null,Object? timeAgo = null,Object? createdAt = null,Object? extensions = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,postId: null == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as PostAuthor,mediaUrl: freezed == mediaUrl ? _self.mediaUrl : mediaUrl // ignore: cast_nullable_to_non_nullable
as String?,mediaType: freezed == mediaType ? _self.mediaType : mediaType // ignore: cast_nullable_to_non_nullable
as String?,media: freezed == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as Media?,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,isLiked: null == isLiked ? _self.isLiked : isLiked // ignore: cast_nullable_to_non_nullable
as bool,myReaction: freezed == myReaction ? _self.myReaction : myReaction // ignore: cast_nullable_to_non_nullable
as String?,isAuthor: null == isAuthor ? _self.isAuthor : isAuthor // ignore: cast_nullable_to_non_nullable
as bool,replies: null == replies ? _self.replies : replies // ignore: cast_nullable_to_non_nullable
as List<Comment>,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,isEdited: null == isEdited ? _self.isEdited : isEdited // ignore: cast_nullable_to_non_nullable
as bool,timeAgo: null == timeAgo ? _self.timeAgo : timeAgo // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,extensions: freezed == extensions ? _self.extensions : extensions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}
/// Create a copy of Comment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaCopyWith<$Res>? get media {
    if (_self.media == null) {
    return null;
  }

  return $MediaCopyWith<$Res>(_self.media!, (value) {
    return _then(_self.copyWith(media: value));
  });
}
}


/// Adds pattern-matching-related methods to [Comment].
extension CommentPatterns on Comment {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Comment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Comment() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Comment value)  $default,){
final _that = this;
switch (_that) {
case _Comment():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Comment value)?  $default,){
final _that = this;
switch (_that) {
case _Comment() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String postId,  String body,  PostAuthor author,  String? mediaUrl,  String? mediaType, @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson)  Media? media,  int likeCount,  bool isLiked,  String? myReaction,  bool isAuthor,  List<Comment> replies,  String? parentId,  bool isEdited,  String timeAgo, @JsonKey(fromJson: dateFromJson, toJson: dateToJson)  DateTime createdAt,  Map<String, dynamic>? extensions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Comment() when $default != null:
return $default(_that.id,_that.postId,_that.body,_that.author,_that.mediaUrl,_that.mediaType,_that.media,_that.likeCount,_that.isLiked,_that.myReaction,_that.isAuthor,_that.replies,_that.parentId,_that.isEdited,_that.timeAgo,_that.createdAt,_that.extensions);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String postId,  String body,  PostAuthor author,  String? mediaUrl,  String? mediaType, @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson)  Media? media,  int likeCount,  bool isLiked,  String? myReaction,  bool isAuthor,  List<Comment> replies,  String? parentId,  bool isEdited,  String timeAgo, @JsonKey(fromJson: dateFromJson, toJson: dateToJson)  DateTime createdAt,  Map<String, dynamic>? extensions)  $default,) {final _that = this;
switch (_that) {
case _Comment():
return $default(_that.id,_that.postId,_that.body,_that.author,_that.mediaUrl,_that.mediaType,_that.media,_that.likeCount,_that.isLiked,_that.myReaction,_that.isAuthor,_that.replies,_that.parentId,_that.isEdited,_that.timeAgo,_that.createdAt,_that.extensions);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String postId,  String body,  PostAuthor author,  String? mediaUrl,  String? mediaType, @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson)  Media? media,  int likeCount,  bool isLiked,  String? myReaction,  bool isAuthor,  List<Comment> replies,  String? parentId,  bool isEdited,  String timeAgo, @JsonKey(fromJson: dateFromJson, toJson: dateToJson)  DateTime createdAt,  Map<String, dynamic>? extensions)?  $default,) {final _that = this;
switch (_that) {
case _Comment() when $default != null:
return $default(_that.id,_that.postId,_that.body,_that.author,_that.mediaUrl,_that.mediaType,_that.media,_that.likeCount,_that.isLiked,_that.myReaction,_that.isAuthor,_that.replies,_that.parentId,_that.isEdited,_that.timeAgo,_that.createdAt,_that.extensions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Comment implements Comment {
  const _Comment({required this.id, required this.postId, required this.body, required this.author, this.mediaUrl, this.mediaType, @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) this.media, this.likeCount = 0, this.isLiked = false, this.myReaction, this.isAuthor = false, final  List<Comment> replies = const <Comment>[], this.parentId, this.isEdited = false, required this.timeAgo, @JsonKey(fromJson: dateFromJson, toJson: dateToJson) required this.createdAt, final  Map<String, dynamic>? extensions}): _replies = replies,_extensions = extensions;
  factory _Comment.fromJson(Map<String, dynamic> json) => _$CommentFromJson(json);

@override final  String id;
@override final  String postId;
@override final  String body;
@override final  PostAuthor author;
@override final  String? mediaUrl;
@override final  String? mediaType;
@override@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) final  Media? media;
@override@JsonKey() final  int likeCount;
@override@JsonKey() final  bool isLiked;
@override final  String? myReaction;
@override@JsonKey() final  bool isAuthor;
 final  List<Comment> _replies;
@override@JsonKey() List<Comment> get replies {
  if (_replies is EqualUnmodifiableListView) return _replies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_replies);
}

@override final  String? parentId;
@override@JsonKey() final  bool isEdited;
@override final  String timeAgo;
@override@JsonKey(fromJson: dateFromJson, toJson: dateToJson) final  DateTime createdAt;
 final  Map<String, dynamic>? _extensions;
@override Map<String, dynamic>? get extensions {
  final value = _extensions;
  if (value == null) return null;
  if (_extensions is EqualUnmodifiableMapView) return _extensions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of Comment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommentCopyWith<_Comment> get copyWith => __$CommentCopyWithImpl<_Comment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Comment&&(identical(other.id, id) || other.id == id)&&(identical(other.postId, postId) || other.postId == postId)&&(identical(other.body, body) || other.body == body)&&(identical(other.author, author) || other.author == author)&&(identical(other.mediaUrl, mediaUrl) || other.mediaUrl == mediaUrl)&&(identical(other.mediaType, mediaType) || other.mediaType == mediaType)&&(identical(other.media, media) || other.media == media)&&(identical(other.likeCount, likeCount) || other.likeCount == likeCount)&&(identical(other.isLiked, isLiked) || other.isLiked == isLiked)&&(identical(other.myReaction, myReaction) || other.myReaction == myReaction)&&(identical(other.isAuthor, isAuthor) || other.isAuthor == isAuthor)&&const DeepCollectionEquality().equals(other._replies, _replies)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.isEdited, isEdited) || other.isEdited == isEdited)&&(identical(other.timeAgo, timeAgo) || other.timeAgo == timeAgo)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other._extensions, _extensions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,postId,body,author,mediaUrl,mediaType,media,likeCount,isLiked,myReaction,isAuthor,const DeepCollectionEquality().hash(_replies),parentId,isEdited,timeAgo,createdAt,const DeepCollectionEquality().hash(_extensions));

@override
String toString() {
  return 'Comment(id: $id, postId: $postId, body: $body, author: $author, mediaUrl: $mediaUrl, mediaType: $mediaType, media: $media, likeCount: $likeCount, isLiked: $isLiked, myReaction: $myReaction, isAuthor: $isAuthor, replies: $replies, parentId: $parentId, isEdited: $isEdited, timeAgo: $timeAgo, createdAt: $createdAt, extensions: $extensions)';
}


}

/// @nodoc
abstract mixin class _$CommentCopyWith<$Res> implements $CommentCopyWith<$Res> {
  factory _$CommentCopyWith(_Comment value, $Res Function(_Comment) _then) = __$CommentCopyWithImpl;
@override @useResult
$Res call({
 String id, String postId, String body, PostAuthor author, String? mediaUrl, String? mediaType,@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? media, int likeCount, bool isLiked, String? myReaction, bool isAuthor, List<Comment> replies, String? parentId, bool isEdited, String timeAgo,@JsonKey(fromJson: dateFromJson, toJson: dateToJson) DateTime createdAt, Map<String, dynamic>? extensions
});


@override $MediaCopyWith<$Res>? get media;

}
/// @nodoc
class __$CommentCopyWithImpl<$Res>
    implements _$CommentCopyWith<$Res> {
  __$CommentCopyWithImpl(this._self, this._then);

  final _Comment _self;
  final $Res Function(_Comment) _then;

/// Create a copy of Comment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? postId = null,Object? body = null,Object? author = null,Object? mediaUrl = freezed,Object? mediaType = freezed,Object? media = freezed,Object? likeCount = null,Object? isLiked = null,Object? myReaction = freezed,Object? isAuthor = null,Object? replies = null,Object? parentId = freezed,Object? isEdited = null,Object? timeAgo = null,Object? createdAt = null,Object? extensions = freezed,}) {
  return _then(_Comment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,postId: null == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as PostAuthor,mediaUrl: freezed == mediaUrl ? _self.mediaUrl : mediaUrl // ignore: cast_nullable_to_non_nullable
as String?,mediaType: freezed == mediaType ? _self.mediaType : mediaType // ignore: cast_nullable_to_non_nullable
as String?,media: freezed == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as Media?,likeCount: null == likeCount ? _self.likeCount : likeCount // ignore: cast_nullable_to_non_nullable
as int,isLiked: null == isLiked ? _self.isLiked : isLiked // ignore: cast_nullable_to_non_nullable
as bool,myReaction: freezed == myReaction ? _self.myReaction : myReaction // ignore: cast_nullable_to_non_nullable
as String?,isAuthor: null == isAuthor ? _self.isAuthor : isAuthor // ignore: cast_nullable_to_non_nullable
as bool,replies: null == replies ? _self._replies : replies // ignore: cast_nullable_to_non_nullable
as List<Comment>,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,isEdited: null == isEdited ? _self.isEdited : isEdited // ignore: cast_nullable_to_non_nullable
as bool,timeAgo: null == timeAgo ? _self.timeAgo : timeAgo // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,extensions: freezed == extensions ? _self._extensions : extensions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

/// Create a copy of Comment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaCopyWith<$Res>? get media {
    if (_self.media == null) {
    return null;
  }

  return $MediaCopyWith<$Res>(_self.media!, (value) {
    return _then(_self.copyWith(media: value));
  });
}
}

// dart format on
