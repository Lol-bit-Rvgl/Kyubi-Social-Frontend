import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_avatar.dart';
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
  final Set<String> _selectedCircleIds = {};
  final Set<String> _joinedCircleIds = {};
  final Set<String> _recommendedCircleIds = {};

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
      _loadCircles(force: true);
    } else {
      await _finish();
    }
  }

  void _goBack() {
    if (_step > 0) _goToStep(_step - 1);
  }

  Future<void> _loadCircles({bool force = false}) async {
    if (!force && (_circles.isNotEmpty || _loadingCircles)) return;
    setState(() => _loadingCircles = true);
    try {
      final circles = await ref
          .read(circleRepositoryProvider)
          .getCircles(limit: 50);

      final normalizedInterests = _interests
          .map((i) => i.trim().toLowerCase())
          .where((i) => i.isNotEmpty)
          .toSet();

      int scoreCircle(Circle c) {
        if (normalizedInterests.isEmpty) return 0;
        int score = 0;
        final name = c.name.toLowerCase();
        final desc = (c.description ?? '').toLowerCase();
        final tags = c.tags.map((t) => t.toLowerCase()).toList();

        for (final interest in normalizedInterests) {
          if (tags.any((t) => t.contains(interest) || interest.contains(t))) {
            score += 4;
          } else if (name.contains(interest)) {
            score += 3;
          } else if (desc.contains(interest)) {
            score += 1;
          }
        }
        return score;
      }

      final matching = <Circle>[];
      final others = <Circle>[];

      for (final c in circles) {
        if (scoreCircle(c) > 0) {
          matching.add(c);
        } else {
          others.add(c);
        }
      }

      matching.sort((a, b) {
        final scoreDiff = scoreCircle(b).compareTo(scoreCircle(a));
        if (scoreDiff != 0) return scoreDiff;
        return b.memberCount.compareTo(a.memberCount);
      });

      others.sort((a, b) => b.memberCount.compareTo(a.memberCount));

      final ranked = [...matching, ...others].take(20).toList();
      final recommendedIds = matching.map((c) => c.id).toSet();

      if (mounted) {
        setState(() {
          _circles = ranked;
          _recommendedCircleIds.clear();
          _recommendedCircleIds.addAll(recommendedIds);
          // Pre-seleccionar recomendaciones directas (hasta 4)
          final topRecommendations = matching.take(4).map((c) => c.id);
          _selectedCircleIds.addAll(topRecommendations);
        });
      }
    } catch (_) {
      // Silently fail – el usuario puede continuar u omitir
    } finally {
      if (mounted) setState(() => _loadingCircles = false);
    }
  }

  void _toggleCircle(Circle circle) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedCircleIds.contains(circle.id)) {
        _selectedCircleIds.remove(circle.id);
      } else {
        _selectedCircleIds.add(circle.id);
      }
    });
  }

  Future<void> _finish() async {
    setState(() => _submitting = true);
    final authState = ref.read(authControllerProvider);
    final authNotifier = ref.read(authControllerProvider.notifier);
    final circleRepo = ref.read(circleRepositoryProvider);

    try {
      // Unirse en lote a los círculos seleccionados
      final toJoin = _selectedCircleIds
          .where((id) => !_joinedCircleIds.contains(id))
          .toList();
      if (toJoin.isNotEmpty) {
        await Future.wait(
          toJoin.map(
            (id) => circleRepo
                .joinCircle(id)
                .then((_) {
                  _joinedCircleIds.add(id);
                })
                .catchError((_) {
                  // Tolerar fallas puntuales para no trabar el onboarding
                }),
          ),
        );
      }

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

  Future<void> _skipCirclesAndFinish() async {
    _selectedCircleIds.clear();
    await _finish();
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
              final isSelected = _selectedCircleIds.contains(circle.id) ||
                  _joinedCircleIds.contains(circle.id) ||
                  circle.isMember;
              final isRecommended = _recommendedCircleIds.contains(circle.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.sm),
                child: _CircleDiscoveryCard(
                  circle: circle,
                  selected: isSelected,
                  isRecommended: isRecommended,
                  onToggle: () => _toggleCircle(circle),
                ),
              );
            }),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: _skipCirclesAndFinish,
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
    required this.selected,
    required this.onToggle,
    this.isRecommended = false,
  });

  final Circle circle;
  final bool selected;
  final VoidCallback onToggle;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBorderColor = AppColors.accentTeal;
    final idleBorderColor =
        isDark ? const Color(0xFF2C2544) : const Color(0xFFE2E2EC);
    final cardBgColor = selected
        ? (isDark ? const Color(0xFF16242A) : const Color(0xFFE6F7F7))
        : (isDark ? const Color(0xFF151124) : Colors.white);

    final description = (circle.description?.trim().isNotEmpty == true)
        ? circle.description!.trim()
        : 'Comunidad para compartir y conectar en Kyubi.';

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? activeBorderColor : idleBorderColor,
          width: selected ? 1.6 : 1.0,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.accentTeal.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppAvatar(
                  imageUrl: circle.avatarUrl,
                  name: circle.name,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              circle.name,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentTeal.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.accentTeal.withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'Para ti',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentTeal,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF9E9EA8)
                              : const Color(0xFF6B6A78),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.people_alt_rounded,
                            size: 13,
                            color: isDark
                                ? const Color(0xFF7A788A)
                                : const Color(0xFF8A889A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${circle.memberCount} ${circle.memberCount == 1 ? 'miembro' : 'miembros'}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFF7A788A)
                                  : const Color(0xFF8A889A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.accentTeal : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? AppColors.accentTeal
                          : (isDark
                              ? const Color(0xFF534C69)
                              : const Color(0xFFB0AFC0)),
                      width: selected ? 0 : 1.8,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Color(0xFF0F1A1E),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
