import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/network/api_client.dart';
import 'package:kyubi/core/widgets/chat_bubble.dart';
import 'package:kyubi/features/salas/presentation/edit_room_screen.dart';
import 'package:kyubi/features/salas/presentation/salas_controller.dart';
import 'package:kyubi/features/salas/presentation/widgets/chat_message_input_bar.dart';
import 'package:kyubi/features/salas/presentation/widgets/role_chat_bubble.dart';
import 'package:kyubi/features/salas/presentation/widgets/roleplay_stage_view.dart';
import 'package:kyubi/models/role_character.dart';
import 'package:kyubi/models/room.dart';
import 'package:kyubi/repositories/room_repository.dart';
import 'package:kyubi/services/room_socket.dart';

class FakeApiClient extends Fake implements ApiClient {
  String? lastPath;
  dynamic lastData;

  @override
  Future<Map<String, dynamic>> postJson(String path, {Object? data, Map<String, dynamic>? query}) async {
    lastPath = path;
    lastData = data;
    return {'id': 'sala-123', 'name': 'Sala Test', 'host': {'id': 'h1', 'username': 'host'}, 'success': true};
  }

  @override
  Future<Map<String, dynamic>> patchJson(String path, {Object? data, Map<String, dynamic>? query}) async {
    lastPath = path;
    lastData = data;
    return {'id': 'sala-123', 'name': 'Sala Test', 'host': {'id': 'h1', 'username': 'host'}, 'tags': (data as Map?)?['tags'] ?? [], 'success': true};
  }
}

