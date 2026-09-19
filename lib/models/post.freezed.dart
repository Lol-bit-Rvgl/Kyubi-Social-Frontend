// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Post {

 String get id; String get type; String get title; String get body; PostAuthor get author; ReactionCounts get reactions; PostStats get stats; bool get isLiked;/// Visibilidad del post (`PUBLIC`, `FOLLOWERS`, `PRIVATE`, `CIRCLE`).
 String get visibility; String? get myReaction; String? get coverImageUrl; String? get bgImageUrl; double get bgOverlay; bool get bgBlur; List<String> get tags; List<String> get genres; List<String> get mediaUrls;@JsonKey(fromJson: mediaListFromJson, toJson: mediaListToJson) List<Media> get media;@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? get cover; String? get audioUrl; bool get chapterMode; int? get chapterNumber; PostWarnings? get warnings;@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) DateTime? get publishedAt; String? get themeBgColor; String? get themeAccent; String? get fontFamily; String get timeAgo; Map<String, dynamic>? get extensions;
/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostCopyWith<Post> get copyWith => _$PostCopyWithImpl<Post>(this as Post, _$identity);

  /// Serializes this Post to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Post&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.author, author) || other.author == author)&&(identical(other.reactions, reactions) || other.reactions == reactions)&&(identical(other.stats, stats) || other.stats == stats)&&(identical(other.isLiked, isLiked) || other.isLiked == isLiked)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.myReaction, myReaction) || other.myReaction == myReaction)&&(identical(other.coverImageUrl, coverImageUrl) || other.coverImageUrl == coverImageUrl)&&(identical(other.bgImageUrl, bgImageUrl) || other.bgImageUrl == bgImageUrl)&&(identical(other.bgOverlay, bgOverlay) || other.bgOverlay == bgOverlay)&&(identical(other.bgBlur, bgBlur) || other.bgBlur == bgBlur)&&const DeepCollectionEquality().equals(other.tags, tags)&&const DeepCollectionEquality().equals(other.genres, genres)&&const DeepCollectionEquality().equals(other.mediaUrls, mediaUrls)&&const DeepCollectionEquality().equals(other.media, media)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.audioUrl, audioUrl) || other.audioUrl == audioUrl)&&(identical(other.chapterMode, chapterMode) || other.chapterMode == chapterMode)&&(identical(other.chapterNumber, chapterNumber) || other.chapterNumber == chapterNumber)&&(identical(other.warnings, warnings) || other.warnings == warnings)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&(identical(other.themeBgColor, themeBgColor) || other.themeBgColor == themeBgColor)&&(identical(other.themeAccent, themeAccent) || other.themeAccent == themeAccent)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.timeAgo, timeAgo) || other.timeAgo == timeAgo)&&const DeepCollectionEquality().equals(other.extensions, extensions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,type,title,body,author,reactions,stats,isLiked,visibility,myReaction,coverImageUrl,bgImageUrl,bgOverlay,bgBlur,const DeepCollectionEquality().hash(tags),const DeepCollectionEquality().hash(genres),const DeepCollectionEquality().hash(mediaUrls),const DeepCollectionEquality().hash(media),cover,audioUrl,chapterMode,chapterNumber,warnings,publishedAt,themeBgColor,themeAccent,fontFamily,timeAgo,const DeepCollectionEquality().hash(extensions)]);

@override
String toString() {
  return 'Post(id: $id, type: $type, title: $title, body: $body, author: $author, reactions: $reactions, stats: $stats, isLiked: $isLiked, visibility: $visibility, myReaction: $myReaction, coverImageUrl: $coverImageUrl, bgImageUrl: $bgImageUrl, bgOverlay: $bgOverlay, bgBlur: $bgBlur, tags: $tags, genres: $genres, mediaUrls: $mediaUrls, media: $media, cover: $cover, audioUrl: $audioUrl, chapterMode: $chapterMode, chapterNumber: $chapterNumber, warnings: $warnings, publishedAt: $publishedAt, themeBgColor: $themeBgColor, themeAccent: $themeAccent, fontFamily: $fontFamily, timeAgo: $timeAgo, extensions: $extensions)';
}


}

