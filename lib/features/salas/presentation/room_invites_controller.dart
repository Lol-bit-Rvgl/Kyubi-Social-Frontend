import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/room.dart';
import '../../../repositories/room_repository.dart';
import '../../../services/auth_controller.dart';
import '../../../services/providers.dart';
import '../../../services/room_socket.dart';
import 'salas_controller.dart';

/// Estado de las invitaciones pendientes a salas (rol INVITED).
class RoomInvitesState {
  const RoomInvitesState({
    this.invites = const [],
    this.loading = false,
    this.refreshing = false,
    this.error,
    this.busyIds = const {},
  });

  final List<Room> invites;
  final bool loading;
  final bool refreshing;
  final String? error;
  final Set<String> busyIds;

  RoomInvitesState copyWith({
    List<Room>? invites,
    bool? loading,
    bool? refreshing,
    String? error,
    Set<String>? busyIds,
  }) {
    return RoomInvitesState(
      invites: invites ?? this.invites,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      error: error,
      busyIds: busyIds ?? this.busyIds,
    );
  }
}

/// Controlador de invitaciones entrantes a salas privadas.
class RoomInvitesNotifier extends Notifier<RoomInvitesState> {
  RoomRepository get _repo => ref.read(roomRepositoryProvider);
  StreamSubscription<RoomSocketEvent>? _socketSub;
  bool _disposed = false;

  @override
  RoomInvitesState build() {
    ref.onDispose(() {
      _disposed = true;
      _socketSub?.cancel();
    });

    final user = ref.watch(authControllerProvider.select((s) => s.user));
    if (user != null && user.id.isNotEmpty) {
      _listenToSocket();
      Future.microtask(_load);
    }
    return const RoomInvitesState();
  }

  void _listenToSocket() {
    _socketSub = ref.read(roomSocketProvider).events.listen((event) {
      if (_disposed) return;
      if (event is RoomInvited) {
        // Al recibir un evento de invitación en vivo, recargamos la lista
        // para sincronizar los metadatos completos de la sala recibida.
        refresh();
      }
    });
  }

  Future<void> _load() async {
    if (_disposed) return;
    if (state.loading || state.refreshing) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final list = await _repo.getRoomInvites();
      if (_disposed) return;
      state = state.copyWith(
        invites: list,
        loading: false,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    state = state.copyWith(refreshing: true, error: null);
    try {
      final list = await _repo.getRoomInvites();
      if (_disposed) return;
      state = state.copyWith(
        invites: list,
        refreshing: false,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(refreshing: false, error: e.toString());
    }
  }

  /// Acepta la invitación a la sala privada.
  Future<Room?> acceptInvite(String roomId) async {
    if (state.busyIds.contains(roomId)) return null;
    state = state.copyWith(busyIds: {...state.busyIds, roomId});
    try {
      final room = await _repo.acceptRoomInvite(roomId);
      if (_disposed) return room;
      state = state.copyWith(
        invites: state.invites.where((r) => r.id != roomId).toList(),
        busyIds: {...state.busyIds}..remove(roomId),
      );
      // Refrescar salasController para que la sala aparezca en las listas del usuario
      ref.read(salasControllerProvider.notifier).refresh();
      return room;
    } catch (e) {
      if (_disposed) return null;
      state = state.copyWith(
        busyIds: {...state.busyIds}..remove(roomId),
        error: 'No se pudo aceptar la invitación: $e',
      );
      return null;
    }
  }

  /// Rechaza la invitación a la sala privada.
  Future<bool> rejectInvite(String roomId) async {
    if (state.busyIds.contains(roomId)) return false;
    state = state.copyWith(busyIds: {...state.busyIds, roomId});
    try {
      await _repo.rejectRoomInvite(roomId);
      if (_disposed) return true;
      state = state.copyWith(
        invites: state.invites.where((r) => r.id != roomId).toList(),
        busyIds: {...state.busyIds}..remove(roomId),
      );
      return true;
    } catch (e) {
      if (_disposed) return false;
      state = state.copyWith(
        busyIds: {...state.busyIds}..remove(roomId),
        error: 'No se pudo rechazar la invitación: $e',
      );
      return false;
    }
  }

  /// Limpia todo el estado de invitaciones (usado al cerrar sesión).
  void clear() {
    state = const RoomInvitesState();
  }
}

final roomInvitesControllerProvider =
    NotifierProvider<RoomInvitesNotifier, RoomInvitesState>(
  RoomInvitesNotifier.new,
);
