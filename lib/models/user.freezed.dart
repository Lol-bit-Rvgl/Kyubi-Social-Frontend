// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$User {

 String get id; String get username; String get displayName; String? get email; String? get avatarUrl; String? get bannerUrl; String? get bio; String? get usernameColor; String? get avatarFrame; int get level; bool get isOnline; String? get gender; bool get showGender;@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) DateTime? get emailVerifiedAt; bool get onboardingCompleted;@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) DateTime? get createdAt; bool get isFollowing; int get followersCount; int get followingCount; bool get hasPaymentPassword; List<String> get stickers; List<String> get interests;/// Títulos comunitarios asignados por los administradores del círculo.
@JsonKey(fromJson: communityTitleListFromJson, toJson: communityTitleListToJson) List<CommunityTitle> get titles; Map<String, dynamic>? get socialLinks; String? get voiceBioUrl; Map<String, dynamic>? get availability;@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? get avatar;@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? get banner; Map<String, dynamic>? get extensions;
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserCopyWith<User> get copyWith => _$UserCopyWithImpl<User>(this as User, _$identity);

  /// Serializes this User to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is User&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.email, email) || other.email == email)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.bannerUrl, bannerUrl) || other.bannerUrl == bannerUrl)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.usernameColor, usernameColor) || other.usernameColor == usernameColor)&&(identical(other.avatarFrame, avatarFrame) || other.avatarFrame == avatarFrame)&&(identical(other.level, level) || other.level == level)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.showGender, showGender) || other.showGender == showGender)&&(identical(other.emailVerifiedAt, emailVerifiedAt) || other.emailVerifiedAt == emailVerifiedAt)&&(identical(other.onboardingCompleted, onboardingCompleted) || other.onboardingCompleted == onboardingCompleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isFollowing, isFollowing) || other.isFollowing == isFollowing)&&(identical(other.followersCount, followersCount) || other.followersCount == followersCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount)&&(identical(other.hasPaymentPassword, hasPaymentPassword) || other.hasPaymentPassword == hasPaymentPassword)&&const DeepCollectionEquality().equals(other.stickers, stickers)&&const DeepCollectionEquality().equals(other.interests, interests)&&const DeepCollectionEquality().equals(other.titles, titles)&&const DeepCollectionEquality().equals(other.socialLinks, socialLinks)&&(identical(other.voiceBioUrl, voiceBioUrl) || other.voiceBioUrl == voiceBioUrl)&&const DeepCollectionEquality().equals(other.availability, availability)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.banner, banner) || other.banner == banner)&&const DeepCollectionEquality().equals(other.extensions, extensions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,username,displayName,email,avatarUrl,bannerUrl,bio,usernameColor,avatarFrame,level,isOnline,gender,showGender,emailVerifiedAt,onboardingCompleted,createdAt,isFollowing,followersCount,followingCount,hasPaymentPassword,const DeepCollectionEquality().hash(stickers),const DeepCollectionEquality().hash(interests),const DeepCollectionEquality().hash(titles),const DeepCollectionEquality().hash(socialLinks),voiceBioUrl,const DeepCollectionEquality().hash(availability),avatar,banner,const DeepCollectionEquality().hash(extensions)]);

@override
String toString() {
  return 'User(id: $id, username: $username, displayName: $displayName, email: $email, avatarUrl: $avatarUrl, bannerUrl: $bannerUrl, bio: $bio, usernameColor: $usernameColor, avatarFrame: $avatarFrame, level: $level, isOnline: $isOnline, gender: $gender, showGender: $showGender, emailVerifiedAt: $emailVerifiedAt, onboardingCompleted: $onboardingCompleted, createdAt: $createdAt, isFollowing: $isFollowing, followersCount: $followersCount, followingCount: $followingCount, hasPaymentPassword: $hasPaymentPassword, stickers: $stickers, interests: $interests, titles: $titles, socialLinks: $socialLinks, voiceBioUrl: $voiceBioUrl, availability: $availability, avatar: $avatar, banner: $banner, extensions: $extensions)';
}


}

