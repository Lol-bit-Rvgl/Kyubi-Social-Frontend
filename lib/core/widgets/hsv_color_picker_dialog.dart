import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Formateador para códigos hexadecimales (#RRGGBB).
class _HexInputFormatter extends TextInputFormatter {
  const _HexInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered =
        newValue.text.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    final truncated =
        filtered.length > 6 ? filtered.substring(0, 6) : filtered;
    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(offset: truncated.length),
    );
  }
}

/// Selector de espectro de color visual interactivo (HSV / Rueda cromática / Panel 2D).
///
/// Permite seleccionar colores mediante:
/// 1. Rueda cromática HSV circular (tono por ángulo, saturación por radio).
/// 2. Panel 2D de Saturación y Brillo con barra deslizadora de Tono (Hue).
/// 3. Entrada manual `#RRGGBB` sincronizada en tiempo real.
/// 4. Vista previa en vivo del texto / nombre de usuario y burbuja de chat.
/// 5. Paleta rápida de colores populares / presets de estilo.
class HsvColorSpectrumPicker extends StatefulWidget {
  const HsvColorSpectrumPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
    this.onQuickSelect,
    this.previewName,
    this.showBubblePreview = true,
  });

  final Color initialColor;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<String>? onQuickSelect;
  final String? previewName;
  final bool showBubblePreview;

  @override
  State<HsvColorSpectrumPicker> createState() => _HsvColorSpectrumPickerState();
}

class _HsvColorSpectrumPickerState extends State<HsvColorSpectrumPicker> {
  late HSVColor _hsvColor;
  late TextEditingController _hexController;
  int _pickerMode = 0; // 0 = Rueda HSV, 1 = Panel 2D S/V

