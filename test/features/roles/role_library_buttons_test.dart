import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/features/roles/presentation/role_library_screen.dart';
import 'package:kyubi/models/character.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/services/auth_controller.dart';

class _FakeAuthNotifier extends AuthNotifier {
  final User? initialUser;
  _FakeAuthNotifier(this.initialUser);

  @override
  AuthState build() => AuthState(
        status: initialUser != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: initialUser,
      );
}

void main() {
  const testUser = User(
    id: 'user-1',
    username: 'kyubi_master',
    displayName: 'Kyubi Master',
  );

  final testCharacter = Character(
    id: 'char-1',
    userId: 'user-1',
    name: 'Kitsune Warrior',
    bio: 'Guerrero ancestral',
    avatarUrl: null,
    themeColor: '#00E5FF',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('RoleLibraryScreen - Botones Únicos de Creación', () {
    testWidgets(
        'Cuando la lista está vacía, solo existe el botón central de llamada a la acción',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider
                .overrideWith(() => _FakeAuthNotifier(testUser)),
            myCharactersProvider.overrideWith((ref) async => <Character>[]),
          ],
          child: const MaterialApp(
            home: RoleLibraryScreen(isPicker: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe mostrar el empty state
      expect(find.text('Aún no tienes fichas de rol'), findsOneWidget);

      // Debe existir exactamente 1 botón de crear ficha: el botón central del empty state
      expect(find.text('Crear Ficha de Personaje'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      // No debe existir FloatingActionButton cuando la lista está vacía
      expect(find.byType(FloatingActionButton), findsNothing);

      // No debe existir el botón redundante en el AppBar
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);
    });

    testWidgets(
        'Cuando la lista tiene fichas, solo existe el FloatingActionButton inferior',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider
                .overrideWith(() => _FakeAuthNotifier(testUser)),
            myCharactersProvider
                .overrideWith((ref) async => <Character>[testCharacter]),
          ],
          child: const MaterialApp(
            home: RoleLibraryScreen(isPicker: true),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Debe listar el personaje
      expect(find.text('Kitsune Warrior'), findsOneWidget);

      // No debe mostrar el botón del empty state
      expect(find.text('Crear Ficha de Personaje'), findsNothing);

      // Debe existir exactamente 1 FloatingActionButton con la etiqueta 'Crear Ficha'
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Crear Ficha'), findsOneWidget);

      // No debe existir el botón redundante en el AppBar
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);
    });
  });
}
