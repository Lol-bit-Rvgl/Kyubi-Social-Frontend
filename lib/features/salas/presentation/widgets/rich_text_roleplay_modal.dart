import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';

/// Editor de Turno de Rol A⁺ a Pantalla Completa (Ref: Botón A⁺).
///
/// Widget 100% autocontenido (sin providers ni dependencias del árbol local):
/// recibe únicamente [initialText], [onSend] y [onCancel]. Renderiza:
///  - Header: título "Editor de Rol", botón cerrar (✕) y botón "Publicar".
///  - Barra de herramientas limpia: alineación, estilos (negrita/cursiva/
///    resaltado `==texto==`), tamaños y swatches de color.
///  - Caja de texto amplia y vista previa en vivo ligera (parseo local).
class RichTextRoleplayModal extends StatefulWidget {
  const RichTextRoleplayModal({
    super.key,
    required this.initialText,
    required this.onSend,
    required this.onCancel,
  });

  /// Presenta el editor como pantalla completa (route root). Devuelve el
  /// resultado de la ruta; el texto se entrega vía [onSend].
  static Future<void> show(
    BuildContext context, {
    required String initialText,
    required ValueChanged<String> onSend,
    required VoidCallback onCancel,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => RichTextRoleplayModal(
          initialText: initialText,
          onSend: onSend,
          onCancel: onCancel,
        ),
      ),
    );
  }

  final String initialText;
  final ValueChanged<String> onSend;
  final VoidCallback onCancel;

  @override
  State<RichTextRoleplayModal> createState() => _RichTextRoleplayModalState();
}

