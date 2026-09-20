import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/features/messages/presentation/conversation_controller.dart';
import 'package:kyubi/features/messages/presentation/conversation_screen.dart';
import 'package:kyubi/features/salas/presentation/widgets/chat_message_input_bar.dart';
import 'package:kyubi/features/salas/presentation/widgets/roleplay_stage_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kyubi/models/character.dart';
import 'package:kyubi/models/role_character.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/services/auth_controller.dart';

void main() {
  group('ChatMessageInputBar - Selector Rápido de Identidad (Roleplay vs Personal)', () {
    const role1 = RoleCharacter(
      id: 'role-warrior',
      name: 'Kaelen',
      tagline: 'Caballero del Alba',
      colorHex: '#FF5722',
      isTaken: true,
      takenByUserId: 'my-user-id',
      takenByUsername: 'Tester',
    );

    const role2 = RoleCharacter(
      id: 'role-mage',
      name: 'Lyra',
      tagline: 'Hechicera Estelar',
      colorHex: '#00E5FF',
      isTaken: true,
      takenByUserId: 'my-user-id',
      takenByUsername: 'Tester',
    );

    const otherUserRole = RoleCharacter(
      id: 'role-rogue',
      name: 'Vane',
      tagline: 'Asesino',
      colorHex: '#9C27B0',
      isTaken: true,
      takenByUserId: 'other-user-id',
      takenByUsername: 'OtroJugador',
    );

    testWidgets('Muestra botón de identidad solo cuando isRoleplay es true', (tester) async {
      // 1. Con isRoleplay = false (Modo normal / DMs)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageInputBar(
              isRoleplay: false,
              userName: 'Tester',
              onSendMessage: (_) {},
              onSendImage: (_) {},
              onSendAudio: (_, _, _) {},
              onSendDiceRoll: (_, _, _) {},
              onSendPoll: (_, _) {},
            ),
          ),
        ),
      );

      expect(find.byTooltip('Identidad: Mi Perfil (Tester)'), findsNothing);
      expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
      expect(find.text('Escribe un mensaje...'), findsOneWidget);

      // 2. Con isRoleplay = true
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageInputBar(
              isRoleplay: true,
              userName: 'Tester',
              currentUserId: 'my-user-id',
              availableRoles: const [role1, role2, otherUserRole],
              onSendMessage: (_) {},
              onSendImage: (_) {},
              onSendAudio: (_, _, _) {},
              onSendDiceRoll: (_, _, _) {},
              onSendPoll: (_, _) {},
            ),
          ),
        ),
      );

      expect(find.byTooltip('Identidad: Mi Perfil (Tester)'), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
      expect(find.text('Escribe un mensaje...'), findsOneWidget);
    });

    testWidgets('Alterna entre Mi Perfil y Roles Asignados actualizando placeholder y callback onRoleChanged', (tester) async {
      RoleCharacter? lastChangedRole;
      bool onRoleChangedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageInputBar(
              isRoleplay: true,
              userName: 'Tester',
              currentUserId: 'my-user-id',
              currentRole: null, // Comienza en modo personal
              availableRoles: const [role1, role2, otherUserRole],
              onRoleChanged: (role) {
                lastChangedRole = role;
                onRoleChangedCalled = true;
              },
              onSendMessage: (_) {},
              onSendImage: (_) {},
              onSendAudio: (_, _, _) {},
              onSendDiceRoll: (_, _, _) {},
              onSendPoll: (_, _) {},
            ),
          ),
        ),
      );

      // Placeholder inicial en modo personal
      expect(find.text('Escribe un mensaje...'), findsOneWidget);

      // Tocar el selector de identidad
      await tester.tap(find.byTooltip('Identidad: Mi Perfil (Tester)'));
      await tester.pumpAndSettle();

      // Verificar contenido del modal BottomSheet
      expect(find.text('Cambiar Identidad'), findsOneWidget);
      expect(find.text('Mi Perfil (Tester)'), findsOneWidget);
      expect(find.text('Kaelen'), findsOneWidget);
      expect(find.text('Caballero del Alba'), findsOneWidget);
      expect(find.text('Lyra'), findsOneWidget);
      expect(find.text('Hechicera Estelar'), findsOneWidget);
      // El rol de otro usuario no debe aparecer en mis roles asignados
      expect(find.text('Vane'), findsNothing);

      // Seleccionar el rol "Kaelen"
      await tester.tap(find.text('Kaelen'));
      await tester.pumpAndSettle();

      // Verificar que el modal se cerró y se notificó el cambio
      expect(find.text('Cambiar Identidad'), findsNothing);
      expect(onRoleChangedCalled, isTrue);
      expect(lastChangedRole?.id, 'role-warrior');
      expect(lastChangedRole?.name, 'Kaelen');

      // Verificar que el placeholder se actualizó al rol
      expect(find.text('Mensaje como Kaelen...'), findsOneWidget);
      expect(find.byTooltip('Identidad: Kaelen (Toca para cambiar)'), findsOneWidget);

      // Volver a abrir el modal y elegir "Mi Perfil"
      onRoleChangedCalled = false;
      await tester.tap(find.byTooltip('Identidad: Kaelen (Toca para cambiar)'));
      await tester.pumpAndSettle();

      expect(find.text('Cambiar Identidad'), findsOneWidget);
      await tester.tap(find.text('Mi Perfil (Tester)'));
      await tester.pumpAndSettle();

      // Verificar que volvió a modo personal
      expect(onRoleChangedCalled, isTrue);
      expect(lastChangedRole, isNull);
      expect(find.text('Escribe un mensaje...'), findsOneWidget);
      expect(find.byTooltip('Identidad: Mi Perfil (Tester)'), findsOneWidget);
    });

    testWidgets('Botonera inferior de 7 herramientas se renderiza sin errores de desbordamiento', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 340, // Pantalla estrecha para probar resistencia a RenderFlex overflow
              child: ChatMessageInputBar(
                isRoleplay: true,
                userName: 'Tester',
                onSendMessage: (_) {},
                onSendImage: (_) {},
                onSendAudio: (_, _, _) {},
                onSendDiceRoll: (_, _, _) {},
                onSendPoll: (_, _) {},
              ),
            ),
          ),
        ),
      );

      // Comprobar presencia de los 7 iconos de herramientas
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.photo_outlined), findsOneWidget);
      expect(find.byIcon(Icons.sentiment_satisfied_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.byIcon(Icons.casino_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
    });
  });

  group('ConversationScreen - Integración con ChatMessageInputBar', () {
    testWidgets('ConversationScreen renderiza ChatMessageInputBar con isRoleplay false', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationChatProvider.overrideWith(
              () => _MockConversationChatNotifier(const ConversationChatState(messages: [], loading: false)),
            ),
            authControllerProvider.overrideWith(
              () => _MockAuthNotifier(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConversationScreen(conversationId: 'dm-conv-1'),
            ),
          ),
        ),
      );

      // Debe contener ChatMessageInputBar
      expect(find.byType(ChatMessageInputBar), findsOneWidget);
      // No debe mostrar botón de identidad porque no es sala de roleplay
      expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
      // Debe contener el placeholder estándar
      expect(find.text('Escribe un mensaje...'), findsOneWidget);
      // Debe mostrar la botonera rápida (sin el acceso rápido duplicado a
      // galería: el "+" abre el sheet unificado Galería/Cámara).
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.photo_outlined), findsNothing);
      expect(find.byIcon(Icons.casino_rounded), findsOneWidget);
    });
  });

  group('Sincronización de Estado de Rol y Avatares', () {
    test('RoleCharacter.toVacant y copyWith(isTaken: false) limpian takenByUserId y takenByUsername', () {
      const occupied = RoleCharacter(
        id: 'role-test',
        name: 'Protagonista',
        avatarUrl: 'https://example.com/avatar.png',
        isTaken: true,
        takenByUserId: 'user-123',
        takenByUsername: 'PlayerOne',
      );

      final vacant = occupied.toVacant();
      expect(vacant.isTaken, isFalse);
      expect(vacant.takenByUserId, isNull);
      expect(vacant.takenByUsername, isNull);
      expect(vacant.occupiedBy, isNull);
      expect(vacant.occupiedByName, isNull);

      final freed = occupied.copyWith(isTaken: false);
      expect(freed.isTaken, isFalse);
      expect(freed.takenByUserId, isNull);
      expect(freed.takenByUsername, isNull);
    });

    test('Character.fromJson y RoleCharacter.fromJson leen avatarUrl desde múltiples claves alternativas', () {
      final jsonWithAvatar = {
        'id': 'char-1',
        'name': 'Ficha 1',
        'avatar': 'https://example.com/from_avatar.png',
      };
      final rc = RoleCharacter.fromJson(jsonWithAvatar);
      expect(rc.avatarUrl, equals('https://example.com/from_avatar.png'));

      final ch = Character.fromJson(jsonWithAvatar);
      expect(ch.avatarUrl, equals('https://example.com/from_avatar.png'));

      final converted = ch.toRoleCharacter(currentUserId: 'u1', currentUsername: 'tester');
      expect(converted.avatarUrl, equals('https://example.com/from_avatar.png'));
    });

    testWidgets('ChatMessageInputBar renderiza CachedNetworkImage para el rol seleccionado con avatar', (tester) async {
      const roleWithImg = RoleCharacter(
        id: 'role-img',
        name: 'Aria',
        avatarUrl: 'https://example.com/aria.png',
        isTaken: true,
        takenByUserId: 'my-user-id',
        takenByUsername: 'Tester',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageInputBar(
              isRoleplay: true,
              userName: 'Tester',
              currentUserId: 'my-user-id',
              currentRole: roleWithImg,
              availableRoles: const [roleWithImg],
              onSendMessage: (_) {},
              onSendImage: (_) {},
              onSendAudio: (_, _, _) {},
              onSendDiceRoll: (_, _, _) {},
              onSendPoll: (_, _) {},
            ),
          ),
        ),
      );

      final cachedImage = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(cachedImage.imageUrl, equals('https://example.com/aria.png'));
    });

    testWidgets('Filtra rigurosamente roles nulos o corruptos y no muestra filas fantasma', (tester) async {
      const corruptRole1 = RoleCharacter(
        id: '',
        name: '',
        isTaken: true,
        takenByUserId: 'my-user-id',
      );
      const corruptRole2 = RoleCharacter(
        id: 'corrupt-dots',
        name: '...',
        isTaken: true,
        takenByUserId: 'my-user-id',
      );
      const corruptRole3 = RoleCharacter(
        id: 'corrupt-spaces',
        name: '   ',
        isTaken: true,
        takenByUserId: 'my-user-id',
      );
      const validRole = RoleCharacter(
        id: 'valid-role',
        name: 'Heroe Real',
        tagline: 'Defensor',
        isTaken: true,
        takenByUserId: 'my-user-id',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageInputBar(
              isRoleplay: true,
              userName: 'Tester',
              currentUserId: 'my-user-id',
              availableRoles: const [corruptRole1, corruptRole2, corruptRole3, validRole],
              onSendMessage: (_) {},
              onSendImage: (_) {},
              onSendAudio: (_, _, _) {},
              onSendDiceRoll: (_, _, _) {},
              onSendPoll: (_, _) {},
            ),
          ),
        ),
      );

      // Abrir modal de identidades
      await tester.tap(find.byTooltip('Identidad: Mi Perfil (Tester)'));
      await tester.pumpAndSettle();

      // Debe mostrar solo 1 rol válido
      expect(find.text('ROLES Y PERSONAJES ASIGNADOS (1)'), findsOneWidget);
      expect(find.text('Heroe Real'), findsOneWidget);
      expect(find.text('...'), findsNothing);
      expect(find.text('Ficha de Rol equipada'), findsNothing);
    });

    testWidgets('Muestra múltiples roles asignados al usuario (ej. 4 roles) y permite conmutar turno sin vacantes ni roles ajenos', (tester) async {
      const myRoles = [
        RoleCharacter(
          id: 'char-1',
          name: 'Guerrero Arturo',
          tagline: 'Defensor del reino',
          isTaken: true,
          takenByUserId: 'my-user-id',
        ),
        RoleCharacter(
          id: 'char-2',
          name: 'Maga Elena',
          tagline: 'Maestra elemental',
          isTaken: true,
          takenByUserId: 'my-user-id',
        ),
        RoleCharacter(
          id: 'char-3',
          name: 'Pícaro Loki',
          tagline: 'Sombra veloz',
          isTaken: true,
          takenByUserId: 'my-user-id',
        ),
        RoleCharacter(
          id: 'char-4',
          name: 'Clérigo Aarón',
          tagline: 'Sanador sagrado',
          isTaken: true,
          takenByUserId: 'my-user-id',
        ),
        RoleCharacter(
          id: 'slot-5',
          name: 'Slot 5',
          isTaken: false, // Vacante
        ),
        RoleCharacter(
          id: 'char-other',
          name: 'Rival Enmascarado',
          isTaken: true,
          takenByUserId: 'other-user-99',
        ),
      ];

      RoleCharacter? selectedRole;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageInputBar(
              isRoleplay: true,
              userName: 'Tester',
              currentUserId: 'my-user-id',
              isHost: true, // Aunque sea host, no deben listarse slots vacantes para hablar
              availableRoles: myRoles,
              onRoleChanged: (r) => selectedRole = r,
              onSendMessage: (_) {},
              onSendImage: (_) {},
              onSendAudio: (_, _, _) {},
              onSendDiceRoll: (_, _, _) {},
              onSendPoll: (_, _) {},
            ),
          ),
        ),
      );

      // Abrir modal de identidad
      await tester.tap(find.byTooltip('Identidad: Mi Perfil (Tester)'));
      await tester.pumpAndSettle();

      // Debe listar exactamente los 4 roles del usuario
      expect(find.text('ROLES Y PERSONAJES ASIGNADOS (4)'), findsOneWidget);
      expect(find.text('Guerrero Arturo'), findsOneWidget);
      expect(find.text('Maga Elena'), findsOneWidget);
      expect(find.text('Pícaro Loki'), findsOneWidget);
      expect(find.text('Clérigo Aarón'), findsOneWidget);

      // NO debe listar el slot vacante ni el rol del otro usuario
      expect(find.text('Slot 5'), findsNothing);
      expect(find.text('Rival Enmascarado'), findsNothing);

      // Seleccionar el tercer personaje (Pícaro Loki)
      await tester.tap(find.text('Pícaro Loki'));
      await tester.pumpAndSettle();

      expect(selectedRole?.name, 'Pícaro Loki');
      expect(find.text('Mensaje como Pícaro Loki...'), findsOneWidget);
    });

    testWidgets('RoleplayStageView permite presionar + Unirse y slots vacantes aunque el usuario ya tenga otros roles', (tester) async {
      int? tappedSlotIndex;
      bool vacantSlotTapped = false;

      final stageRoles = [
        const RoleCharacter(
          id: 'char-1',
          name: 'Mi Primer Rol',
          isTaken: true,
          takenByUserId: 'my-user-id',
        ),
        const RoleCharacter(
          id: 'slot-2',
          name: 'Slot 2',
          isTaken: false, // Slot vacante disponible
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoleplayStageView(
              isExpanded: true,
              roles: stageRoles,
              currentUserId: 'my-user-id',
              onRoleTap: (_) {},
              onPlayTap: () {},
              onVacantSlotTap: (slotIdx) {
                tappedSlotIndex = slotIdx;
                vacantSlotTapped = true;
              },
            ),
          ),
        ),
      );

      // Tocar el slot vacante (Slot 2)
      await tester.tap(find.text('Slot 2'));
      await tester.pumpAndSettle();

      expect(vacantSlotTapped, isTrue);
      expect(tappedSlotIndex, 1);

      // Tocar el botón "+ Unirse" del slot extra
      vacantSlotTapped = false;
      tappedSlotIndex = null;
      await tester.tap(find.text('+ Unirse').first);
      await tester.pumpAndSettle();

      expect(vacantSlotTapped, isTrue);
    });
  });
}

class _MockConversationChatNotifier extends ConversationChatNotifier {
  _MockConversationChatNotifier(this._initialState);
  final ConversationChatState _initialState;

  @override
  ConversationChatState build(String conversationId) => _initialState;
}

class _MockAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        user: const User(
          id: 'user-1',
          username: 'tester',
          email: 'test@kyubi.app',
          displayName: 'Tester User',
        ),
      );
}