/// @nodoc
abstract mixin class $UserCopyWith<$Res>  {
  factory $UserCopyWith(User value, $Res Function(User) _then) = _$UserCopyWithImpl;
@useResult
$Res call({
 String id, String username, String displayName, String? email, String? avatarUrl, String? bannerUrl, String? bio, String? usernameColor, String? avatarFrame, int level, bool isOnline, String? gender, bool showGender,@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) DateTime? emailVerifiedAt, bool onboardingCompleted,@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) DateTime? createdAt, bool isFollowing, int followersCount, int followingCount, bool hasPaymentPassword, List<String> stickers, List<String> interests,@JsonKey(fromJson: communityTitleListFromJson, toJson: communityTitleListToJson) List<CommunityTitle> titles, Map<String, dynamic>? socialLinks, String? voiceBioUrl, Map<String, dynamic>? availability,@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? avatar,@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? banner, Map<String, dynamic>? extensions
});


$MediaCopyWith<$Res>? get avatar;$MediaCopyWith<$Res>? get banner;

}
/// @nodoc
class _$UserCopyWithImpl<$Res>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._self, this._then);

  final User _self;
  final $Res Function(User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? displayName = null,Object? email = freezed,Object? avatarUrl = freezed,Object? bannerUrl = freezed,Object? bio = freezed,Object? usernameColor = freezed,Object? avatarFrame = freezed,Object? level = null,Object? isOnline = null,Object? gender = freezed,Object? showGender = null,Object? emailVerifiedAt = freezed,Object? onboardingCompleted = null,Object? createdAt = freezed,Object? isFollowing = null,Object? followersCount = null,Object? followingCount = null,Object? hasPaymentPassword = null,Object? stickers = null,Object? interests = null,Object? titles = null,Object? socialLinks = freezed,Object? voiceBioUrl = freezed,Object? availability = freezed,Object? avatar = freezed,Object? banner = freezed,Object? extensions = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,bannerUrl: freezed == bannerUrl ? _self.bannerUrl : bannerUrl // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,usernameColor: freezed == usernameColor ? _self.usernameColor : usernameColor // ignore: cast_nullable_to_non_nullable
as String?,avatarFrame: freezed == avatarFrame ? _self.avatarFrame : avatarFrame // ignore: cast_nullable_to_non_nullable
as String?,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,isOnline: null == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,showGender: null == showGender ? _self.showGender : showGender // ignore: cast_nullable_to_non_nullable
as bool,emailVerifiedAt: freezed == emailVerifiedAt ? _self.emailVerifiedAt : emailVerifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,onboardingCompleted: null == onboardingCompleted ? _self.onboardingCompleted : onboardingCompleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isFollowing: null == isFollowing ? _self.isFollowing : isFollowing // ignore: cast_nullable_to_non_nullable
as bool,followersCount: null == followersCount ? _self.followersCount : followersCount // ignore: cast_nullable_to_non_nullable
as int,followingCount: null == followingCount ? _self.followingCount : followingCount // ignore: cast_nullable_to_non_nullable
as int,hasPaymentPassword: null == hasPaymentPassword ? _self.hasPaymentPassword : hasPaymentPassword // ignore: cast_nullable_to_non_nullable
as bool,stickers: null == stickers ? _self.stickers : stickers // ignore: cast_nullable_to_non_nullable
as List<String>,interests: null == interests ? _self.interests : interests // ignore: cast_nullable_to_non_nullable
as List<String>,titles: null == titles ? _self.titles : titles // ignore: cast_nullable_to_non_nullable
as List<CommunityTitle>,socialLinks: freezed == socialLinks ? _self.socialLinks : socialLinks // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,voiceBioUrl: freezed == voiceBioUrl ? _self.voiceBioUrl : voiceBioUrl // ignore: cast_nullable_to_non_nullable
as String?,availability: freezed == availability ? _self.availability : availability // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as Media?,banner: freezed == banner ? _self.banner : banner // ignore: cast_nullable_to_non_nullable
as Media?,extensions: freezed == extensions ? _self.extensions : extensions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaCopyWith<$Res>? get avatar {
    if (_self.avatar == null) {
    return null;
  }

  return $MediaCopyWith<$Res>(_self.avatar!, (value) {
    return _then(_self.copyWith(avatar: value));
  });
}/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaCopyWith<$Res>? get banner {
    if (_self.banner == null) {
    return null;
  }

  return $MediaCopyWith<$Res>(_self.banner!, (value) {
    return _then(_self.copyWith(banner: value));
  });
}
}


