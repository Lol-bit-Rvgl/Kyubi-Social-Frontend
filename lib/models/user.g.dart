// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  id: json['id'] as String,
  username: json['username'] as String,
  displayName: json['displayName'] as String,
  email: json['email'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  bannerUrl: json['bannerUrl'] as String?,
  bio: json['bio'] as String?,
  usernameColor: json['usernameColor'] as String?,
  avatarFrame: json['avatarFrame'] as String?,
  level: (json['level'] as num?)?.toInt() ?? 1,
  isOnline: json['isOnline'] as bool? ?? false,
  gender: json['gender'] as String?,
  showGender: json['showGender'] as bool? ?? true,
  emailVerifiedAt: nullableDateFromJson(json['emailVerifiedAt']),
  onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
  createdAt: nullableDateFromJson(json['createdAt']),
  isFollowing: json['isFollowing'] as bool? ?? false,
  followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
  followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
  hasPaymentPassword: json['hasPaymentPassword'] as bool? ?? false,
  stickers:
      (json['stickers'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  interests:
      (json['interests'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  titles: json['titles'] == null
      ? const <CommunityTitle>[]
      : communityTitleListFromJson(json['titles']),
  socialLinks: json['socialLinks'] as Map<String, dynamic>?,
  voiceBioUrl: json['voiceBioUrl'] as String?,
  availability: json['availability'] as Map<String, dynamic>?,
  avatar: mediaFromJson(json['avatar']),
  banner: mediaFromJson(json['banner']),
  extensions: json['extensions'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'displayName': instance.displayName,
  'email': instance.email,
  'avatarUrl': instance.avatarUrl,
  'bannerUrl': instance.bannerUrl,
  'bio': instance.bio,
  'usernameColor': instance.usernameColor,
  'avatarFrame': instance.avatarFrame,
  'level': instance.level,
  'isOnline': instance.isOnline,
  'gender': instance.gender,
  'showGender': instance.showGender,
  'emailVerifiedAt': nullableDateToJson(instance.emailVerifiedAt),
  'onboardingCompleted': instance.onboardingCompleted,
  'createdAt': nullableDateToJson(instance.createdAt),
  'isFollowing': instance.isFollowing,
  'followersCount': instance.followersCount,
  'followingCount': instance.followingCount,
  'hasPaymentPassword': instance.hasPaymentPassword,
  'stickers': instance.stickers,
  'interests': instance.interests,
  'titles': communityTitleListToJson(instance.titles),
  'socialLinks': instance.socialLinks,
  'voiceBioUrl': instance.voiceBioUrl,
  'availability': instance.availability,
  'avatar': mediaToJson(instance.avatar),
  'banner': mediaToJson(instance.banner),
  'extensions': instance.extensions,
};
