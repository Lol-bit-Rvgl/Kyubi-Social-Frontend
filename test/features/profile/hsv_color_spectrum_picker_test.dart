import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/widgets/hsv_color_picker_dialog.dart';

void main() {
  group('HsvColorSpectrumPicker Tests', () {
    testWidgets('Renders HSV wheel, hex input, preview cards and switches to 2D panel', (tester) async {
      Color? selectedColor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HsvColorSpectrumPicker(
                initialColor: const Color(0xFFFF0055),
                previewName: 'GamerKyubi',
                showBubblePreview: true,
                onColorChanged: (c) => selectedColor = c,
              ),
            ),
          ),
        ),
      );

      // Verifica presencia del campo #HEX con el color inicial 'FF0055'
      final textField = find.byType(TextFormField);
      expect(textField, findsOneWidget);
      final formField = tester.widget<TextFormField>(textField);
      expect(formField.controller?.text, 'FF0055');

      // Verifica vista previa del nombre
      expect(find.text('GamerKyubi'), findsOneWidget);
      final previewText = tester.widget<Text>(find.text('GamerKyubi'));
      expect(previewText.style?.color, const Color(0xFFFF0055));

      // Verifica vista previa de burbuja
      expect(find.text('Vista previa de Burbuja:'), findsOneWidget);
      expect(find.text('¡Hola! Así lucirá tu mensaje con este tono.'), findsOneWidget);

      // Alternar al modo 'Panel 2D'
      final panelModeBtn = find.byKey(const Key('hsv_mode_box'));
      expect(panelModeBtn, findsOneWidget);
      await tester.tap(panelModeBtn);
      await tester.pump();

      // En modo panel 2D, se muestra el slider de tono
      expect(find.byIcon(Icons.color_lens_rounded), findsOneWidget);

      // Volver a modo Rueda HSV
      final wheelModeBtn = find.byKey(const Key('hsv_mode_wheel'));
      await tester.tap(wheelModeBtn);
      await tester.pump();

      // Ingresar nuevo código hexadecimal manual en el input
      await tester.enterText(textField, '00E5FF');
      await tester.pump();

      expect(selectedColor, const Color(0xFF00E5FF));
      final updatedPreview = tester.widget<Text>(find.text('GamerKyubi'));
      expect(updatedPreview.style?.color, const Color(0xFF00E5FF));
    });

    testWidgets('Quick palette presets update color and trigger onQuickSelect', (tester) async {
      Color? changedColor;
      String? quickSelectedHex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HsvColorSpectrumPicker(
                initialColor: const Color(0xFFFFFFFF),
                previewName: 'Tester',
                onColorChanged: (c) => changedColor = c,
                onQuickSelect: (hex) => quickSelectedHex = hex,
              ),
            ),
          ),
        ),
      );

      // Tocar un color rápido de la paleta (ej. #00E676)
      final greenChip = find.byKey(const Key('palette_color_#00E676'));
      expect(greenChip, findsOneWidget);

      await tester.tap(greenChip);
      await tester.pump();

      expect(changedColor, const Color(0xFF00E676));
      expect(quickSelectedHex, '#00E676');

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller?.text, '00E676');
    });

    testWidgets('showHsvColorPickerDialog opens, allows cancel and apply', (tester) async {
      String? returnedHex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () async {
                  returnedHex = await showHsvColorPickerDialog(
                    ctx,
                    initialHex: '#7C4DFF',
                    previewName: 'KyubiHero',
                    title: 'Personalizar Color',
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      // Abrir diálogo
      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Personalizar Color'), findsOneWidget);
      expect(find.byKey(const Key('hsv_dialog_cancel')), findsOneWidget);
      expect(find.byKey(const Key('hsv_dialog_apply')), findsOneWidget);

      // Tocar cancelar
      await tester.tap(find.byKey(const Key('hsv_dialog_cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Personalizar Color'), findsNothing);
      expect(returnedHex, isNull);

      // Abrir de nuevo y aplicar
      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Cambiar texto en el diálogo
      final dialogInput = find.byType(TextFormField);
      await tester.enterText(dialogInput, 'FFD700');
      await tester.pump();

      // Tocar aplicar
      await tester.tap(find.byKey(const Key('hsv_dialog_apply')));
      await tester.pumpAndSettle();

      expect(find.text('Personalizar Color'), findsNothing);
      expect(returnedHex, '#FFD700');
    });
  });
}