void main() {
  group('Room Model - Deserialización segura de Roles', () {
    test('Room.fromJson deserializa stageRoles y activeCharacter desde mapas dinámicos', () {
      final jsonDynamic = <dynamic, dynamic>{
        'id': 'sala-123',
        'name': 'Sala Roleplay',
        'host': {'id': 'host-1', 'username': 'host_user'},
        'currentMode': 'roleplay',
        'stageRoles': <dynamic>[
          <dynamic, dynamic>{
            'id': 'role-1',
            'name': 'Saira',
            'tagline': 'Guerrera',
            'description': 'Luchadora hábil',
            'colorHex': '#FF0055',
            'isTaken': true,
            'takenByUserId': 'user-1',
            'takenByUsername': 'SairaPlayer',
          },
        ],
        'activeCharacter': <dynamic, dynamic>{
          'id': 'role-1',
          'name': 'Saira',
          'isTaken': true,
        },
      };

      final room = Room.fromJson(Map<String, dynamic>.from(jsonDynamic));

      expect(room.id, 'sala-123');
      expect(room.stageRoles.length, 1);
      expect(room.stageRoles.first.id, 'role-1');
      expect(room.stageRoles.first.name, 'Saira');
      expect(room.stageRoles.first.isTaken, true);
      expect(room.stageRoles.first.takenByUsername, 'SairaPlayer');
      expect(room.activeCharacter?.id, 'role-1');
      expect(room.activeCharacter?.name, 'Saira');
    });

    test('Room.fromJson tolera stageRoles nulo o lista vacía', () {
      final json = <String, dynamic>{
        'id': 'sala-456',
        'name': 'Sala Estándar',
        'host': {'id': 'host-1', 'username': 'host_user'},
        'stageRoles': null,
        'activeCharacter': null,
      };

      final room = Room.fromJson(json);

      expect(room.stageRoles, isEmpty);
      expect(room.activeCharacter, isNull);
    });
  });

  group('RoomRepository - Persistencia de Roles', () {
    late FakeApiClient fakeApi;
    late RoomRepository repository;

    setUp(() {
      fakeApi = FakeApiClient();
      repository = RoomRepository(fakeApi);
    });

    test('saveStageRole envía POST con action: create y datos del rol', () async {
      const role = RoleCharacter(
        id: 'role-new',
        name: 'Guerrero',
        tagline: 'Defensor',
        description: 'Protege a sus aliados',
        colorHex: '#00E5FF',
      );

      await repository.saveStageRole('room-1', role);

      expect(fakeApi.lastPath, contains('/salas/room-1/stage/role'));
      final data = fakeApi.lastData as Map<String, dynamic>;
      expect(data['action'], 'create');
      expect(data['roleId'], 'role-new');
      expect(data['role']['name'], 'Guerrero');
    });

    test('deleteStageRole envía POST con action: delete y roleId', () async {
      await repository.deleteStageRole('room-1', 'role-delete-id');

      expect(fakeApi.lastPath, contains('/salas/room-1/stage/role'));
      final data = fakeApi.lastData as Map<String, dynamic>;
      expect(data['action'], 'delete');
      expect(data['roleId'], 'role-delete-id');
    });

    test('updateStageRole con isTake:false envía POST con action: leave', () async {
      const role = RoleCharacter(
        id: 'role-leave-id',
        name: 'Guerrero',
        tagline: 'Defensor',
        description: '',
        colorHex: '#00E5FF',
      );

      await repository.updateStageRole('room-1', role: role, isTake: false);

      expect(fakeApi.lastPath, contains('/salas/room-1/stage/role'));
      final data = fakeApi.lastData as Map<String, dynamic>;
      expect(data['action'], 'leave');
      expect(data['roleId'], 'role-leave-id');
    });
  });

  group('Room Model - Reglas de Sala y Compatibilidad de Roles', () {
    test('Room.fromJson deserializa reglas personalizadas y tolera lista vacía sin reemplazarla', () {
      final jsonCustomRules = <String, dynamic>{
        'id': 'sala-rules-1',
        'name': 'Sala con Reglas Personalizadas',
        'host': {'id': 'host-1', 'username': 'host_user'},
        'rules': <dynamic>['solo panitas', 'no spoiler'],
      };

      final roomCustom = Room.fromJson(jsonCustomRules);
      expect(roomCustom.rules, ['solo panitas', 'no spoiler']);

      final jsonEmptyRules = <String, dynamic>{
        'id': 'sala-rules-2',
        'name': 'Sala Sin Reglas (0/10)',
        'host': {'id': 'host-1', 'username': 'host_user'},
        'rules': <dynamic>[],
      };

      final roomEmpty = Room.fromJson(jsonEmptyRules);
      expect(roomEmpty.rules, isEmpty);
    });

    test('RoleCharacter.fromJson tolera tanto isOccupied/occupiedBy como isTaken/takenByUserId', () {
      final jsonWithOccupied = <String, dynamic>{
        'id': 'role-compat-1',
        'name': 'Mago',
        'isOccupied': true,
        'occupiedBy': 'user-mago',
        'occupiedByName': 'MagoPlayer',
      };

      final role1 = RoleCharacter.fromJson(jsonWithOccupied);
      expect(role1.isTaken, true);
      expect(role1.takenByUserId, 'user-mago');
      expect(role1.takenByUsername, 'MagoPlayer');

      final jsonWithTaken = <String, dynamic>{
        'id': 'role-compat-2',
        'name': 'Arquera',
        'isTaken': true,
        'takenByUserId': 'user-arquera',
        'takenByUsername': 'ArqueraPlayer',
      };

      final role2 = RoleCharacter.fromJson(jsonWithTaken);
      expect(role2.isTaken, true);
      expect(role2.isOccupied, true);
      expect(role2.takenByUserId, 'user-arquera');
      expect(role2.occupiedBy, 'user-arquera');
      expect(role2.takenByUsername, 'ArqueraPlayer');
      expect(role2.occupiedByName, 'ArqueraPlayer');

      final serialized = role2.toJson();
      expect(serialized['isOccupied'], true);
      expect(serialized['occupiedBy'], 'user-arquera');
      expect(serialized['occupiedByName'], 'ArqueraPlayer');
    });
  });

  group('SalasNotifier - Gestión atómica de roles de stage', () {
    test('setRoomRoles reemplaza la lista completa de roles de una sala', () {
      final controller = SalasNotifier();
      const role1 = RoleCharacter(id: 'r-1', name: 'Role 1');
      const role2 = RoleCharacter(id: 'r-2', name: 'Role 2');

      controller.setRoomRoles('sala-1', [role1, role2]);
      expect(controller.rolesFor('sala-1').length, 2);

      // Si se actualiza con una lista donde se eliminó un rol:
      controller.setRoomRoles('sala-1', [role2]);
      expect(controller.rolesFor('sala-1').length, 1);
      expect(controller.rolesFor('sala-1').first.id, 'r-2');
    });

    test('removeRoomRole elimina roles con comparación estricta de strings y trim', () {
      final controller = SalasNotifier();
      const role1 = RoleCharacter(id: ' role-abc ', name: 'Role ABC');
      controller.setRoomRoles('sala-1', [role1]);

      controller.removeRoomRole('sala-1', 'role-abc');
      expect(controller.rolesFor('sala-1'), isEmpty);
    });
  });

  group('RoleChatBubble & ChatMessageBubble - Layout y Alineación de Mensajes Editados', () {
    testWidgets('RoleChatBubble usa CrossAxisAlignment.start para mensajes ajenos y CrossAxisAlignment.end para propios', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                RoleChatBubble(
                  body: '2222',
                  senderName: 'Otro Usuario',
                  isMine: false,
                  timestamp: '21:30',
                  isEdited: true,
                  editedAt: '2026-09-13T21:30:00.000Z',
                ),
                RoleChatBubble(
                  body: '2222',
                  senderName: 'Mi Usuario',
                  isMine: true,
                  timestamp: '21:30',
                  isEdited: true,
                  editedAt: '2026-09-13T21:30:00.000Z',
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('2222'),
        ),
        findsNWidgets(2),
      );
      expect(find.textContaining('(editado'), findsNWidgets(2));

      final columns = tester.widgetList<Column>(find.byType(Column)).toList();
      // Buscamos columnas con CrossAxisAlignment.start y CrossAxisAlignment.end
      final hasStart = columns.any((c) => c.crossAxisAlignment == CrossAxisAlignment.start);
      final hasEnd = columns.any((c) => c.crossAxisAlignment == CrossAxisAlignment.end);
      expect(hasStart, isTrue);
      expect(hasEnd, isTrue);
    });

    testWidgets('ChatMessageBubble se alinea a la derecha cuando isMine es verdadero y muestra editado', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              displayName: 'Yo',
              body: 'Mensaje propio',
              timestamp: '21:35',
              isMine: true,
              isEdited: true,
              editedAt: '2026-09-13T21:35:00.000Z',
            ),
          ),
        ),
      );

      expect(find.textContaining('Mensaje propio'), findsOneWidget);
      expect(find.textContaining('(editado'), findsOneWidget);

      final aligns = tester.widgetList<Align>(find.byType(Align)).toList();
      final hasRightAlign = aligns.any((a) => a.alignment == Alignment.centerRight);
      expect(hasRightAlign, isTrue);
    });
  });

  group('Purgado de Roles Fantasma e Inválidos', () {
    test('Room.fromJson descarta roles corruptos sin id o con name vacío', () {
      final json = {
        'id': 'sala-ghost-test',
        'name': 'Sala Fantasma Test',
        'host': {'id': 'h1', 'username': 'host'},
        'stageRoles': [
          {'id': 'r-valid', 'name': 'Kenshi', 'colorHex': '#00E5FF'},
          {'id': 'r-ghost-1', 'name': ''},
          {'id': 'r-ghost-2', 'name': '   '},
          {'id': '', 'name': 'Sin ID'},
          null,
        ],
      };

      final room = Room.fromJson(json);
      expect(room.stageRoles.length, 1);
      expect(room.stageRoles.first.id, 'r-valid');
      expect(room.stageRoles.first.name, 'Kenshi');
    });

    test('RoleCharacter.isValid identifica roles completos vs inválidos', () {
      const valid = RoleCharacter(id: 'r1', name: 'Nombre');
      const emptyId = RoleCharacter(id: '', name: 'Nombre');
      const emptyName = RoleCharacter(id: 'r1', name: '   ');

      expect(valid.isValid, isTrue);
      expect(emptyId.isValid, isFalse);
      expect(emptyName.isValid, isFalse);
    });

    testWidgets('RoleplayStageView solo renderiza roles válidos y no muestra fichas huérfanas', (tester) async {
      final roles = [
        const RoleCharacter(id: 'r-valid-1', name: 'Heroe'),
        const RoleCharacter(id: '', name: 'Fantasma'),
        const RoleCharacter(id: 'r-ghost-2', name: '   '),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoleplayStageView(
              roles: roles,
              isExpanded: true,
              onRoleTap: (_) {},
              onPlayTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Heroe'), findsOneWidget);
      expect(find.text('Fantasma'), findsNothing);
    });
  });

  group('Persistencia y Límite de Etiquetas (Tags) en Salas', () {
    test('RoomRepository.updateSala envía tags al endpoint PATCH', () async {
      final fakeApi = FakeApiClient();
      final repo = RoomRepository(fakeApi);

      final result = await repo.updateSala(
        'sala-123',
        tags: ['Cyberpunk', 'Voz', 'Anime'],
      );

      expect(fakeApi.lastPath, '/salas/sala-123');
      expect(fakeApi.lastData['tags'], ['Cyberpunk', 'Voz', 'Anime']);
      expect(result.tags, ['Cyberpunk', 'Voz', 'Anime']);
    });

    test('RoomRepository.createSala envía tags al endpoint POST', () async {
      final fakeApi = FakeApiClient();
      final repo = RoomRepository(fakeApi);

      await repo.createSala(
        name: 'Nueva Sala',
        tags: ['Rol', 'Gaming'],
      );

      expect(fakeApi.lastPath, '/salas');
      expect(fakeApi.lastData['tags'], ['Rol', 'Gaming']);
    });

    test('EditRoomScreen define maxTags = 5', () {
      expect(EditRoomScreen.maxTags, 5);
    });
  });

  group('RoleplayStageView - Paginación 6 slots por página y Chat Anti-Spam Rate Limiting', () {
    testWidgets('RoleplayStageView divide 8 roles en 2 páginas de máximo 6 slots cada una', (tester) async {
      final roles = List.generate(
        8,
        (i) => RoleCharacter(
          id: 'role-$i',
          name: 'Personaje $i',
          tagline: 'Rol $i',
          colorHex: '#FF5500',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 500,
              child: RoleplayStageView(
                roles: roles,
                isExpanded: true,
                onRoleTap: (_) {},
                onPlayTap: () {},
                onAddRoleTap: () {},
              ),
            ),
          ),
        ),
      );

      // Página 1: debe contener exactamente los primeros 6 roles
      for (int i = 0; i < 6; i++) {
        expect(find.text('Personaje $i'), findsOneWidget);
      }
      // Los roles 6 y 7 (7mo y 8vo) no deben estar en la primera página
      expect(find.text('Personaje 6'), findsNothing);
      expect(find.text('Personaje 7'), findsNothing);

      // Deslizar horizontalmente para ir a la página 2
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Página 2: contiene los roles 6 y 7, más el slot de unirse (+ Unirse)
      expect(find.text('Personaje 6'), findsOneWidget);
      expect(find.text('Personaje 7'), findsOneWidget);
      expect(find.text('+ Unirse'), findsOneWidget);
    });

    testWidgets('ChatMessageInputBar activa cooldown de 1.5s y deshabilita envíos en spam', (tester) async {
      String? sentText;
      int sendCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageInputBar(
              onSendMessage: (text) {
                sentText = text;
                sendCount++;
              },
              onSendImage: (_) {},
              onSendAudio: (_, _, _) {},
              onSendDiceRoll: (_, _, _) {},
              onSendPoll: (_, _) {},
            ),
          ),
        ),
      );

      // Escribir texto y enviar
      await tester.enterText(find.byType(TextField), 'Hola mundo');
      await tester.pump();

      // Tap en enviar
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(sendCount, 1);
      expect(sentText, 'Hola mundo');

      // Durante el cooldown, se muestra el CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Intentar enviar de nuevo durante el cooldown con nuevo texto
      await tester.enterText(find.byType(TextField), 'Spam rápido');
      await tester.pump();
      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();

      // No se envía otro mensaje
      expect(sendCount, 1);

      // Avanzar el tiempo 1500 ms para completar el cooldown
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();

      // Cooldown terminado: indicador desaparece y vuelve el icono de enviar
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    test('RoomRateLimited procesa payload con mensaje personalizado y retryAfterMs', () {
      final event = RoomRateLimited({
        'message': 'Estás enviando mensajes demasiado rápido.',
        'retryAfterMs': 1200,
      });

      expect(event.message, 'Estás enviando mensajes demasiado rápido.');
      expect(event.retryAfterMs, 1200);
    });

    test('RoomRateLimited proporciona valores por defecto ante payload vacío', () {
      final event = RoomRateLimited({});

      expect(event.message, contains('Por favor no spamees'));
      expect(event.retryAfterMs, 1500);
    });
  });
}