/// Adds pattern-matching-related methods to [User].
extension UserPatterns on User {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _User value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _User value)  $default,){
final _that = this;
switch (_that) {
case _User():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _User value)?  $default,){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String username,  String displayName,  String? email,  String? avatarUrl,  String? bannerUrl,  String? bio,  String? usernameColor,  String? avatarFrame,  int level,  bool isOnline,  String? gender,  bool showGender, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)  DateTime? emailVerifiedAt,  bool onboardingCompleted, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)  DateTime? createdAt,  bool isFollowing,  int followersCount,  int followingCount,  bool hasPaymentPassword,  List<String> stickers,  List<String> interests, @JsonKey(fromJson: communityTitleListFromJson, toJson: communityTitleListToJson)  List<CommunityTitle> titles,  Map<String, dynamic>? socialLinks,  String? voiceBioUrl,  Map<String, dynamic>? availability, @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson)  Media? avatar, @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson)  Media? banner,  Map<String, dynamic>? extensions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.email,_that.avatarUrl,_that.bannerUrl,_that.bio,_that.usernameColor,_that.avatarFrame,_that.level,_that.isOnline,_that.gender,_that.showGender,_that.emailVerifiedAt,_that.onboardingCompleted,_that.createdAt,_that.isFollowing,_that.followersCount,_that.followingCount,_that.hasPaymentPassword,_that.stickers,_that.interests,_that.titles,_that.socialLinks,_that.voiceBioUrl,_that.availability,_that.avatar,_that.banner,_that.extensions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String username,  String displayName,  String? email,  String? avatarUrl,  String? bannerUrl,  String? bio,  String? usernameColor,  String? avatarFrame,  int level,  bool isOnline,  String? gender,  bool showGender, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)  DateTime? emailVerifiedAt,  bool onboardingCompleted, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)  DateTime? createdAt,  bool isFollowing,  int followersCount,  int followingCount,  bool hasPaymentPassword,  List<String> stickers,  List<String> interests, @JsonKey(fromJson: communityTitleListFromJson, toJson: communityTitleListToJson)  List<CommunityTitle> titles,  Map<String, dynamic>? socialLinks,  String? voiceBioUrl,  Map<String, dynamic>? availability, @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson)  Media? avatar, @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson)  Media? banner,  Map<String, dynamic>? extensions)  $default,) {final _that = this;
switch (_that) {
case _User():
return $default(_that.id,_that.username,_that.displayName,_that.email,_that.avatarUrl,_that.bannerUrl,_that.bio,_that.usernameColor,_that.avatarFrame,_that.level,_that.isOnline,_that.gender,_that.showGender,_that.emailVerifiedAt,_that.onboardingCompleted,_that.createdAt,_that.isFollowing,_that.followersCount,_that.followingCount,_that.hasPaymentPassword,_that.stickers,_that.interests,_that.titles,_that.socialLinks,_that.voiceBioUrl,_that.availability,_that.avatar,_that.banner,_that.extensions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String username,  String displayName,  String? email,  String? avatarUrl,  String? bannerUrl,  String? bio,  String? usernameColor,  String? avatarFrame,  int level,  bool isOnline,  String? gender,  bool showGender, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)  DateTime? emailVerifiedAt,  bool onboardingCompleted, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)  DateTime? createdAt,  bool isFollowing,  int followersCount,  int followingCount,  bool hasPaymentPassword,  List<String> stickers,  List<String> interests, @JsonKey(fromJson: communityTitleListFromJson, toJson: communityTitleListToJson)  List<CommunityTitle> titles,  Map<String, dynamic>? socialLinks,  String? voiceBioUrl,  Map<String, dynamic>? availability, @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson)  Media? avatar, @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson)  Media? banner,  Map<String, dynamic>? extensions)?  $default,) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.username,_that.displayName,_that.email,_that.avatarUrl,_that.bannerUrl,_that.bio,_that.usernameColor,_that.avatarFrame,_that.level,_that.isOnline,_that.gender,_that.showGender,_that.emailVerifiedAt,_that.onboardingCompleted,_that.createdAt,_that.isFollowing,_that.followersCount,_that.followingCount,_that.hasPaymentPassword,_that.stickers,_that.interests,_that.titles,_that.socialLinks,_that.voiceBioUrl,_that.availability,_that.avatar,_that.banner,_that.extensions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _User extends User {
  const _User({required this.id, required this.username, required this.displayName, this.email, this.avatarUrl, this.bannerUrl, this.bio, this.usernameColor, this.avatarFrame, this.level = 1, this.isOnline = false, this.gender, this.showGender = true, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) this.emailVerifiedAt, this.onboardingCompleted = false, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) this.createdAt, this.isFollowing = false, this.followersCount = 0, this.followingCount = 0, this.hasPaymentPassword = false, final  List<String> stickers = const <String>[], final  List<String> interests = const <String>[], @JsonKey(fromJson: communityTitleListFromJson, toJson: communityTitleListToJson) final  List<CommunityTitle> titles = const <CommunityTitle>[], final  Map<String, dynamic>? socialLinks, this.voiceBioUrl, final  Map<String, dynamic>? availability, @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) this.avatar, @JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) this.banner, final  Map<String, dynamic>? extensions}): _stickers = stickers,_interests = interests,_titles = titles,_socialLinks = socialLinks,_availability = availability,_extensions = extensions,super._();
  factory _User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

