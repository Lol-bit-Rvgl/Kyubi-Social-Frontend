import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../models/circle.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';

const _interestSuggestions = [
  'Música',
  'Arte',
  'Tecnología',
  'Gaming',
  'Cine',
  'Anime',
  'Fitness',
  'Cocina',
  'Viajes',
  'Fotografía',
  'Libros',
  'Moda',
  'Deportes',
  'Ciencia',
  'Naturaleza',
  'Negocios',
];

/// Onboarding inicial del usuario (3 pasos: género, intereses, círculos).
/// El nombre y usuario ya se recogen en RegisterScreen.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  String? _gender;
  final Set<String> _interests = {};
  int _step = 0;
  bool _submitting = false;

  // Circle discovery state
  List<Circle> _circles = [];
  bool _loadingCircles = false;
  final Set<String> _joinedCircleIds = {};

  // Pulsing animation for tutorial hint
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const _totalSteps = 3;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_step == 0) {
      if (_gender == null) {
        _snack('Selecciona una opción');
        return;
      }
      _goToStep(1);
    } else if (_step == 1) {
      _goToStep(2);
      _loadCircles();
    } else {
      await _finish();
    }
  }

  void _goBack() {
    if (_step > 0) _goToStep(_step - 1);
  }

  Future<void> _loadCircles() async {
    if (_circles.isNotEmpty || _loadingCircles) return;
    setState(() => _loadingCircles = true);
    try {
      final circles = await ref
          .read(circleRepositoryProvider)
          .getCircles(limit: 3);
      if (mounted) setState(() => _circles = circles);
    } catch (_) {
      // Silently fail – the user can skip this step
    } finally {
      if (mounted) setState(() => _loadingCircles = false);
    }
  }

  Future<void> _joinCircle(Circle circle) async {
    if (_joinedCircleIds.contains(circle.id)) return;
    try {
      await ref.read(circleRepositoryProvider).joinCircle(circle.id);
      if (mounted) {
        setState(() {
          _joinedCircleIds.add(circle.id);
          _circles = _circles
              .map((c) => c.id == circle.id ? c.copyWith(isMember: true) : c)
              .toList();
        });
      }
    } catch (_) {
      _snack('No se pudo unir al círculo');
    }
  }

  Future<void> _finish() async {
    setState(() => _submitting = true);
    final authState = ref.read(authControllerProvider);
    final authNotifier = ref.read(authControllerProvider.notifier);
    try {
      final user = await ref
          .read(userRepositoryProvider)
          .completeOnboarding(
            username: authState.user?.username ?? '',
            displayName: authState.user?.displayName ?? '',
            gender: _gender,
            interests: _interests.toList(),
            onboardingCompleted: true,
          );
      authNotifier.updateUser(user);
      if (mounted) context.go('/app/feed');
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo completar el perfil. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
    setState(() => _step = step);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleInterest(String value) {
    setState(() {
      if (_interests.contains(value)) {
        _interests.remove(value);
      } else {
        _interests.add(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu perfil'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _goBack,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: AppDimens.pagePadding,
              child: LinearProgressIndicator(
                value: (_step + 1) / _totalSteps,
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStepOne(scheme),
                  _buildStepTwo(scheme),
                  _buildStepThree(scheme),
                ],
              ),
            ),
            Padding(
              padding: AppDimens.pagePadding,
              child: AppButton(
                label: _step == 2 ? 'Empezar' : 'Continuar',
                icon: _step == 2 ? Icons.rocket_launch_rounded : null,
                loading: _submitting,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepOne(ColorScheme scheme) {
    return SingleChildScrollView(
      padding: AppDimens.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu género',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Puedes ocultarlo más tarde en la configuración.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                ['Masculino', 'Femenino', 'No binario', 'Prefiero no decir']
                    .map(
                      (option) => ChoiceChip(
                        label: Text(option),
                        selected: _gender == option,
                        onSelected: (_) => setState(() => _gender = option),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTwo(ColorScheme scheme) {
    return SingleChildScrollView(
      padding: AppDimens.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tus intereses',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Elige al menos uno para personalizar tu feed.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _interestSuggestions
                .map(
                  (interest) => FilterChip(
                    label: Text(interest),
                    selected: _interests.contains(interest),
                    onSelected: (_) => _toggleInterest(interest),
                    selectedColor: AppColors.primary.withValues(alpha: 0.25),
                    checkmarkColor: AppColors.primary,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepThree(ColorScheme scheme) {
    return SingleChildScrollView(
      padding: AppDimens.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Descubre tu lado oscuro',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Únete a círculos de tu interés',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          if (_loadingCircles)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_circles.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  'No se encontraron círculos en este momento.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...List.generate(_circles.length, (i) {
              final circle = _circles[i];
              final joined =
                  _joinedCircleIds.contains(circle.id) || circle.isMember;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.sm),
                child: _CircleDiscoveryCard(
                  circle: circle,
                  joined: joined,
                  onJoin: () => _joinCircle(circle),
                ),
              );
            }),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: _finish,
              child: Text(
                'Omitir',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Tutorial hint: pulsing indicator
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(opacity: _pulseAnimation.value, child: child);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.md,
                  vertical: AppDimens.xs,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.group_work_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppDimens.xs),
                    Text(
                      'Los círculos están en la barra inferior',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleDiscoveryCard extends StatelessWidget {
  const _CircleDiscoveryCard({
    required this.circle,
    required this.joined,
    required this.onJoin,
  });

  final Circle circle;
  final bool joined;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        gradient: AppColors.accentGradient,
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd - 1),
        ),
        padding: const EdgeInsets.all(AppDimens.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.brandGradient,
              ),
              child: Center(
                child: Text(
                  circle.name.isNotEmpty ? circle.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    circle.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      '${circle.memberCount} miembros',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            joined
                ? Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 28,
                  )
                : FilledButton.tonal(
                    onPressed: onJoin,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.md,
                        vertical: AppDimens.xs,
                      ),
                    ),
                    child: const Text('Unirse'),
                  ),
          ],
        ),
      ),
    );
  }
}
