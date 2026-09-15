import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../theme/app_colors.dart';

class KyubiAudioPlayer extends StatefulWidget {
  const KyubiAudioPlayer({required this.url, this.maxDuration, super.key});

  final String url;
  final Duration? maxDuration;

  @override
  State<KyubiAudioPlayer> createState() => _KyubiAudioPlayerState();
}

class _KyubiAudioPlayerState extends State<KyubiAudioPlayer> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
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
    } catch (e) {
      debugPrint('Error initializing audio player: $e');
    }
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final mins = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCards,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              size: 32,
              color: AppColors.primary,
            ),
            onPressed: _togglePlayPause,
          ),
          const SizedBox(height: 8),
          _duration != null
              ? Slider(
                  value: (_position?.inSeconds.toDouble() ?? 0.0).clamp(
                    0.0,
                    _duration!.inSeconds.toDouble(),
                  ),
                  max: _duration!.inSeconds.toDouble(),
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.surfaceAlt,
                  onChanged: (double value) {
                    _player.seek(Duration(seconds: value.round()));
                  },
                )
              : const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
