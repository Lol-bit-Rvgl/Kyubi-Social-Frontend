import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/character_repository.dart';
import 'role_character.dart';

/// Modelo de Ficha de Personaje / Original Character (OC) estilo Kubi-Space.
class Character {
  const Character({
    required this.id,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.bio,
    this.age,
    this.gender,
    this.species,
    this.role,
    this.alignment,
    this.personality,
    this.appearance,
    this.background,
    this.abilities = const [],
    this.galleryUrls = const [],
    this.isPublic = true,
    this.themeColor,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? bio;
  final String? age;
  final String? gender;
  final String? species;
  final String? role;
  final String? alignment;
  final String? personality;
  final String? appearance;
  final String? background;
  final List<String> abilities;
  final List<String> galleryUrls;
  final bool isPublic;
  final String? themeColor;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? 'Sin nombre',
      avatarUrl: (json['avatarUrl'] ??
              json['avatar'] ??
              json['imageUrl'] ??
              json['image'] ??
              json['photoUrl']) as String?,
      bio: (json['bio'] ?? json['description'] ?? json['tagline']) as String?,
      age: json['age'] as String?,
      gender: json['gender'] as String?,
      species: json['species'] as String?,
      role: (json['role'] ?? json['tagline'] ?? json['description']) as String?,
      alignment: json['alignment'] as String?,
      personality: json['personality'] as String?,
      appearance: json['appearance'] as String?,
      background: (json['background'] ?? json['lore'] ?? json['description']) as String?,
      abilities:
          (json['abilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      galleryUrls:
          (json['galleryUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isPublic: json['isPublic'] as bool? ?? true,
      themeColor: json['themeColor'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'name': name,
    'avatarUrl': avatarUrl,
    'avatar': avatarUrl,
    'bio': bio,
    'age': age,
    'gender': gender,
    'species': species,
    'role': role,
    'alignment': alignment,
    'personality': personality,
    'appearance': appearance,
    'background': background,
    'abilities': abilities,
    'galleryUrls': galleryUrls,
    'isPublic': isPublic,
    'themeColor': themeColor,
  };

  /// Convierte la ficha de personaje en un Rol para el escenario de sala.
  RoleCharacter toRoleCharacter({String? currentUserId, String? currentUsername}) {
    return RoleCharacter(
      id: id,
      name: name,
      avatarUrl: avatarUrl,
      colorHex: (themeColor != null && themeColor!.isNotEmpty)
          ? (themeColor!.startsWith('#') ? themeColor! : '#$themeColor')
          : '#E5A93C',
      tagline: role ?? bio ?? 'Personaje',
      description: background ?? bio ?? '',
      isTaken: currentUserId != null,
      takenByUserId: currentUserId,
      takenByUsername: currentUsername,
    );
  }
}

/// Provider para obtener los personajes de un usuario específico.
final userCharactersProvider = FutureProvider.family<List<Character>, String>((
  ref,
  userId,
) async {
  final repo = ref.watch(characterRepositoryProvider);
  return repo.getUserCharacters(userId);
});

/// Provider para obtener las fichas de rol del usuario autenticado ("Mis Fichas de Rol").
final myCharactersProvider = FutureProvider<List<Character>>((ref) async {
  final repo = ref.watch(characterRepositoryProvider);
  return repo.getMyRoles();
});