@override final  String id;
@override final  String username;
@override final  String displayName;
@override final  String? email;
@override final  String? avatarUrl;
@override final  String? bannerUrl;
@override final  String? bio;
@override final  String? usernameColor;
@override final  String? avatarFrame;
@override@JsonKey() final  int level;
@override@JsonKey() final  bool isOnline;
@override final  String? gender;
@override@JsonKey() final  bool showGender;
@override@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) final  DateTime? emailVerifiedAt;
@override@JsonKey() final  bool onboardingCompleted;
@override@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) final  DateTime? createdAt;
@override@JsonKey() final  bool isFollowing;
@override@JsonKey() final  int followersCount;
@override@JsonKey() final  int followingCount;
@override@JsonKey() final  bool hasPaymentPassword;
 final  List<String> _stickers;
@override@JsonKey() List<String> get stickers {
  if (_stickers is EqualUnmodifiableListView) return _stickers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stickers);
}

 final  List<String> _interests;
@override@JsonKey() List<String> get interests {
  if (_interests is EqualUnmodifiableListView) return _interests;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_interests);
}

/// Títulos comunitarios asignados por los administradores del círculo.
 final  List<CommunityTitle> _titles;
/// Títulos comunitarios asignados por los administradores del círculo.
@override@JsonKey(fromJson: communityTitleListFromJson, toJson: communityTitleListToJson) List<CommunityTitle> get titles {
  if (_titles is EqualUnmodifiableListView) return _titles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_titles);
}

 final  Map<String, dynamic>? _socialLinks;
@override Map<String, dynamic>? get socialLinks {
  final value = _socialLinks;
  if (value == null) return null;
  if (_socialLinks is EqualUnmodifiableMapView) return _socialLinks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  String? voiceBioUrl;
 final  Map<String, dynamic>? _availability;
@override Map<String, dynamic>? get availability {
  final value = _availability;
  if (value == null) return null;
  if (_availability is EqualUnmodifiableMapView) return _availability;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) final  Media? avatar;
@override@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) final  Media? banner;
 final  Map<String, dynamic>? _extensions;
