/// Título comunitario asignado a un perfil (`serializeCommunityTitle`).
///
/// Cada título tiene un nombre visible y un color hex (p. ej. `#00E5FF`)
/// usado por la UI para las placas estilo Amino. Solo los administradores
/// del círculo pueden crearlos, editarlos o eliminarlos.
class CommunityTitle {
  const CommunityTitle({required this.name, this.colorHex = '#00E5FF'});

  final String name;
  final String colorHex;

  factory CommunityTitle.fromJson(Map<String, dynamic> json) {
    return CommunityTitle(
      name: json['name'] as String? ?? '',
      colorHex:
          (json['colorHex'] as String?) ??
          (json['color'] as String?) ??
          '#00E5FF',
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'colorHex': colorHex};

  CommunityTitle copyWith({String? name, String? colorHex}) {
    return CommunityTitle(
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityTitle &&
          other.name == name &&
          other.colorHex == colorHex;

  @override
  int get hashCode => Object.hash(name, colorHex);
}