/// @nodoc
abstract mixin class $PostCopyWith<$Res>  {
  factory $PostCopyWith(Post value, $Res Function(Post) _then) = _$PostCopyWithImpl;
@useResult
$Res call({
 String id, String type, String title, String body, PostAuthor author, ReactionCounts reactions, PostStats stats, bool isLiked, String visibility, String? myReaction, String? coverImageUrl, String? bgImageUrl, double bgOverlay, bool bgBlur, List<String> tags, List<String> genres, List<String> mediaUrls,@JsonKey(fromJson: mediaListFromJson, toJson: mediaListToJson) List<Media> media,@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? cover, String? audioUrl, bool chapterMode, int? chapterNumber, PostWarnings? warnings,@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) DateTime? publishedAt, String? themeBgColor, String? themeAccent, String? fontFamily, String timeAgo, Map<String, dynamic>? extensions
});


$MediaCopyWith<$Res>? get cover;

}
/// @nodoc
class _$PostCopyWithImpl<$Res>
    implements $PostCopyWith<$Res> {
  _$PostCopyWithImpl(this._self, this._then);

  final Post _self;
  final $Res Function(Post) _then;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? title = null,Object? body = null,Object? author = null,Object? reactions = null,Object? stats = null,Object? isLiked = null,Object? visibility = null,Object? myReaction = freezed,Object? coverImageUrl = freezed,Object? bgImageUrl = freezed,Object? bgOverlay = null,Object? bgBlur = null,Object? tags = null,Object? genres = null,Object? mediaUrls = null,Object? media = null,Object? cover = freezed,Object? audioUrl = freezed,Object? chapterMode = null,Object? chapterNumber = freezed,Object? warnings = freezed,Object? publishedAt = freezed,Object? themeBgColor = freezed,Object? themeAccent = freezed,Object? fontFamily = freezed,Object? timeAgo = null,Object? extensions = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as PostAuthor,reactions: null == reactions ? _self.reactions : reactions // ignore: cast_nullable_to_non_nullable
as ReactionCounts,stats: null == stats ? _self.stats : stats // ignore: cast_nullable_to_non_nullable
as PostStats,isLiked: null == isLiked ? _self.isLiked : isLiked // ignore: cast_nullable_to_non_nullable
as bool,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,myReaction: freezed == myReaction ? _self.myReaction : myReaction // ignore: cast_nullable_to_non_nullable
as String?,coverImageUrl: freezed == coverImageUrl ? _self.coverImageUrl : coverImageUrl // ignore: cast_nullable_to_non_nullable
as String?,bgImageUrl: freezed == bgImageUrl ? _self.bgImageUrl : bgImageUrl // ignore: cast_nullable_to_non_nullable
as String?,bgOverlay: null == bgOverlay ? _self.bgOverlay : bgOverlay // ignore: cast_nullable_to_non_nullable
as double,bgBlur: null == bgBlur ? _self.bgBlur : bgBlur // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,genres: null == genres ? _self.genres : genres // ignore: cast_nullable_to_non_nullable
as List<String>,mediaUrls: null == mediaUrls ? _self.mediaUrls : mediaUrls // ignore: cast_nullable_to_non_nullable
as List<String>,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as List<Media>,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as Media?,audioUrl: freezed == audioUrl ? _self.audioUrl : audioUrl // ignore: cast_nullable_to_non_nullable
as String?,chapterMode: null == chapterMode ? _self.chapterMode : chapterMode // ignore: cast_nullable_to_non_nullable
as bool,chapterNumber: freezed == chapterNumber ? _self.chapterNumber : chapterNumber // ignore: cast_nullable_to_non_nullable
as int?,warnings: freezed == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as PostWarnings?,publishedAt: freezed == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,themeBgColor: freezed == themeBgColor ? _self.themeBgColor : themeBgColor // ignore: cast_nullable_to_non_nullable
as String?,themeAccent: freezed == themeAccent ? _self.themeAccent : themeAccent // ignore: cast_nullable_to_non_nullable
as String?,fontFamily: freezed == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String?,timeAgo: null == timeAgo ? _self.timeAgo : timeAgo // ignore: cast_nullable_to_non_nullable
as String,extensions: freezed == extensions ? _self.extensions : extensions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}
/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaCopyWith<$Res>? get cover {
    if (_self.cover == null) {
    return null;
  }

  return $MediaCopyWith<$Res>(_self.cover!, (value) {
    return _then(_self.copyWith(cover: value));
  });
}
}


