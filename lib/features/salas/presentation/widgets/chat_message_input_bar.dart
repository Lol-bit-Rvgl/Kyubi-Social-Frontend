import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sticker_catalog.dart';
import '../../../../core/widgets/sticker_picker.dart';
import '../../../../models/role_character.dart';
import 'animated_emoji_keyboard.dart';
import 'dice_selector_modal.dart';
import 'poll_creation_modal.dart';
import 'rich_text_roleplay_modal.dart';

/// Barra de Input y Herramientas Rápidas de Chat con selector de identidad,
/// editor A⁺ enriquecido y panel de grabación de audio en vivo.
class ChatMessageInputBar extends StatefulWidget {
  const ChatMessageInputBar({
    super.key,
    required this.onSendMessage,
    required this.onSendImage,
    required this.onSendAudio,
    required this.onSendDiceRoll,
    required this.onSendPoll,
    this.onSendSticker,
    this.onOpenModesTap,
    this.isRoleplay = true,
    this.userName = 'Usuario',
    this.userAvatarUrl,
    this.currentRole,
    this.availableRoles = const [],
    this.onIdentityChanged,
    this.onRoleChanged,
    this.currentUserId,
    this.isHost = false,
    this.onTypingChanged,
    this.enabled = true,
    this.disabledHint,
    this.replyingToMessage,
    this.onCancelReply,
    this.editingMessage,
    this.onCancelEdit,
    this.onSendEdit,
  });

  final bool enabled;
  final String? disabledHint;

  final Function(String text) onSendMessage;
  final Function(String imagePath) onSendImage;

  /// Nota de voz grabada: duración en ms + bytes del audio + nombre de archivo.
  final Function(int durationMs, Uint8List audioBytes, String filename)
  onSendAudio;
  final Function(String diceName, String result, String emoji) onSendDiceRoll;
  final Function(String question, List<String> options) onSendPoll;
  final Function(StickerItem sticker)? onSendSticker;
  final VoidCallback? onOpenModesTap;
  final bool isRoleplay;
  final String userName;
  final String? userAvatarUrl;
  final RoleCharacter? currentRole;
  final List<RoleCharacter> availableRoles;
  final Function(RoleCharacter? role)? onIdentityChanged;
  final Function(RoleCharacter? role)? onRoleChanged;

  /// Mensaje citado para responder (Reply).
  final Map<String, dynamic>? replyingToMessage;
  final VoidCallback? onCancelReply;

  /// Mensaje en edición (Edición única).
  final Map<String, dynamic>? editingMessage;
  final VoidCallback? onCancelEdit;
  final Function(String messageId, String newContent)? onSendEdit;

  /// Id del usuario autenticado: el selector de identidad sólo ofrece los
  /// roles/personajes cuya `takenByUserId`/`userId` coincide con él.
  final String? currentUserId;

  /// Si es Host de la sala, puede asumir cualquier rol (permiso explícito).
  final bool isHost;

  /// Notifica cuando el usuario empieza/deja de escribir (foco del campo):
  /// el chat pausa los emojis animados mientras se está escribiendo.
  final ValueChanged<bool>? onTypingChanged;

  @override
  State<ChatMessageInputBar> createState() => _ChatMessageInputBarState();
}