@override Map<String, dynamic>? get extensions {
  final value = _extensions;
  if (value == null) return null;
  if (_extensions is EqualUnmodifiableMapView) return _extensions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserCopyWith<_User> get copyWith => __$UserCopyWithImpl<_User>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _User&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.email, email) || other.email == email)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.bannerUrl, bannerUrl) || other.bannerUrl == bannerUrl)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.usernameColor, usernameColor) || other.usernameColor == usernameColor)&&(identical(other.avatarFrame, avatarFrame) || other.avatarFrame == avatarFrame)&&(identical(other.level, level) || other.level == level)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.showGender, showGender) || other.showGender == showGender)&&(identical(other.emailVerifiedAt, emailVerifiedAt) || other.emailVerifiedAt == emailVerifiedAt)&&(identical(other.onboardingCompleted, onboardingCompleted) || other.onboardingCompleted == onboardingCompleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isFollowing, isFollowing) || other.isFollowing == isFollowing)&&(identical(other.followersCount, followersCount) || other.followersCount == followersCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount)&&(identical(other.hasPaymentPassword, hasPaymentPassword) || other.hasPaymentPassword == hasPaymentPassword)&&const DeepCollectionEquality().equals(other._stickers, _stickers)&&const DeepCollectionEquality().equals(other._interests, _interests)&&const DeepCollectionEquality().equals(other._titles, _titles)&&const DeepCollectionEquality().equals(other._socialLinks, _socialLinks)&&(identical(other.voiceBioUrl, voiceBioUrl) || other.voiceBioUrl == voiceBioUrl)&&const DeepCollectionEquality().equals(other._availability, _availability)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.banner, banner) || other.banner == banner)&&const DeepCollectionEquality().equals(other._extensions, _extensions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,username,displayName,email,avatarUrl,bannerUrl,bio,usernameColor,avatarFrame,level,isOnline,gender,showGender,emailVerifiedAt,onboardingCompleted,createdAt,isFollowing,followersCount,followingCount,hasPaymentPassword,const DeepCollectionEquality().hash(_stickers),const DeepCollectionEquality().hash(_interests),const DeepCollectionEquality().hash(_titles),const DeepCollectionEquality().hash(_socialLinks),voiceBioUrl,const DeepCollectionEquality().hash(_availability),avatar,banner,const DeepCollectionEquality().hash(_extensions)]);

@override
String toString() {
  return 'User(id: $id, username: $username, displayName: $displayName, email: $email, avatarUrl: $avatarUrl, bannerUrl: $bannerUrl, bio: $bio, usernameColor: $usernameColor, avatarFrame: $avatarFrame, level: $level, isOnline: $isOnline, gender: $gender, showGender: $showGender, emailVerifiedAt: $emailVerifiedAt, onboardingCompleted: $onboardingCompleted, createdAt: $createdAt, isFollowing: $isFollowing, followersCount: $followersCount, followingCount: $followingCount, hasPaymentPassword: $hasPaymentPassword, stickers: $stickers, interests: $interests, titles: $titles, socialLinks: $socialLinks, voiceBioUrl: $voiceBioUrl, availability: $availability, avatar: $avatar, banner: $banner, extensions: $extensions)';
}


}

/// @nodoc
abstract mixin class _$UserCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$UserCopyWith(_User value, $Res Function(_User) _then) = __$UserCopyWithImpl;
@override @useResult
$Res call({
 String id, String username, String displayName, String? email, String? avatarUrl, String? bannerUrl, String? bio, String? usernameColor, String? avatarFrame, int level, bool isOnline, String? gender, bool showGender,@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) DateTime? emailVerifiedAt, bool onboardingCompleted,@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) DateTime? createdAt, bool isFollowing, int followersCount, int followingCount, bool hasPaymentPassword, List<String> stickers, List<String> interests,@JsonKey(fromJson: communityTitleListFromJson, toJson: communityTitleListToJson) List<CommunityTitle> titles, Map<String, dynamic>? socialLinks, String? voiceBioUrl, Map<String, dynamic>? availability,@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? avatar,@JsonKey(fromJson: mediaFromJson, toJson: mediaToJson) Media? banner, Map<String, dynamic>? extensions
});


