import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kyubi/features/auth/presentation/onboarding/onboarding_screen.dart';
import 'package:kyubi/models/circle.dart';
import 'package:kyubi/models/post_author.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/repositories/circle_repository.dart';
import 'package:kyubi/repositories/user_repository.dart';
import 'package:kyubi/services/auth_controller.dart';
import 'package:kyubi/services/providers.dart';

class _FakeCircleRepository implements CircleRepository {
  _FakeCircleRepository(this.circles);

  final List<Circle> circles;
  final List<String> joinedIds = [];

  @override
  Future<List<Circle>> getCircles({
    int limit = 30,
    String? query,
    bool mine = false,
  }) async {
    return circles;
  }

  @override
  Future<Circle> joinCircle(String id) async {
    joinedIds.add(id);
    return circles.firstWhere(
      (c) => c.id == id,
      orElse: () => circles.first,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserRepository implements UserRepository {
  bool onboardingCompletedCalled = false;
  List<String>? passedInterests;

  @override
  Future<User> completeOnboarding({
    String? username,
    String? displayName,
    String? gender,
    List<String>? interests,
    bool? onboardingCompleted,
  }) async {
    onboardingCompletedCalled = true;
    passedInterests = interests;
    return User(
      id: 'test-user',
      username: username != null && username.isNotEmpty ? username : 'tester',
      displayName: displayName != null && displayName.isNotEmpty ? displayName : 'Tester',
      onboardingCompleted: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.initialUser);

  final User? initialUser;

  @override
  AuthState build() => AuthState(
        status: initialUser != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: initialUser,
      );
}

void main() {
  late List<Circle> sampleCircles;
  late _FakeCircleRepository fakeCircleRepo;
  late _FakeUserRepository fakeUserRepo;

  setUp(() {
    sampleCircles = [
      Circle(
        id: 'circle-music',
        name: 'Comunidad de Música',
        description: 'Todo sobre música indie, rock y producción.',
        memberCount: 42,
        tags: const ['música', 'rock'],
        creator: const PostAuthor(
          id: 'u1',
          username: 'dj',
          displayName: 'DJ Kyubi',
        ),
      ),
      Circle(
        id: 'circle-gaming',
        name: 'Gaming Nocturno',
        description: 'Partidas y torneos online.',
        memberCount: 88,
        tags: const ['gaming', 'videojuegos'],
        creator: const PostAuthor(
          id: 'u2',
          username: 'gamer',
          displayName: 'Gamer Pro',
        ),
      ),
      Circle(
        id: 'circle-general',
        name: 'Kyubi General',
        description: 'La plaza central de la comunidad.',
        memberCount: 150,
        tags: const ['general'],
        creator: const PostAuthor(
          id: 'u3',
          username: 'admin',
          displayName: 'Admin',
        ),
      ),
    ];
    fakeCircleRepo = _FakeCircleRepository(sampleCircles);
    fakeUserRepo = _FakeUserRepository();
  });

  Widget createTestWidget({required WidgetRefCallback? onRef}) {
    final user = User(
      id: 'usr-1',
      username: 'usuario_test',
      displayName: 'Usuario Test',
    );

    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/app/feed',
          builder: (context, state) => const Scaffold(body: Text('FeedScreen')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _FakeAuthNotifier(user)),
        circleRepositoryProvider.overrideWithValue(fakeCircleRepo),
        userRepositoryProvider.overrideWithValue(fakeUserRepo),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Paso 3 muestra tarjetas con nombre, descripción, miembros y avatar',
      (tester) async {
    await tester.pumpWidget(createTestWidget(onRef: null));
    await pumpPage(tester);

    // Paso 1: Seleccionar género y avanzar
    await tester.tap(find.text('No binario'));
    await pumpPage(tester);
    await tester.tap(find.text('Continuar'));
    await pumpPage(tester);

    // Paso 2: Avanzar sin seleccionar intereses
    await tester.tap(find.text('Continuar'));
    await pumpPage(tester);

    // Paso 3: Verificar que las tarjetas se muestran correctamente
    expect(find.text('Descubre tu lado oscuro'), findsOneWidget);
    expect(find.text('Únete a círculos de tu interés'), findsOneWidget);

    expect(find.text('Comunidad de Música'), findsOneWidget);
    expect(find.text('Todo sobre música indie, rock y producción.'), findsOneWidget);
    expect(find.text('42 miembros'), findsOneWidget);

    expect(find.text('Gaming Nocturno'), findsOneWidget);
    expect(find.text('Partidas y torneos online.'), findsOneWidget);
    expect(find.text('88 miembros'), findsOneWidget);
  });

  testWidgets('Filtrado y priorización: al elegir "Música" en paso 2, el círculo correspondiente se destaca con "Para ti"',
      (tester) async {
    await tester.pumpWidget(createTestWidget(onRef: null));
    await pumpPage(tester);

    // Paso 1: Género
    await tester.tap(find.text('Femenino'));
    await pumpPage(tester);
    await tester.tap(find.text('Continuar'));
    await pumpPage(tester);

    // Paso 2: Seleccionar 'Música'
    await tester.tap(find.text('Música'));
    await pumpPage(tester);
    await tester.tap(find.text('Continuar'));
    await pumpPage(tester);

    // Paso 3: Debe mostrarse el badge 'Para ti'
    expect(find.text('Para ti'), findsAtLeastNWidgets(1));
    expect(find.text('Comunidad de Música'), findsOneWidget);
  });

  testWidgets('Interacción táctil: tocar una tarjeta conmuta la selección y "Empezar" ejecuta joinCircle en lote',
      (tester) async {
    await tester.pumpWidget(createTestWidget(onRef: null));
    await pumpPage(tester);

    // Paso 1
    await tester.tap(find.text('Masculino'));
    await pumpPage(tester);
    await tester.tap(find.text('Continuar'));
    await pumpPage(tester);

    // Paso 2: Avanzar
    await tester.tap(find.text('Continuar'));
    await pumpPage(tester);

    // Paso 3: Tocar 'Gaming Nocturno' para seleccionarlo
    await tester.tap(find.text('Gaming Nocturno'));
    await pumpPage(tester);

    // Tocar el botón "Empezar"
    await tester.tap(find.text('Empezar'));
    await pumpPage(tester);

    // Verificar que se haya llamado a joinCircle con el id seleccionado
    expect(fakeCircleRepo.joinedIds, contains('circle-gaming'));
    expect(fakeUserRepo.onboardingCompletedCalled, isTrue);
    expect(find.text('FeedScreen'), findsOneWidget);
  });

  testWidgets('Botón "Omitir" finaliza onboarding sin unirse a los círculos pendientes',
      (tester) async {
    await tester.pumpWidget(createTestWidget(onRef: null));
    await pumpPage(tester);

    // Paso 1
    await tester.tap(find.text('Prefiero no decir'));
    await pumpPage(tester);
    await tester.tap(find.text('Continuar'));
    await pumpPage(tester);

    // Paso 2: Continuar
    await tester.tap(find.text('Continuar'));
    await pumpPage(tester);

    // Paso 3: Pulsar "Omitir"
    await tester.tap(find.text('Omitir'));
    await pumpPage(tester);

    expect(fakeCircleRepo.joinedIds, isEmpty);
    expect(fakeUserRepo.onboardingCompletedCalled, isTrue);
    expect(find.text('FeedScreen'), findsOneWidget);
  });
}

typedef WidgetRefCallback = void Function(WidgetRef ref);
