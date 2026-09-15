import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user.dart';

/// Nombre del rango según el nivel, reemplazando la lógica local duplicada
/// en las pantallas de perfil.
String rankTitleForLevel(int level) {
  if (level >= 20) return 'Leyenda';
  if (level >= 16) return 'Campeón';
  if (level >= 11) return 'Especialista';
  if (level >= 6) return 'Aventurero';
  return 'Novato';
}

/// Métricas de actividad del perfil derivadas del [User].
///
/// Exponen `level`, `levelName`, `streakDays`, `profileViews` y
/// `followersCount` de forma centralizada.
class ProfileMetrics {
  const ProfileMetrics({
    required this.level,
    required this.levelName,
    required this.streakDays,
    required this.profileViews,
    required this.followersCount,
  });

  factory ProfileMetrics.fromUser(User user) {
    final level = user.level;
    final rawStreak = user.extensions?['streakDays'];
    final streakDays = rawStreak is num ? rawStreak.toInt() : level * 2 + 3;
    return ProfileMetrics(
      level: level,
      levelName: rankTitleForLevel(level),
      streakDays: streakDays,
      profileViews: user.profileViews,
      followersCount: user.followersCount,
    );
  }

  final int level;
  final String levelName;
  final int streakDays;
  final int profileViews;
  final int followersCount;

  @Deprecated('Use levelName instead')
  String get levelTitle => levelName;
}

/// Métricas del perfil de un usuario (propio o visitado).
final profileMetricsProvider = Provider.family<ProfileMetrics, User>((
  ref,
  user,
) {
  return ProfileMetrics.fromUser(user);
});
