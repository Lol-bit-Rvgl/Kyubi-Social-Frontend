import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/room.dart';

/// Stage desplegado cuando el modo **Voice Chat** está activo.
class VoiceStageView extends StatefulWidget {
  const VoiceStageView({
    super.key,
    required this.participants,
    required this.canManage,
    this.onToggleOff,
    this.onParticipantTap,
  });

  final List<RoomParticipant> participants;
  final bool canManage;
  final VoidCallback? onToggleOff;

  /// Tap sobre el avatar/nombre de un participante (perfil o moderación).
  final ValueChanged<RoomParticipant>? onParticipantTap;

  @override
  State<VoiceStageView> createState() => _VoiceStageViewState();
}

class _VoiceStageViewState extends State<VoiceStageView> {
  bool _isMuted = false;
  bool _isDeafened = false;

  @override
  Widget build(BuildContext context) {
    return _StageShell(
      emoji: '🎙️',
      title: 'Voice Chat',
      subtitle: 'Canal de voz en vivo',
      canManage: widget.canManage,
      onToggleOff: widget.onToggleOff,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.participants.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      'Esperando voces en la sala…',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final p in widget.participants)
                      Tooltip(
                        message: '${p.user.displayName} · ${p.role}',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Voz/Cine = usuarios reales → avatares CIRCULARES.
                            _StageMemberAvatar(
                              size: 44,
                              imageUrl: p.user.avatarUrl,
                              hasActiveMic: true,
                              onTap: () => widget.onParticipantTap?.call(p),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.graphic_eq_rounded,
                              size: 14,
                              color: AppColors.success,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
          const SizedBox(height: 10),
          // Barra de controles de llamada de voz
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF181428),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2C2542), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCircleAction(
                  icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: _isMuted
                      ? AppColors.accentCrimson
                      : AppColors.accentTeal,
                  bgColor: _isMuted
                      ? const Color(0x33E61E43)
                      : const Color(0x2200E676),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isMuted = !_isMuted);
                  },
                ),
                const SizedBox(width: 12),
                _buildCircleAction(
                  icon: _isDeafened
                      ? Icons.headset_off_rounded
                      : Icons.headset_rounded,
                  color: _isDeafened
                      ? AppColors.accentCrimson
                      : const Color(0xFF00E5FF),
                  bgColor: _isDeafened
                      ? const Color(0x33E61E43)
                      : const Color(0x2200E5FF),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isDeafened = !_isDeafened);
                  },
                ),
                const SizedBox(width: 12),
                _buildCircleAction(
                  icon: Icons.call_end_rounded,
                  color: Colors.white,
                  bgColor: AppColors.accentCrimson,
                  onTap: widget.onToggleOff,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleAction({
    required IconData icon,
    required Color color,
    required Color bgColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        ),
        child: Center(child: Icon(icon, color: color, size: 18)),
      ),
    );
  }
}

/// Stage desplegado cuando el modo **Screening Room** está activo (Ref: Captura 5).
///
/// Muestra un contenedor 16:9 con video sincronizado / simulación multimedia
/// y la barra de controles de voz y participantes inmediatamente debajo.
class ScreeningStageView extends StatefulWidget {
  const ScreeningStageView({
    super.key,
    required this.canManage,
    this.participants = const [],
    this.onToggleOff,
    this.onParticipantTap,
    this.nowPlaying = 'Infieles en la Calle - Episodio 10',
    this.videoUrl,
    this.thumbnailUrl =
        'https://images.unsplash.com/photo-1485846234645-a62644f84728?w=800&auto=format&fit=crop&q=60',
  });

  final bool canManage;
  final List<RoomParticipant> participants;
  final VoidCallback? onToggleOff;

  /// Tap sobre el avatar/nombre de un participante (perfil o moderación).
  final ValueChanged<RoomParticipant>? onParticipantTap;

  final String nowPlaying;
  final String? videoUrl;
  final String thumbnailUrl;

  @override
  State<ScreeningStageView> createState() => _ScreeningStageViewState();
}

class _ScreeningStageViewState extends State<ScreeningStageView> {
  bool _isPlaying = true;
  bool _isMuted = false;
  bool _isDeafened = false;
  bool _isMinimized = false;