class _ChatMessageInputBarState extends State<ChatMessageInputBar>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _fieldFocusNode = FocusNode();
  bool _showEmojiPicker = false;
  bool _showAudioPanel = false;

  // Estado de cooldown anti-spam (1.5 segundos entre envíos)
  bool _isCoolingDown = false;
  Timer? _cooldownTimer;

  // Estado de grabación de audio
  bool _isPaused = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  AudioRecorder? _recorder = AudioRecorder();

  late RoleCharacter? _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.isRoleplay ? widget.currentRole : null;
    // Sincronización teclado ↔ paneles: al escribir, el teclado cierra los
    // paneles de emojis/audio para no solaparse con la barra de herramientas.
    _fieldFocusNode.addListener(_onFieldFocusChanged);
  }

  void _onFieldFocusChanged() {
    widget.onTypingChanged?.call(_fieldFocusNode.hasFocus);
    if (!_fieldFocusNode.hasFocus) return;
    if (_showEmojiPicker || _showAudioPanel) {
      setState(() {
        _showEmojiPicker = false;
        _showAudioPanel = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ChatMessageInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fuera del Roleplay Stage la equipación de personajes queda bloqueada:
    // la identidad activa se fuerza a la Cuenta Personal.
    if (!widget.isRoleplay) {
      if (_selectedRole != null) {
        _selectedRole = null;
        widget.onRoleChanged?.call(null);
        widget.onIdentityChanged?.call(null);
      }
    } else if (widget.currentRole != oldWidget.currentRole) {
      _selectedRole = widget.currentRole;
    }
    if (widget.editingMessage != oldWidget.editingMessage) {
      if (widget.editingMessage != null) {
        final body = (widget.editingMessage!['body'] ??
                widget.editingMessage!['content'] ??
                widget.editingMessage!['text'] ??
                '')
            .toString();
        _textController.text = body;
        _textController.selection = TextSelection.collapsed(offset: body.length);
        _fieldFocusNode.requestFocus();
      } else if (oldWidget.editingMessage != null) {
        _textController.clear();
      }
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _textController.dispose();
    _fieldFocusNode.removeListener(_onFieldFocusChanged);
    _fieldFocusNode.dispose();
    _recordTimer?.cancel();
    _recorder?.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (!widget.enabled || _isCoolingDown) return;
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Iniciar cooldown anti-spam inmediatamente
    setState(() {
      _isCoolingDown = true;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isCoolingDown = false;
        });
      }
    });

    HapticFeedback.lightImpact();
    if (widget.editingMessage != null) {
      final msgId = widget.editingMessage!['id']?.toString() ?? '';
      widget.onSendEdit?.call(msgId, text);
      _textController.clear();
      setState(() {});
      return;
    }

    widget.onSendMessage(text);
    _textController.clear();
    setState(() {});
  }

  /// Abre el Editor A⁺ de turno de rol a pantalla completa.
  /// El botón A⁺ cierra el teclado/paneles y presenta el editor enriquecido.
  ///
  /// La navegación y la construcción del editor van protegidas con try/catch:
  /// ningún fallo dentro de `RichTextRoleplayModal` debe disparar el ErrorWidget
  /// global ("Ha ocurrido un error inesperado").
  Future<void> _openRichTextModal() async {
    if (!widget.enabled) return;
    HapticFeedback.lightImpact();
    if (!mounted) return;
    _fieldFocusNode.unfocus();
    setState(() {
      _showEmojiPicker = false;
      _showAudioPanel = false;
    });
    if (!mounted || !context.mounted) return;

    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (ctx) => RichTextRoleplayModal(
            initialText: _textController.text,
            onSend: (text) {
              _textController.text = text;
              _handleSend();
            },
            onCancel: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    } catch (e, stack) {
      debugPrint('ERROR EN A+: $e\n$stack');
    }
  }

  // ── 3. GRABACIÓN DE AUDIO (PANEL INFERIOR) ────────────────────────────────

  void _toggleAudioPanel() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    // El teclado no debe quedarse abierto sobre el panel de grabación.
    _fieldFocusNode.unfocus();
    setState(() {
      _showAudioPanel = !_showAudioPanel;
      if (_showAudioPanel) {
        _showEmojiPicker = false;
        unawaited(_startRecording());
      } else {
        unawaited(_cancelRecording());
      }
    });
  }

  Future<void> _startRecording() async {
    _isPaused = false;
    _recordSeconds = 0;

    // Timer del panel (visualización por arranque del grabador real).
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) setState(() => _recordSeconds++);
    });

    _recorder ??= AudioRecorder();
    try {
      if (!await _recorder!.hasPermission()) {
        _showMicDenied();
        if (mounted) setState(() => _showAudioPanel = false);
        return;
      }
      final path =
          '${Directory.systemTemp.path}/kyubi_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
    } catch (_) {
      // Sin grabador real (test/simulación): el panel conserva el timer.
    }
  }

  Future<void> _pauseResumeRecording() async {
    HapticFeedback.selectionClick();
    final recorder = _recorder;
    try {
      if (_isPaused) {
        await recorder?.resume();
      } else {
        await recorder?.pause();
      }
    } catch (_) {
      // Fallback simulado si el grabador no responde.
    }
    if (mounted) setState(() => _isPaused = !_isPaused);
  }

  Future<void> _cancelRecording() async {
    HapticFeedback.selectionClick();
    final recorder = _recorder;
    String? path;
    try {
      path = await recorder?.stop();
    } catch (_) {}
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    _recordTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPaused = false;
        _recordSeconds = 0;
        _showAudioPanel = false;
      });
    }
  }

  Future<void> _sendVoiceNote() async {
    HapticFeedback.mediumImpact();
    final durationMs = _recordSeconds * 1000;
    final recorder = _recorder;
    String? path;
    try {
      path = await recorder?.stop();
    } catch (_) {}
    _recordTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPaused = false;
        _recordSeconds = 0;
        _showAudioPanel = false;
      });
    }

    if (path == null || path.isEmpty) {
      widget.onSendAudio(durationMs, Uint8List(0), 'voice_note.m4a');
      return;
    }
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      widget.onSendAudio(durationMs, bytes, 'voice_note.m4a');
    } catch (_) {
      widget.onSendAudio(durationMs, Uint8List(0), 'voice_note.m4a');
    }
  }

  void _showMicDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Permiso de micrófono requerido para grabar notas de voz',
          textAlign: TextAlign.center,
        ),
        backgroundColor: Color(0xFF2A121E),
      ),
    );
  }

  Future<void> _pickImage() async {
    if (!widget.enabled) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      widget.onSendImage(image.path);
    }
  }

  void _showDiceModal() {
    if (!widget.enabled) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DiceSelectorModal(onRollResult: widget.onSendDiceRoll),
    );
  }

  void _showPollModal() {
    if (!widget.enabled) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PollCreationModal(onCreated: widget.onSendPoll),
    );
  }

  void _showStickerPicker() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    _fieldFocusNode.unfocus();
    setState(() {
      _showEmojiPicker = false;
      _showAudioPanel = false;
    });
    showStickerPicker(context, onSelected: widget.onSendSticker);
  }

  @override
  Widget build(BuildContext context) {
    final activeRole = widget.isRoleplay ? _selectedRole : null;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF13101E),
        border: Border(top: BorderSide(color: Color(0xFF221D32), width: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Banner de Respuesta (Reply) ──
          if (widget.replyingToMessage != null) _buildReplyPreviewBanner(),

          // ── Banner de Edición de Mensaje ──
          if (widget.editingMessage != null) _buildEditingBanner(),

          // ── Barra de sugerencias de menciones (@) ──
          _buildMentionSuggestionsBar(),

          // ── Fila 1: Selector de Identidad (si Roleplay) + Input + A⁺ + Enviar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Selector Rápido de Identidad de Rol (Exclusivo en modo Roleplay)
                if (widget.isRoleplay) ...[
                  _buildIdentitySelectorButton(context, activeRole),
                  const SizedBox(width: 8),
                ],

                // Campo de Texto Multilínea
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B172B),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF2E2746),
                        width: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _fieldFocusNode,
                      enabled: widget.enabled,
                      maxLength: 4000,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                          currentLength > 3500
                              ? Text(
                                  '$currentLength/$maxLength',
                                  style: const TextStyle(
                                    color: Color(0xFF9E9EAF),
                                    fontSize: 10,
                                  ),
                                )
                              : null,
                      maxLines: null,
                      style: TextStyle(
                        color: widget.enabled ? Colors.white : const Color(0xFF8E889D),
                        fontSize: 14,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: !widget.enabled
                            ? (widget.disabledHint ?? 'No puedes enviar mensajes en este momento')
                            : (activeRole != null
                                ? 'Mensaje como ${activeRole.name}...'
                                : 'Escribe un mensaje...'),
                        hintStyle: TextStyle(
                          color: !widget.enabled
                              ? ((widget.disabledHint != null &&
                                      (widget.disabledHint!.toLowerCase().contains('moderación') ||
                                          widget.disabledHint!.toLowerCase().contains('sancionada') ||
                                          widget.disabledHint!.toLowerCase().contains('bloqueado')))
                                  ? const Color(0xFFFF8A9D)
                                  : const Color(0xFF7A7A8E))
                              : const Color(0xFF7A7A8E),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Botón Formato A⁺ (Abre Editor Enriquecido)
                GestureDetector(
                  onTap: widget.enabled ? _openRichTextModal : null,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1930),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF332B4F),
                        width: 0.8,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'A⁺',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: widget.enabled
                              ? AppColors.accentCyan
                              : const Color(0xFF5A556E),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Botón Enviar ➤
                GestureDetector(
                  onTap: widget.enabled && !_isCoolingDown ? _handleSend : null,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: widget.enabled &&
                              !_isCoolingDown &&
                              _textController.text.trim().isNotEmpty
                          ? AppColors.crimsonGlow
                          : null,
                      color: (!widget.enabled ||
                              _isCoolingDown ||
                              _textController.text.trim().isEmpty)
                          ? const Color(0xFF1E1930)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.enabled &&
                                !_isCoolingDown &&
                                _textController.text.trim().isNotEmpty
                            ? AppColors.accentCrimson
                            : const Color(0xFF332B4F),
                        width: 0.8,
                      ),
                    ),
                    child: _isCoolingDown
                        ? const Center(
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF8E889D),
                                ),
                              ),
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            size: 18,
                            color: widget.enabled &&
                                    _textController.text.trim().isNotEmpty
                                ? Colors.white
                                : const Color(0xFF6E6888),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // ── Fila 2: Herramientas Rápidas (7 Herramientas Estandarizadas) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // 0. Añadir archivo / adjuntos generales (+)
                        _toolButton(
                          icon: Icons.add_circle_outline_rounded,
                          color: AppColors.accentCyan,
                          tooltip: 'Añadir adjuntos',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (widget.onOpenModesTap != null) {
                              widget.onOpenModesTap!();
                            } else {
                              _showAttachmentsMenu();
                            }
                          },
                        ),

                        // 1. Grabar nota de voz (🎙️)
                        _toolButton(
                          icon: _showAudioPanel
                              ? Icons.graphic_eq_rounded
                              : Icons.mic_none_rounded,
                          color: _showAudioPanel
                              ? const Color(0xFFBA68C8)
                              : const Color(0xFF9E9EA8),
                          tooltip: 'Grabar audio',
                          onTap: _toggleAudioPanel,
                        ),

                        // 2. Enviar imagen desde galería o cámara (🖼️)
                        _toolButton(
                          icon: Icons.photo_outlined,
                          color: const Color(0xFF9E9EA8),
                          tooltip: 'Enviar imagen',
                          onTap: _pickImage,
                        ),

                        // 3. Selector de emojis y stickers (😊)
                        _toolButton(
                          icon: Icons.sentiment_satisfied_alt_rounded,
                          color: _showEmojiPicker
                              ? AppColors.accentCyan
                              : const Color(0xFF9E9EA8),
                          tooltip: 'Emojis y Stickers',
                          onTap: () {
                            if (!_showEmojiPicker) {
                              _fieldFocusNode.unfocus();
                            }
                            setState(() {
                              _showEmojiPicker = !_showEmojiPicker;
                              if (_showEmojiPicker) _showAudioPanel = false;
                            });
                          },
                        ),

                        // 4. Acciones de sala / extensiones (🎛️)
                        _toolButton(
                          icon: Icons.tune_rounded,
                          color: const Color(0xFFA594F9),
                          tooltip: 'Acciones de sala / Stickers',
                          onTap: () {
                            if (widget.onOpenModesTap != null && !widget.isRoleplay) {
                              widget.onOpenModesTap!();
                            } else {
                              _showStickerPicker();
                            }
                          },
                        ),

                        // 5. Tirar dados (🎲)
                        _toolButton(
                          icon: Icons.casino_rounded,
                          color: const Color(0xFFFFB300),
                          tooltip: 'Tirar dados',
                          onTap: _showDiceModal,
                        ),

                        // 6. Crear encuesta rápida (📊)
                        _toolButton(
                          icon: Icons.bar_chart_rounded,
                          color: AppColors.accentTeal,
                          tooltip: 'Crear encuesta',
                          onTap: _showPollModal,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Panel Inferior Deslizante de Grabación de Audio ──
          if (_showAudioPanel) _buildAudioRecordingPanel(),

          // ── Drawer de Emojis animados WebP integrado ──
          if (_showEmojiPicker)
            AnimatedEmojiKeyboard(
              onEmojiSelected: (emoji) {
                HapticFeedback.lightImpact();
                if (widget.onSendSticker != null) {
                  widget.onSendSticker!(
                    StickerItem(
                      id: 'webp_${emoji.index}',
                      name: 'Emoji WebP',
                      assetPath: emoji.path,
                      emoji: '✨',
                    ),
                  );
                  setState(() => _showEmojiPicker = false);
                } else {
                  _textController.text += '✨';
                  _textController.selection = TextSelection.collapsed(
                    offset: _textController.text.length,
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  // ── Panel de Grabación de Audio con Visualizador y Controles ─────────────

  Widget _buildAudioRecordingPanel() {
    final durationStr =
        '${(_recordSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordSeconds % 60).toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF100D1A),
        border: Border(top: BorderSide(color: Color(0xFF262038), width: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Estado y Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isPaused
                      ? const Color(0xFFFFB300)
                      : AppColors.accentCrimson,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isPaused ? 'Pausado $durationStr' : 'Grabando $durationStr',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _isPaused ? const Color(0xFFFFB300) : Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Onda de Audio Visualizada (Simulación de Barras de Amplitud)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(24, (i) {
              final heights = [
                8.0,
                14.0,
                22.0,
                32.0,
                18.0,
                10.0,
                28.0,
                36.0,
                20.0,
                12.0,
                26.0,
                34.0,
                16.0,
                30.0,
                22.0,
                10.0,
                18.0,
                28.0,
                14.0,
                32.0,
                20.0,
                12.0,
                24.0,
                10.0,
              ];
              final barHeight = _isPaused
                  ? 6.0
                  : (heights[i % heights.length] *
                            (0.5 + 0.5 * math.sin((_recordSeconds * 3) + i)))
                        .clamp(6.0, 38.0);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 3.5,
                height: barHeight,
                decoration: BoxDecoration(
                  color: i % 2 == 0
                      ? AppColors.accentCyan
                      : AppColors.accentCrimson,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // Controles de Audio: [ Cancelar 🗑️ ] | [ ⏸️ Pausar/Reanudar ] | [ ✈️ Enviar ]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Botón Cancelar (🗑️)
              GestureDetector(
                onTap: _cancelRecording,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E192D),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF332B4F),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFFF5252),
                    size: 20,
                  ),
                ),
              ),

              // Botón Pausar / Reanudar
              GestureDetector(
                onTap: _pauseResumeRecording,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isPaused
                        ? const Color(0xFF0F3A3A)
                        : const Color(0xFF2A1526),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isPaused
                          ? AppColors.accentCyan
                          : AppColors.accentCrimson,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: _isPaused
                        ? AppColors.accentCyan
                        : AppColors.accentCrimson,
                    size: 24,
                  ),
                ),
              ),

              // Botón Enviar (✈️)
              GestureDetector(
                onTap: _sendVoiceNote,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.crimsonGlow,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentCrimson.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _insertMention() {
    HapticFeedback.lightImpact();
    final text = _textController.text;
    final selection = _textController.selection;
    final pos = selection.isValid && selection.baseOffset >= 0
        ? selection.baseOffset
        : text.length;
    final prefix = (pos > 0 && !text[pos - 1].contains(RegExp(r'\s'))) ? ' @' : '@';
    final newText = text.replaceRange(pos, pos, prefix);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
    _fieldFocusNode.requestFocus();
    setState(() {});
  }

  Widget _buildReplyPreviewBanner() {
    final reply = widget.replyingToMessage!;
    final author = (reply['senderName'] ?? reply['username'] ?? 'Usuario').toString();
    final content = (reply['body'] ?? reply['content'] ?? reply['text'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B172B),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: AppColors.accentCyan, width: 3.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.reply_rounded,
            color: AppColors.accentCyan,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Respondiendo a $author',
                  style: const TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  content.isNotEmpty ? content : '[Contenido multimedia]',
                  style: const TextStyle(
                    color: Color(0xFFB0ACC4),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF8E889D)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildEditingBanner() {
    final editMsg = widget.editingMessage!;
    final content = (editMsg['body'] ?? editMsg['content'] ?? editMsg['text'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B172B),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFFFFB300), width: 3.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.edit_rounded,
            color: Color(0xFFFFB300),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Editando mensaje (edición única)',
                  style: TextStyle(
                    color: Color(0xFFFFB300),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: const TextStyle(
                    color: Color(0xFFB0ACC4),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF8E889D)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: widget.onCancelEdit,
          ),
        ],
      ),
    );
  }

  Widget _buildMentionSuggestionsBar() {
    final text = _textController.text;
    final selection = _textController.selection;
    final pos = selection.isValid && selection.baseOffset >= 0
        ? selection.baseOffset
        : text.length;
    if (pos == 0) return const SizedBox.shrink();
    final lastAt = text.lastIndexOf('@', pos - 1);
    if (lastAt < 0) return const SizedBox.shrink();
    final query = text.substring(lastAt + 1, pos);
    if (query.contains(' ')) return const SizedBox.shrink();

    final suggestions = <String>[
      'todos',
      'host',
      ...widget.availableRoles.map((r) => r.name),
    ];
    final filtered = suggestions
        .where((s) => s.toLowerCase().contains(query.toLowerCase()))
        .take(5)
        .toList();
    if (filtered.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF181328),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2442), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            AppAssets.iconMencion1,
            width: 16,
            height: 16,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filtered.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final newText = text.replaceRange(lastAt, pos, '@$s ');
                        _textController.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(
                            offset: lastAt + s.length + 2,
                          ),
                        );
                        setState(() {});
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF241C3B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFA594F9).withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '@$s',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFA594F9),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentitySelectorButton(
    BuildContext context,
    RoleCharacter? activeRole,
  ) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final roleColor = activeRole != null ? activeRole.color : primaryColor;

    return Tooltip(
      message: activeRole != null
          ? 'Identidad: ${activeRole.name} (Toca para cambiar)'
          : 'Identidad: Mi Perfil (${widget.userName})',
      child: GestureDetector(
        onTap: widget.enabled ? _showIdentitySelectorModal : null,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1930),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: activeRole != null
                  ? roleColor.withValues(alpha: 0.8)
                  : const Color(0xFF332B4F),
              width: activeRole != null ? 1.4 : 0.8,
            ),
            boxShadow: activeRole != null
                ? [
                    BoxShadow(
                      color: roleColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (activeRole != null) ...[
                if (activeRole.avatarUrl != null &&
                    activeRole.avatarUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      activeRole.avatarUrl!,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _roleInitial(activeRole),
                    ),
                  )
                else
                  _roleInitial(activeRole),
              ] else ...[
                if (widget.userAvatarUrl != null &&
                    widget.userAvatarUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      widget.userAvatarUrl!,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _userInitial(),
                    ),
                  )
                else
                  _userInitial(),
              ],
              // Micro badge indicador de selector desplegable
              Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13101E),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: activeRole != null
                          ? roleColor
                          : const Color(0xFF5A556E),
                      width: 0.6,
                    ),
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    size: 9,
                    color: activeRole != null ? roleColor : Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleInitial(RoleCharacter role) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: role.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          role.name.isNotEmpty ? role.name[0].toUpperCase() : 'R',
          style: TextStyle(
            color: role.color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _userInitial() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF2E2746),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: Color(0xFFB39DDB),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  void _showIdentitySelectorModal() {
    if (!widget.enabled) return;
    HapticFeedback.lightImpact();
    final myId = widget.currentUserId ?? '';

    // Filtrar los roles asignados al usuario actual o disponibles si es host
    final userRoles = widget.availableRoles.where((r) {
      if (r.takenByUserId != null && r.takenByUserId == myId) return true;
      if (r.occupiedBy != null && r.occupiedBy == myId) return true;
      if (widget.isHost && !r.isTaken) return true;
      return false;
    }).toList();

    // Asegurar que si hay un rol seleccionado actualmente, figure en la lista
    if (_selectedRole != null &&
        !userRoles.any((r) => r.id == _selectedRole!.id)) {
      userRoles.insert(0, _selectedRole!);
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final primaryColor = theme.colorScheme.primary;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141220),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: primaryColor.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicador de arrastre
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Título y Subtítulo
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.badge_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cambiar Identidad',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Selecciona con qué personaje o perfil deseas hablar',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF262038), height: 1),
                const SizedBox(height: 12),

                // 1. Opción Personal: "Mi Perfil ([Nombre del Usuario])"
                _buildIdentityTile(
                  ctx: ctx,
                  title: 'Mi Perfil (${widget.userName})',
                  subtitle: 'Cuenta personal (Mensajes fuera de rol)',
                  avatarUrl: widget.userAvatarUrl,
                  isSelected: _selectedRole == null,
                  fallbackColor: primaryColor,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedRole = null;
                    });
                    widget.onRoleChanged?.call(null);
                    widget.onIdentityChanged?.call(null);
                  },
                ),

                const SizedBox(height: 12),

                // Encabezado de Sección: Roles Disponibles
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    'ROLES Y PERSONAJES ASIGNADOS (${userRoles.length})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ),

                if (userRoles.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B172B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF2E2746),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No tienes personajes equipados en el Stage. Puedes unirte a un rol desde el escenario superior.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...userRoles.map((role) {
                    final isRoleSelected = _selectedRole?.id == role.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildIdentityTile(
                        ctx: ctx,
                        title: role.name,
                        subtitle: role.tagline.isNotEmpty
                            ? role.tagline
                            : 'Ficha de Rol equipada',
                        avatarUrl: role.avatarUrl,
                        isSelected: isRoleSelected,
                        fallbackColor: role.color,
                        roleBadgeColor: role.color,
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _selectedRole = role;
                          });
                          widget.onRoleChanged?.call(role);
                          widget.onIdentityChanged?.call(role);
                        },
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIdentityTile({
    required BuildContext ctx,
    required String title,
    required String subtitle,
    required String? avatarUrl,
    required bool isSelected,
    required Color fallbackColor,
    Color? roleBadgeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? fallbackColor.withValues(alpha: 0.12)
              : const Color(0xFF1B172B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? fallbackColor.withValues(alpha: 0.6)
                : const Color(0xFF2E2746),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: roleBadgeColor ?? fallbackColor,
                  width: 1.2,
                ),
              ),
              child: ClipOval(
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _fallbackTileAvatar(title, fallbackColor),
                      )
                    : _fallbackTileAvatar(title, fallbackColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFFE2E0EE),
                          ),
                        ),
                      ),
                      if (roleBadgeColor != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: roleBadgeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: fallbackColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackTileAvatar(String title, Color color) {
    return Container(
      color: color.withValues(alpha: 0.25),
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : '?',
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  void _showAttachmentsMenu() {
    if (!widget.enabled) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141220),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF2E2746), width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.accentCyan,
                ),
                title: const Text(
                  'Galería de fotos',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: Color(0xFFBA68C8),
                ),
                title: const Text(
                  'Cámara',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final image =
                      await picker.pickImage(source: ImageSource.camera);
                  if (image != null) widget.onSendImage(image.path);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.alternate_email_rounded,
                  color: Color(0xFFA594F9),
                ),
                title: const Text(
                  'Mencionar usuario (@)',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _insertMention();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.accentTeal,
                ),
                title: const Text(
                  'Crear Encuesta',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPollModal();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.casino_rounded,
                  color: Color(0xFFFFB300),
                ),
                title: const Text(
                  'Lanzar Dados',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDiceModal();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolButton({
    IconData? icon,
    Widget? iconWidget,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final child = GestureDetector(
      onTap: widget.enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: Colors.transparent,
        child: iconWidget ??
            Icon(
              icon,
              size: 22,
              color: widget.enabled ? color : const Color(0xFF4A4458),
            ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip, child: child);
    }
    return child;
  }
}