  static const List<String> _quickPalette = [
    '#FF0055', '#E91E63', '#F44336', '#FF5722',
    '#FF9100', '#FFD700', '#FFC107', '#FFA000',
    '#00E676', '#4CAF50', '#1DE9B6', '#00BFA5',
    '#00E5FF', '#03A9F4', '#2196F3', '#3D5AFE',
    '#BA68C8', '#9C27B0', '#7C4DFF', '#673AB7',
    '#FF1493', '#FF4081', '#A594F9', '#FFFFFF',
  ];

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.initialColor);
    final hexCode = _colorToHex(widget.initialColor).replaceAll('#', '');
    _hexController = TextEditingController(text: hexCode);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  static String _colorToHex(Color color) {
    final int r = (color.r * 255.0).round().clamp(0, 255);
    final int g = (color.g * 255.0).round().clamp(0, 255);
    final int b = (color.b * 255.0).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'.toUpperCase();
  }

  static Color _hexToColor(String hex) {
    return AppColors.fromHex(hex);
  }

  void _updateHsv(HSVColor newHsv, {bool updateText = true}) {
    setState(() {
      _hsvColor = newHsv;
      if (updateText) {
        final hex = _colorToHex(newHsv.toColor()).replaceAll('#', '');
        if (_hexController.text != hex) {
          _hexController.text = hex;
        }
      }
    });
    widget.onColorChanged(_hsvColor.toColor());
  }

  void _onHexSubmitted(String value) {
    final clean = value.replaceAll('#', '').trim().toUpperCase();
    if (clean.length == 6 && RegExp(r'^[0-9A-F]{6}$').hasMatch(clean)) {
      final color = _hexToColor('#$clean');
      _updateHsv(HSVColor.fromColor(color), updateText: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _hsvColor.toColor();
    final hexString = _colorToHex(currentColor);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Paleta Rápida (Presets Populares) ──
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: _quickPalette.map((hex) {
              final color = _hexToColor(hex);
              final isSelected = hexString.toUpperCase() == hex.toUpperCase();
              return InkWell(
                key: Key('palette_color_$hex'),
                onTap: () {
                  _updateHsv(HSVColor.fromColor(color));
                  widget.onQuickSelect?.call(hex);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.black45,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: ThemeData.estimateBrightnessForColor(color) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // ── Selector de Modo: Rueda vs Panel 2D ──
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF140F24),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const Key('hsv_mode_wheel'),
                    onTap: () => setState(() => _pickerMode = 0),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _pickerMode == 0
                            ? const Color(0xFFA594F9).withValues(alpha: 0.22)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        border: _pickerMode == 0
                            ? Border.all(
                                color: const Color(0xFFA594F9).withValues(alpha: 0.4),
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.donut_large_rounded,
                            size: 15,
                            color: _pickerMode == 0
                                ? const Color(0xFFA594F9)
                                : Colors.white60,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Rueda HSV',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _pickerMode == 0
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: _pickerMode == 0
                                    ? Colors.white
                                    : Colors.white60,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    key: const Key('hsv_mode_box'),
                    onTap: () => setState(() => _pickerMode = 1),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _pickerMode == 1
                            ? const Color(0xFFA594F9).withValues(alpha: 0.22)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        border: _pickerMode == 1
                            ? Border.all(
                                color: const Color(0xFFA594F9).withValues(alpha: 0.4),
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.grid_view_rounded,
                            size: 15,
                            color: _pickerMode == 1
                                ? const Color(0xFFA594F9)
                                : Colors.white60,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Panel 2D',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _pickerMode == 1
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: _pickerMode == 1
                                    ? Colors.white
                                    : Colors.white60,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Área Interactiva del Selector ──
          if (_pickerMode == 0) ...[
            // Rueda Cromática Circular
            Center(
              child: SizedBox(
                width: 170,
                height: 170,
                child: _HsvWheelCanvas(
                  hsv: _hsvColor,
                  onChanged: (hsv) => _updateHsv(hsv),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Barra de Brillo / Valor (Value)
            Row(
              children: [
                const Icon(
                  Icons.brightness_medium_rounded,
                  size: 18,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ValueSlider(
                    hsv: _hsvColor,
                    onChanged: (val) =>
                        _updateHsv(_hsvColor.withValue(val)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_hsvColor.value * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ] else ...[
            // Panel 2D de Saturación y Brillo
            SizedBox(
              height: 170,
              child: _SaturationValueBox(
                hsv: _hsvColor,
                onChanged: (hsv) => _updateHsv(hsv),
              ),
            ),
            const SizedBox(height: 14),

            // Deslizador de Tono Arcoíris (Hue)
            Row(
              children: [
                const Icon(
                  Icons.color_lens_rounded,
                  size: 18,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HueSlider(
                    hue: _hsvColor.hue,
                    onChanged: (newHue) =>
                        _updateHsv(_hsvColor.withHue(newHue)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_hsvColor.hue.round()}°',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Deslizador de Brillo / Valor
            Row(
              children: [
                const Icon(
                  Icons.brightness_medium_rounded,
                  size: 18,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ValueSlider(
                    hsv: _hsvColor,
                    onChanged: (val) =>
                        _updateHsv(_hsvColor.withValue(val)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_hsvColor.value * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // ── Fila de Muestra Actual + Input Manual #HEX ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF140F24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Comparación Original vs Nuevo
                Row(
                  children: [
                    Tooltip(
                      message: 'Color original',
                      child: Container(
                        width: 28,
                        height: 38,
                        decoration: BoxDecoration(
                          color: widget.initialColor,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(8),
                          ),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Color seleccionado',
                      child: Container(
                        width: 28,
                        height: 38,
                        decoration: BoxDecoration(
                          color: currentColor,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(8),
                          ),
                          border: Border.all(color: Colors.white54, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: currentColor.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Campo interactivo #HEX
                Expanded(
                  child: TextFormField(
                    controller: _hexController,
                    maxLength: 6,
                    onChanged: _onHexSubmitted,
                    inputFormatters: const [_HexInputFormatter()],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      prefixText: '#',
                      prefixStyle: const TextStyle(
                        color: Color(0xFFA594F9),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1E1833),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFA594F9),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Botón copiar código
                IconButton(
                  tooltip: 'Copiar #HEX',
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: hexString));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Código $hexString copiado al portapapeles'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Vista Previa en Vivo de Nombre / Texto ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0A14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Nombre: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9E9EA8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.previewName != null && widget.previewName!.isNotEmpty
                        ? widget.previewName!
                        : 'Tu Nombre Aquí',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: currentColor,
                      letterSpacing: -0.2,
                      shadows: [
                        Shadow(
                          color: currentColor.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),

          // ── Vista Previa de Burbuja de Chat ──
          if (widget.showBubblePreview) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0A14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vista previa de Burbuja:',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF9E9EA8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Burbuja saliente con el color
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      constraints: const BoxConstraints(maxWidth: 240),
                      decoration: BoxDecoration(
                        color: currentColor.withValues(alpha: 0.85),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: currentColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '¡Hola! Así lucirá tu mensaje con este tono.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: ThemeData.estimateBrightnessForColor(currentColor) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIÁLOGO / MODAL REUTILIZABLE
// ─────────────────────────────────────────────────────────────────────────────

/// Muestra un modal/diálogo con el selector interactivo de espectro HSV.
///
/// Retorna el código `#RRGGBB` seleccionado si el usuario acepta, o `null` si cancela.
Future<String?> showHsvColorPickerDialog(
  BuildContext context, {
  required String initialHex,
  String? previewName,
  String title = 'Espectro de Colores',
  bool showBubblePreview = true,
  ValueChanged<String>? onLiveColorChanged,
}) async {
  Color currentColor = AppColors.fromHex(initialHex);
  String finalHex = initialHex;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF120E22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFA594F9).withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.palette_rounded,
              color: Color(0xFFA594F9),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: HsvColorSpectrumPicker(
          initialColor: currentColor,
          previewName: previewName,
          showBubblePreview: showBubblePreview,
          onQuickSelect: (hex) {
            finalHex = hex;
            onLiveColorChanged?.call(hex);
            Navigator.of(ctx).pop(true);
          },
          onColorChanged: (newColor) {
            currentColor = newColor;
            final int r = (newColor.r * 255.0).round().clamp(0, 255);
            final int g = (newColor.g * 255.0).round().clamp(0, 255);
            final int b = (newColor.b * 255.0).round().clamp(0, 255);
            finalHex =
                '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
                    .toUpperCase();
            onLiveColorChanged?.call(finalHex);
          },
        ),
      ),
      actions: [
        TextButton(
          key: const Key('hsv_dialog_cancel'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(
            'Cancelar',
            style: TextStyle(
              color: Colors.white60,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ElevatedButton(
          key: const Key('hsv_dialog_apply'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA594F9),
            foregroundColor: const Color(0xFF0F0C1B),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text(
            'Aplicar',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    ),
  );

  if (result == true) {
    return finalHex;
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTES GRÁFICOS Y CANVASES HSV
// ─────────────────────────────────────────────────────────────────────────────

/// Rueda cromática HSV circular interactiva.
class _HsvWheelCanvas extends StatelessWidget {
  const _HsvWheelCanvas({
    required this.hsv,
    required this.onChanged,
  });

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  void _handleTouch(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    final dist = math.sqrt(dx * dx + dy * dy);
    final sat = (dist / radius).clamp(0.0, 1.0);

    // Ángulo en radianes -> grados 0-360
    double angle = math.atan2(dy, dx) * 180 / math.pi;
    if (angle < 0) angle += 360;

    onChanged(HSVColor.fromAHSV(1.0, angle, sat, hsv.value));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final radius = size.width / 2;

        // Posición del selector
        final angleRad = hsv.hue * math.pi / 180;
        final thumbDist = hsv.saturation * radius;
        final thumbX = radius + thumbDist * math.cos(angleRad);
        final thumbY = radius + thumbDist * math.sin(angleRad);

        return GestureDetector(
          onPanDown: (d) => _handleTouch(d.localPosition, size),
          onPanUpdate: (d) => _handleTouch(d.localPosition, size),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: size,
                painter: _WheelPainter(value: hsv.value),
              ),
              Positioned(
                left: thumbX - 11,
                top: thumbY - 11,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: hsv.toColor(),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Barrido continuo de tonos (Sweep Gradient 0° - 360°)
    const sweepColors = [
      Color(0xFFFF0000), // 0°
      Color(0xFFFFFF00), // 60°
      Color(0xFF00FF00), // 120°
      Color(0xFF00FFFF), // 180°
      Color(0xFF0000FF), // 240°
      Color(0xFFFF00FF), // 300°
      Color(0xFFFF0000), // 360°
    ];

    final sweepPaint = Paint()
      ..shader = const SweepGradient(colors: sweepColors).createShader(rect);
    canvas.drawCircle(center, radius, sweepPaint);

    // 2. Gradiente radial blanco en centro -> transparente en bordes (Saturación)
    final satPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 1.0),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, satPaint);

    // 3. Si el brillo / valor < 1.0, oscurecer
    if (value < 1.0) {
      final darkPaint = Paint()
        ..color = Colors.black.withValues(alpha: (1.0 - value).clamp(0.0, 0.95));
      canvas.drawCircle(center, radius, darkPaint);
    }

    // Borde exterior
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

/// Panel interactivo 2D de Saturación (eje X) y Brillo/Valor (eje Y).
class _SaturationValueBox extends StatelessWidget {
  const _SaturationValueBox({
    required this.hsv,
    required this.onChanged,
  });

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  void _handleTouch(Offset localPosition, Size size) {
    final sat = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final val = (1.0 - (localPosition.dy / size.height)).clamp(0.0, 1.0);
    onChanged(HSVColor.fromAHSV(1.0, hsv.hue, sat, val));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final thumbX = (hsv.saturation * size.width).clamp(0.0, size.width);
        final thumbY = ((1.0 - hsv.value) * size.height).clamp(0.0, size.height);

        return GestureDetector(
          onPanDown: (d) => _handleTouch(d.localPosition, size),
          onPanUpdate: (d) => _handleTouch(d.localPosition, size),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: size,
                  painter: _SaturationValuePainter(hue: hsv.hue),
                ),
                Positioned(
                  left: thumbX - 10,
                  top: thumbY - 10,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: hsv.toColor(),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SaturationValuePainter extends CustomPainter {
  _SaturationValuePainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final pureHueColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();

    // Fondo del color del tono puro
    canvas.drawRect(rect, Paint()..color = pureHueColor);

    // Gradiente horizontal blanco -> transparente (Saturación)
    final satPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white, Colors.transparent],
      ).createShader(rect);
    canvas.drawRect(rect, satPaint);

    // Gradiente vertical transparente -> negro (Brillo/Valor)
    final valPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
      ).createShader(rect);
    canvas.drawRect(rect, valPaint);

    // Borde
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}

/// Slider de tono continuo arcoíris (0° a 360°).
class _HueSlider extends StatelessWidget {
  const _HueSlider({
    required this.hue,
    required this.onChanged,
  });

  final double hue;
  final ValueChanged<double> onChanged;

  void _handleTouch(Offset localPosition, Size size) {
    final newHue = ((localPosition.dx / size.width) * 360.0).clamp(0.0, 360.0);
    onChanged(newHue);
  }

  @override
  Widget build(BuildContext context) {
    const rainbowColors = [
      Color(0xFFFF0000),
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0xFF00FFFF),
      Color(0xFF0000FF),
      Color(0xFFFF00FF),
      Color(0xFFFF0000),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 20);
        final thumbX = (hue / 360.0 * size.width).clamp(0.0, size.width);

        return GestureDetector(
          onPanDown: (d) => _handleTouch(d.localPosition, size),
          onPanUpdate: (d) => _handleTouch(d.localPosition, size),
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: const LinearGradient(colors: rainbowColors),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
              ),
              Positioned(
                left: (thumbX - 9).clamp(0.0, size.width - 18),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor(),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Slider de brillo / valor (Value) de 0.0 a 1.0.
class _ValueSlider extends StatelessWidget {
  const _ValueSlider({
    required this.hsv,
    required this.onChanged,
  });

  final HSVColor hsv;
  final ValueChanged<double> onChanged;

  void _handleTouch(Offset localPosition, Size size) {
    final val = (localPosition.dx / size.width).clamp(0.0, 1.0);
    onChanged(val);
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = HSVColor.fromAHSV(1.0, hsv.hue, hsv.saturation, 1.0).toColor();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 20);
        final thumbX = (hsv.value * size.width).clamp(0.0, size.width);

        return GestureDetector(
          onPanDown: (d) => _handleTouch(d.localPosition, size),
          onPanUpdate: (d) => _handleTouch(d.localPosition, size),
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: LinearGradient(
                    colors: [Colors.black, baseColor],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
              ),
              Positioned(
                left: (thumbX - 9).clamp(0.0, size.width - 18),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: hsv.toColor(),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
