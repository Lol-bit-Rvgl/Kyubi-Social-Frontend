import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/storage_keys.dart';
import '../core/widgets/liquid_glass_container.dart';
import '../models/user.dart';
import 'auth_controller.dart';

/// Proveedor inicial de tema del usuario para tests o inyecciones tempranas.
final userThemeInitialProvider = Provider<UserThemeSettings>(
  (ref) => const UserThemeSettings(),
);

/// Notificador que gestiona el tema global reactivo y persistente del usuario.
class UserThemeNotifier extends Notifier<UserThemeSettings> {
  bool _manuallySet = false;

  @override
  UserThemeSettings build() {
    final authUser = ref.watch(authControllerProvider).user;
    if (authUser != null && !_manuallySet) {
      return authUser.themeSettings;
    }
    return ref.watch(userThemeInitialProvider);
  }

  /// Actualiza sincrónica e inmutablemente el tema y lo persiste en SharedPreferences.
  Future<void> updateTheme(UserThemeSettings settings) async {
    _manuallySet = true;
    state = settings;
    await _persistTheme(settings);
  }

  Future<void> _persistTheme(UserThemeSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.themeColor, settings.primaryColor);
      if (settings.accentColor != null && settings.accentColor!.isNotEmpty) {
        await prefs.setString(StorageKeys.accentColor, settings.accentColor!);
      } else {
        await prefs.remove(StorageKeys.accentColor);
      }
      await prefs.setString(
        StorageKeys.cardStyle,
        settings.glassStyle.toValue(),
      );
    } catch (e) {
      debugPrint('[UserThemeNotifier] Error guardando tema en storage: $e');
    }
  }

  /// Carga valores de tema previamente persistidos localmente.
  Future<void> loadPersistedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final primary = prefs.getString(StorageKeys.themeColor);
      final accent = prefs.getString(StorageKeys.accentColor);
      final cardStyle = prefs.getString(StorageKeys.cardStyle);

      if (primary != null && primary.isNotEmpty) {
        _manuallySet = true;
        state = UserThemeSettings(
          primaryColor: primary,
          accentColor: accent?.isNotEmpty == true ? accent : null,
          glassStyle: GlassStyle.fromString(cardStyle),
        );
      }
    } catch (e) {
      debugPrint('[UserThemeNotifier] Error cargando tema persistido: $e');
    }
  }
}

/// Proveedor global del tema del usuario.
final userThemeProvider =
    NotifierProvider<UserThemeNotifier, UserThemeSettings>(
      UserThemeNotifier.new,
    );
