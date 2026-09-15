// Modelo de vacante de rol (RoleSlot) de una publicación de roleplay.
//
// Corresponde al contrato real del backend:
// - `GET/POST /posts/:postId/slots`
// - `GET/PATCH/DELETE /posts/slots/:id`
// - `POST/DELETE /posts/slots/:id/assign`
//
// Se implementa como clase estándar (sin freezed) porque el entorno no puede
// regenerar código con build_runner (incompatibilidad de versiones del
// analyzer con el SDK de Dart instalado).

/// Personaje (OC) asignado a una vacante.
class RoleSlotCharacter {
  const RoleSlotCharacter({
    required this.id,
    required this.name,
    this.alias,
    this.avatarUrl,
    this.tagline,
  });

  final String id;
  final String name;
  final String? alias;
  final String? avatarUrl;
  final String? tagline;

  factory RoleSlotCharacter.fromJson(Map<String, dynamic> json) {
    return RoleSlotCharacter(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      alias: json['alias'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      tagline: json['tagline'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'alias': alias,
    'avatarUrl': avatarUrl,
    'tagline': tagline,
  };
}

/// Usuario que interpreta la vacante asignada.
class RoleSlotUser {
  const RoleSlotUser({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  factory RoleSlotUser.fromJson(Map<String, dynamic> json) {
    return RoleSlotUser(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
  };
}

/// Vacante de rol de una publicación.
class RoleSlot {
  const RoleSlot({
    required this.id,
    required this.postId,
    required this.title,
    this.description,
    this.requirements,
    this.isOpen = true,
    this.assignedCharacterId,
    this.assignedUserId,
    this.assignedCharacter,
    this.assignedUser,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String postId;
  final String title;
  final String? description;
  final String? requirements;
  final bool isOpen;
  final String? assignedCharacterId;
  final String? assignedUserId;
  final RoleSlotCharacter? assignedCharacter;
  final RoleSlotUser? assignedUser;
  final String? createdAt;
  final String? updatedAt;

  /// `true` si la vacante ya tiene un intérprete asignado.
  bool get isAssigned => assignedUserId != null;

  RoleSlot copyWith({
    String? id,
    String? postId,
    String? title,
    String? description,
    String? requirements,
    bool? isOpen,
    String? assignedCharacterId,
    String? assignedUserId,
    RoleSlotCharacter? assignedCharacter,
    RoleSlotUser? assignedUser,
    String? createdAt,
    String? updatedAt,
  }) {
    return RoleSlot(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      title: title ?? this.title,
      description: description ?? this.description,
      requirements: requirements ?? this.requirements,
      isOpen: isOpen ?? this.isOpen,
      assignedCharacterId: assignedCharacterId ?? this.assignedCharacterId,
      assignedUserId: assignedUserId ?? this.assignedUserId,
      assignedCharacter: assignedCharacter ?? this.assignedCharacter,
      assignedUser: assignedUser ?? this.assignedUser,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory RoleSlot.fromJson(Map<String, dynamic> json) {
    final char = json['assignedCharacter'];
    final user = json['assignedUser'];
    return RoleSlot(
      id: json['id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      requirements: json['requirements'] as String?,
      isOpen: json['isOpen'] as bool? ?? true,
      assignedCharacterId: json['assignedCharacterId'] as String?,
      assignedUserId: json['assignedUserId'] as String?,
      assignedCharacter: char is Map<String, dynamic>
          ? RoleSlotCharacter.fromJson(char)
          : null,
      assignedUser: user is Map<String, dynamic>
          ? RoleSlotUser.fromJson(user)
          : null,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'postId': postId,
    'title': title,
    'description': description,
    'requirements': requirements,
    'isOpen': isOpen,
    'assignedCharacterId': assignedCharacterId,
    'assignedUserId': assignedUserId,
    'assignedCharacter': assignedCharacter?.toJson(),
    'assignedUser': assignedUser?.toJson(),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}