/// Adds pattern-matching-related methods to [Post].
extension PostPatterns on Post {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Post value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Post() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Post value)  $default,){
final _that = this;
switch (_that) {
case _Post():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Post value)?  $default,){
final _that = this;
switch (_that) {
case _Post() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type,  String title,  String body,  PostAuthor author,  ReactionCounts reactions,  PostStats stats,  bool isLiked,  String visibility,  String? myReaction,  String? coverImageUrl,  String? bgImageUrl,  double bgOverlay,  bool bgBlur,  List<String> tags,  List<String> genres,  List<String> mediaUrls, @JsonKey(fromJson: mediaListFromJson, toJson: mediaListToJson)  List<Media> media, @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson)  Media? cover,  String? audioUrl,  bool chapterMode,  int? chapterNumber,  PostWarnings? warnings, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)  DateTime? publishedAt,  String? themeBgColor,  String? themeAccent,  String? fontFamily,  String timeAgo,  Map<String, dynamic>? extensions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.type,_that.title,_that.body,_that.author,_that.reactions,_that.stats,_that.isLiked,_that.visibility,_that.myReaction,_that.coverImageUrl,_that.bgImageUrl,_that.bgOverlay,_that.bgBlur,_that.tags,_that.genres,_that.mediaUrls,_that.media,_that.cover,_that.audioUrl,_that.chapterMode,_that.chapterNumber,_that.warnings,_that.publishedAt,_that.themeBgColor,_that.themeAccent,_that.fontFamily,_that.timeAgo,_that.extensions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type,  String title,  String body,  PostAuthor author,  ReactionCounts reactions,  PostStats stats,  bool isLiked,  String visibility,  String? myReaction,  String? coverImageUrl,  String? bgImageUrl,  double bgOverlay,  bool bgBlur,  List<String> tags,  List<String> genres,  List<String> mediaUrls, @JsonKey(fromJson: mediaListFromJson, toJson: mediaListToJson)  List<Media> media, @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson)  Media? cover,  String? audioUrl,  bool chapterMode,  int? chapterNumber,  PostWarnings? warnings, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)  DateTime? publishedAt,  String? themeBgColor,  String? themeAccent,  String? fontFamily,  String timeAgo,  Map<String, dynamic>? extensions)  $default,) {final _that = this;
switch (_that) {
case _Post():
return $default(_that.id,_that.type,_that.title,_that.body,_that.author,_that.reactions,_that.stats,_that.isLiked,_that.visibility,_that.myReaction,_that.coverImageUrl,_that.bgImageUrl,_that.bgOverlay,_that.bgBlur,_that.tags,_that.genres,_that.mediaUrls,_that.media,_that.cover,_that.audioUrl,_that.chapterMode,_that.chapterNumber,_that.warnings,_that.publishedAt,_that.themeBgColor,_that.themeAccent,_that.fontFamily,_that.timeAgo,_that.extensions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type,  String title,  String body,  PostAuthor author,  ReactionCounts reactions,  PostStats stats,  bool isLiked,  String visibility,  String? myReaction,  String? coverImageUrl,  String? bgImageUrl,  double bgOverlay,  bool bgBlur,  List<String> tags,  List<String> genres,  List<String> mediaUrls, @JsonKey(fromJson: mediaListFromJson, toJson: mediaListToJson)  List<Media> media, @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson)  Media? cover,  String? audioUrl,  bool chapterMode,  int? chapterNumber,  PostWarnings? warnings, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)  DateTime? publishedAt,  String? themeBgColor,  String? themeAccent,  String? fontFamily,  String timeAgo,  Map<String, dynamic>? extensions)?  $default,) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.type,_that.title,_that.body,_that.author,_that.reactions,_that.stats,_that.isLiked,_that.visibility,_that.myReaction,_that.coverImageUrl,_that.bgImageUrl,_that.bgOverlay,_that.bgBlur,_that.tags,_that.genres,_that.mediaUrls,_that.media,_that.cover,_that.audioUrl,_that.chapterMode,_that.chapterNumber,_that.warnings,_that.publishedAt,_that.themeBgColor,_that.themeAccent,_that.fontFamily,_that.timeAgo,_that.extensions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Post extends Post {
  const _Post({required this.id, required this.type, required this.title, required this.body, required this.author, required this.reactions, required this.stats, required this.isLiked, this.visibility = 'PUBLIC', this.myReaction, this.coverImageUrl, this.bgImageUrl, this.bgOverlay = 0.55, this.bgBlur = false, final  List<String> tags = const <String>[], final  List<String> genres = const <String>[], final  List<String> mediaUrls = const <String>[], @JsonKey(fromJson: mediaListFromJson, toJson: mediaListToJson) final  List<Media> media = const <Media>[], @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) this.cover, this.audioUrl, this.chapterMode = false, this.chapterNumber, this.warnings, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) this.publishedAt, this.themeBgColor, this.themeAccent, this.fontFamily, required this.timeAgo, final  Map<String, dynamic>? extensions}): _tags = tags,_genres = genres,_mediaUrls = mediaUrls,_media = media,_extensions = extensions,super._();
  factory _Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

