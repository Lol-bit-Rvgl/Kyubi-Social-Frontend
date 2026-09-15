import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/room.dart';
import '../../../repositories/room_repository.dart';
import '../../../services/providers.dart';

/// Estado del detalle de una sala: datos + participantes + acciones.
class SalaDetailState {
  const SalaDetailState({
    this.room,
    this.loading = false,
    this.error,
    this.acting = false,
  });

  final Room? room;
  final bool loading;
  final String? error;
  final bool acting;

  SalaDetailState copyWith({
    Room? room,
    bool? loading,
    String? error,
    bool? acting,
  }) {
    return SalaDetailState(
      room: room ?? this.room,
      loading: loading ?? this.loading,
      error: error ?? this.error,
      acting: acting ?? this.acting,
    );
  }
}

class SalaDetailNotifier extends FamilyNotifier<SalaDetailState, String> {
  RoomRepository get _repo => ref.read(roomRepositoryProvider);

  bool _disposed = false;

  @override
  SalaDetailState build(String arg) {
    ref.onDispose(() => _disposed = true);
    _roomId = arg;
    Future.microtask(_load);
    return const SalaDetailState(loading: true);
  }

  late String _roomId;

  Future<void> _load() async {
    if (_disposed) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final room = await _repo.getSala(_roomId);
      if (_disposed) return;
      state = state.copyWith(room: room, loading: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> refresh() => _load();

  /// Entra a la sala (o recupera el estado si ya eres participante).
  Future<void> join() async {
    if (_disposed) return;
    if (state.acting) return;
    state = state.copyWith(acting: true);
    try {
      final room = await _repo.joinSala(_roomId);
      if (_disposed) return;
      state = state.copyWith(room: room, acting: false);
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(acting: false);
      rethrow;
    }
  }

  /// Sale de la sala. Si el host sale, la sala termina.
  Future<void> leave() async {
    if (_disposed) return;
    if (state.acting) return;
    state = state.copyWith(acting: true);
    try {
      final result = await _repo.leaveSala(_roomId);
      if (_disposed) return;
      if (result.ended) {
        final room = state.room;
        state = state.copyWith(
          room: room?.copyWith(
            status: RoomStatus.ended,
            isParticipant: false,
            participantCount: 0,
            participants: const [],
            endedAt: room.endedAt,
          ),
          acting: false,
        );
      } else {
        final room = await _repo.getSala(_roomId);
        if (_disposed) return;
        state = state.copyWith(room: room, acting: false);
      }
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(acting: false);
      rethrow;
    }
  }

  /// Aplica una sala actualizada desde el detalle.
  void applyRoom(Room room) {
    state = state.copyWith(room: room);
  }
}

final salaDetailControllerProvider =
    NotifierProvider.family<SalaDetailNotifier, SalaDetailState, String>(
      SalaDetailNotifier.new,
    );
