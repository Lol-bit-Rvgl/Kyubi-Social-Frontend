import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/widgets/animated_sticker.dart';
import 'package:kyubi/core/widgets/chat_bubble.dart';
import 'package:kyubi/features/feed/presentation/widgets/interactive_poll_card.dart';

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