@override final  String id;
@override final  String type;
@override final  String title;
@override final  String body;
@override final  PostAuthor author;
@override final  ReactionCounts reactions;
@override final  PostStats stats;
@override final  bool isLiked;
/// Visibilidad del post (`PUBLIC`, `FOLLOWERS`, `PRIVATE`, `CIRCLE`).
@override@JsonKey() final  String visibility;
@override final  String? myReaction;
@override final  String? coverImageUrl;
@override final  String? bgImageUrl;
@override@JsonKey() final  double bgOverlay;
@override@JsonKey() final  bool bgBlur;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

 final  List<String> _genres;
@override@JsonKey() List<String> get genres {
  if (_genres is EqualUnmodifiableListView) return _genres;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_genres);
}

 final  List<String> _mediaUrls;
@override@JsonKey() List<String> get mediaUrls {
  if (_mediaUrls is EqualUnmodifiableListView) return _mediaUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mediaUrls);
}

 final  List<Media> _media;
@override@JsonKey(fromJson: mediaListFromJson, toJson: mediaListToJson) List<Media> get media {
  if (_media is EqualUnmodifiableListView) return _media;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_media);
}

@override@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) final  Media? cover;
@override final  String? audioUrl;
@override@JsonKey() final  bool chapterMode;
@override final  int? chapterNumber;
@override final  PostWarnings? warnings;
@override@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) final  DateTime? publishedAt;
@override final  String? themeBgColor;
@override final  String? themeAccent;
@override final  String? fontFamily;
@override final  String timeAgo;
 final  Map<String, dynamic>? _extensions;