@override $MediaCopyWith<$Res>? get avatar;@override $MediaCopyWith<$Res>? get banner;

}
/// @nodoc
class __$UserCopyWithImpl<$Res>
    implements _$UserCopyWith<$Res> {
  __$UserCopyWithImpl(this._self, this._then);

  final _User _self;
  final $Res Function(_User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? displayName = null,Object? email = freezed,Object? avatarUrl = freezed,Object? bannerUrl = freezed,Object? bio = freezed,Object? usernameColor = freezed,Object? avatarFrame = freezed,Object? level = null,Object? isOnline = null,Object? gender = freezed,Object? showGender = null,Object? emailVerifiedAt = freezed,Object? onboardingCompleted = null,Object? createdAt = freezed,Object? isFollowing = null,Object? followersCount = null,Object? followingCount = null,Object? hasPaymentPassword = null,Object? stickers = null,Object? interests = null,Object? titles = null,Object? socialLinks = freezed,Object? voiceBioUrl = freezed,Object? availability = freezed,Object? avatar = freezed,Object? banner = freezed,Object? extensions = freezed,}) {
  return _then(_User(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,bannerUrl: freezed == bannerUrl ? _self.bannerUrl : bannerUrl // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,usernameColor: freezed == usernameColor ? _self.usernameColor : usernameColor // ignore: cast_nullable_to_non_nullable
as String?,avatarFrame: freezed == avatarFrame ? _self.avatarFrame : avatarFrame // ignore: cast_nullable_to_non_nullable
as String?,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,isOnline: null == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,showGender: null == showGender ? _self.showGender : showGender // ignore: cast_nullable_to_non_nullable
as bool,emailVerifiedAt: freezed == emailVerifiedAt ? _self.emailVerifiedAt : emailVerifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,onboardingCompleted: null == onboardingCompleted ? _self.onboardingCompleted : onboardingCompleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isFollowing: null == isFollowing ? _self.isFollowing : isFollowing // ignore: cast_nullable_to_non_nullable
as bool,followersCount: null == followersCount ? _self.followersCount : followersCount // ignore: cast_nullable_to_non_nullable
as int,followingCount: null == followingCount ? _self.followingCount : followingCount // ignore: cast_nullable_to_non_nullable
as int,hasPaymentPassword: null == hasPaymentPassword ? _self.hasPaymentPassword : hasPaymentPassword // ignore: cast_nullable_to_non_nullable
as bool,stickers: null == stickers ? _self._stickers : stickers // ignore: cast_nullable_to_non_nullable
as List<String>,interests: null == interests ? _self._interests : interests // ignore: cast_nullable_to_non_nullable
as List<String>,titles: null == titles ? _self._titles : titles // ignore: cast_nullable_to_non_nullable
as List<CommunityTitle>,socialLinks: freezed == socialLinks ? _self._socialLinks : socialLinks // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,voiceBioUrl: freezed == voiceBioUrl ? _self.voiceBioUrl : voiceBioUrl // ignore: cast_nullable_to_non_nullable
as String?,availability: freezed == availability ? _self._availability : availability // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as Media?,banner: freezed == banner ? _self.banner : banner // ignore: cast_nullable_to_non_nullable
as Media?,extensions: freezed == extensions ? _self._extensions : extensions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaCopyWith<$Res>? get avatar {
    if (_self.avatar == null) {
    return null;
  }

  return $MediaCopyWith<$Res>(_self.avatar!, (value) {
    return _then(_self.copyWith(avatar: value));
  });
}/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MediaCopyWith<$Res>? get banner {
    if (_self.banner == null) {
    return null;
  }

  return $MediaCopyWith<$Res>(_self.banner!, (value) {
    return _then(_self.copyWith(banner: value));
  });
}
}

// dart format on
