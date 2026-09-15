import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/kyubi_logo.dart';

/// Widget central que reproduce en bucle la animación heroica del zorro Kyubi
/// (ssets/animations/kyubi_fox_loop.mp4) con fondo fundido y aura de resplandor
/// violeta/cian.
class KyubiFoxHeroAnimation extends StatefulWidget {
  const KyubiFoxHeroAnimation({
    super.key,
    this.width = 190,
    this.height = 170,
  });

  final double width;
  final double height;

  @override
  State<KyubiFoxHeroAnimation> createState() => _KyubiFoxHeroAnimationState();
}

class _KyubiFoxHeroAnimationState extends State<KyubiFoxHeroAnimation> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.asset(AppAssets.kyubiFoxLoop);
      _controller = controller;

      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0.0);
      await controller.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('[KyubiFoxHeroAnimation] Error inicializando video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Aura de resplandor difuso violeta y cian
          Container(
            width: widget.width * 0.78,
            height: widget.height * 0.78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFA594F9).withValues(alpha: 0.45),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.30),
                  blurRadius: 42,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

          // Reproductor de video con fusión de fondo oscuro o fallback
          if (_isInitialized && _controller != null && !_hasError)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller!.value.size.width > 0
                        ? _controller!.value.size.width
                        : widget.width,
                    height: _controller!.value.size.height > 0
                        ? _controller!.value.size.height
                        : widget.height,
                    child: ColorFiltered(
                      // Matriz que deriva el canal alfa de la luminancia (R*0.33 + G*0.59 + B*0.11),
                      // volviendo transparentes los fondos negros del video MP4.
                      colorFilter: const ColorFilter.matrix(<double>[
                        1.0, 0.0, 0.0, 0.0, 0.0,
                        0.0, 1.0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 1.0, 0.0, 0.0,
                        0.33, 0.59, 0.11, 0.0, 0.0,
                      ]),
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
              ),
            )
          else if (_hasError)
            // Error al inicializar el video: mostrar logo oficial con fallback limpio
            const KyubiLogo(
              size: 80,
              showGlow: false,
            )
          else
            // Durante la carga inicial: contenedor limpio y transparente sobre el aura
            // para evitar parpadeos visuales con iconos anteriores.
            SizedBox(
              width: widget.width,
              height: widget.height,
            ),
        ],
      ),
    );
  }
}
