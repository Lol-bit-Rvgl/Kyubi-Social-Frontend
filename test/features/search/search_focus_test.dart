import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/widgets/animated_fluid_background.dart';
import 'package:kyubi/features/search/presentation/search_screen.dart';
import 'package:kyubi/models/circle.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/repositories/circle_repository.dart';
import 'package:kyubi/repositories/search_repository.dart';
import 'package:kyubi/repositories/user_repository.dart';
import 'package:kyubi/services/providers.dart';

class _FakeUserRepository implements UserRepository {
  @override
  Future<List<FollowItem>> suggestPeople({int limit = 20}) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCircleRepository implements CircleRepository {
  @override
  Future<List<Circle>> searchCircles(String query, {int limit = 30}) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSearchRepository implements SearchRepository {
  @override
  Future<List<TrendingTag>> trending({int limit = 15}) async => const [];

  @override
  Future<SearchResults> search(
    String query, {
    String type = 'all',
    int limit = 20,
    int offset = 0,
  }) async {
    return const SearchResults(
      posts: [],
      users: [],
      rooms: [],
      circles: [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Búsqueda - Foco Persistente y Scroll Dismiss Behavior', () {
    testWidgets('CustomScrollView usa ScrollViewKeyboardDismissBehavior.onDrag', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
            searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
            circleRepositoryProvider.overrideWithValue(_FakeCircleRepository()),
          ],
          child: const MaterialApp(
            home: SearchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final scrollView = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
      expect(
        scrollView.keyboardDismissBehavior,
        equals(ScrollViewKeyboardDismissBehavior.onDrag),
      );
    });

    testWidgets('El foco del TextField se mantiene tras el debounce de consulta', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
            searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
            circleRepositoryProvider.overrideWithValue(_FakeCircleRepository()),
          ],
          child: const MaterialApp(
            home: SearchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Enfocar y escribir
      await tester.tap(searchField);
      await tester.pump();
      await tester.enterText(searchField, 'flutter');
      await tester.pump();

      final textFieldWidget = tester.widget<TextField>(searchField);
      expect(textFieldWidget.focusNode?.hasFocus, isTrue);

      // Avanzar el tiempo para que se complete el debounce (400ms) y la llamada _search()
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // El campo de texto DEBE continuar enfocado (el teclado no se cierra)
      expect(textFieldWidget.focusNode?.hasFocus, isTrue);
    });

    testWidgets('Limpiar texto mediante el botón suffixIcon desenfoca explícitamente', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
            searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
            circleRepositoryProvider.overrideWithValue(_FakeCircleRepository()),
          ],
          child: const MaterialApp(
            home: SearchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.tap(searchField);
      await tester.enterText(searchField, 'kyubi');
      await tester.pump();

      // El botón de limpiar (close_rounded) debe aparecer
      final clearButton = find.byIcon(Icons.close_rounded);
      expect(clearButton, findsOneWidget);

      // Tocar botón de limpiar
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      final textFieldWidget = tester.widget<TextField>(searchField);
      expect(textFieldWidget.controller?.text.isEmpty, isTrue);
      expect(textFieldWidget.focusNode?.hasFocus, isFalse);
    });
  });

  group('Fondo Cósmico - AnimatedFluidBackground Estabilizado', () {
    testWidgets('Renderiza sin errores de desbordamiento ni desplazamientos bruscos', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedFluidBackground(
              assetPath: 'assets/images/bg_fluid_ambient.webp',
              child: Text('Contenido'),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Contenido'), findsOneWidget);
      expect(find.byType(AnimatedFluidBackground), findsOneWidget);
      expect(find.byType(ClipRect), findsWidgets);

      // Avanzar animación y verificar estabilidad
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });
}
