import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kyubi/features/salas/presentation/widgets/roleplay_stage_view.dart';
import 'package:kyubi/models/role_character.dart';

void main() {
  const myUserId = 'user-me';

  group('RoleplayStageView — Slot injection and 2-slot limit', () {
    testWidgets(
      'Con 1 slot propio, el botón de control "+ Unirse" pasa firstVacantIndex al callback',
      (tester) async {
        int? capturedSlotIndex;
        int callCount = 0;

        final roles = [
          const RoleCharacter(
            id: 'char-1',
            name: 'Héroe',
            isTaken: true,
            takenByUserId: myUserId,
            takenByUsername: 'Me',
          ),
          RoleCharacter.vacant(id: 'slot-2', name: 'Slot 2'),
          RoleCharacter.vacant(id: 'slot-3', name: 'Slot 3'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RoleplayStageView(
                roles: roles,
                isExpanded: true,
                currentUserId: myUserId,
                onRoleTap: (_) {},
                onPlayTap: () {},
                onVacantSlotTap: (idx) {
                  callCount++;
                  capturedSlotIndex = idx;
                },
              ),
            ),
          ),
        );

        await tester.pump();

        // Hay múltiples textos "+ Unirse" (barra de control + slots vacantes en grid),
        // el botón de control tiene fontSize 13.5 y el de los slots 10.5.
        // Por eso el control inferior expone una Key dedicada
        // (`stage_control_join_button`) y el tap apunta siempre a ese botón,
        // nunca a una casilla vacante del grid.
        expect(find.text('+ Unirse'), findsWidgets); // al menos uno (grid + control)

        final controlBarJoinButton =
            find.byKey(const Key('stage_control_join_button'));
        expect(controlBarJoinButton, findsOneWidget);

        // Reset defensivo: descarta cualquier lectura de taps previos del grid
        // antes de pulsar el botón de la barra de controles.
        capturedSlotIndex = null;
        callCount = 0;

        await tester.tap(controlBarJoinButton);
        await tester.pump();

        expect(callCount, equals(1));
        // El firstVacantIndex para [taken, vacant, vacant] es 1.
        expect(capturedSlotIndex, isNotNull);
        expect(capturedSlotIndex, equals(1));
      },
    );

    testWidgets(
      'Con 2 slots propios, el botón de control "+ Unirse" es reemplazado por "Límite: 2 roles"',
      (tester) async {
        int? capturedSlotIndex = -99;

        final roles = [
          const RoleCharacter(
            id: 'char-1',
            name: 'Héroe',
            isTaken: true,
            takenByUserId: myUserId,
            takenByUsername: 'Me',
          ),
          const RoleCharacter(
            id: 'char-2',
            name: 'Villano',
            isTaken: true,
            takenByUserId: myUserId,
            takenByUsername: 'Me',
          ),
          RoleCharacter.vacant(id: 'slot-3', name: 'Slot 3'),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RoleplayStageView(
                roles: roles,
                isExpanded: true,
                currentUserId: myUserId,
                onRoleTap: (_) {},
                onPlayTap: () {},
                onVacantSlotTap: (idx) => capturedSlotIndex = idx,
              ),
            ),
          ),
        );

        await tester.pump();

        // La barra de control NO debe exponer el botón "+ Unirse"
        // (puede haber un "+ Unirse" en el slot vacante del grid, pero no en la barra)
        expect(find.byKey(const Key('stage_control_join_button')), findsNothing);

        // Verificamos que el indicador "Límite: 2 roles" aparece en pantalla,
        // identificado por su Key para no confundirlo con otros textos.
        expect(find.text('Límite: 2 roles'), findsOneWidget);
        expect(
          find.byKey(const Key('stage_control_slot_limit_indicator')),
          findsOneWidget,
        );

        // No se debe haber llamado al callback sin interacción
        expect(capturedSlotIndex, equals(-99));
      },
    );

    testWidgets(
      'Botón "Unirse" principal (isOnStage == false) pasa null cuando no hay slots vacantes',
      (tester) async {
        int? capturedSlotIndex = -99;

        // Stage vacío — indexWhere devuelve -1 → se pasa null
        const roles = <RoleCharacter>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RoleplayStageView(
                roles: roles,
                isExpanded: true,
                currentUserId: myUserId,
                onRoleTap: (_) {},
                onPlayTap: () {},
                onVacantSlotTap: (idx) => capturedSlotIndex = idx,
              ),
            ),
          ),
        );

        await tester.pump();

        // Con stage vacío y ningún rol, isOnStage == false.
        // El botón principal "Unirse" (sin +) debe estar presente
        expect(find.text('Unirse'), findsOneWidget);

        await tester.tap(find.text('Unirse'));
        await tester.pump();

        // Con stage vacío, widget.roles.indexWhere devuelve -1 → null
        expect(capturedSlotIndex, isNull);
      },
    );

    testWidgets(
      'Con 1 slot propio, mySlotCount == 1 y aún no se alcanza el límite',
      (tester) async {
        final roles = [
          const RoleCharacter(
            id: 'char-1',
            name: 'Héroe',
            isTaken: true,
            takenByUserId: myUserId,
            takenByUsername: 'Me',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RoleplayStageView(
                roles: roles,
                isExpanded: true,
                currentUserId: myUserId,
                onRoleTap: (_) {},
                onPlayTap: () {},
                onVacantSlotTap: (_) {},
              ),
            ),
          ),
        );

        await tester.pump();

        // Con 1 slot ocupado, NO debe aparecer el mensaje de límite
        expect(find.text('Límite: 2 roles'), findsNothing);
      },
    );
  });
}