@override Map<String, dynamic>? get extensions {
  final value = _extensions;
  if (value == null) return null;
  if (_extensions is EqualUnmodifiableMapView) return _extensions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostCopyWith<_Post> get copyWith => __$PostCopyWithImpl<_Post>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PostToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Post&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.author, author) || other.author == author)&&(identical(other.reactions, reactions) || other.reactions == reactions)&&(identical(other.stats, stats) || other.stats == stats)&&(identical(other.isLiked, isLiked) || other.isLiked == isLiked)&&(identical(other.visibility, visibility) || other.visibility == visibility)&&(identical(other.myReaction, myReaction) || other.myReaction == myReaction)&&(identical(other.coverImageUrl, coverImageUrl) || other.coverImageUrl == coverImageUrl)&&(identical(other.bgImageUrl, bgImageUrl) || other.bgImageUrl == bgImageUrl)&&(identical(other.bgOverlay, bgOverlay) || other.bgOverlay == bgOverlay)&&(identical(other.bgBlur, bgBlur) || other.bgBlur == bgBlur)&&const DeepCollectionEquality().equals(other._tags, _tags)&&const DeepCollectionEquality().equals(other._genres, _genres)&&const DeepCollectionEquality().equals(other._mediaUrls, _mediaUrls)&&const DeepCollectionEquality().equals(other._media, _media)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.audioUrl, audioUrl) || other.audioUrl == audioUrl)&&(identical(other.chapterMode, chapterMode) || other.chapterMode == chapterMode)&&(identical(other.chapterNumber, chapterNumber) || other.chapterNumber == chapterNumber)&&(identical(other.warnings, warnings) || other.warnings == warnings)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt)&&(identical(other.themeBgColor, themeBgColor) || other.themeBgColor == themeBgColor)&&(identical(other.themeAccent, themeAccent) || other.themeAccent == themeAccent)&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.timeAgo, timeAgo) || other.timeAgo == timeAgo)&&const DeepCollectionEquality().equals(other._extensions, _extensions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,type,title,body,author,reactions,stats,isLiked,visibility,myReaction,coverImageUrl,bgImageUrl,bgOverlay,bgBlur,const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_genres),const DeepCollectionEquality().hash(_mediaUrls),const DeepCollectionEquality().hash(_media),cover,audioUrl,chapterMode,chapterNumber,warnings,publishedAt,themeBgColor,themeAccent,fontFamily,timeAgo,const DeepCollectionEquality().hash(_extensions)]);

@override
String toString() {
  return 'Post(id: $id, type: $type, title: $title, body: $body, author: $author, reactions: $reactions, stats: $stats, isLiked: $isLiked, visibility: $visibility, myReaction: $myReaction, coverImageUrl: $coverImageUrl, bgImageUrl: $bgImageUrl, bgOverlay: $bgOverlay, bgBlur: $bgBlur, tags: $tags, genres: $genres, mediaUrls: $mediaUrls, media: $media, cover: $cover, audioUrl: $audioUrl, chapterMode: $chapterMode, chapterNumber: $chapterNumber, warnings: $warnings, publishedAt: $publishedAt, themeBgColor: $themeBgColor, themeAccent: $themeAccent, fontFamily: $fontFamily, timeAgo: $timeAgo, extensions: $extensions)';
}


}

/// @nodoc
abstract mixin class _$PostCopyWith<$Res> implements $PostCopyWith<$Res> {
  factory _$PostCopyWith(_Post value, $Res Function(_Post) _then) = __$PostCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, String title, String body, PostAuthor author, ReactionCounts reactions, PostStats stats, bool isLiked, String visibility, String? myReaction, String? coverImageUrl, String? bgImageUrl, double bgOverlay, bool bgBlur, List<String> tags, List<String> genres, List<String> mediaUrls,@JsonKey(fromJson: mediaListFromJson, toJson: mediaListToJson) List<Media> media,@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? cover, String? audioUrl, bool chapterMode, int? chapterNumber, PostWarnings? warnings,@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) DateTime? publishedAt, String? themeBgColor, String? themeAccent, String? fontFamily, String timeAgo, Map<String, dynamic>? extensions
});


