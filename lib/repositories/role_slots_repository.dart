import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/role_slot.dart';

/// Repositorio de vacantes de rol (RoleSlots) de las publicaciones.
///
/// Contrato backend:
/// - `GET    /posts/:postId/slots`          → `{ slots, total }`
/// - `POST   /posts/:postId/slots`          → slot serializado (solo autor)
/// - `GET    /posts/slots/:slotId`          → slot serializado
/// - `PATCH  /posts/slots/:slotId`          → slot serializado (solo autor)
/// - `DELETE /posts/slots/:slotId`          → `{ deleted, slotId }` (solo autor)
/// - `POST   /posts/slots/:slotId/assign`   → slot serializado
/// - `DELETE /posts/slots/:slotId/assign`   → slot serializado
class RoleSlotsRepository {
  RoleSlotsRepository(this._api);

  final ApiClient _api;

  /// Lista las vacantes de una publicación.
  Future<List<RoleSlot>> getSlotsForPost(String postId) async {
    final json = await _api.getJson(AppConfig.postSlots(postId));
    final raw = json['slots'] ?? json['items'] ?? json['data'];
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(RoleSlot.fromJson)
          .toList();
    }
    return const [];
  }

  /// Detalle de una vacante.
  Future<RoleSlot> getSlotDetail(String slotId) async {
    final json = await _api.getJson(AppConfig.slotDetail(slotId));
    return RoleSlot.fromJson(json['slot'] as Map<String, dynamic>? ?? json);
  }

  /// Crea una vacante (solo autor de la publicación).
  Future<RoleSlot> createSlot(
    String postId, {
    required String title,
    String? description,
    String? requirements,
    bool isOpen = true,
  }) async {
    final json = await _api.postJson(
      AppConfig.postSlots(postId),
      data: {
        'title': title,
        'description': ?description,
        'requirements': ?requirements,
        'isOpen': isOpen,
      },
    );
    return RoleSlot.fromJson(json['slot'] as Map<String, dynamic>? ?? json);
  }

  /// Edita una vacante (solo autor). Solo se envían los campos no nulos.
  Future<RoleSlot> updateSlot(
    String slotId, {
    String? title,
    String? description,
    String? requirements,
    bool? isOpen,
  }) async {
    final json = await _api.patchJson(
      AppConfig.slotDetail(slotId),
      data: {
        'title': ?title,
        'description': ?description,
        'requirements': ?requirements,
        'isOpen': ?isOpen,
      },
    );
    return RoleSlot.fromJson(json['slot'] as Map<String, dynamic>? ?? json);
  }

  /// Elimina una vacante (solo autor).
  Future<void> deleteSlot(String slotId) async {
    await _api.deleteJson(AppConfig.slotDetail(slotId));
  }

  /// Postula/asigna un personaje a la vacante. Si [characterId] es nulo el
  /// usuario reclama la vacante sin ficha.
  ///
  /// El backend espera la clave `assignedCharacterId`.
  Future<RoleSlot> assignSlot(String slotId, {String? characterId}) async {
    final json = await _api.postJson(
      AppConfig.slotAssign(slotId),
      data: {'assignedCharacterId': characterId},
    );
    return RoleSlot.fromJson(json['slot'] as Map<String, dynamic>? ?? json);
  }

  /// Libera/desasigna la vacante (la vuelve a dejar abierta).
  Future<RoleSlot> releaseSlot(String slotId) async {
    final json = await _api.deleteJson(AppConfig.slotAssign(slotId));
    return RoleSlot.fromJson(json['slot'] as Map<String, dynamic>? ?? json);
  }
}