  @override
  Widget build(BuildContext context) {
    return _StageShell(
      emoji: '🎬',
      title: 'Screening Room',
      subtitle: 'Sala de Cine / Video 16:9',
      canManage: widget.canManage,
      onToggleOff: widget.onToggleOff,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 1. Contenedor de Video 16:9 con Overlays (Ref: Captura 5) ──
          if (!_isMinimized) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video Thumbnail / Cover
                    CachedNetworkImage(
                      imageUrl: widget.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: const Color(0xFF0C0A16),
                        child: const Icon(
                          Icons.movie_rounded,
                          size: 48,
                          color: AppColors.accentCrimson,
                        ),
                      ),
                    ),

                    // Gradiente cinemático oscuro
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black45,
                            Colors.transparent,
                            Colors.black87,
                          ],
                        ),
                      ),
                    ),

                    // Header del video: [ 🔴 EN VIVO ] + [ 1080p HD ]
                    Positioned(
                      top: 8,
                      left: 10,
                      right: 10,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentCrimson,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Colors.white,
                                  size: 7,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'EN VIVO',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white24,
                                width: 0.6,
                              ),
                            ),
                            child: const Text(
                              '1080p HD',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Botón central Play / Pause
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _isPlaying = !_isPlaying);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.55),
                            border: Border.all(
                              color: Colors.white70,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),

                    // Barra inferior de progreso y título del video
                    Positioned(
                      bottom: 8,
                      left: 10,
                      right: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.nowPlaying,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Barra de progreso animada
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: const LinearProgressIndicator(
                                    value: 0.42,
                                    backgroundColor: Colors.white24,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.accentCrimson,
                                    ),
                                    minHeight: 3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '14:20 / 32:45',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── 2. Barra de Participantes y Controles de Voz (Ref: Captura 5) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF161224),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF28223C), width: 0.8),
            ),
            child: Row(
              children: [
                // Participantes en el stage con halo de voz
                Expanded(
                  child: widget.participants.isEmpty
                      ? const Row(
                          children: [
                            Icon(
                              Icons.headset_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Transmisión activa',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final p in widget.participants.take(6))
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Tooltip(
                                    message: p.user.displayName,
                                    // Voz/Cine = usuario real → avatar CIRCULAR.
                                    child: _StageMemberAvatar(
                                      size: 32,
                                      imageUrl: p.user.avatarUrl,
                                      hasActiveMic: true,
                                      onTap: () =>
                                          widget.onParticipantTap?.call(p),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),

                const SizedBox(width: 8),

                // Controles de llamada de voz integrados (Ref: Captura 5)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mute Mic
                    _buildPillButton(
                      icon: _isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      color: _isMuted
                          ? AppColors.accentCrimson
                          : AppColors.accentTeal,
                      bgColor: _isMuted
                          ? const Color(0x33E61E43)
                          : const Color(0x2200E676),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isMuted = !_isMuted);
                      },
                    ),
                    const SizedBox(width: 6),

                    // Deafen / Altavoz
                    _buildPillButton(
                      icon: _isDeafened
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: _isDeafened
                          ? AppColors.accentCrimson
                          : const Color(0xFF00E5FF),
                      bgColor: _isDeafened
                          ? const Color(0x33E61E43)
                          : const Color(0x2200E5FF),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isDeafened = !_isDeafened);
                      },
                    ),
                    const SizedBox(width: 6),

                    // Botón rojo desconectar
                    _buildPillButton(
                      icon: Icons.call_end_rounded,
                      color: Colors.white,
                      bgColor: AppColors.accentCrimson,
                      onTap: widget.onToggleOff,
                    ),
                    const SizedBox(width: 6),

                    // Minimizar / Expandir 16:9
                    _buildPillButton(
                      icon: _isMinimized
                          ? Icons.fullscreen_rounded
                          : Icons.fullscreen_exit_rounded,
                      color: AppColors.textSecondary,
                      bgColor: const Color(0xFF1E1A2E),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isMinimized = !_isMinimized);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
        ),
        child: Center(child: Icon(icon, color: color, size: 16)),
      ),
    );
  }
}

class _StageShell extends StatelessWidget {
  const _StageShell({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.canManage,
    required this.child,
    this.onToggleOff,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool canManage;
  final Widget child;
  final VoidCallback? onToggleOff;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xCC13101E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2C2542), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (canManage && onToggleOff != null)
                  GestureDetector(
                    onTap: onToggleOff,
                    child: const Icon(
                      Icons.power_settings_new_rounded,
                      size: 16,
                      color: AppColors.accentCrimson,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// Avatar circular de un participante en stage de Voz/Cine. Convención visual:
/// CIRCULO = usuario real (Voz/Cine), a diferencia del HEXÁGONO que se reserva
/// para personajes de Roleplay.
class _StageMemberAvatar extends StatelessWidget {
  const _StageMemberAvatar({
    required this.size,
    required this.imageUrl,
    this.hasActiveMic = false,
    this.onTap,
  });

  final double size;
  final String? imageUrl;
  final bool hasActiveMic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: hasActiveMic ? AppColors.accentTeal : const Color(0xFF2C2542),
          width: 1.4,
        ),
        boxShadow: hasActiveMic
            ? [
                BoxShadow(
                  color: AppColors.accentTeal.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => const ColoredBox(
                  color: Color(0xFF1E1A2E),
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white38,
                    size: 18,
                  ),
                ),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: Color(0xFF1E1A2E),
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white38,
                    size: 18,
                  ),
                ),
              )
            : const ColoredBox(
                color: Color(0xFF1E1A2E),
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white38,
                  size: 18,
                ),
              ),
        ),
      ),
    );
  }
}
