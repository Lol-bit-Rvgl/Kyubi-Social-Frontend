import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/widgets/animated_sticker.dart';
import 'package:kyubi/core/widgets/chat_bubble.dart';
import 'package:kyubi/features/feed/presentation/widgets/interactive_poll_card.dart';
import 'package:kyubi/features/salas/presentation/widgets/voice_note_bubble.dart';

void main() {
  group('1. Fotos sin texto redundante [Imagen adjunta]', () {
    testWidgets('Oculta el texto redundante cuando el cuerpo es [Imagen adjunta]', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              displayName: 'Usuario',
              body: '📷 [Imagen adjunta]',
              timestamp: '12:00',
              mediaUrl: 'https://example.com/foto.jpg',
              mediaType: 'image',
            ),
          ),
        ),
      );

      // No debe existir widget de texto con [Imagen adjunta]
      expect(find.text('📷 [Imagen adjunta]'), findsNothing);
      expect(find.text('[Imagen adjunta]'), findsNothing);
    });

    testWidgets('Oculta el texto redundante cuando el cuerpo es [Contenido multimedia]', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              displayName: 'Usuario',
              body: '📷 [Contenido multimedia]',
              timestamp: '12:00',
              mediaUrl: 'https://example.com/foto.jpg',
              mediaType: 'image',
            ),
          ),
        ),
      );

      // No debe existir widget de texto redundante
      expect(find.text('📷 [Contenido multimedia]'), findsNothing);
      expect(find.text('[Contenido multimedia]'), findsNothing);
    });

    testWidgets('Muestra la descripción real si el usuario escribió un pie de foto', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              displayName: 'Usuario',
              body: 'Mi nuevo dibujo terminado',
              timestamp: '12:00',
              mediaUrl: 'https://example.com/foto.jpg',
              mediaType: 'image',
            ),
          ),
        ),
      );

      // Debe mostrarse la descripción
      expect(find.text('Mi nuevo dibujo terminado'), findsOneWidget);
    });
  });

  group('2. Stickers animados sin fondo opaco ni estrellita ✨', () {
    testWidgets('Renderiza AnimatedSticker directamente sin texto de estrellita', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              displayName: 'Usuario',
              body: '✨ Destello',
              timestamp: '12:00',
              mediaType: 'sticker',
              extensions: {
                'isAnimated': true,
                'stickerId': 'sparkle',
                'assetPath': 'assets/stickers/sparkle.json',
                'name': 'Destello',
              },
            ),
          ),
        ),
      );

      // No debe mostrarse el texto plano con la estrellita
      expect(find.text('✨ Destello'), findsNothing);

      // Debe renderizar AnimatedSticker
      expect(find.byType(AnimatedSticker), findsOneWidget);
      final sticker = tester.widget<AnimatedSticker>(find.byType(AnimatedSticker));
      expect(sticker.assetPath, 'assets/stickers/sparkle.json');
    });

    testWidgets('Renderiza AnimatedSticker con formato :nombre: sin mostrar texto de reserva', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              displayName: 'Usuario',
              body: ':Destello:',
              timestamp: '12:00',
              mediaUrl: 'assets/stickers/sparkle.json',
              mediaType: 'sticker',
              extensions: {
                'isAnimated': true,
                'stickerId': 'sparkle',
                'assetPath': 'assets/stickers/sparkle.json',
                'name': 'Destello',
              },
            ),
          ),
        ),
      );

      // No debe mostrar el texto :Destello:
      expect(find.text(':Destello:'), findsNothing);

      // Debe renderizar AnimatedSticker
      expect(find.byType(AnimatedSticker), findsOneWidget);
      final sticker = tester.widget<AnimatedSticker>(find.byType(AnimatedSticker));
      expect(sticker.assetPath, 'assets/stickers/sparkle.json');
    });
  });

  group('3. Encuestas y Notas de voz interactivas', () {
    testWidgets('Renderiza InteractivePollCard con opciones gráficas', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              displayName: 'Usuario',
              body: '📊 Encuesta: ¿Cuál es tu personaje favorito?\n• Kyubi\n• Kurama',
              timestamp: '12:00',
              mediaType: 'poll',
              extensions: {
                'poll': {
                  'question': '¿Cuál es tu personaje favorito?',
                  'options': [
                    {'id': 'opt_1', 'text': 'Kyubi', 'votes': 5},
                    {'id': 'opt_2', 'text': 'Kurama', 'votes': 3},
                  ],
                  'totalVotes': 8,
                },
              },
            ),
          ),
        ),
      );

      // Debe montar InteractivePollCard con la pregunta y opciones
      expect(find.byType(InteractivePollCard), findsOneWidget);
      expect(find.text('¿Cuál es tu personaje favorito?'), findsOneWidget);
      expect(find.text('Kyubi'), findsOneWidget);
      expect(find.text('Kurama'), findsOneWidget);
    });

    testWidgets('Renderiza reproductor de nota de voz con botón Play/Pause y duración', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              displayName: 'Usuario',
              body: '🎤 [Nota de voz (8s)]',
              timestamp: '12:00',
              mediaType: 'audio',
              extensions: {
                'voice': true,
                'durationMs': 8000,
              },
            ),
          ),
        ),
      );

      // No debe mostrarse como texto plano crudo
      expect(find.text('🎤 [Nota de voz (8s)]'), findsNothing);

      // Debe mostrar icono de reproducción y duración formateada 00:08
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('00:08'), findsOneWidget);
    });

    testWidgets('Renderiza VoiceNoteBubble cuando type es VOICE con mediaUrl m4a', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              displayName: 'Usuario',
              body: '',
              timestamp: '12:00',
              type: 'VOICE',
              mediaUrl: 'https://example.com/audio.m4a',
            ),
          ),
        ),
      );

      // Debe montar VoiceNoteBubble
      expect(find.byType(VoiceNoteBubble), findsOneWidget);
    });
  });

  group('5. Burbuja compacta para textos muy cortos (1-4 caracteres)', () {
    // La burbuja estándar es el Container con borde de 0.9 (dice/morra usan 1.2).
    RenderBox bubbleBox(WidgetTester tester) {
      final finder = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border is Border &&
            ((w.decoration as BoxDecoration).border as Border).top.width == 0.9,
      );
      return tester.renderObject<RenderBox>(finder);
    }

    Future<Size> pumpBubble(
      WidgetTester tester,
      String body, {
      required bool isMine,
      String name = '',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment:
                  isMine ? Alignment.centerRight : Alignment.centerLeft,
              child: ChatMessageBubble(
                displayName: name,
                body: body,
                timestamp: '12:00',
                isMine: isMine,
              ),
            ),
          ),
        ),
      );
      return bubbleBox(tester).size;
    }

    testWidgets(
        'Burbuja propia y ajena (sin nombre, DM 1:1) miden lo mismo y la altura no crece con textos de 1 a 4 caracteres',
        (tester) async {
      const sizes = ['E', '12', '1234'];
      double? reference;
      for (final body in sizes) {
        final own = await pumpBubble(tester, body, isMine: true);
        final other = await pumpBubble(tester, body, isMine: false);
        expect(own.height, other.height,
            reason: 'La burbuja propia y la ajena deben medir lo mismo');
        reference ??= own.height;
        expect(own.height, reference,
            reason: 'La altura no debe cambiar entre textos de 1 a 4 caracteres');
      }
    });

    testWidgets(
        'Un texto de 1 caracter mide la altura de una linea y el timestamp queda dentro con doble check',
        (tester) async {
      final size = await pumpBubble(tester, 'E', isMine: true);
      // Una línea de texto + timestamp inline + padding vertical 12: la burbuja
      // debe seguir siendo baja (sin filas fantasma ni padding sobredimensionado).
      expect(size.height, lessThan(50));
      expect(find.text('12:00'), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
    });

    testWidgets(
        'Con nombre explicito (salas) el nombre sigue renderizandose encima del texto',
        (tester) async {
      await pumpBubble(tester, 'E', isMine: false, name: 'Usuario');
      expect(find.text('Usuario'), findsOneWidget);
    });

    testWidgets(
        'El nombre se oculta en la burbuja ajena cuando no se pasa displayName (DM 1:1)',
        (tester) async {
      await pumpBubble(tester, 'E', isMine: false, name: '');
      expect(find.text('Usuario'), findsNothing);
    });
  });

  group('4. Tiradas de Dados y Morra con Contenedor y Borde Dorado', () {
    testWidgets('Aplica borde dorado brillante 0xFFFFD700 y fondo ámbar 0xFF2B2206 a tirada de dados', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              displayName: 'Usuario',
              body: '🎲 Ha lanzado D20: 19',
              timestamp: '12:00',
              mediaType: 'dice',
              extensions: {
                'dice': {
                  'name': 'D20',
                  'result': '19',
                  'emoji': '🎲',
                },
              },
            ),
          ),
        ),
      );

      expect(find.text('TIRADA DE DADOS'), findsOneWidget);
      expect(find.text('Ha lanzado D20: 19'), findsOneWidget);

      // Verificar contenedor con borde y fondo dorado
      final containers = tester.widgetList<Container>(find.byType(Container));
      final goldBox = containers.firstWhere((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration) {
          final border = dec.border;
          if (border is Border) {
            return border.top.color == const Color(0xFFFFD700).withValues(alpha: 0.7);
          }
        }
        return false;
      });

      expect(goldBox, isNotNull);
      final dec = goldBox.decoration as BoxDecoration;
      expect(dec.color, const Color(0xFF2B2206).withValues(alpha: 0.5));
    });

    testWidgets('Aplica contenedor dorado a juego de Morra', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              displayName: 'Usuario',
              body: '✋ Ha lanzado Morra: Papel',
              timestamp: '12:00',
              mediaType: 'dice',
              extensions: {
                'dice': {
                  'name': 'Morra',
                  'result': 'Papel',
                  'emoji': '✋',
                },
              },
            ),
          ),
        ),
      );

      expect(find.text('JUEGO DE MORRA'), findsOneWidget);
      expect(find.text('Ha lanzado Morra: Papel'), findsOneWidget);
    });
  });
}
