import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/features/profile/presentation/widgets/hex_color_picker_tile.dart';

void main() {
  group('HexColorPickerTile Tests', () {
    testWidgets('Validates 6-digit hex string and notifies onColorChanged and updates preview', (tester) async {
      String? changedColor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HexColorPickerTile(
              initialColor: '#FFFFFF',
              previewName: 'Kitsune Hero',
              onColorChanged: (color) => changedColor = color,
            ),
          ),
        ),
      );

      // Verificar vista previa inicial con Kitsune Hero
      final initialPreview = tester.widget<Text>(find.text('Kitsune Hero'));
      expect(initialPreview.style?.color, const Color(0xFFFFFFFF));

      // Ingresar nuevo código hexadecimal válido de 6 dígitos
      final textField = find.byType(TextFormField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, '00E5FF');
      await tester.pump();

      // Debe notificar '#00E5FF'
      expect(changedColor, '#00E5FF');

      // Debe actualizar en vivo la vista previa del nombre
      final updatedPreview = tester.widget<Text>(find.text('Kitsune Hero'));
      expect(updatedPreview.style?.color, const Color(0xFF00E5FF));
    });

    testWidgets('Rejects non-hex characters and limits length strictly to 6', (tester) async {
      String? changedColor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HexColorPickerTile(
              initialColor: '#FFFFFF',
              previewName: 'Kitsune Hero',
              onColorChanged: (color) => changedColor = color,
            ),
          ),
        ),
      );

      final textField = find.byType(TextFormField);

      // Ingresar caracteres no válidos 'XYZ123456789'
      await tester.enterText(textField, 'XYZ123456789');
      await tester.pump();

      // Los caracteres no válidos (X, Y, Z) son rechazados y se corta a 6 dígitos ('123456')
      final fieldWidget = tester.widget<TextFormField>(textField);
      expect(fieldWidget.controller?.text, '123456');
      expect(changedColor, '#123456');

      // Intentar ingresar símbolos y letras no hexadecimales
      await tester.enterText(textField, 'GHJK!@#');
      await tester.pump();
      expect(fieldWidget.controller?.text, '');
    });

    testWidgets('Updates selected color and live preview when selecting a preset chip', (tester) async {
      String? changedColor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HexColorPickerTile(
              initialColor: '#FFFFFF',
              previewName: 'Kitsune Hero',
              onColorChanged: (color) => changedColor = color,
            ),
          ),
        ),
      );

      // Tocar el chip de color predefinido 'Morado'
      final chip = find.widgetWithText(ChoiceChip, 'Morado');
      expect(chip, findsOneWidget);

      await tester.tap(chip);
      await tester.pump();

      expect(changedColor, '#9B59B6');

      // Verificar que el campo de texto se actualizó a '9B59B6'
      final fieldWidget = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(fieldWidget.controller?.text, '9B59B6');

      // Verificar vista previa con el color del chip
      final previewText = tester.widget<Text>(find.text('Kitsune Hero'));
      expect(previewText.style?.color, const Color(0xFF9B59B6));
    });

    testWidgets('Opens palette dialog and selects color from visual palette', (tester) async {
      String? changedColor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HexColorPickerTile(
              initialColor: '#FFFFFF',
              previewName: 'Kitsune Hero',
              onColorChanged: (color) => changedColor = color,
            ),
          ),
        ),
      );

      // Tocar el cuadro de muestra con icono de cuentagotas
      await tester.tap(find.byIcon(Icons.colorize_rounded));
      await tester.pumpAndSettle();

      // Diálogo de paleta abierto
      expect(find.text('Paleta de Colores'), findsOneWidget);

      // Seleccionar un color de la paleta
      final paletteColorTile = find.byKey(const Key('palette_color_#FF0055'));
      expect(paletteColorTile, findsOneWidget);
      await tester.tap(paletteColorTile);
      await tester.pumpAndSettle();

      // El diálogo se cierra
      expect(find.text('Paleta de Colores'), findsNothing);

      // El color fue cambiado
      expect(changedColor, '#FF0055');
    });
  });
}
