import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/storage_keys.dart';

/// Valor inicial del modo de tema (se sobreescribe en `main`).
final themeModeInitialProvider = Provider<ThemeMode>((ref) => ThemeMode.dark);

/// Controla el modo de tema (oscuro/claro/sistema).
class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(themeModeInitialProvider);

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.themeMode, mode.name);
  }
}

Future<ThemeMode> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(StorageKeys.themeMode);
  for (final mode in ThemeMode.values) {
    if (mode.name == raw) return mode;
  }
  return ThemeMode.dark;
}

final themeControllerProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);
