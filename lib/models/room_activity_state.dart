/// Tipos de actividad que pueden estar activos en una sala.
enum ActivityType {
  none('Sin actividad'),
  cinema('Cine'),
  roleplayStage('Roleplay'),
  voiceRoom('Voz');

  const ActivityType(this.label);
  final String label;
}

/// Estado de la actividad actual en una sala.
///
/// Controla la cabecera superior del [SalaDetailScreen]: cuando una actividad
/// está activa, el layout muestra el widget de actividad y reduce el chat.
/// Al pausar o cerrar, transiciona limpiamente al modo chat completo.
class RoomActivityState {
  const RoomActivityState({
    this.type = ActivityType.none,
    this.isActive = false,
    this.title,
    this.metadata = const {},
  });

  /// Tipo de actividad actual.
  final ActivityType type;

  /// Si la actividad está en curso.
  final bool isActive;

  /// Título descriptivo de la actividad (ej. nombre de la película).
  final String? title;

  /// Datos adicionales específicos del tipo de actividad.
  /// - `cinema`: `{ 'videoUrl': '...', 'currentTime': 120, 'isPlaying': true }`
  /// - `roleplayStage`: `{ 'currentTurn': 'userId', 'turnNumber': 3 }`
  /// - `voiceRoom`: `{ 'participantCount': 5 }`
  final Map<String, dynamic> metadata;

  RoomActivityState copyWith({
    ActivityType? type,
    bool? isActive,
    String? title,
    Map<String, dynamic>? metadata,
  }) {
    return RoomActivityState(
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      title: title ?? this.title,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Crea un estado inactivo (sin actividad).
  const RoomActivityState.none()
    : type = ActivityType.none,
      isActive = false,
      title = null,
      metadata = const {};

  /// Si hay una actividad activa.
  bool get hasActiveActivity => isActive && type != ActivityType.none;
}
