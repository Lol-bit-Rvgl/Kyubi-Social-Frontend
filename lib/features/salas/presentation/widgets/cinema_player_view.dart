import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/providers.dart';
import '../../../../services/room_socket.dart';

/// Sala de Cine sincronizada con YouTube (Screening Room).
///
/// - El HOST de la sala controla el reproductor (controles nativos + cargar
///   video). Cada play/pause/seek se emite al backend vía `cinema:action`.
/// - Los espectadores ven el reproductor en modo de solo lectura
///   (`PointerEvents.none`, sin controles) y se sincronizan con los eventos
///   `cinema:sync` que emite el servidor a toda la sala.
class CinemaPlayerView extends ConsumerStatefulWidget {
  const CinemaPlayerView({
    super.key,
    required this.roomId,
    required this.initialVideoId,
    required this.initialState,
    required this.initialPosition,
    required this.isHost,
    this.onToggleOff,
    this.isMinimized = false,
    this.onToggleMinimize,
    this.canManage = false,
    this.onOpenSettings,
  });

  final String roomId;

  /// Video actual según el detalle de la sala (`GET /salas/:id`).
  final String? initialVideoId;

  /// Estado persistido: 'PLAYING' | 'PAUSED' | 'STOPPED'.
  final String initialState;

  /// Segundo estimado de arranque (el caller aplica la fórmula
  /// `cinemaCurrentTime + (now - cinemaUpdatedAt)` cuando está sonando).
  final double initialPosition;

  final bool isHost;

  /// Cierra la actividad de cine (vuelve a Chat Estándar). Solo host.
  final VoidCallback? onToggleOff;

  /// Si el reproductor se encuentra minimizado.
  final bool isMinimized;

  /// Callback para alternar entre minimizado y expandido.
  final VoidCallback? onToggleMinimize;

  /// Si el usuario actual tiene permisos de staff para gestionar el cine.
  final bool canManage;

  /// Abre la hoja modal de ajustes de cine para staff.
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<CinemaPlayerView> createState() => _CinemaPlayerViewState();
}

