import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import 'voice_foreground_service.dart';

enum VoiceConnectionStatus { idle, connecting, connected, error }

/// Estado reactivo de un participante dentro del canal de voz.
class VoiceParticipant {
  const VoiceParticipant({
    required this.identity,
    required this.name,
    required this.isSpeaking,
    required this.isMicEnabled,
    required this.isYou,
    this.avatarUrl,
    this.role,
  });

  final String identity;
  final String name;
  final String? avatarUrl;
  final String? role;
  final bool isSpeaking;
  final bool isMicEnabled;
  final bool isYou;

  /// Copia forzada como "silenciado" por moderación remota: se apaga el
  /// micrófono y se oculta el indicador de habla aunque LiveKit aún reporte
  /// la pista activa durante un instante.
  VoiceParticipant mutedCopy() => VoiceParticipant(
        identity: identity,
        name: name,
        avatarUrl: avatarUrl,
        role: role,
        isSpeaking: false,
        isMicEnabled: false,
        isYou: isYou,
      );
}

/// Pide el permiso de micrófono (Android/iOS) y devuelve si fue concedido.
Future<bool> ensureMicrophonePermission() async {
  final status = await Permission.microphone.request();
  return status.isGranted;
}

/// Contenedor del estado audio de LiveKit. Se conecta a las salas
/// `sala_<id>` (chat de sala) o `dm_<idMenor>_<idMayor>` (llamadas directas)
/// creadas por el backend y rebota los cambios hacia el notifier.
class VoiceRoomController extends ChangeNotifier {
  Room? _room;
  VoiceConnectionStatus _status = VoiceConnectionStatus.idle;
  String? _error;
  String _roomName = '';

  String? _selfAvatarUrl;
  bool _isDeafened = false;
  CancelListenFunc? _cancelRoomEvents;

  Room? get room => _room;
  bool get isDeafened => _isDeafened;
  VoiceConnectionStatus get status => _status;
  String? get error => _error;
  String get roomName => _roomName;
  bool get isConnected =>
      _status == VoiceConnectionStatus.connected && _room != null;

  bool get isMicrophoneEnabled =>
      _room?.localParticipant?.isMicrophoneEnabled() ?? false;

