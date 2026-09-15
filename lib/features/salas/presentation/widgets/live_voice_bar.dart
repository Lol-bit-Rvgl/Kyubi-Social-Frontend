import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';
import '../../../../services/voice/voice_room_controller.dart';

/// Panel Superior Integrado del Canal de Voz (Ref. salas de voz comunitarias).
///
/// Muestra: encabezado "Chat de Voz" con icono de onda, una grilla de avatares
/// grandes de los usuarios conectados a LiveKit (con nombre, badge y halo verde
/// cuando hablan) y el botón de acción principal: "Unirse" (si el usuario aún
/// no entró) o los controles circulares de audio (micrófono / altavoz / colgar).
class LiveVoiceBar extends ConsumerWidget {
  const LiveVoiceBar({
    super.key,
    required this.roomId,
    this.onParticipantTap,
    this.canPowerOff = false,
    this.onPowerOff,
    this.isMinimized = false,
    this.onToggleMinimize,
    this.canManage = false,
    this.onOpenSettings,
    this.isStaffOnly = false,
    this.canJoinVoice = true,
  });

  final String roomId;

  /// Tap sobre un avatar de participante real del canal de LiveKit.
  /// La hoja que se abre (perfil o moderación) la decide el padre según el
  /// rol del usuario local.
  final ValueChanged<VoiceParticipant>? onParticipantTap;

  /// Si el usuario local (host/admin) puede apagar la actividad de voz.
  final bool canPowerOff;

  /// Apaga la actividad de voz: el padre emite `emitModeChange(roomId, 'standard')`.
  final VoidCallback? onPowerOff;

  /// Si el panel se muestra en modo compacto/minimizado.
  final bool isMinimized;

  /// Alterna entre minimizado y expandido.
  final VoidCallback? onToggleMinimize;

  /// Si el usuario tiene rol de gestión (Host / Admin / Co-Admin).
  final bool canManage;

  /// Abre la hoja modal de configuración de voz para staff.
  final VoidCallback? onOpenSettings;

  /// Si el canal de voz está restringido exclusivamente al staff.
  final bool isStaffOnly;

