// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_conversation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Conversation {

 String get id; String get type; String? get title;@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) DateTime? get createdAt;@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) DateTime? get updatedAt; List<ChatMember> get members; ChatAuthor? get otherMember; bool get isGroup; Message? get lastMessage; int get unreadCount; String? get lastReadMessageId; bool get muted; Map<String, dynamic>? get extensions;
/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationCopyWith<Conversation> get copyWith => _$ConversationCopyWithImpl<Conversation>(this as Conversation, _$identity);

  /// Serializes this Conversation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Conversation&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.title, title) || other.title == title)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.members, members)&&(identical(other.otherMember, otherMember) || other.otherMember == otherMember)&&(identical(other.isGroup, isGroup) || other.isGroup == isGroup)&&(identical(other.lastMessage, lastMessage) || other.lastMessage == lastMessage)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.lastReadMessageId, lastReadMessageId) || other.lastReadMessageId == lastReadMessageId)&&(identical(other.muted, muted) || other.muted == muted)&&const DeepCollectionEquality().equals(other.extensions, extensions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,title,createdAt,updatedAt,const DeepCollectionEquality().hash(members),otherMember,isGroup,lastMessage,unreadCount,lastReadMessageId,muted,const DeepCollectionEquality().hash(extensions));

@override
String toString() {
  return 'Conversation(id: $id, type: $type, title: $title, createdAt: $createdAt, updatedAt: $updatedAt, members: $members, otherMember: $otherMember, isGroup: $isGroup, lastMessage: $lastMessage, unreadCount: $unreadCount, lastReadMessageId: $lastReadMessageId, muted: $muted, extensions: $extensions)';
}


}

/// @nodoc
abstract mixin class $ConversationCopyWith<$Res>  {
  factory $ConversationCopyWith(Conversation value, $Res Function(Conversation) _then) = _$ConversationCopyWithImpl;
@useResult
$Res call({
 String id, String type, String? title,@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) DateTime? createdAt,@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) DateTime? updatedAt, List<ChatMember> members, ChatAuthor? otherMember, bool isGroup, Message? lastMessage, int unreadCount, String? lastReadMessageId, bool muted, Map<String, dynamic>? extensions
});


$MessageCopyWith<$Res>? get lastMessage;

}
/// @nodoc
class _$ConversationCopyWithImpl<$Res>
    implements $ConversationCopyWith<$Res> {
  _$ConversationCopyWithImpl(this._self, this._then);

  final Conversation _self;
  final $Res Function(Conversation) _then;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? title = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? members = null,Object? otherMember = freezed,Object? isGroup = null,Object? lastMessage = freezed,Object? unreadCount = null,Object? lastReadMessageId = freezed,Object? muted = null,Object? extensions = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,members: null == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as List<ChatMember>,otherMember: freezed == otherMember ? _self.otherMember : otherMember // ignore: cast_nullable_to_non_nullable
as ChatAuthor?,isGroup: null == isGroup ? _self.isGroup : isGroup // ignore: cast_nullable_to_non_nullable
as bool,lastMessage: freezed == lastMessage ? _self.lastMessage : lastMessage // ignore: cast_nullable_to_non_nullable
as Message?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,lastReadMessageId: freezed == lastReadMessageId ? _self.lastReadMessageId : lastReadMessageId // ignore: cast_nullable_to_non_nullable
as String?,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,extensions: freezed == extensions ? _self.extensions : extensions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}
/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageCopyWith<$Res>? get lastMessage {
    if (_self.lastMessage == null) {
    return null;
  }

  return $MessageCopyWith<$Res>(_self.lastMessage!, (value) {
    return _then(_self.copyWith(lastMessage: value));
  });
}
}


/// Adds pattern-matching-related methods to [Conversation].
extension ConversationPatterns on Conversation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Conversation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Conversation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Conversation value)  $default,){
final _that = this;
switch (_that) {
case _Conversation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Conversation value)?  $default,){
final _that = this;
switch (_that) {
case _Conversation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type,  String? title, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)  DateTime? createdAt, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)  DateTime? updatedAt,  List<ChatMember> members,  ChatAuthor? otherMember,  bool isGroup,  Message? lastMessage,  int unreadCount,  String? lastReadMessageId,  bool muted,  Map<String, dynamic>? extensions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that.id,_that.type,_that.title,_that.createdAt,_that.updatedAt,_that.members,_that.otherMember,_that.isGroup,_that.lastMessage,_that.unreadCount,_that.lastReadMessageId,_that.muted,_that.extensions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type,  String? title, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)  DateTime? createdAt, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)  DateTime? updatedAt,  List<ChatMember> members,  ChatAuthor? otherMember,  bool isGroup,  Message? lastMessage,  int unreadCount,  String? lastReadMessageId,  bool muted,  Map<String, dynamic>? extensions)  $default,) {final _that = this;
switch (_that) {
case _Conversation():
return $default(_that.id,_that.type,_that.title,_that.createdAt,_that.updatedAt,_that.members,_that.otherMember,_that.isGroup,_that.lastMessage,_that.unreadCount,_that.lastReadMessageId,_that.muted,_that.extensions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type,  String? title, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)  DateTime? createdAt, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson)  DateTime? updatedAt,  List<ChatMember> members,  ChatAuthor? otherMember,  bool isGroup,  Message? lastMessage,  int unreadCount,  String? lastReadMessageId,  bool muted,  Map<String, dynamic>? extensions)?  $default,) {final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that.id,_that.type,_that.title,_that.createdAt,_that.updatedAt,_that.members,_that.otherMember,_that.isGroup,_that.lastMessage,_that.unreadCount,_that.lastReadMessageId,_that.muted,_that.extensions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Conversation extends Conversation {
  const _Conversation({required this.id, required this.type, this.title, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) this.createdAt, @JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) this.updatedAt, final  List<ChatMember> members = const <ChatMember>[], this.otherMember, this.isGroup = false, this.lastMessage, this.unreadCount = 0, this.lastReadMessageId, this.muted = false, final  Map<String, dynamic>? extensions}): _members = members,_extensions = extensions,super._();
  factory _Conversation.fromJson(Map<String, dynamic> json) => _$ConversationFromJson(json);

