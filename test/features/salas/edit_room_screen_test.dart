import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/features/salas/presentation/edit_room_screen.dart';
import 'package:kyubi/features/salas/presentation/sala_detail_controller.dart';
import 'package:kyubi/models/post_author.dart';
import 'package:kyubi/models/room.dart';
import 'package:kyubi/repositories/room_repository.dart';
import 'package:kyubi/services/providers.dart';

class _FakeRoomRepository implements RoomRepository {
  _FakeRoomRepository({this.room});
  final Room? room;

  @override
  Future<Room> getSala(String id) async {
    return room ??
        Room(
          id: id,
          name: 'Sala Default',
          host: const PostAuthor(
            id: 'h1',
            username: 'host1',
            displayName: 'Host 1',
          ),
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testHost = PostAuthor(
    id: 'host-1',
    username: 'kyubi_master',
    displayName: 'Kyubi Master',
  );

  group('EditRoomScreen - Persistencia de Lore y Eliminación de Color Temático', () {
    test('Room model expone alias .lore equivalente a .description', () {
      final roomWithLore = Room(
        id: 'room-101',
        name: 'Sala de Rol',
        host: testHost,
        description: 'Un mundo cyberpunk en 2088 donde los androides sueñan.',
      );

      expect(roomWithLore.lore, equals('Un mundo cyberpunk en 2088 donde los androides sueñan.'));
      expect(roomWithLore.lore, equals(roomWithLore.description));
    });

    testWidgets('Hidrata _descController con la descripción existente de la sala', (tester) async {
      final room = Room(
        id: 'room-101',
        name: 'Mundo Astral',
        host: testHost,
        description: 'Crónicas de las tierras místicas de Kyubi.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomRepositoryProvider.overrideWithValue(_FakeRoomRepository(room: room)),
          ],
          child: MaterialApp(
            home: EditRoomScreen(room: room),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que el campo "Descripción / Lore" contiene el texto
      expect(find.text('Crónicas de las tierras místicas de Kyubi.'), findsOneWidget);
    });

    testWidgets('No renderiza la sección ni opción "Color Temático de la Sala"', (tester) async {
      final room = Room(
        id: 'room-101',
        name: 'Sala Limpia',
        host: testHost,
        description: 'Descripción básica',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomRepositoryProvider.overrideWithValue(_FakeRoomRepository(room: room)),
          ],
          child: MaterialApp(
            home: EditRoomScreen(room: room),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que "Color Temático de la Sala" no existe en la jerarquía visual
      expect(find.text('Color Temático de la Sala'), findsNothing);
    });

    testWidgets('Sincroniza reactivamente el lore ante cambios en el provider si el controlador está vacío', (tester) async {
      final initialRoom = Room(
        id: 'room-202',
        name: 'Sala Reactiva',
        host: testHost,
        description: '',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomRepositoryProvider.overrideWithValue(_FakeRoomRepository(room: initialRoom)),
          ],
          child: MaterialApp(
            home: EditRoomScreen(room: initialRoom),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inicialmente la descripción está vacía
      final descFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.maxLines == 3,
      );
      expect(descFinder, findsOneWidget);
      final textField = tester.widget<TextField>(descFinder);
      expect(textField.controller?.text, isEmpty);

      // Actualizar el estado del provider con nuevo lore
      final updatedRoom = Room(
        id: 'room-202',
        name: 'Sala Reactiva',
        host: testHost,
        description: 'Lore recibido asíncronamente desde el servidor',
      );

      final container = ProviderScope.containerOf(tester.element(find.byType(EditRoomScreen)));
      container.read(salaDetailControllerProvider('room-202').notifier).applyRoom(updatedRoom);
      await tester.pumpAndSettle();

      // El controlador debió hidratarse automáticamente
      expect(find.text('Lore recibido asíncronamente desde el servidor'), findsOneWidget);
    });

    testWidgets('didUpdateWidget sincroniza el lore si el controlador está vacío', (tester) async {
      final initialRoom = Room(
        id: 'room-303',
        name: 'Sala DidUpdate',
        host: testHost,
        description: '',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomRepositoryProvider.overrideWithValue(_FakeRoomRepository(room: initialRoom)),
          ],
          child: MaterialApp(
            home: EditRoomScreen(room: initialRoom),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final descFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.maxLines == 3,
      );
      expect(descFinder, findsOneWidget);
      expect(tester.widget<TextField>(descFinder).controller?.text, isEmpty);

      final updatedRoom = Room(
        id: 'room-303',
        name: 'Sala DidUpdate',
        host: testHost,
        description: 'Lore sincronizado mediante didUpdateWidget',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomRepositoryProvider.overrideWithValue(_FakeRoomRepository(room: updatedRoom)),
          ],
          child: MaterialApp(
            home: EditRoomScreen(room: updatedRoom),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(descFinder).controller?.text, equals('Lore sincronizado mediante didUpdateWidget'));
    });
  });
}