class _RichTextRoleplayModalState extends State<RichTextRoleplayModal> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Envuelve la selección activa con [prefix]/[suffix]; si no hay selección,
  /// inserta los delimitadores (con [fallback] en medio) y sitúa el cursor en
  /// el centro. Hace que el formato "abra/cierre" alrededor de lo escrito.
  void _wrapSelection(String prefix, String suffix, [String fallback = '']) {
    HapticFeedback.selectionClick();
    final text = _controller.text;
    final selection = _controller.selection;

    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$prefix$selectedText$suffix',
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.end + prefix.length + suffix.length,
        ),
      );
    } else {
      final pos = _controller.selection.baseOffset;
      final insertText = '$prefix$fallback$suffix';
      if (pos >= 0) {
        final newText = text.replaceRange(pos, pos, insertText);
        final cursorOffset = pos + prefix.length + fallback.length;
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursorOffset),
        );
      } else {
        _controller.text += insertText;
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length - suffix.length,
        );
      }
    }
    setState(() {});
  }

  /// Aplica un nivel jerárquico de título en el inicio de la línea actual.
  /// [level]: 0 = Normal (T¹, quita marca de encabezado), 1 = Subtítulo (T²),
  /// 2 = Título (T³).
  void _applyHeading(int level) {
    HapticFeedback.selectionClick();
    final t = _controller.text;
    final sel = _controller.selection;
    final pos = sel.isValid
        ? sel.start
        : (_controller.selection.baseOffset >= 0
              ? _controller.selection.baseOffset
              : t.length);
    final ls = t.lastIndexOf('\n', pos - 1) + 1;
    final lineEnd = t.indexOf('\n', ls);
    final end = lineEnd < 0 ? t.length : lineEnd;
    final desired = level == 2 ? '# ' : (level == 1 ? '## ' : '');
    final head = RegExp(r'^(#{1,6}\s*)').firstMatch(t.substring(ls, end));

    String newText;
    if (desired == '') {
      newText = head != null
          ? t.substring(0, ls) + t.substring(ls + head[1]!.length)
          : t;
    } else {
      newText = head != null
          ? t.substring(0, ls) + desired + t.substring(ls + head[1]!.length)
          : t.substring(0, ls) + desired + t.substring(ls);
    }
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: ls + desired.length),
    );
    setState(() {});
  }

  /// Inserta/quita un marcador de alineación en el inicio de la línea actual.
  /// [marker]: 'left' | 'center' | 'right' | 'justify'.
  void _applyAlignment(String marker) {
    HapticFeedback.selectionClick();
    final t = _controller.text;
    final pos = _controller.selection.baseOffset >= 0
        ? _controller.selection.baseOffset
        : t.length;
    final ls = t.lastIndexOf('\n', pos - 1) + 1;
    final lineEnd = t.indexOf('\n', ls);
    final end = lineEnd < 0 ? t.length : lineEnd;
    final line = t.substring(ls, end);
    final alignRe = RegExp(r'^\[(left|center|right|justify)\]\s*');
    String newLine = line;
    if (alignRe.hasMatch(line)) {
      newLine = line.replaceFirst(alignRe, '');
    }
    final pref = marker == 'left' ? '' : '[$marker] ';
    final newText = t.substring(0, ls) + pref + newLine + t.substring(end);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: ls + pref.length),
    );
    setState(() {});
  }

  Future<void> _copyDraft() async {
    final text = _controller.text;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay texto para copiar'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Borrador copiado al portapapeles'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _clearAll() {
    if (_controller.text.isEmpty) return;
    HapticFeedback.mediumImpact();
    _controller.clear();
    setState(() {});
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    widget.onSend(text);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _buildSafeScaffold(context);
    } catch (e) {
      debugPrint('[A+ editor] build error: $e');
      return Scaffold(
        backgroundColor: AppColors.backgroundBase,
        appBar: AppBar(
          leading: CloseButton(onPressed: widget.onCancel),
          title: const Text('Editor de Rol'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudo abrir el editor.\n\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildSafeScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBase,
        elevation: 0,
        leading: CloseButton(
          color: Colors.white70,
          onPressed: widget.onCancel,
        ),
        title: const Text(
          'Editor de Rol',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _handleSend,
              icon: const Icon(Icons.send_rounded, size: 15, color: Colors.white),
              label: const Text(
                'Publicar',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.accentCrimson,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de herramientas (Wrap, sin Row desbordables).
              _buildToolbar(),
              const Divider(color: Color(0xFF221E32), height: 1),

              // Caja de texto amplia (minLines/maxLines, sin expands: true).
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _controller,
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
                  minLines: 4,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText:
                        'Escribe tu turno de rol...\n\nUsa *acciones en asteriscos* para describir movimientos y «diálogos» para las palabras de tu personaje.',
                    hintStyle: TextStyle(
                      color: Color(0xFF6A6A7E),
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),

              const Divider(color: Color(0xFF221E32), height: 1),

              // Vista previa en vivo (altura acotada para evitar overflow).
              _buildLivePreview(),
            ],
          ),
        ),
      ),
    );
  }

  /// Vista previa en vivo ligera y autocontenida: parsea los marcadores
  /// básicos (`**negrita**`, `*cursiva*`, `==resaltado==`, `«diálogo»`) y los
  /// muestra en un Text.rich sin depender de la burbuja rol pesada.
  Widget _buildLivePreview() {
    final text = _controller.text.trim();
    return Container(
      height: 120,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF0C0A16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.visibility_rounded,
                color: AppColors.accentCyan,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'Vista previa',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentCyan.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: text.isEmpty
                ? Center(
                    child: Text(
                      'Escribe para ver el formato aquí',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: _buildPreviewSpans(text),
                  ),
          ),
        ],
      ),
    );
  }

  /// Convierte el texto del borrador en spans con formato básico.
  Widget _buildPreviewSpans(String text) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'(\*\*[^*]+\*\*)|(\*[^*\n]+\*)|(==[^=]+==)|(«[^»]*»)',
      multiLine: true,
    );
    var last = 0;
    void addPlain(String s) {
      if (s.isEmpty) return;
      spans.add(
        TextSpan(
          text: s,
          style: const TextStyle(color: Colors.white, height: 1.35),
        ),
      );
    }

    for (final m in pattern.allMatches(text)) {
      if (m.start > last) addPlain(text.substring(last, m.start));
      last = m.end;
      if (m.group(1) != null) {
        spans.add(TextSpan(
          text: m.group(1)!.substring(2, m.group(1)!.length - 2),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
          text: m.group(2)!.substring(1, m.group(2)!.length - 1),
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            color: AppColors.accentCyan,
          ),
        ));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
          text: m.group(3)!.substring(2, m.group(3)!.length - 2),
          style: TextStyle(
            backgroundColor: const Color(0xFFFFD600).withValues(alpha: 0.28),
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(
          text: m.group(4)!.substring(1, m.group(4)!.length - 1),
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            color: AppColors.accentTeal,
            fontWeight: FontWeight.w500,
          ),
        ));
      }
    }
    if (last < text.length) addPlain(text.substring(last));

    return Align(
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(children: spans),
        style: const TextStyle(fontSize: 13.5),
      ),
    );
  }

  /// Barra de formato fijada justo encima del teclado (al pie del editor).
  /// Usa `Wrap` (nunca `Row` desbordable) para garantizar que cualquier ancho
  /// de pantalla o fuente grande pliegue los botones a varias líneas.
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: const Color(0xFF141022),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: formatos básicos + tamaños tipográficos
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _formatChip(
                label: '🎭 Acción',
                tooltip: 'Acción de rol (*acción*)',
                color: AppColors.accentCyan,
                onTap: () => _wrapSelection('*', '*', 'acción'),
              ),
              _formatChip(
                label: '«» Diálogo',
                tooltip: 'Diálogo («diálogo»)',
                color: const Color(0xFFFFD600),
                onTap: () => _wrapSelection('«', '»', 'diálogo'),
              ),
              _formatChip(
                iconWidget: Image.asset(
                  AppAssets.iconMencion1,
                  width: 15,
                  height: 15,
                  fit: BoxFit.contain,
                ),
                label: 'Mención',
                tooltip: 'Mencionar a un usuario (@usuario)',
                color: const Color(0xFFA594F9),
                onTap: () => _wrapSelection('@', '', 'usuario'),
              ),
              _formatChip(
                label: 'B',
                tooltip: 'Negrita',
                color: Colors.white,
                onTap: () => _wrapSelection('**', '**', 'texto'),
              ),
              _formatChip(
                label: 'I',
                tooltip: 'Cursiva',
                color: const Color(0xFFD500F9),
                onTap: () => _wrapSelection('*', '*', 'texto'),
              ),
              _formatChip(
                label: '🖍️ Resaltado',
                tooltip: 'Resaltar (==texto==)',
                color: const Color(0xFFFFD600),
                onTap: () => _wrapSelection('==', '==', 'texto'),
              ),
              _formatChip(
                label: '📜 Narración',
                tooltip: 'Separador narrativo',
                color: AppColors.accentTeal,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _controller.text += '\n\n━━━━━━━━━━━━━━\n';
                  setState(() {});
                },
              ),
              _sizeButton('T¹', 'Normal', level: 0),
              _sizeButton('T²', 'Subtítulo', level: 1),
              _sizeButton('T³', 'Título', level: 2),
            ],
          ),
          const SizedBox(height: 8),
          // Fila 2: alineación + utilidades
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _iconTool(
                icon: Icons.format_align_left,
                tooltip: 'Alinear izquierda',
                onTap: () => _applyAlignment('left'),
              ),
              _iconTool(
                icon: Icons.format_align_center,
                tooltip: 'Alinear centro',
                onTap: () => _applyAlignment('center'),
              ),
              _iconTool(
                icon: Icons.format_align_right,
                tooltip: 'Alinear derecha',
                onTap: () => _applyAlignment('right'),
              ),
              _iconTool(
                icon: Icons.format_align_justify,
                tooltip: 'Justificar',
                onTap: () => _applyAlignment('justify'),
              ),
              _iconTool(
                icon: Icons.copy_rounded,
                tooltip: 'Copiar borrador',
                onTap: _copyDraft,
              ),
              _iconTool(
                icon: Icons.edit_rounded,
                tooltip: 'Limpiar / Deshacer formato',
                onTap: _clearAll,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Fila 3: paleta de colores del texto
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Paleta',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              _colorSwatch(const Color(0xFFFFFFFF), 'blanco'),
              _colorSwatch(const Color(0xFF00E5FF), 'cian'),
              _colorSwatch(const Color(0xFF00D4B4), 'verde'),
              _colorSwatch(const Color(0xFFD500F9), 'purpura'),
              _colorSwatch(const Color(0xFFFFD600), 'amarillo'),
              _colorSwatch(const Color(0xFFFF7043), 'naranja'),
              _colorSwatch(const Color(0xFFEF4444), 'rojo'),
            ],
          ),
        ],
      ),
    );
  }

  /// Swatch circular que envuelve la selección con el marcador
  /// `{color:#HEX}texto{/color}` (renderizado por la burbuja del chat).
  Widget _colorSwatch(Color c, String name) {
    final hex = c
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
    return Tooltip(
      message: 'Color $name (#$hex)',
      child: GestureDetector(
        onTap: () => _wrapSelection('{color:#$hex}', '{/color}', 'texto'),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 0.8),
          ),
        ),
      ),
    );
  }

  Widget _formatChip({
    Widget? iconWidget,
    required String label,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconWidget != null) ...[
                iconWidget,
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sizeButton(String label, String tooltip, {required int level}) {
    final active = _currentHeadingLevel() == level;
    final color = active ? AppColors.accentCyan : Colors.white70;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => _applyHeading(level),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? AppColors.accentCyan.withValues(alpha: 0.18)
                : const Color(0xFF1C172B),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active ? AppColors.accentCyan : const Color(0xFF2E2744),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconTool({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1C172B),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFF2E2744), width: 0.8),
          ),
          child: Icon(icon, color: Colors.white70, size: 17),
        ),
      ),
    );
  }

  /// Nivel de encabezado de la línea actual (0 = normal, 1 = T², 2 = T³).
  int _currentHeadingLevel() {
    final t = _controller.text;
    final pos = _controller.selection.baseOffset >= 0
        ? _controller.selection.baseOffset
        : t.length;
    final ls = t.lastIndexOf('\n', pos - 1) + 1;
    final lineEnd = t.indexOf('\n', ls);
    final end = lineEnd < 0 ? t.length : lineEnd;
    final line = t.substring(ls, end);
    if (RegExp(r'^#{3,}\s').hasMatch(line)) return 2;
    if (line.startsWith('##')) return 1;
    if (line.startsWith('#')) return 2;
    return 0;
  }
}