@override final  String id;
@override final  String type;
@override final  String? title;
@override@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) final  DateTime? createdAt;
@override@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) final  DateTime? updatedAt;
 final  List<ChatMember> _members;
@override@JsonKey() List<ChatMember> get members {
  if (_members is EqualUnmodifiableListView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_members);
}

@override final  ChatAuthor? otherMember;
@override@JsonKey() final  bool isGroup;
@override final  Message? lastMessage;
@override@JsonKey() final  int unreadCount;
@override final  String? lastReadMessageId;
@override@JsonKey() final  bool muted;
 final  Map<String, dynamic>? _extensions;
@override Map<String, dynamic>? get extensions {
  final value = _extensions;
  if (value == null) return null;
  if (_extensions is EqualUnmodifiableMapView) return _extensions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationCopyWith<_Conversation> get copyWith => __$ConversationCopyWithImpl<_Conversation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConversationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Conversation&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.title, title) || other.title == title)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other._members, _members)&&(identical(other.otherMember, otherMember) || other.otherMember == otherMember)&&(identical(other.isGroup, isGroup) || other.isGroup == isGroup)&&(identical(other.lastMessage, lastMessage) || other.lastMessage == lastMessage)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.lastReadMessageId, lastReadMessageId) || other.lastReadMessageId == lastReadMessageId)&&(identical(other.muted, muted) || other.muted == muted)&&const DeepCollectionEquality().equals(other._extensions, _extensions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,title,createdAt,updatedAt,const DeepCollectionEquality().hash(_members),otherMember,isGroup,lastMessage,unreadCount,lastReadMessageId,muted,const DeepCollectionEquality().hash(_extensions));

@override
String toString() {
  return 'Conversation(id: $id, type: $type, title: $title, createdAt: $createdAt, updatedAt: $updatedAt, members: $members, otherMember: $otherMember, isGroup: $isGroup, lastMessage: $lastMessage, unreadCount: $unreadCount, lastReadMessageId: $lastReadMessageId, muted: $muted, extensions: $extensions)';
}


}

/// @nodoc
abstract mixin class _$ConversationCopyWith<$Res> implements $ConversationCopyWith<$Res> {
  factory _$ConversationCopyWith(_Conversation value, $Res Function(_Conversation) _then) = __$ConversationCopyWithImpl;
@override @useResult
$Res call({
 String id, String type, String? title,@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) DateTime? createdAt,@JsonKey(fromJson: nullableDateFromJson, toJson: nullableDateToJson) DateTime? updatedAt, List<ChatMember> members, ChatAuthor? otherMember, bool isGroup, Message? lastMessage, int unreadCount, String? lastReadMessageId, bool muted, Map<String, dynamic>? extensions
});


@override $MessageCopyWith<$Res>? get lastMessage;

}
/// @nodoc
class __$ConversationCopyWithImpl<$Res>
    implements _$ConversationCopyWith<$Res> {
  __$ConversationCopyWithImpl(this._self, this._then);

  final _Conversation _self;
  final $Res Function(_Conversation) _then;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? title = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? members = null,Object? otherMember = freezed,Object? isGroup = null,Object? lastMessage = freezed,Object? unreadCount = null,Object? lastReadMessageId = freezed,Object? muted = null,Object? extensions = freezed,}) {
  return _then(_Conversation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,members: null == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as List<ChatMember>,otherMember: freezed == otherMember ? _self.otherMember : otherMember // ignore: cast_nullable_to_non_nullable
as ChatAuthor?,isGroup: null == isGroup ? _self.isGroup : isGroup // ignore: cast_nullable_to_non_nullable
as bool,lastMessage: freezed == lastMessage ? _self.lastMessage : lastMessage // ignore: cast_nullable_to_non_nullable
as Message?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,lastReadMessageId: freezed == lastReadMessageId ? _self.lastReadMessageId : lastReadMessageId // ignore: cast_nullable_to_non_nullable
as String?,muted: null == muted ? _self.muted : muted // ignore: cast_nullable_to_non_nullable
as bool,extensions: freezed == extensions ? _self._extensions : extensions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageCopyWith<$Res>? get lastMessage {
    if (_self.lastMessage == null) {
    return null;
  }

  return $MessageCopyWith<$Res>(_self.lastMessage!, (value) {
    return _then(_self.copyWith(lastMessage: value));
  });
}
}

// dart format on
