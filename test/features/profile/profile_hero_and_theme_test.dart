import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kyubi/core/constants/storage_keys.dart';
import 'package:kyubi/core/widgets/liquid_glass_container.dart';
import 'package:kyubi/features/profile/presentation/widgets/profile_sliver_app_bar.dart';
import 'package:kyubi/models/user.dart';
import 'package:kyubi/services/auth_controller.dart';
import 'package:kyubi/services/user_theme_provider.dart';

import 'package:kyubi/features/profile/presentation/profile_screen.dart';
import 'package:kyubi/repositories/user_repository.dart';
import 'package:kyubi/services/providers.dart';

class _FakeProfileUserRepository implements UserRepository {
  final User user;
  _FakeProfileUserRepository(this.user);

  @override
  Future<User> getMe() async => user;

  @override
  Future<List<VisitItem>> getVisits(String username) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileSliverAppBar - Leading y Acciones', () {
    const testUser = User(
      id: 'u-hero-1',
      username: 'cosmicfox',
      displayName: 'Cosmic Fox',
    );

    testWidgets('ProfileSliverAppBar sin leading no renderiza botón de menú', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                ProfileSliverAppBar(
                  user: testUser,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings_rounded),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      // Verificamos que no exista icono de menú hamburguesa
      expect(find.byIcon(Icons.menu_rounded), findsNothing);
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    });

    testWidgets('ProfileSliverAppBar con leading renderiza el botón provisto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                ProfileSliverAppBar(
                  user: testUser,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () {},
                  ),
                  actions: const [],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });
  });

  group('UserThemeNotifier & Persistencia de Tema', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('updateTheme actualiza el estado de forma síncrona y persiste en SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const newSettings = UserThemeSettings(
        primaryColor: '#7C4DFF',
        accentColor: '#FF6D00',
        glassStyle: GlassStyle.transparent,
      );

      final notifier = container.read(userThemeProvider.notifier);
      await notifier.updateTheme(newSettings);

      // Verificación de actualización sincrónica en el estado
      expect(container.read(userThemeProvider).primaryColor, '#7C4DFF');
      expect(container.read(userThemeProvider).accentColor, '#FF6D00');
      expect(container.read(userThemeProvider).glassStyle, GlassStyle.transparent);

      // Verificación de persistencia en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(StorageKeys.themeColor), '#7C4DFF');
      expect(prefs.getString(StorageKeys.accentColor), '#FF6D00');
      expect(prefs.getString(StorageKeys.cardStyle), 'transparent');
    });

    test('loadPersistedTheme restaura valores previamente guardados', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.themeColor: '#00E5FF',
        StorageKeys.accentColor: '#FF4081',
        StorageKeys.cardStyle: 'frosted',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userThemeProvider.notifier);
      await notifier.loadPersistedTheme();

      expect(container.read(userThemeProvider).primaryColor, '#00E5FF');
      expect(container.read(userThemeProvider).accentColor, '#FF4081');
      expect(container.read(userThemeProvider).glassStyle, GlassStyle.frosted);
    });
  });

  group('AuthController - Protección de Tema ante getMe retrasado', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('updateUser preserva el tema activo si el usuario entrante carece de themeSettings', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final authNotifier = container.read(authControllerProvider.notifier);

      // Usuario inicial con tema personalizado
      const initialUser = User(
        id: 'u-1',
        username: 'fox',
        displayName: 'Fox',
        extensions: {
          'themeColor': '#7C4DFF',
          'themeSettings': {
            'primaryColor': '#7C4DFF',
            'accentColor': '#00E676',
            'glassStyle': 'frosted',
          },
        },
      );

      authNotifier.updateUser(initialUser);
      expect(container.read(authControllerProvider).user?.themeSettings.primaryColor, '#7C4DFF');

      // Simular llegada de getMe() con caché antiguo sin themeSettings
      const staleUser = User(
        id: 'u-1',
        username: 'fox',
        displayName: 'Fox',
        extensions: {},
      );

      authNotifier.updateUser(staleUser);

      // El tema activo debe preservarse y no resetearse al default #BA68C8
      final resolvedUser = container.read(authControllerProvider).user;
      expect(resolvedUser?.themeSettings.primaryColor, '#7C4DFF');
      expect(resolvedUser?.themeSettings.accentColor, '#00E676');
    });
  });

  group('ProfileScreen - Botones de Acción de Perfil Propio', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    const ownUser = User(
      id: 'u-own-1',
      username: 'cosmicfox',
      displayName: 'Cosmic Fox',
    );

    testWidgets('Muestra "Editar perfil" y Configuración, y NO muestra "Fichas de Rol"', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _FakeAuthNotifier(ownUser)),
            userRepositoryProvider.overrideWithValue(_FakeProfileUserRepository(ownUser)),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Debe mostrar Editar perfil como botón de acción
      expect(find.text('Editar perfil'), findsOneWidget);
      // Debe mostrar el botón de Configuración
      expect(find.byTooltip('Configuración'), findsOneWidget);
      // NO debe mostrar el botón "Fichas de Rol"
      expect(find.text('Fichas de Rol'), findsNothing);
    });
  });
}

