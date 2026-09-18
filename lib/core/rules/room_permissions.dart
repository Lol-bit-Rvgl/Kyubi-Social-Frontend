import '../../models/post_author.dart';
import '../../models/room.dart';

/// Reglas de negocio y permisos de las salas/chat, basadas en Project Z.
class RoomPermissions {
  RoomPermissions._();

  /// Roles con permisos de gestión: el Admin (Owner) y los Co-Admins.
  static bool isAdminRole(String role) =>
      role == 'HOST' || role == 'ADMIN' || role == 'OWNER';

  static bool isCoAdminRole(String role) =>
      role == 'CO_ADMIN' || role == 'COADMIN' || role == 'CO_HOST';

  static bool canManageRole(String role) =>
      isAdminRole(role) || isCoAdminRole(role) || role == 'MODERATOR';

  /// ¿El [room] le concede al usuario permisos de gestión?
  ///
  /// El Admin es el Host/Owner de la sala. Los Co-Admins llegan marcados en el
  /// participante reportado por el backend. [me] es la `PostAuthor` del usuario
  /// local (para detectar si coincide con `host`).
  static bool canManage({Room? room, PostAuthor? me}) {
    if (room == null) return false;
    final myId = me?.id ?? '';
    if (myId.isEmpty) return false;
    if (room.host.id == myId) return true;
    for (final p in room.participants) {
      if (p.user.id == myId && canManageRole(p.role)) return true;
    }
    return false;
  }

  /// Solo Admin/Co-Admin pueden editar info, apariencia y tags de la sala.
  static bool canEdit({Room? room, PostAuthor? me}) =>
      canManage(room: room, me: me);
}
