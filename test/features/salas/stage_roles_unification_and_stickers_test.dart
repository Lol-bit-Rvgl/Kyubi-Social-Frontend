import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/widgets/animated_sticker.dart';
import 'package:kyubi/features/salas/presentation/widgets/chat_message_input_bar.dart';
import 'package:kyubi/features/salas/presentation/widgets/roleplay_stage_view.dart';
import 'package:kyubi/models/role_character.dart';

void main() {
  group('AnimatedSticker Tests', () {
    testWidgets('Configura gaplessPlayback y filterQuality en asset webp/gif/png',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSticker(
              assetPath: 'assets/stickers/sparkle.webp',
              emoji: '✨',
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.gaplessPlayback, isTrue);
      expect(imageWidget.filterQuality, FilterQuality.medium);
    });

    testWidgets('Configura Image.network con gaplessPlayback para URLs remotas',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSticker(
              assetPath: 'https://media.example.dev/stickers/test.webp',
              emoji: '🦊',
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<NetworkImage>());
      expect(imageWidget.gaplessPlayback, isTrue);
      expect(imageWidget.filterQuality, FilterQuality.medium);
    });
  });

  group('RoleCharacter Vacant Tests', () {
    test('RoleCharacter.vacant crea slot neutral sin dueño', () {
      final vacant = RoleCharacter.vacant(id: 'slot-1', name: 'Slot 1');
      expect(vacant.id, 'slot-1');
      expect(vacant.name, 'Slot 1');
      expect(vacant.isTaken, isFalse);
      expect(vacant.takenByUserId, isNull);
      expect(vacant.avatarUrl, isNull);
    });

    test('toVacant con resetId resetea id y nombre', () {
      const occupied = RoleCharacter(
        id: 'char-123',
        name: 'Guerrero',
        isTaken: true,
        takenByUserId: 'user-abc',
      );
      final reset = occupied.toVacant(resetId: 'slot-2', resetName: 'Slot 2');
      expect(reset.id, 'slot-2');
      expect(reset.name, 'Slot 2');
      expect(reset.isTaken, isFalse);
      expect(reset.takenByUserId, isNull);
    });
  });

  group('ChatMessageInputBar Identity & Roles Tests', () {
    testWidgets(
        'No muestra opción "Mi Biblioteca de Roles" ni marca rol fantasma',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageInputBar(
              onSendMessage: (_) {},
              onSendImage: (_) {},
              onSendAudio: (_, _, _) {},
              onSendDiceRoll: (_, _, _) {},
              onSendPoll: (_, _) {},
              isRoleplay: true,
              userName: 'Carlos',
              currentUserId: 'user-me',
              availableRoles: const [
                RoleCharacter(
                  id: 'slot-1',
                  name: 'Slot 1',
                  isTaken: false,
                ),
              ],
            ),
          ),
        ),
      );

      // Abrir modal de identidad pulsando el avatar/selector de rol
      final identityBtnFinder =
          find.byTooltip('Identidad: Mi Perfil (Carlos)');
      expect(identityBtnFinder, findsOneWidget);
      await tester.tap(identityBtnFinder);
      await tester.pumpAndSettle();

      // Verificar que NO existe la opción "Mi Biblioteca de Roles"
      expect(find.text('Mi Biblioteca de Roles'), findsNothing);

      // Verificar que "Mi Perfil (Carlos)" está presente
      expect(find.text('Mi Perfil (Carlos)'), findsOneWidget);
    });
  });

  group('RoleplayStageView Keys Tests', () {
    testWidgets('Asigna claves únicas slot_index_roleId y empty_slot_index',
        (tester) async {
      final roles = [
        const RoleCharacter(
          id: 'role-aaa',
          name: 'Mago',
          isTaken: true,
          takenByUserId: 'other-user',
          takenByUsername: 'Other',
        ),
        RoleCharacter.vacant(id: 'slot-2', name: 'Slot 2'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoleplayStageView(
              roles: roles,
              isExpanded: true,
              currentUserId: 'user-me',
              onRoleTap: (_) {},
              onPlayTap: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('slot_0_role-aaa')), findsOneWidget);
      expect(find.byKey(const ValueKey('slot_1_slot-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('empty_slot_2')), findsOneWidget);
    });
  });
}