@override $MediaCopyWith<$Res>? get cover;

}
/// @nodoc
class __$PostCopyWithImpl<$Res>
    implements _$PostCopyWith<$Res> {
  __$PostCopyWithImpl(this._self, this._then);

  final _Post _self;
  final $Res Function(_Post) _then;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? title = null,Object? body = null,Object? author = null,Object? reactions = null,Object? stats = null,Object? isLiked = null,Object? visibility = null,Object? myReaction = freezed,Object? coverImageUrl = freezed,Object? bgImageUrl = freezed,Object? bgOverlay = null,Object? bgBlur = null,Object? tags = null,Object? genres = null,Object? mediaUrls = null,Object? media = null,Object? cover = freezed,Object? audioUrl = freezed,Object? chapterMode = null,Object? chapterNumber = freezed,Object? warnings = freezed,Object? publishedAt = freezed,Object? themeBgColor = freezed,Object? themeAccent = freezed,Object? fontFamily = freezed,Object? timeAgo = null,Object? extensions = freezed,}) {
  return _then(_Post(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as PostAuthor,reactions: null == reactions ? _self.reactions : reactions // ignore: cast_nullable_to_non_nullable
as ReactionCounts,stats: null == stats ? _self.stats : stats // ignore: cast_nullable_to_non_nullable
as PostStats,isLiked: null == isLiked ? _self.isLiked : isLiked // ignore: cast_nullable_to_non_nullable
as bool,visibility: null == visibility ? _self.visibility : visibility // ignore: cast_nullable_to_non_nullable
as String,myReaction: freezed == myReaction ? _self.myReaction : myReaction // ignore: cast_nullable_to_non_nullable
as String?,coverImageUrl: freezed == coverImageUrl ? _self.coverImageUrl : coverImageUrl // ignore: cast_nullable_to_non_nullable
as String?,bgImageUrl: freezed == bgImageUrl ? _self.bgImageUrl : bgImageUrl // ignore: cast_nullable_to_non_nullable
as String?,bgOverlay: null == bgOverlay ? _self.bgOverlay : bgOverlay // ignore: cast_nullable_to_non_nullable
as double,bgBlur: null == bgBlur ? _self.bgBlur : bgBlur // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,genres: null == genres ? _self._genres : genres // ignore: cast_nullable_to_non_nullable
as List<String>,mediaUrls: null == mediaUrls ? _self._mediaUrls : mediaUrls // ignore: cast_nullable_to_non_nullable
as List<String>,media: null == media ? _self._media : media // ignore: cast_nullable_to_non_nullable
as List<Media>,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as Media?,audioUrl: freezed == audioUrl ? _self.audioUrl : audioUrl // ignore: cast_nullable_to_non_nullable
as String?,chapterMode: null == chapterMode ? _self.chapterMode : chapterMode // ignore: cast_nullable_to_non_nullable
as bool,chapterNumber: freezed == chapterNumber ? _self.chapterNumber : chapterNumber // ignore: cast_nullable_to_non_nullable
as int?,warnings: freezed == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as PostWarnings?,publishedAt: freezed == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,themeBgColor: freezed == themeBgColor ? _self.themeBgColor : themeBgColor // ignore: cast_nullable_to_non_nullable
as String?,themeAccent: freezed == themeAccent ? _self.themeAccent : themeAccent // ignore: cast_nullable_to_non_nullable
as String?,fontFamily: freezed == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String?,timeAgo: null == timeAgo ? _self.timeAgo : timeAgo // ignore: cast_nullable_to_non_nullable
as String,extensions: freezed == extensions ? _self._extensions : extensions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaCopyWith<$Res>? get cover {
    if (_self.cover == null) {
    return null;
  }

  return $MediaCopyWith<$Res>(_self.cover!, (value) {
    return _then(_self.copyWith(cover: value));
  });
}
}

// dart format on