class _CinemaPlayerViewState extends ConsumerState<CinemaPlayerView>
    with WidgetsBindingObserver {
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _playerSub;
  StreamSubscription<YoutubeVideoState>? _positionSub;
  StreamSubscription<RoomSocketEvent>? _socketSub;

  String? _currentVideoId;
  String _state = 'STOPPED';
  Duration _position = Duration.zero;
  bool _showControls = true;
  Timer? _controlsTimer;
  double _playbackRate = 1.0;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _showCenterActionFeedback = false;
  Timer? _feedbackTimer;

  bool get _canControl => widget.isHost || widget.canManage;

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    if (_showControls) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _resetControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _lifecycleState = state;
    debugPrint('[CinemaPlayerView] didChangeAppLifecycleState: $state');

    // Al bajar la barra de notificaciones o desplegar ajustes rápidos en Android,
    // el sistema pasa transitoriamente por AppLifecycleState.inactive.
    // Ignoramos completamente 'inactive' para NO pausar el video ni emitir pausa a la sala.
    if (state == AppLifecycleState.inactive) {
      return;
    }

    // Si la app vuelve a primer plano (resumed):
    if (state == AppLifecycleState.resumed) {
      // Si la sala está en PLAYING y el WebView nativo de Android había pausado el audio/video,
      // aseguramos que continúe reproduciéndose sin cortes.
      if (_state == 'PLAYING') {
        _controller?.playVideo();
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Evita que el host emita un SEEK cuando el salto provino de una acción
  /// remota aplicada localmente (eco de sync).
  bool _applyingSync = false;
  Timer? _syncGuardTimer;

  /// Debounce mínimo para no inundar el socket al tocar play/pause seguido.
  DateTime _lastEmitAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _hasVideo => _currentVideoId != null && _currentVideoId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentVideoId = widget.initialVideoId;
    _state = widget.initialState;
    _initController();
    _resetControlsTimer();
    _socketSub = ref.read(roomSocketProvider).events.listen(_onSocketEvent);
  }

  @override
  void didUpdateWidget(covariant CinemaPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialVideoId != oldWidget.initialVideoId) {
      if (widget.initialVideoId == null || widget.initialVideoId!.isEmpty) {
        setState(() {
          _currentVideoId = null;
          _state = 'STOPPED';
          _position = Duration.zero;
        });
        unawaited(_controller?.pauseVideo());
        unawaited(_controller?.stopVideo());
      } else if (widget.initialVideoId != _currentVideoId) {
        setState(() {
          _currentVideoId = widget.initialVideoId;
          _state = widget.initialState;
        });
        if (widget.initialState == 'PLAYING') {
          unawaited(_controller?.loadVideoById(
            videoId: widget.initialVideoId!,
            startSeconds: widget.initialPosition,
          ));
        } else {
          unawaited(_controller?.cueVideoById(
            videoId: widget.initialVideoId!,
            startSeconds: widget.initialPosition,
          ));
        }
      }
    }
  }

  void _initController() {
    final playing = widget.initialState == 'PLAYING';
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: false,
        pointerEvents: PointerEvents.none,
        showFullscreenButton: false,
        showVideoAnnotations: false,
        playsInline: true,
      ),
    );

    _playerSub = _controller!.listen(_onPlayerState);

    _positionSub = _controller!.videoStateStream.listen((state) {
      _position = state.position;
      _maybeEmitSeekFromHost();
    });

    // Precarga el video si ya había uno persistido en la sala.
    if (widget.initialVideoId != null && widget.initialVideoId!.isNotEmpty) {
      if (playing) {
        _controller!.loadVideoById(
          videoId: widget.initialVideoId!,
          startSeconds: widget.initialPosition,
        );
      } else {
        _controller!.cueVideoById(
          videoId: widget.initialVideoId!,
          startSeconds: widget.initialPosition,
        );
      }
    }
  }

  // ── Sync del socket (todas las acciones del host) ─────────────────────────

  void _onSocketEvent(RoomSocketEvent event) {
    if (event is! RoomCinemaSync || event.roomId != widget.roomId) return;
    _applySync(event);
  }

  Future<void> _applySync(RoomCinemaSync sync) async {
    final controller = _controller;
    if (controller == null || !mounted) return;

    // Marca que el próximo seek proviene de un sync remoto (no re-emitir).
    _beginSyncGuard();

    final target = sync.currentTime;
    switch (sync.action) {
      case 'LOAD':
        final vid = sync.videoId;
        if (vid == null || vid.isEmpty) return;
        setState(() {
          _currentVideoId = vid;
          _state = 'PLAYING';
          _position = Duration(milliseconds: (target * 1000).round());
        });
        await controller.loadVideoById(videoId: vid, startSeconds: target);
        break;
      case 'PLAY':
        setState(() => _state = 'PLAYING');
        await _seekIfDrift(controller, target);
        await controller.playVideo();
        break;
      case 'PAUSE':
        setState(() => _state = 'PAUSED');
        await _seekIfDrift(controller, target);
        await controller.pauseVideo();
        break;
      case 'SEEK':
        setState(() {
          _position = Duration(milliseconds: (target * 1000).round());
        });
        await controller.seekTo(
          seconds: target,
          allowSeekAhead: true,
        );
        break;
      case 'STOP':
      case 'CLEAR':
      case 'REMOVE':
        setState(() {
          _state = 'STOPPED';
          _currentVideoId = null;
          _position = Duration.zero;
        });
        unawaited(controller.pauseVideo());
        unawaited(controller.stopVideo());
        break;
    }
  }

  /// Salta solo si el desfasaje entre el cliente y el host supera 2.5s
  /// (evita micro-cortes innecesarios en la reproducción).
  Future<void> _seekIfDrift(
    YoutubePlayerController controller,
    double hostSeconds,
  ) async {
    final localSec = _position.inMilliseconds / 1000.0;
    if ((localSec - hostSeconds).abs() > 2.5) {
      await controller.seekTo(seconds: hostSeconds, allowSeekAhead: true);
    }
  }

  void _beginSyncGuard() {
    _applyingSync = true;
    _syncGuardTimer?.cancel();
    _syncGuardTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _applyingSync = false;
    });
  }

  // ── Emisión del HOST hacia la sala vía Socket ────────────────────────────

  void _onPlayerState(YoutubePlayerValue value) {
    if (!mounted) return;
    if (_applyingSync) return;

    // Si la aplicación está inactiva (ej. barra de notificaciones bajada en Android),
    // la WebView puede pausar localmente el video. NO debemos propagarlo como pausa del anfitrión.
    if (_lifecycleState == AppLifecycleState.inactive) return;

    if (!_canControl) return;

    final ps = value.playerState;

    // Si la sala o estado local está en PAUSED, bloquear que el reproductor nativo
    // sobreescriba el estado ni emita PLAY a la sala.
    if (_state == 'PAUSED') {
      if (ps == PlayerState.playing) {
        unawaited(_controller?.pauseVideo());
      }
      return;
    }

    if (ps == PlayerState.playing && _state != 'PLAYING') {
      _emitHostAction('PLAY');
      setState(() => _state = 'PLAYING');
    } else if (ps == PlayerState.paused && _state != 'PAUSED') {
      _emitHostAction('PAUSE');
      setState(() => _state = 'PAUSED');
    } else if (ps == PlayerState.ended && _state != 'STOPPED') {
      _emitHostAction('STOP');
      setState(() => _state = 'STOPPED');
    }
  }

  double _lastKnownPositionSeconds = 0;

  void _maybeEmitSeekFromHost() {
    if (!_canControl || _applyingSync || !mounted) return;
    if (_state == 'PAUSED' || _state == 'STOPPED') return;
    final current = _position.inMilliseconds / 1000.0;
    final diff = (current - _lastKnownPositionSeconds).abs();
    // Un salto > 3.0s que no coincide con reproducción normal (~1s) es un SEEK
    // explícito del usuario.
    if (diff > 3.0) {
      _lastKnownPositionSeconds = current;
      _emitHostAction('SEEK', currentTime: current);
    } else {
      _lastKnownPositionSeconds = current;
    }
  }

  void _emitHostAction(String action, {double? currentTime}) {
    final now = DateTime.now();
    if (now.difference(_lastEmitAt).inMilliseconds < 400 && action != 'LOAD') {
      return;
    }
    _lastEmitAt = now;

    final pos = currentTime ?? (_position.inMilliseconds / 1000.0);
    ref.read(roomSocketProvider).emitCinemaAction(
      roomId: widget.roomId,
      action: action,
      videoId: _currentVideoId,
      currentTime: pos,
    );
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null) return;
    if (!_canControl) return;

    _resetControlsTimer();
    final isPlaying =
        controller.value.playerState == PlayerState.playing ||
        _state == 'PLAYING';

    _showActionFeedback();
    _beginSyncGuard();

    final targetPlaying = !isPlaying;
    final stateStr = targetPlaying ? 'PLAYING' : 'PAUSED';
    final actionStr = targetPlaying ? 'PLAY' : 'PAUSE';

    if (mounted) {
      setState(() => _state = stateStr);
    }

    if (isPlaying) {
      // Pausa explícita sincrónica/await en el controlador nativo
      await controller.pauseVideo();
      try {
        if (controller.value.playerState == PlayerState.playing) {
          await controller.pauseVideo();
        }
      } catch (_) {}
    } else {
      await controller.playVideo();
    }

    final posSec = _position.inMilliseconds / 1000.0;
    ref.read(roomSocketProvider).emitCinemaAction(
      roomId: widget.roomId,
      action: actionStr,
      videoId: _currentVideoId,
      currentTime: posSec,
    );
  }

  void _showActionFeedback() {
    _feedbackTimer?.cancel();
    if (mounted) setState(() => _showCenterActionFeedback = true);
    _feedbackTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showCenterActionFeedback = false);
    });
  }

  // ── Diálogo para cargar URL / ID de YouTube (solo Host) ──────────────────

  Future<void> _openLoadVideoDialog() async {
    final textController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161226),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF332B4F), width: 0.8),
        ),
        title: const Row(
          children: [
            Icon(Icons.video_library_rounded, color: AppColors.accentTeal),
            SizedBox(width: 8),
            Text(
              'Cargar Video',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pega el enlace completo de YouTube o el ID del video:',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://youtube.com/watch?v=... o dQw4w9WgXcQ',
                hintStyle: const TextStyle(
                  color: Color(0xFF6E6E7C),
                  fontSize: 12,
                ),
                filled: true,
                fillColor: const Color(0xFF0F0D1B),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2C2542)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(textController.text.trim()),
            child: const Text(
              'Reproducir',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    final extracted = _extractVideoId(result);
    if (extracted == null || extracted.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enlace de YouTube no válido'),
            backgroundColor: Color(0xFF2A121E),
          ),
        );
      }
      return;
    }

    _loadVideo(extracted);
  }

  String? _extractVideoId(String input) {
    final trimmed = input.trim();
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) return trimmed;
    try {
      final uri = Uri.parse(trimmed);
      if (uri.host.contains('youtube.com')) {
        return uri.queryParameters['v'];
      }
      if (uri.host.contains('youtu.be')) {
        final segs = uri.pathSegments;
        if (segs.isNotEmpty) return segs.first;
      }
    } catch (_) {}
    return null;
  }

  /// Carga inmediata en el reproductor del host + broadcast `cinema:action`
  /// al socket para que el backend lo persista y lo redistribuya.
  void _loadVideo(String videoId) {
    setState(() {
      _currentVideoId = videoId;
      _state = 'PLAYING';
      _position = Duration.zero;
      _lastKnownPositionSeconds = 0;
    });
    unawaited(_controller?.loadVideoById(videoId: videoId, startSeconds: 0));
    ref.read(roomSocketProvider).emitCinemaAction(
      roomId: widget.roomId,
      action: 'LOAD',
      videoId: videoId,
      currentTime: 0,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _feedbackTimer?.cancel();
    _socketSub?.cancel();
    _syncGuardTimer?.cancel();
    _playerSub?.cancel();
    _positionSub?.cancel();
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC13101E),
        borderRadius: BorderRadius.circular(widget.isMinimized ? 16 : 20),
        border: Border.all(color: const Color(0xFF2C2542), width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header del Screening ──
          Padding(
            padding: EdgeInsets.fromLTRB(14, 8, 8, widget.isMinimized ? 8 : 6),
            child: Row(
              children: [
                const Icon(
                  Icons.live_tv_rounded,
                  color: Color(0xFFD500F9),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Sala de Cine',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.accentTeal, width: 0.8),
                  ),
                  child: Text(
                    _state == 'PLAYING'
                        ? 'EN VIVO'
                        : (_state == 'PAUSED' ? 'PAUSADO' : 'DETENIDO'),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accentTeal,
                    ),
                  ),
                ),
                if (widget.isMinimized && _hasVideo) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Video: $_currentVideoId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (widget.isMinimized &&
                    (widget.isHost || widget.canManage) &&
                    widget.onOpenSettings != null) ...[
                  GestureDetector(
                    onTap: widget.onOpenSettings,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if ((widget.isHost || widget.canManage) && !widget.isMinimized) ...[
                  // Host / Staff: ajustes de cine + cargar video + cerrar cine
                  if (widget.onOpenSettings != null)
                    IconButton(
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Ajustes de cine',
                      icon: const Icon(
                        Icons.settings_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      onPressed: widget.onOpenSettings,
                    ),
                  IconButton(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Cargar video de YouTube',
                    icon: const Icon(
                      Icons.add_rounded,
                      color: AppColors.accentCyan,
                      size: 18,
                    ),
                    onPressed: _openLoadVideoDialog,
                  ),
                  IconButton(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Cerrar sala de cine',
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: widget.onToggleOff,
                  ),
                ] else if (!(widget.isHost || widget.canManage) && !widget.isMinimized) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 12,
                          color: Color(0xFF8A8A9A),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Solo el host controla',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8A8A9A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.onToggleMinimize != null) ...[
                  GestureDetector(
                    onTap: widget.onToggleMinimize,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isMinimized
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Reproductor 16:9 (mantenido con Offstage para no perder playback ni sincronía) ──
          Offstage(
            offstage: widget.isMinimized,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: controller == null
                      ? _placeholder('Iniciando reproductor...')
                      : !_hasVideo
                          ? _placeholder(
                              widget.isHost || widget.canManage
                                  ? 'Sin video cargado.\nToca + o Ajustes para elegir un video de YouTube'
                                  : 'Esperando que el anfitrión elija un video...',
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                // 1. Reproductor en el fondo (sin controles ni eventos nativos)
                                Positioned.fill(
                                  child: YoutubePlayer(
                                    controller: controller,
                                    aspectRatio: 16 / 9,
                                  ),
                                ),
                                // 2. Capa transparente que absorbe clics parásitos al iframe
                                // y vincula el tap al toggle de play/pausa para Host y Staff
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (_canControl) {
                                        _togglePlayPause();
                                      } else {
                                        _toggleControls();
                                      }
                                    },
                                  ),
                                ),
                                // 3. Feedback visual central de Play/Pausa
                                if (_showCenterActionFeedback ||
                                    (_state == 'PAUSED' && _showControls))
                                  IgnorePointer(
                                    child: AnimatedOpacity(
                                      opacity: 1.0,
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.65),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.2),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Icon(
                                          _state == 'PLAYING'
                                              ? Icons.play_arrow_rounded
                                              : Icons.pause_rounded,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  ),
                                // 4. Barra de controles inferior compacta con auto-hide (solo host/staff)
                                if (_canControl)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: AnimatedOpacity(
                                      opacity: _showControls ? 1.0 : 0.0,
                                      duration:
                                          const Duration(milliseconds: 250),
                                      child: IgnorePointer(
                                        ignoring: !_showControls,
                                        child: _buildControlsBar(controller),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsBar(YoutubePlayerController controller) {
    final duration = controller.metadata.duration;
    final totalSec = duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 0.0;
    final curSec = (_position.inSeconds.toDouble()).clamp(0.0, totalSec > 0 ? totalSec : 3600.0);
    final isPlaying = _state == 'PLAYING';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (totalSec > 0)
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: AppColors.accentCyan,
                inactiveTrackColor: Colors.white24,
                thumbColor: AppColors.accentCyan,
              ),
              child: Slider(
                value: curSec,
                min: 0.0,
                max: totalSec,
                onChangeStart: (_) => _controlsTimer?.cancel(),
                onChanged: (val) {
                  setState(() {
                    _position = Duration(seconds: val.round());
                  });
                },
                onChangeEnd: (val) {
                  _resetControlsTimer();
                  controller.seekTo(seconds: val, allowSeekAhead: true);
                  _lastKnownPositionSeconds = val;
                  _emitHostAction('SEEK', currentTime: val);
                },
              ),
            ),
          Row(
            children: [
              IconButton(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _togglePlayPause,
              ),
              const SizedBox(width: 4),
              Text(
                '${_formatDuration(_position)} / ${_formatDuration(duration)}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  _resetControlsTimer();
                  final nextRate = _playbackRate == 1.0
                      ? 1.25
                      : (_playbackRate == 1.25
                          ? 1.5
                          : (_playbackRate == 1.5 ? 2.0 : 1.0));
                  setState(() => _playbackRate = nextRate);
                  controller.setPlaybackRate(nextRate);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_playbackRate}x',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String text) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0C0A16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppAssets.iconTransmisionesApagadas,
              width: 38,
              height: 38,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9E9EA8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
