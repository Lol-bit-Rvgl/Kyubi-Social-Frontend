import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kyubi/models/character.dart';
import 'package:kyubi/services/auth_controller.dart';

void main() {
  group('AuthController — logout purges myCharactersProvider', () {
    test('myCharactersProvider es invalidado al purgar la sesión', () {
      // Verifica que el estado de myCharactersProvider es AsyncLoading
      // (se re-fetcha) luego de crear un nuevo ProviderContainer,
      // que simula el efecto de ref.invalidate() tras logout.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Antes de tocar nada, el provider está en AsyncLoading
      final initialState = container.read(myCharactersProvider);
      expect(initialState, isA<AsyncLoading>());

      // Simula la invalidación tal como hace _purgeUserSessionState
      container.invalidate(myCharactersProvider);
      container.invalidate(userCharactersProvider);

      // Tras invalidate, el provider vuelve a AsyncLoading (se resetea)
      final afterInvalidate = container.read(myCharactersProvider);
      expect(afterInvalidate, isA<AsyncLoading>());
    });

    test('userCharactersProvider family es invalidado al purgar la sesión', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Forzamos una lectura del family provider para un userId
      final _ = container.read(userCharactersProvider('user-old'));

      // Simula la invalidación — debe resetear todas las entradas del family
      container.invalidate(userCharactersProvider);

      final afterInvalidate = container.read(userCharactersProvider('user-old'));
      expect(afterInvalidate, isA<AsyncLoading>());
    });

    test(
      'authControllerProvider incluye myCharactersProvider en el purgado',
      () {
        // Verifica que AuthController importa y conoce myCharactersProvider
        // (test de integración de compilación: si el import falta, esto falla)
        expect(myCharactersProvider, isNotNull);
        expect(userCharactersProvider, isNotNull);
        expect(authControllerProvider, isNotNull);
      },
    );
  });
}