  /// Si el usuario actual tiene permiso para unirse al audio.
  final bool canJoinVoice;

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    if (isStaffOnly && !canJoinVoice) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Solo el staff o miembros autorizados pueden hablar'),
          backgroundColor: Color(0xFF2A121E),
        ),
      );
      return;
    }
    final granted = await ensureMicrophonePermission();
    if (!context.mounted) return;
    if (!granted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Permiso de micrófono denegado')),
      );
      return;
    }
    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Inicia sesión para entrar al canal')),
      );
      return;
    }
    try {
      final creds = await ref.read(voiceRepositoryProvider).roomVoiceToken(roomId);
      if (!context.mounted) return;
      if (creds.token.isEmpty || creds.url.isEmpty) {
        debugPrint('[voice] token vacío para sala $roomId: $creds');
        messenger.showSnackBar(
          const SnackBar(content: Text('El canal de voz no está disponible')),
        );
        return;
      }
      final ok = await ref.read(voiceRoomProvider.notifier).joinRoom(
            url: creds.url,
            token: creds.token,
            roomName: creds.roomName,
            identity: user.id,
            displayName: user.displayName.isEmpty ? user.username : user.displayName,
            avatarUrl: user.effectiveAvatarUrl,
          );
      if (!context.mounted) return;
      if (!ok) {
        final err = ref.read(voiceRoomProvider).error;
        messenger.showSnackBar(
          SnackBar(
            content: Text(err ?? 'No se pudo entrar al canal de voz'),
            backgroundColor: const Color(0xFF2A121E),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      debugPrint('[voice] error al pedir token/join para $roomId: $e');
      final msg = e is ApiException
          ? e.message
          : (e.toString().isEmpty ? 'Error al entrar al canal de voz' : e.toString());
      messenger.showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  Future<void> _toggleMic(BuildContext context, WidgetRef ref) async {
    final voice = ref.read(voiceRoomProvider);
    // Si está silenciado y desea encender el micrófono, comprobar permisos
    if (voice.isMuted) {
      final granted = await ensureMicrophonePermission();
      if (!context.mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de micrófono denegado')),
        );
        return;
      }
    }
    if (!context.mounted) return;
    await ref.read(voiceRoomProvider.notifier).toggleMicrophone();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceRoomProvider);
    final isConnectedToThisRoom =
        voice.isConnected && voice.activeRoomId == roomId;
    final connected = isConnectedToThisRoom;
    final connecting = voice.isConnecting &&
        (voice.activeRoomId == roomId || voice.roomName.isEmpty);
    final participants =
        isConnectedToThisRoom ? voice.participants : const <VoiceParticipant>[];

    // ── Modo Minimizado: Barra compacta (~48-52dp) ──
    if (isMinimized) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppColors.glassGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: connected
                ? AppColors.accentTeal.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.12),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                connected ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                size: 16,
                color: connected ? AppColors.accentTeal : Colors.white70,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Chat de Voz',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _statusColor(voice),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _subtitle(voice),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (connecting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (connected) ...[
              GestureDetector(
                onTap: () => _toggleMic(context, ref),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (voice.isMuted ? Colors.redAccent : Colors.tealAccent)
                        .withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    voice.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    size: 16,
                    color: voice.isMuted ? Colors.redAccent : Colors.tealAccent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(voiceRoomProvider.notifier).toggleDeafen();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (voice.isDeafened ? Colors.redAccent : Colors.white70)
                        .withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    voice.isDeafened
                        ? Icons.headset_off_rounded
                        : Icons.headset_rounded,
                    size: 16,
                    color: voice.isDeafened ? Colors.redAccent : Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => ref.read(voiceRoomProvider.notifier).leaveRoom(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.call_end_rounded,
                    size: 16,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ] else ...[
              GestureDetector(
                onTap: () => _join(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: (isStaffOnly && !canJoinVoice)
                        ? const LinearGradient(
                            colors: [Color(0xFF4A4A5A), Color(0xFF333342)],
                          )
                        : AppColors.mintTurquoise,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (isStaffOnly && !canJoinVoice) ? 'Solo Staff' : 'Unirse',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: (isStaffOnly && !canJoinVoice)
                          ? Colors.white60
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
            if (canManage && onOpenSettings != null) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: 'Ajustes de voz',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpenSettings,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      size: 16,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
            if (canPowerOff && onPowerOff != null) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: 'Finalizar chat de voz',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPowerOff,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.accentCrimson.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.power_settings_new_rounded,
                      size: 16,
                      color: AppColors.accentCrimson,
                    ),
                  ),
                ),
              ),
            ],
            if (onToggleMinimize != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: 'Expandir',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleMinimize,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // ── Modo Expandido ──
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            gradient: AppColors.glassGradient,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: connected
                  ? AppColors.accentTeal.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.12),
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 20,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera fija universal: Título + Estado a la izq, Acciones a la der ──
          _buildHeader(context, voice),

          const SizedBox(height: 14),

          // ── Grilla de avatares grandes (solo conectados a LiveKit) ──
          if (participants.isNotEmpty)
            SizedBox(
              height: 125,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                clipBehavior: Clip.none,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < participants.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          right: i == participants.length - 1 ? 0 : 16,
                        ),
                        child: _ParticipantTile(
                          participant: participants[i],
                          onTap: onParticipantTap == null
                              ? null
                              : () => onParticipantTap!(participants[i]),
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    AppAssets.iconTransmisionesApagadas,
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Nadie está conectado todavía',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          // ── Botón de Acción Principal / Controles circulares ──
          Center(
            child: connecting
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  )
                : connected
                    ? _connectedControls(context, ref, voice)
                    : _JoinButton(
                        onTap: () => _join(context, ref),
                        isStaffOnly: isStaffOnly,
                        canJoin: canJoinVoice,
                      ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  /// Cabecera fija universal: Ícono + Título + Estado a la izquierda,
  /// y botones de acción (Settings / Power / Minimizar) fijos a la derecha.
  Widget _buildHeader(BuildContext context, VoiceRoomState voice) {
    final connected = voice.isConnected;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Izquierda: Ícono + Título + Dot/Badge + Subtítulo ──
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  connected ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                  size: 20,
                  color: connected ? AppColors.accentTeal : Colors.white70,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Chat de Voz',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _statusColor(voice),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (isStaffOnly) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentCrimson.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.accentCrimson.withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'SOLO STAFF',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFF8A80),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(voice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // ── Derecha: Fila de Botones de Acción Rápida (Settings / Power / Minimizar) ──
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canManage && onOpenSettings != null) ...[
              Tooltip(
                message: 'Ajustes de voz',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpenSettings,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (canPowerOff && onPowerOff != null) ...[
              Tooltip(
                message: 'Finalizar chat de voz',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPowerOff,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.accentCrimson.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentCrimson.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.power_settings_new_rounded,
                      size: 18,
                      color: AppColors.accentCrimson,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (onToggleMinimize != null)
              Tooltip(
                message: 'Minimizar',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleMinimize,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Controles circulares cuando el usuario está dentro del canal de voz:
  /// [micrófono mute/unmute] [ensordecerse (deafen)] [colgar].
  Widget _connectedControls(
    BuildContext context,
    WidgetRef ref,
    VoiceRoomState voice,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(
          icon: voice.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          color: voice.isMuted ? Colors.redAccent : Colors.tealAccent,
          enabled: !voice.micBusy,
          tooltip: voice.isMuted ? 'Activar micrófono' : 'Silenciar micrófono',
          onTap: () => _toggleMic(context, ref),
        ),
        const SizedBox(width: 14),
        _RoundButton(
          icon: voice.isDeafened
              ? Icons.headset_off_rounded
              : Icons.headset_rounded,
          color: voice.isDeafened ? Colors.redAccent : Colors.white70,
          tooltip: 'Ensordecerse',
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(voiceRoomProvider.notifier).toggleDeafen();
          },
        ),
        const SizedBox(width: 14),
        _RoundButton(
          icon: Icons.call_end_rounded,
          color: AppColors.danger,
          gradient: AppColors.crimsonBurgundy,
          tooltip: 'Desconectarse',
          onTap: () => ref.read(voiceRoomProvider.notifier).leaveRoom(),
        ),
      ],
    );
  }

  String _subtitle(VoiceRoomState voice) {
    if (voice.isConnected) {
      final n = voice.participants.length;
      return n == 1 ? 'Solo tú' : '$n en vivo';
    }
    if (voice.isConnecting) return 'Conectando…';
    if (voice.error != null) return 'Canal no disponible';
    return 'Pulsa Unirse para hablar';
  }

  /// Color del indicador de estado: verde = conectado, ámbar = conectando,
  /// gris = desconectado. 100% reactivo al estado del canal LiveKit.
  Color _statusColor(VoiceRoomState voice) {
    if (voice.isConnected) return AppColors.success;
    if (voice.isConnecting) return const Color(0xFFF5B041);
    return const Color(0xFF6B6B7B);
  }
}

/// Mapea el rol del participante (metadata de LiveKit) al badge visible.
(String, Color) _badgeForRole(String? role) {
  if (role == null || role.isEmpty) return ('Miembro', const Color(0xFF6B7280));
  final r = role.toUpperCase();
  if (r == 'HOST' || r == 'ADMIN' || r == 'OWNER') {
    return ('Admin', AppColors.accentCrimson);
  }
  if (r == 'CO_ADMIN' || r == 'COADMIN' || r == 'CO_HOST') {
    return ('Co-Admin', const Color(0xFF8B5CF6));
  }
  return ('Miembro', const Color(0xFF6B7280));
}

/// Avatar grande de un participante conectado: halo verde reactivo cuando
/// habla, nombre y badge (Admin / Co-Admin / Miembro) debajo.
class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant, this.onTap});

  final VoiceParticipant participant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (badgeLabel, badgeColor) = _badgeForRole(participant.role);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: participant.isSpeaking
                    ? AppColors.success
                    : Colors.white.withValues(alpha: 0.12),
                boxShadow: participant.isSpeaking
                    ? [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.55),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: ClipOval(
                child: AppAvatar(
                  name: participant.name,
                  imageUrl: participant.avatarUrl,
                  radius: 32,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              participant.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 0.6),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({
    required this.onTap,
    this.isStaffOnly = false,
    this.canJoin = true,
  });

  final VoidCallback onTap;
  final bool isStaffOnly;
  final bool canJoin;

  @override
  Widget build(BuildContext context) {
    final isDisabled = isStaffOnly && !canJoin;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 15),
        decoration: BoxDecoration(
          gradient: isDisabled
              ? const LinearGradient(
                  colors: [Color(0xFF424252), Color(0xFF2E2E3A)],
                )
              : AppColors.mintTurquoise,
          borderRadius: BorderRadius.circular(30),
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: AppColors.accentTeal.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDisabled ? Icons.lock_outline_rounded : Icons.mic_rounded,
              size: 20,
              color: isDisabled ? Colors.white60 : Colors.white,
            ),
            const SizedBox(width: 10),
            Text(
              isDisabled ? 'Solo Staff' : 'Unirse',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDisabled ? Colors.white60 : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
    this.tooltip,
    this.gradient,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;
  final String? tooltip;

  /// Si se define, el fondo del botón usa este degradado y el icono pasa a blanco.
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final button = Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              color: gradient == null ? color.withValues(alpha: 0.18) : null,
              boxShadow: gradient == null
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFFFF4B72).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Icon(icon, size: 22, color: gradient == null ? color : Colors.white),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }
    return button;
  }
}