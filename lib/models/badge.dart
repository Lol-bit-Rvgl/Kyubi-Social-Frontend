/// Catálogo canónico de insignias de perfil.
///
/// Única fuente de verdad en frontend: tanto el perfil propio como el
/// perfil visitado deben iterar sobre [BadgeCatalog.allBadges] en lugar de
/// mantener listas estáticas duplicadas por vista.
///
/// El estado bloqueado/desbloqueado de cada insignia se determina comparando
/// [BadgeItem.id] con los IDs reales del usuario (`user.badges`).
class BadgeItem {
  const BadgeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
}

class BadgeCatalog {
  const BadgeCatalog._();

  static const List<BadgeItem> allBadges = [
    BadgeItem(
      id: 'pionero',
      title: 'Pionero Kyubi',
      description: 'Miembro de la primera generación',
      icon: '⭐',
    ),
    BadgeItem(
      id: 'racha',
      title: 'Racha Legendaria',
      description: 'Más de 7 días consecutivos',
      icon: '🔥',
    ),
    BadgeItem(
      id: 'maestro_rol',
      title: 'Maestro de Rol',
      description: 'Participante activo en salas de roleplay',
      icon: '🎭',
    ),
    BadgeItem(
      id: 'creador_visual',
      title: 'Creador Visual',
      description: 'Publicaciones destacadas en el feed',
      icon: '🎨',
    ),
    BadgeItem(
      id: 'guardian_social',
      title: 'Guardián Social',
      description: 'Contribuyente ejemplar en círculos',
      icon: '🛡️',
    ),
  ];

  /// Insignia dinámica de membresía premium (fuera del catálogo base).
  static const BadgeItem vip = BadgeItem(
    id: 'vip',
    title: 'Rango VIP',
    description: 'Membresía premium activa',
    icon: '👑',
  );
}
