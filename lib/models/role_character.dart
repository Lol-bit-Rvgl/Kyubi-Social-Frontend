import 'package:flutter/material.dart';

/// Modelo de Ficha de Rol / Personaje (OC) para Salas y Chat de Roleplay.
class RoleCharacter {
  const RoleCharacter({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.colorHex = '#00E5FF',
    this.tagline = '',
    this.description = '',
    this.language = 'Español',
    this.isTaken = false,
    this.takenByUserId,
    this.takenByUsername,
    this.hasActiveMic = false,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final String colorHex;
  final String tagline;
  final String description;
  final String language;
  final bool isTaken;
  final String? takenByUserId;
  final String? takenByUsername;
  final bool hasActiveMic;

  bool get isOccupied => isTaken;
  String? get occupiedBy => takenByUserId;
  String? get occupiedByName => takenByUsername;
  bool get isValid {
    final cleanId = id.trim();
    final cleanName = name.trim().replaceAll(RegExp(r'^[.\s]+$'), '');
    return cleanId.isNotEmpty && cleanName.isNotEmpty;
  }

  Color get color {
    final hex = colorHex.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('0xFF$hex'));
    } else if (hex.length == 8) {
      return Color(int.parse('0x$hex'));
    }
    return const Color(0xFF00E5FF);
  }

  RoleCharacter copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? colorHex,
    String? tagline,
    String? description,
    String? language,
    bool? isTaken,
    String? takenByUserId,
    String? takenByUsername,
    bool? hasActiveMic,
    bool clearOccupant = false,
  }) {
    final shouldClear = clearOccupant || isTaken == false;
    return RoleCharacter(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      colorHex: colorHex ?? this.colorHex,
      tagline: tagline ?? this.tagline,
      description: description ?? this.description,
      language: language ?? this.language,
      isTaken: shouldClear ? false : (isTaken ?? this.isTaken),
      takenByUserId: shouldClear
          ? (isTaken == false && takenByUserId != null ? takenByUserId : null)
          : (takenByUserId ?? this.takenByUserId),
      takenByUsername: shouldClear
          ? (isTaken == false && takenByUsername != null ? takenByUsername : null)
          : (takenByUsername ?? this.takenByUsername),
      hasActiveMic: hasActiveMic ?? this.hasActiveMic,
    );
  }

  /// Retorna una copia de la ficha de personaje completamente vacante y desvinculada de cualquier usuario.
  RoleCharacter toVacant({String? resetId, String? resetName}) {
    if (resetId != null) {
      return RoleCharacter.vacant(
        id: resetId,
        name: resetName ?? 'Slot Vacante',
      );
    }
    return copyWith(clearOccupant: true);
  }

  /// Crea un slot vacante neutral sin dueño ni avatar.
  factory RoleCharacter.vacant({required String id, required String name}) {
    return RoleCharacter(
      id: id,
      name: name,
      isTaken: false,
      takenByUserId: null,
      takenByUsername: null,
      avatarUrl: null,
      colorHex: '#00E5FF',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatarUrl': avatarUrl,
    'avatar': avatarUrl,
    'colorHex': colorHex,
    'tagline': tagline,
    'description': description,
    'language': language,
    'isTaken': isTaken,
    'isOccupied': isTaken,
    'takenByUserId': takenByUserId,
    'occupiedBy': takenByUserId,
    'takenByUsername': takenByUsername,
    'occupiedByName': takenByUsername,
  };

  factory RoleCharacter.fromJson(Map<String, dynamic> json) {
    return RoleCharacter(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: (json['avatarUrl'] ??
              json['avatar'] ??
              json['imageUrl'] ??
              json['image'] ??
              json['photoUrl']) as String?,
      colorHex: json['colorHex'] as String? ??
          json['roleColor'] as String? ??
          json['roleColorHex'] as String? ??
          json['color'] as String? ??
          '#00E5FF',
      tagline: json['tagline'] as String? ?? '',
      description: json['description'] as String? ?? '',
      language: json['language'] as String? ?? 'Español',
      isTaken: (json['isTaken'] == true || json['isOccupied'] == true) ||
          ((json['takenByUserId'] != null || json['occupiedBy'] != null) &&
              json['isTaken'] != false &&
              json['isOccupied'] != false),
      takenByUserId:
          (json['takenByUserId'] ?? json['occupiedBy']) as String?,
      takenByUsername:
          (json['takenByUsername'] ?? json['occupiedByName']) as String?,
    );
  }
}