  List<VoiceParticipant> get participants {
    final room = _room;
    if (room == null) return const [];

    final result = <VoiceParticipant>[];
    final local = room.localParticipant;
    if (local != null) result.add(_describe(local, isYou: true));
    result.addAll(
      room.remoteParticipants.values
          .map((p) => _describe(p, isYou: false)),
    );
    result.sort((a, b) {
      if (a.isYou != b.isYou) return a.isYou ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  VoiceParticipant _describe(Participant p, {required bool isYou}) {
    final name = p.name.isEmpty ? p.identity : p.name;
    String? avatarUrl;
    String? role;
    final metadata = p.metadata;
    if (metadata != null && metadata.isNotEmpty) {
      try {
        final decoded = jsonDecode(metadata) as Map<String, dynamic>;
        avatarUrl = decoded['avatarUrl'] as String?;
        role = decoded['role'] as String?;
      } catch (_) {}
    }
    if (isYou && avatarUrl == null) avatarUrl = _selfAvatarUrl;
    return VoiceParticipant(
      identity: p.identity,
      name: name,
      avatarUrl: avatarUrl,
      role: role,
      isSpeaking: p.isSpeaking,
      isMicEnabled: p.isMicrophoneEnabled(),
      isYou: isYou,
    );
  }

  Future<void> connect({
    required String url,
    required String token,
    required String roomName,
    required String identity,
    required String displayName,
    String? avatarUrl,
  }) async {
    if (_status == VoiceConnectionStatus.connecting || isConnected) return;

    // Verificar y solicitar permiso de micrófono antes de conectar
    final micGranted = await Permission.microphone.isGranted;
    if (!micGranted) {
      final req = await Permission.microphone.request();
      if (!req.isGranted) {
        debugPrint('[voice] Permiso de micrófono no concedido. Abortando conexión.');
        _status = VoiceConnectionStatus.error;
        _error = 'Permiso de micrófono requerido para el canal de voz.';
        notifyListeners();
        return;
      }
    }

    _roomName = roomName;
    _selfAvatarUrl = avatarUrl;
    _error = null;
    _status = VoiceConnectionStatus.connecting;
    notifyListeners();

    final room = Room(roomOptions: const RoomOptions(adaptiveStream: true));
    _room = room;
    _isDeafened = false;
    room.addListener(_onRoomChanged);
    _cancelRoomEvents?.call();
    _cancelRoomEvents = room.events.listen((event) async {
      if (event is TrackSubscribedEvent) {
        if (_isDeafened && event.track.kind == TrackType.AUDIO) {
          try {
            event.track.mediaStreamTrack.enabled = false;
            await event.track.disable();
            await event.publication.disable();
          } catch (_) {}
          // Asegurar silencio en el siguiente ciclo tras el start() de LiveKit
          Future.microtask(() async {
            try {
              event.track.mediaStreamTrack.enabled = false;
              await event.track.disable();
            } catch (_) {}
          });
        }
      }
    });

    try {
      await room.connect(url, token).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw TimeoutException(
            'Tiempo de espera agotado al conectar con el servidor de voz.',
          );
        },
      );
      _status = VoiceConnectionStatus.connected;
      // Iniciar Foreground Service y WakeLock para llamadas de voz en segundo plano ÚNICAMENTE si está conectado
      if (_status == VoiceConnectionStatus.connected) {
        await VoiceForegroundService.instance.start(
          title: 'Kyubi — Chat de Voz Activo',
          body: _roomName.isNotEmpty
              ? 'Conectado a $_roomName'
              : 'Conectado a la sala',
        );
      }
    } catch (error) {
      debugPrint('[voice] room.connect error: $error (room=$roomName, url=$url)');
      _room = null;
      _cancelRoomEvents?.call();
      _cancelRoomEvents = null;
      room.removeListener(_onRoomChanged);
      try {
        await room.disconnect();
      } catch (_) {}
      await room.dispose();
      await VoiceForegroundService.instance.stop();
      _status = VoiceConnectionStatus.error;
      _error = error is TimeoutException
          ? 'Tiempo de conexión agotado. Comprueba tu red.'
          : 'No se pudo conectar al canal de voz';
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  void _onRoomChanged() => notifyListeners();

  Future<void> setMicrophoneEnabled(bool enabled) async {
    final local = _room?.localParticipant;
    if (local == null) return;
    await local.setMicrophoneEnabled(enabled);
    if (VoiceForegroundService.instance.isRunning) {
      unawaited(VoiceForegroundService.instance.update(
        title: 'Kyubi — Chat de Voz Activo',
        body: enabled ? 'Micrófono activo' : 'Micrófono silenciado',
      ));
    }
    notifyListeners();
  }

  Future<bool> toggleMic() async {
    final local = _room?.localParticipant;
    if (local == null) return false;
    final enable = !local.isMicrophoneEnabled();
    await setMicrophoneEnabled(enable);
    return enable;
  }

  /// Aplica el ensordecimiento silenciando o reactivando las pistas remotas.
  Future<void> applyDeafen(bool deafened) async {
    _isDeafened = deafened;
    final room = _room;
    if (room != null) {
      for (final participant in room.remoteParticipants.values) {
        for (final publication in participant.audioTrackPublications) {
          try {
            final track = publication.track;
            if (track != null) {
              track.mediaStreamTrack.enabled = !deafened;
              if (deafened) {
                await track.disable();
              } else {
                await track.enable();
              }
            }
            if (deafened) {
              await publication.disable();
            } else {
              await publication.enable();
            }
          } catch (e) {
            debugPrint('[voice] Error toggling audio track: $e');
          }
        }
      }
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    await VoiceForegroundService.instance.stop();
    VoiceForegroundService.instance.onHangup = null;
    final room = _room;
    _room = null;
    _isDeafened = false;
    _cancelRoomEvents?.call();
    _cancelRoomEvents = null;
    if (room != null) {
      room.removeListener(_onRoomChanged);
      try {
        await room.disconnect();
      } catch (_) {}
      await room.dispose();
    }
    _roomName = '';
    _status = VoiceConnectionStatus.idle;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(VoiceForegroundService.instance.stop());
    VoiceForegroundService.instance.onHangup = null;
    final room = _room;
    _room = null;
    _isDeafened = false;
    _cancelRoomEvents?.call();
    _cancelRoomEvents = null;
    if (room != null) {
      room.removeListener(_onRoomChanged);
      room.dispose();
    }
    super.dispose();
  }
}

class VoiceRoomState {
  const VoiceRoomState({
    this.status = VoiceConnectionStatus.idle,
    this.error,
    this.roomName = '',
    this.participants = const [],
    this.isMicEnabled = false,
    this.isMuted = true,
    this.isDeafened = false,
    this.micBusy = false,
    this.mutedIds = const {},
  });

  final VoiceConnectionStatus status;
  final String? error;
  final String roomName;
  final List<VoiceParticipant> participants;
  final bool isMicEnabled;
  final bool isMuted;
  final bool isDeafened;
  final bool micBusy;

  /// Identidades silenciadas por moderación remota del canal (Host/Co-Host).
  final Set<String> mutedIds;

  bool get isConnected =>
      status == VoiceConnectionStatus.connected && roomName.isNotEmpty;

  /// ID de la sala activa (removiendo el prefijo de transporte `sala_` si existe).
  String? get activeRoomId {
    if (roomName.isEmpty) return null;
    if (roomName.startsWith('sala_')) {
      return roomName.substring(5);
    }
    return roomName;
  }

  bool get isConnecting => status == VoiceConnectionStatus.connecting;

  VoiceRoomState copyWith({
    VoiceConnectionStatus? status,
    String? error,
    String? roomName,
    List<VoiceParticipant>? participants,
    bool? isMicEnabled,
    bool? isMuted,
    bool? isDeafened,
    bool? micBusy,
    Set<String>? mutedIds,
  }) {
    final bool nextMuted;
    if (isMuted != null) {
      nextMuted = isMuted;
    } else if (isMicEnabled != null) {
      nextMuted = !isMicEnabled;
    } else {
      nextMuted = this.isMuted;
    }
    final bool nextMic = isMicEnabled ?? !nextMuted;

    return VoiceRoomState(
      status: status ?? this.status,
      error: error ?? this.error,
      roomName: roomName ?? this.roomName,
      participants: participants ?? this.participants,
      isMicEnabled: nextMic,
      isMuted: nextMuted,
      isDeafened: isDeafened ?? this.isDeafened,
      micBusy: micBusy ?? this.micBusy,
      mutedIds: mutedIds ?? this.mutedIds,
    );
  }
}

final voiceRoomProvider = NotifierProvider<VoiceRoomNotifier, VoiceRoomState>(
  VoiceRoomNotifier.new,
);

class VoiceRoomNotifier extends Notifier<VoiceRoomState> {
  VoiceRoomController? _controller;

  VoiceRoomController get _ctrl => _controller ??=
      VoiceRoomController()..addListener(_sync);

  @override
  VoiceRoomState build() {
    ref.onDispose(() {
      final c = _controller;
      _controller = null;
      if (c != null) {
        c.removeListener(_sync);
        c.dispose();
      }
    });
    return const VoiceRoomState();
  }

  void _sync() {
    final c = _controller;
    if (c == null) return;
    final mutedIds = state.mutedIds;
    final participants = c.participants
        .map((p) => mutedIds.contains(p.identity) ? p.mutedCopy() : p)
        .toList();
    final isMicEnabled = c.isMicrophoneEnabled;
    state = state.copyWith(
      status: c.status,
      error: c.error,
      roomName: c.roomName,
      participants: participants,
      isMicEnabled: isMicEnabled,
      isMuted: !isMicEnabled,
      isDeafened: c.isDeafened,
      mutedIds: mutedIds,
    );
  }

  Future<bool> joinRoom({
    required String url,
    required String token,
    required String roomName,
    required String identity,
    required String displayName,
    String? avatarUrl,
  }) async {
    final c = _ctrl;
    try {
      await c.connect(
        url: url,
        token: token,
        roomName: roomName,
        identity: identity,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      VoiceForegroundService.instance.onHangup = () {
        leaveRoom();
      };
      _sync();
      return true;
    } catch (_) {
      _sync();
      return false;
    }
  }

  Future<void> leaveRoom() async {
    final c = _controller;
    if (c != null) await c.disconnect();
    await VoiceForegroundService.instance.stop();
    VoiceForegroundService.instance.onHangup = null;
    state = state.copyWith(
      status: VoiceConnectionStatus.idle,
      roomName: '',
      participants: const [],
      mutedIds: const {},
      isDeafened: false,
      isMuted: true,
      isMicEnabled: false,
    );
    _sync();
  }

  /// Alias de conveniencia para [leaveRoom].
  Future<void> leaveVoice() => leaveRoom();

  /// Enciende/apaga el micrófono local (usado también al recibir un
  /// `room:voice_moderated` de mute desde el servidor de salas).
  Future<void> setMic(bool enabled) async {
    final c = _controller;
    if (c == null) return;
    await c.setMicrophoneEnabled(enabled);
    state = state.copyWith(
      isMicEnabled: enabled,
      isMuted: !enabled,
    );
    _sync();
  }

  /// Marca/desmarca un participante remoto como silenciado por moderación.
  /// El efecto visual (mic apagado) se aplica de inmediato; el servidor de
  /// salas ya aplicó el cambio real sobre LiveKit vía `room:voice-moderation`.
  void setRemoteMuted(String identity, {required bool muted}) {
    final next = Set<String>.of(state.mutedIds);
    if (muted) {
      next.add(identity);
    } else {
      next.remove(identity);
    }
    state = state.copyWith(mutedIds: next);
    _sync();
  }

  /// Alterna el estado del micrófono local (mute / unmute).
  /// Llama directamente a la API de LiveKit setMicrophoneEnabled.
  Future<bool> toggleMicrophone() async {
    final room = _ctrl.room;
    final localParticipant = room?.localParticipant;
    if (localParticipant == null) return false;

    state = state.copyWith(micBusy: true);
    try {
      // Si el usuario está ensordecido y desea desmutear su micrófono,
      // se retira el ensordecimiento para permitir comunicación bidireccional.
      if (state.isDeafened) {
        await toggleDeafen();
        await localParticipant.setMicrophoneEnabled(true);
        state = state.copyWith(
          isMuted: false,
          isMicEnabled: true,
          isDeafened: false,
        );
        _sync();
        return true;
      }

      final newMuteState = !state.isMuted;
      await localParticipant.setMicrophoneEnabled(!newMuteState);
      state = state.copyWith(
        isMuted: newMuteState,
        isMicEnabled: !newMuteState,
      );
      _sync();
      return !newMuteState;
    } finally {
      state = state.copyWith(micBusy: false);
    }
  }

  /// Alias de conveniencia para compatibilidad con [toggleMic].
  Future<bool> toggleMic() => toggleMicrophone();

  /// Alterna el ensordecimiento (deafen): silencia todo el audio entrante
  /// de la sala y silencia obligatoriamente el micrófono local (estilo Discord).
  Future<void> toggleDeafen() async {
    final newDeafenState = !state.isDeafened;

    // 1. Silenciar o reactivar tracks de audio de todos los participantes remotos
    await _ctrl.applyDeafen(newDeafenState);

    // 2. Si se ensordece, también debe mutear su propio micrófono obligatoriamente
    if (newDeafenState) {
      await _ctrl.setMicrophoneEnabled(false);
    }

    state = state.copyWith(
      isDeafened: newDeafenState,
      isMuted: newDeafenState ? true : state.isMuted,
      isMicEnabled: newDeafenState ? false : state.isMicEnabled,
    );
    _sync();
  }
}