import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/hsv_color_picker_dialog.dart';

/// Formateador que convierte caracteres a mayúsculas, filtra caracteres no hexadecimales
/// y limita la longitud a un máximo de 6 caracteres.
class HexColorFormatter extends TextInputFormatter {
  const HexColorFormatter();

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

/// Selector de color hexadecimal (#HEX) interactivo y paleta para el nombre.
///
/// Ofrece:
/// 1. Chips de colores predefinidos como accesos rápidos.
/// 2. Entrada de texto interactiva con prefijo '#' y validación estricta de 6 caracteres HEX.
/// 3. Muestra de color en tiempo real (36x36) con soporte para abrir diálogo con espectro extendido.
/// 4. Vista previa en vivo del nombre con el color seleccionado.
class HexColorPickerTile extends StatefulWidget {
  const HexColorPickerTile({
    super.key,
    this.initialColor,
    required this.onColorChanged,
    this.previewName,
  });

  final String? initialColor;
  final ValueChanged<String> onColorChanged;
  final String? previewName;

  static const List<String> extendedPalette = [
    '#FF0055', '#E91E63', '#F44336', '#FF5722',
    '#FF9100', '#FFD700', '#FFC107', '#FFA000',
    '#00E676', '#4CAF50', '#1DE9B6', '#00BFA5',
    '#00E5FF', '#03A9F4', '#2196F3', '#3D5AFE',
    '#BA68C8', '#9C27B0', '#7C4DFF', '#673AB7',
    '#FF1493', '#FF4081', '#A594F9', '#FFFFFF',
  ];

  @override
  State<HexColorPickerTile> createState() => _HexColorPickerTileState();
}

class _HexColorPickerTileState extends State<HexColorPickerTile> {
  late final TextEditingController _hexController;
  late String _currentColorHex;

  @override
  void initState() {
    super.initState();
    final raw = widget.initialColor?.replaceAll('#', '').trim() ?? '';
    _currentColorHex = raw.length == 6 ? '#${raw.toUpperCase()}' : '#FFFFFF';
    _hexController = TextEditingController(
      text: raw.length == 6 ? raw.toUpperCase() : 'FFFFFF',
    );
  }

  @override
  void didUpdateWidget(covariant HexColorPickerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialColor != null &&
        widget.initialColor != oldWidget.initialColor) {
      final raw = widget.initialColor!.replaceAll('#', '').trim().toUpperCase();
      if (raw.length == 6 && raw != _hexController.text) {
        _hexController.text = raw;
        _currentColorHex = '#$raw';
      }
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) return Color(0xFF000000 | val);
    }
    return Colors.white;
  }

  void _onHexChanged(String value) {
    final clean = value.replaceAll('#', '').trim().toUpperCase();
    if (clean.length == 6 && RegExp(r'^[0-9A-F]{6}$').hasMatch(clean)) {
      final fullHex = '#$clean';
      setState(() {
        _currentColorHex = fullHex;
      });
      widget.onColorChanged(fullHex);
    }
  }

  void _selectColor(String hex) {
    final clean = hex.replaceAll('#', '').trim().toUpperCase();
    _hexController.text = clean;
    setState(() {
      _currentColorHex = '#$clean';
    });
    widget.onColorChanged('#$clean');
  }

  void _openPaletteDialog(BuildContext context) {
    showHsvColorPickerDialog(
      context,
      initialHex: _currentColorHex,
      previewName: widget.previewName,
      title: 'Paleta de Colores',
      showBubblePreview: true,
      onLiveColorChanged: (liveHex) {
        final clean = liveHex.replaceAll('#', '').trim().toUpperCase();
        if (clean.length == 6) {
          _hexController.text = clean;
          setState(() {
            _currentColorHex = '#$clean';
          });
          widget.onColorChanged('#$clean');
        }
      },
    ).then((selected) {
      if (selected != null) {
        _selectColor(selected);
      }
    });
  }

  String _capitalizeName(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Accesos Rápidos Predefinidos ──
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConstants.usernameColors.entries.map(
            (entry) {
              final isSelected =
                  _currentColorHex.toUpperCase() == entry.value.toUpperCase();
              return ChoiceChip(
                label: Text(_capitalizeName(entry.key)),
                selected: isSelected,
                onSelected: (_) => _selectColor(entry.value),
                avatar: CircleAvatar(
                  backgroundColor: _parseColor(entry.value),
                  radius: 6,
                ),
              );
            },
          ).toList(),
        ),
        const SizedBox(height: 12),

        // ── Celda de Color Personalizado (#HEX) + Muestra y Vista Previa ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF140F24).withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF2A2A38),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Muestra en vivo 36x36 px con detector de toque para paleta
                  GestureDetector(
                    onTap: () => _openPaletteDialog(context),
                    child: Tooltip(
                      message: 'Tocar para abrir paleta visual',
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _parseColor(_currentColorHex),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _parseColor(_currentColorHex).withValues(
                                alpha: 0.45,
                              ),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.colorize_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Campo de texto HEX interactivo
                  Expanded(
                    child: TextFormField(
                      controller: _hexController,
                      maxLength: 6,
                      onChanged: _onHexChanged,
                      inputFormatters: const [
                        HexColorFormatter(),
                      ],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Personalizado (#HEX)',
                        prefixText: '#',
                        prefixStyle: const TextStyle(
                          color: Color(0xFFA594F9),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1E1833),
                        suffixIcon: IconButton(
                          key: const Key('open_hsv_spectrum_picker_btn'),
                          tooltip: 'Abrir espectro visual (Rueda HSV)',
                          icon: const Icon(
                            Icons.palette_rounded,
                            size: 19,
                            color: Color(0xFFA594F9),
                          ),
                          onPressed: () => _openPaletteDialog(context),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFA594F9),
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const Key('open_spectrum_wheel_btn'),
                  onPressed: () => _openPaletteDialog(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(
                    Icons.donut_large_rounded,
                    size: 14,
                    color: Color(0xFFA594F9),
                  ),
                  label: const Text(
                    'Abrir Rueda de Espectro HSV',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFA594F9),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Vista previa en vivo del nombre
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0A14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Vista previa: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9E9EA8),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.previewName != null &&
                                widget.previewName!.isNotEmpty
                            ? widget.previewName!
                            : 'Tu Nombre Aquí',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: _parseColor(_currentColorHex),
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
