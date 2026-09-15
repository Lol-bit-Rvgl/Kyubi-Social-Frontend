import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/role_slot.dart';
import '../../../repositories/role_slots_repository.dart';
import '../../../services/providers.dart';

/// Estado de las vacantes de rol de una publicación.
class RoleSlotsState {
  const RoleSlotsState({
    this.slots = const [],
    this.loading = false,
    this.refreshing = false,
    this.error,
    this.busyIds = const {},
  });

  final List<RoleSlot> slots;
  final bool loading;
  final bool refreshing;
  final String? error;

  /// IDs de vacantes con una operación en curso (postular/liberar/editar).
  final Set<String> busyIds;

  bool isBusy(String slotId) => busyIds.contains(slotId);

  RoleSlotsState copyWith({
    List<RoleSlot>? slots,
    bool? loading,
    bool? refreshing,
    String? error,
    Set<String>? busyIds,
  }) {
    return RoleSlotsState(
      slots: slots ?? this.slots,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      error: error,
      busyIds: busyIds ?? this.busyIds,
    );
  }
}

/// Controlador de las vacantes de rol de una publicación concreta.
///
/// Se parametro por `postId` (`FamilyNotifier`) para que cada publicación
/// mantenga su propia caché de vacantes.
class RoleSlotsNotifier extends FamilyNotifier<RoleSlotsState, String> {
  RoleSlotsRepository get _repo => ref.read(roleSlotsRepositoryProvider);

  bool _disposed = false;

  @override
  RoleSlotsState build(String arg) {
    ref.onDispose(() => _disposed = true);
    Future.microtask(_load);
    return const RoleSlotsState(loading: true);
  }

  /// Id de la publicación de la que son estas vacantes.
  String get postId => arg;

  Future<void> _load() async {
    try {
      final slots = await _repo.getSlotsForPost(arg);
      if (_disposed) return;
      state = state.copyWith(slots: slots, loading: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    if (_disposed || state.refreshing) return;
    state = state.copyWith(refreshing: true);
    try {
      final slots = await _repo.getSlotsForPost(arg);
      if (_disposed) return;
      state = state.copyWith(slots: slots, refreshing: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(refreshing: false, error: e.toString());
    }
  }

  /// Crea una vacante. Devuelve `true` si se creó correctamente y actualiza
  /// la lista local sin esperar una nueva petición completa.
  Future<bool> createSlot({
    required String title,
    String? description,
    String? requirements,
  }) async {
    try {
      final slot = await _repo.createSlot(
        arg,
        title: title,
        description: description,
        requirements: requirements,
      );
      if (_disposed) return true;
      state = state.copyWith(slots: [...state.slots, slot]);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Edita una vacante existente y la sustituye en el estado local.
  Future<bool> updateSlot(
    String slotId, {
    String? title,
    String? description,
    String? requirements,
    bool? isOpen,
  }) async {
    _setBusy(slotId, true);
    try {
      final updated = await _repo.updateSlot(
        slotId,
        title: title,
        description: description,
        requirements: requirements,
        isOpen: isOpen,
      );
      if (_disposed) return true;
      _replace(updated);
      return true;
    } catch (_) {
      return false;
    } finally {
      _setBusy(slotId, false);
    }
  }

  /// Elimina una vacante y la quita de la lista local.
  Future<bool> deleteSlot(String slotId) async {
    _setBusy(slotId, true);
    try {
      await _repo.deleteSlot(slotId);
      if (_disposed) return true;
      state = state.copyWith(
        slots: state.slots.where((s) => s.id != slotId).toList(),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _setBusy(slotId, false);
    }
  }

  /// Postula un personaje (o el perfil propio si [characterId] es nulo) a la
  /// vacante y actualiza el estado localmente con la respuesta del backend.
  Future<bool> applyToSlot(String slotId, {String? characterId}) async {
    _setBusy(slotId, true);
    try {
      final updated = await _repo.assignSlot(slotId, characterId: characterId);
      if (_disposed) return true;
      _replace(updated);
      return true;
    } catch (_) {
      return false;
    } finally {
      _setBusy(slotId, false);
    }
  }

  /// Libera la vacante (la vuelve a dejar abierta).
  Future<bool> leaveSlot(String slotId) async {
    _setBusy(slotId, true);
    try {
      final updated = await _repo.releaseSlot(slotId);
      if (_disposed) return true;
      _replace(updated);
      return true;
    } catch (_) {
      return false;
    } finally {
      _setBusy(slotId, false);
    }
  }

  /// Devuelve la copia más reciente de una vacante (útil para detalle).
  RoleSlot? slotById(String slotId) {
    for (final slot in state.slots) {
      if (slot.id == slotId) return slot;
    }
    return null;
  }

  void _replace(RoleSlot updated) {
    state = state.copyWith(
      slots: [for (final s in state.slots) s.id == updated.id ? updated : s],
    );
  }

  void _setBusy(String slotId, bool busy) {
    if (_disposed) return;
    final next = {...state.busyIds};
    if (busy) {
      next.add(slotId);
    } else {
      next.remove(slotId);
    }
    state = state.copyWith(busyIds: next);
  }
}

/// Provider de las vacantes de una publicación: `roleSlotsControllerProvider(postId)`.
final roleSlotsControllerProvider =
    NotifierProvider.family<RoleSlotsNotifier, RoleSlotsState, String>(
      RoleSlotsNotifier.new,
    );
