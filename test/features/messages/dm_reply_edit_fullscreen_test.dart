import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/widgets/chat_bubble.dart';
import 'package:kyubi/core/widgets/fullscreen_image_viewer.dart';
import 'package:kyubi/core/widgets/swipe_to_reply.dart';

void main() {
  group('DMs: Reply Preview y Edición', () {
    testWidgets('Muestra la tarjeta de respuesta citada en la burbuja', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              body: 'Totalmente de acuerdo',
              timestamp: '14:20',
              isMine: true,
              replyToId: 'msg_123',
              replyToName: 'Amigo',
              replyToBody: '¿Vamos a la sala de rol?',
            ),
          ),
        ),
      );

      // Debe mostrar el autor citado y el cuerpo citado
      expect(find.text('Amigo'), findsOneWidget);
      expect(find.text('¿Vamos a la sala de rol?'), findsOneWidget);
      expect(find.text('Totalmente de acuerdo'), findsOneWidget);
    });

    testWidgets('Muestra indicador de mensaje editado', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              body: 'Mensaje corregido',
              timestamp: '14:25',
              isMine: false,
              isEdited: true,
              editedAt: '2026-09-23T14:26:00Z',
            ),
          ),
        ),
      );

      expect(find.text('Mensaje corregido'), findsOneWidget);
      expect(find.textContaining('editado'), findsOneWidget);
    });
  });

  group('SwipeToReply Widget', () {
    testWidgets('Dispara onReply tras un desplazamiento horizontal suficiente', (tester) async {
      var replied = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SwipeToReply(
                threshold: 64.0,
                onReply: () => replied = true,
                child: Container(
                  width: 200,
                  height: 60,
                  color: Colors.blue,
                  child: const Text('Deslízame'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(replied, isFalse);

      // Deslizar hacia la derecha superando el threshold de 64 px
      await tester.drag(find.text('Deslízame'), const Offset(100, 0));
      await tester.pumpAndSettle();

      expect(replied, isTrue);
    });
  });

  group('Visor de Imágenes Fullscreen', () {
    testWidgets('Renderiza InteractiveViewer y botón de descarga', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FullscreenImageViewer(
            url: 'https://example.com/imagen_test.png',
          ),
        ),
      );

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    });
  });
}
