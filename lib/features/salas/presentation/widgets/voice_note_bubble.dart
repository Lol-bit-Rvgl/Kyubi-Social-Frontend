import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/theme/app_colors.dart';

/// Burbuja de nota de voz compacta para el chat de salas.
///
/// Diseño fijo (ancho 264) para no superar la altura del reproductor genérico:
/// - Fila superior: botón play/pausa + barra de progreso + duración total.
/// - Fila inferior: `Row` con `spaceBetween` → [nombre remitente] [00:05] [21:19].
class VoiceNoteBubble extends StatefulWidget {
  const VoiceNoteBubble({
    super.key,
    required this.url,
    required this.senderName,
    this.sendTime,
  });

  final String url;
  final String senderName;
  final String? sendTime;

  @override
  State<VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<VoiceNoteBubble> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _failed = false;
  Duration? _duration;
  Duration? _position;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setUrl(widget.url);
      _player.durationStream.listen((d) {
        if (!mounted) return;
        setState(() => _duration = d);
      });
      _player.positionStream.listen((p) {
        if (!mounted) return;
        setState(() => _position = p);
      });
      _player.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() => _isPlaying = state.playing);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration? d) {
    if (d == null) return '00:00';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggle() {
    if (_failed) return;
    HapticFeedback.lightImpact();
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = _duration;
    final position = _position ?? Duration.zero;
    final totalMs = duration?.inMilliseconds ?? 0;
    final progress =
        totalMs > 0 ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: 264,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2138),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Botón play / pausa
              GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF8A7EB8),
                  ),
                  child: Icon(
                    _failed
                        ? Icons.refresh_rounded
                        : (_isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Barra de progreso + tiempo transcurrido
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSeekBar(progress, duration),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fmt(duration),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Fila inferior: nombre · duración · hora (spaceBetween)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  widget.senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF5F3FA),
                  ),
                ),
              ),
              if (widget.sendTime != null) ...[
                const SizedBox(width: 8),
                Text(
                  _fmt(position),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.sendTime!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeekBar(double progress, Duration? duration) {
    return GestureDetector(
      onTapDown: duration == null
          ? null
          : (tapDetails) {
              final total = duration.inMilliseconds.toDouble();
              // Usa el ancho real de la barra vía LayoutBuilder almacenado.
              final fraction = (_barWidth > 0
                      ? tapDetails.localPosition.dx / _barWidth
                      : 0.0)
                  .clamp(0.0, 1.0);
              _player.seek(Duration(milliseconds: (total * fraction).round()));
            },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _barWidth = constraints.maxWidth;
          return SizedBox(
            height: 22,
            child: Center(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3450),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      width: constraints.maxWidth * progress,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _barWidth = 0;
}