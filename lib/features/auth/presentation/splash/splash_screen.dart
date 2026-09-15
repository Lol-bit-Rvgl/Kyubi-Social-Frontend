import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/kyubi_blob.dart';
import '../../../../core/widgets/kyubi_logo.dart';
import '../../../../services/auth_controller.dart';

/// Pantalla de arranque: restaura la sesión si existe.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (_started) return;
    _started = true;
    // Pequeña pausa para la animación del logo.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await ref.read(authControllerProvider.notifier).restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    // Cuando la sesión termina de restaurarse, la navegación se redirige sola.
    if (auth.status != AuthStatus.unknown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final isAuthed = auth.isAuthenticated;
        final onboardingDone = auth.user?.onboardingCompleted ?? false;
        if (isAuthed && !onboardingDone) {
          context.go('/onboarding');
        } else if (isAuthed) {
          context.go('/app/feed');
        } else {
          context.go('/login');
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.ink900,
      body: Stack(
        children: [
          // Resplandor de marca para identidad visual.
          Positioned(
            top: -140,
            left: -100,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -160,
            right: -120,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryDark.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Cola orgánica discreta (lenguaje visual Kyubi).
          Positioned(
            right: -10,
            bottom: 36,
            child: KyubiBlob(
              size: 120,
              color: AppColors.primary.withValues(alpha: 0.10),
              tail: true,
            ),
          ),
          Positioned(
            left: -24,
            top: 90,
            child: KyubiBlob(
              size: 80,
              color: AppColors.primaryDark.withValues(alpha: 0.12),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: const KyubiLogo(
                    size: 90,
                    withWordmark: true,
                    wordmarkSize: 30,
                  ),
                ),
                const SizedBox(height: AppDimens.xxl),
                Text(
                  'Comparte, conecta, crea',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: AppDimens.xxl),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          // Atribución de identidad.
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: Text(
                'DESARROLLADO POR ${AppConstants.companyName.toUpperCase()}',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
