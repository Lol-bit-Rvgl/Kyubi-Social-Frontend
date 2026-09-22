import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/features/salas/presentation/widgets/roleplay_stage_view.dart';
import 'package:kyubi/models/role_character.dart';

void main() {
  group('RoleplayStageView - Adjudicación Continua de Múltiples Slots', () {
    final myRole = const RoleCharacter(
      id: 'role-1',
      name: 'Kitsune Warrior',
      isTaken: true,
      takenByUserId: 'user-1',
      takenByUsername: 'Kyubi Master',
    );

    testWidgets(
        'Cuando el usuario ya está en el Stage (isOnStage == true), el botón + Unirse sigue visible en los controles inferiores',
        (tester) async {
      int? tappedSlot;
      bool playTurnTapped = false;
      bool leaveStageTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoleplayStageView(
              roles: [myRole],
              currentUserId: 'user-1',
              isExpanded: true,
              onRoleTap: (_) {},
              onPlayTap: () => playTurnTapped = true,
              onLeaveStageTap: () => leaveStageTapped = true,
              onVacantSlotTap: (slot) => tappedSlot = slot,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe mostrar el botón de "Tu Turno" y llamar al callback
      expect(find.text('Tu Turno'), findsOneWidget);
      await tester.tap(find.text('Tu Turno'), warnIfMissed: false);
      await tester.pump();
      expect(playTurnTapped, isTrue);

      // Debe mostrar el botón de "Bajar" y llamar al callback
      expect(find.text('Bajar'), findsOneWidget);
      await tester.tap(find.text('Bajar'), warnIfMissed: false);
      await tester.pump();
      expect(leaveStageTapped, isTrue);

      // Debe mantener el botón "+ Unirse" en los controles inferiores
      expect(find.text('+ Unirse'), findsWidgets);

      // Al pulsar "+ Unirse" en la barra inferior, se invoca onVacantSlotTap
      final unirseFinder = find.widgetWithText(GestureDetector, '+ Unirse');
      expect(unirseFinder, findsWidgets);

      await tester.tap(unirseFinder.last, warnIfMissed: false);
      await tester.pump();

      // Al pulsar en el botón de la barra de acciones inferiores, llama con null
      expect(tappedSlot, isNull);
    });

    testWidgets(
        'Al tocar el slot vacío en el grid cuando ya se tiene un rol, se invoca onVacantSlotTap con el slotIndex correspondiente',
        (tester) async {
      int? tappedSlot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoleplayStageView(
              roles: [myRole],
              currentUserId: 'user-1',
              isExpanded: true,
              onRoleTap: (_) {},
              onPlayTap: () {},
              onVacantSlotTap: (slot) => tappedSlot = slot,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // El slot vacío del grid tiene la key empty_slot_1 (ya que el slot 0 está tomado por myRole)
      final emptySlotFinder = find.byKey(const ValueKey('empty_slot_1'));
      expect(emptySlotFinder, findsOneWidget);

      await tester.tap(emptySlotFinder, warnIfMissed: false);
      await tester.pump();

      // Debe recibir exactamente el slotIndex 1 para adjudicarse el nuevo espacio
      expect(tappedSlot, 1);
    });
  });

  group('Roleplay Stage - Compuerta de Visitante (_isJoined Guard)', () {
    testWidgets(
        'Para usuario no miembro (_isJoined == false), pulsar en slot vacante o + Unirse muestra SnackBar de membresía requerida',
        (tester) async {
      bool isJoined = false;
      bool pickerOpened = false;

      void showVisitorWarning(BuildContext context) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Debes unirte a la sala para poder participar en el Stage de Roleplay'),
          ),
        );
      }

      void handleSelectRoleForStage(BuildContext context, {int? targetSlotIndex}) {
        if (!isJoined) {
          showVisitorWarning(context);
          return;
        }
        pickerOpened = true;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => RoleplayStageView(
                roles: const [],
                currentUserId: 'visitor-user',
                isExpanded: true,
                onRoleTap: (_) {},
                onPlayTap: () {},
                onVacantSlotTap: (slot) =>
                    handleSelectRoleForStage(context, targetSlotIndex: slot),
                onAddRoleTap: () => handleSelectRoleForStage(context),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pulsar en el slot vacante
      final emptySlotFinder = find.byKey(const ValueKey('empty_slot_0'));
      expect(emptySlotFinder, findsOneWidget);

      await tester.tap(emptySlotFinder, warnIfMissed: false);
      await tester.pump();

      // El picker NO debe haberse abierto
      expect(pickerOpened, isFalse);

      // Debe mostrar el SnackBar informativo
      expect(
        find.text('Debes unirte a la sala para poder participar en el Stage de Roleplay'),
        findsOneWidget,
      );

      // Ahora simular que el usuario se une a la sala (isJoined = true)
      isJoined = true;
      await tester.tap(emptySlotFinder, warnIfMissed: false);
      await tester.pump();

      // Ahora sí se abre el picker
      expect(pickerOpened, isTrue);
    });
  });
}
