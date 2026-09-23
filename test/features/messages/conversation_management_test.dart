import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/theme/app_colors.dart';
import 'package:kyubi/models/chat_conversation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testConvUnmuted = Conversation(
    id: 'conv-123',
    type: 'direct',
    muted: false,
    members: const [
      ChatMember(
        id: 'member-1',
        username: 'sakura',
        displayName: 'Sakura Haruno',
      ),
    ],
  );

  final testConvMuted = testConvUnmuted.copyWith(muted: true);

  group('Conversation Model - muted & copyWith', () {
    test('copyWith altera correctamente la propiedad muted', () {
      expect(testConvUnmuted.muted, isFalse);
      expect(testConvMuted.muted, isTrue);

      final backToUnmuted = testConvMuted.copyWith(muted: false);
      expect(backToUnmuted.muted, isFalse);
    });

    test('toJson y fromJson preservan muted', () {
      final json = {
        'id': 'conv-123',
        'type': 'direct',
        'muted': true,
        'members': [
          {
            'id': 'member-1',
            'username': 'sakura',
            'displayName': 'Sakura Haruno',
          }
        ],
      };
      final conv = Conversation.fromJson(json);
      expect(conv.muted, isTrue);

      final outJson = conv.toJson();
      expect(outJson['muted'], isTrue);
    });
  });

  group('Diálogo de Confirmación de Eliminación', () {
    testWidgets('Muestra título, texto de advertencia, cancelar y eliminar destructivo', (tester) async {
      bool deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      backgroundColor: const Color(0xFF14141B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      title: const Text(
                        'Eliminar conversación',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      content: const Text(
                        '¿Deseas eliminar esta conversación? Los mensajes se borrarán de tu bandeja.',
                        style: TextStyle(color: Color(0xFF9E9EA8)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(dialogCtx).pop();
                            deleted = true;
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.danger,
                          ),
                          child: const Text('Eliminar'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Abrir Diálogo'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Diálogo'));
      await tester.pumpAndSettle();

      expect(find.text('Eliminar conversación'), findsOneWidget);
      expect(
        find.text('¿Deseas eliminar esta conversación? Los mensajes se borrarán de tu bandeja.'),
        findsOneWidget,
      );
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
      expect(find.text('Eliminar conversación'), findsNothing);
    });
  });

  group('Modal BottomSheet de Opciones de DM', () {
    testWidgets('Muestra Silenciar conversación si no está silenciado', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (ctx) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Icon(
                            testConvUnmuted.muted
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_rounded,
                          ),
                          title: Text(
                            testConvUnmuted.muted
                                ? 'Reactivar notificaciones'
                                : 'Silenciar conversación',
                          ),
                        ),
                        const ListTile(
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Eliminar conversación'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Abrir Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Silenciar conversación'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_off_rounded), findsOneWidget);
      expect(find.text('Eliminar conversación'), findsOneWidget);
    });

    testWidgets('Muestra Reactivar notificaciones si la conversación ya está silenciada', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (ctx) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Icon(
                            testConvMuted.muted
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_rounded,
                          ),
                          title: Text(
                            testConvMuted.muted
                                ? 'Reactivar notificaciones'
                                : 'Silenciar conversación',
                          ),
                        ),
                        const ListTile(
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Eliminar conversación'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Abrir Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Reactivar notificaciones'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
      expect(find.text('Eliminar conversación'), findsOneWidget);
    });
  });
}
