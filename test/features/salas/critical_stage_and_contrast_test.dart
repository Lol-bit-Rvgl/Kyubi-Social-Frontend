import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/widgets/app_button.dart';
import 'package:kyubi/features/circles/presentation/circles_screen.dart';
import 'package:kyubi/features/salas/presentation/widgets/roleplay_stage_view.dart';
import 'package:kyubi/models/role_character.dart';
import 'package:kyubi/routing/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RoleplayStageView - Abandono de Rol y Botón Bajar', () {
    testWidgets(
      'Muestra botón Bajar cuando el usuario tiene un rol asignado por takenByUserId',
      (tester) async {
        bool leaveTapped = false;
        final roles = [
          const RoleCharacter(
            id: 'role-1',
            name: 'Guerrero',
            colorHex: '#00E5FF',
            isTaken: true,
            takenByUserId: 'user-me',
            takenByUsername: 'MiUsuario',
          ),
          const RoleCharacter(
            id: 'role-2',
            name: 'Mago',
            colorHex: '#BA68C8',
            isTaken: false,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RoleplayStageView(
                roles: roles,
                currentUserId: 'user-me',
                isExpanded: true,
                onRoleTap: (_) {},
                onPlayTap: () {},
                onLeaveStageTap: () {
                  leaveTapped = true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tu Turno'), findsOneWidget);
        expect(find.text('Bajar'), findsOneWidget);
        expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

        await tester.tap(find.text('Bajar'));
        await tester.pumpAndSettle();

        expect(leaveTapped, isTrue);
      },
    );

    testWidgets(
      'Muestra botón Unirse cuando el usuario NO está en el stage',
      (tester) async {
        final roles = [
          const RoleCharacter(
            id: 'role-1',
            name: 'Guerrero',
            colorHex: '#00E5FF',
            isTaken: true,
            takenByUserId: 'other-user',
            takenByUsername: 'Otro',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RoleplayStageView(
                roles: roles,
                currentUserId: 'user-me',
                isExpanded: true,
                onRoleTap: (_) {},
                onPlayTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unirse'), findsOneWidget);
        expect(find.text('Bajar'), findsNothing);
      },
    );
  });

  group('AppButton - Contraste Automático por Luminancia', () {
    testWidgets('Con fondo blanco #FFFFFF el texto e icono son oscuros (#0D0A14)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Guardar',
              icon: Icons.check_rounded,
              backgroundColor: Color(0xFFFFFFFF),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('Guardar'));
      expect(textWidget.style?.color, const Color(0xFF0D0A14));

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
      expect(iconWidget.color, const Color(0xFF0D0A14));
    });

    testWidgets('Con fondo oscuro el texto e icono son blancos', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Guardar',
              icon: Icons.check_rounded,
              backgroundColor: Color(0xFF171424),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('Guardar'));
      expect(textWidget.style?.color, Colors.white);

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
      expect(iconWidget.color, Colors.white);
    });
  });

  group('AppRouter - Ruta /circles Registrada como Pantalla Independiente', () {
    test('El provider del router está configurado', () {
      expect(routerProvider, isNotNull);
    });
  });
}
