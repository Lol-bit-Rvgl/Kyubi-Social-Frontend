import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';
import '../../messages/presentation/conversations_controller.dart';
import 'matchmaking_controller.dart';

/// Pantalla inmersiva de Matchmaking Aleatorio (Ref: Requisito 3).
/// Fondo oscuro con radar/pulso cian y carmesí, búsqueda activa y transición
/// fluida de match. Conectada a una cola real de Socket.IO (`match:start` /
/// `match:found` / `match:none`) controlada por [matchmakingControllerProvider].
class MatchmakingScreen extends ConsumerStatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _radarController;
  late final AnimationController _matchFoundController;

  Timer? _cosmeticTimer;
  int _secondsElapsed = 0;
  int _statusTextIndex = 0;
  String _selectedCategory = '🎭 Roleplay';

  bool _openingChat = false;

  final List<String> _categories = [
    '🎭 Roleplay',
    '💬 Casual',
    '🎌 Anime',
    '🎮 Gaming',
    '🎨 Arte',
  ];

  final List<String> _statusTexts = [
    'Buscando a alguien compatible...',
    'Sintonizando frecuencias del Kubi-Space...',
    'Escaneando usuarios afines en vivo...',
    'Calculando compatibilidad de intereses...',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _matchFoundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _startCosmeticTimer();
    // Inicia la búsqueda en cuanto abres la pantalla.
    Future.microtask(() {
      if (mounted) {
        ref
            .read(matchmakingControllerProvider.notifier)
            .startSearch(_selectedCategory);
      }
    });
  }

  @override
  void dispose() {
    _cosmeticTimer?.cancel();
    _pulseController.dispose();
    _radarController.dispose();
    _matchFoundController.dispose();
    ref.read(matchmakingControllerProvider.notifier).cancel();
    super.dispose();
  }

  void _startCosmeticTimer() {
    _cosmeticTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _secondsElapsed++;
        if (_secondsElapsed % 3 == 0) {
          _statusTextIndex = (_statusTextIndex + 1) % _statusTexts.length;
        }
      });
    });
  }

  void _selectCategory(String category) {
    if (category == _selectedCategory) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedCategory = category);
    ref.read(matchmakingControllerProvider.notifier).startSearch(category);
  }

  Future<void> _startDirectChat(
    Map<String, dynamic> peer, {
    String? conversationId,
  }) async {
    if (_openingChat) return;
    HapticFeedback.selectionClick();
    setState(() => _openingChat = true);

    try {
      if (conversationId != null && conversationId.isNotEmpty) {
        if (!mounted) return;
        context.pushReplacement('/conversation/$conversationId');
        return;
      }

      final chat = ref.read(chatRepositoryProvider);
      final conversation = await chat.openOrCreateDirect(
        peer['id'] as String,
        username: peer['username'] as String? ?? '',
      );

      if (!mounted) return;
      ref
          .read(conversationsControllerProvider.notifier)
          .upsertConversation(conversation);

      context.pushReplacement('/conversation/${conversation.id}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _openingChat = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iniciando sala privada de chat...')),
      );
    }
  }

  void _closeScreen() {
    HapticFeedback.selectionClick();
    ref.read(matchmakingControllerProvider.notifier).cancel();
    Navigator.pop(context);
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MatchState>(matchmakingControllerProvider, (prev, next) {
      if (next.status == MatchStatus.matched &&
          prev?.status != MatchStatus.matched &&
          mounted) {
        HapticFeedback.heavyImpact();
        _matchFoundController.forward(from: 0.0);
      }
    });

    final match = ref.watch(matchmakingControllerProvider);
    final myUser = ref.watch(authControllerProvider).user;
    final myAvatarUrl = myUser?.effectiveAvatarUrl;
    final myName = myUser?.displayName ?? 'Tú';

    final isMatched = match.status == MatchStatus.matched;
    final isNoResult =
        match.status == MatchStatus.timeout ||
        match.status == MatchStatus.error;

    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Fondo de degradado radial oscuro ──
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    Color(0xFF161224),
                    Color(0xFF0F0D1A),
                    AppColors.backgroundBase,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top Bar con Salir y Categorías ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                        ),
                        onPressed: _closeScreen,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Kyubi Match',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1A2E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accentCyan.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 13,
                              color: AppColors.accentCyan,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTimer(_secondsElapsed),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accentCyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Selector de categoría temática (solo durante la búsqueda)
                if (!isMatched && !isNoResult)
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat;

                        return GestureDetector(
                          onTap: () => _selectCategory(cat),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accentCrimson
                                  : const Color(0xFF181524),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accentCrimson
                                    : const Color(0xFF28233C),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF9E9EA8),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const Spacer(),

                // ── Contenido Central: Radar / Match / Sin resultados ──
                if (isMatched)
                  _buildMatchFoundView(match.peer ?? const {})
                else if (isNoResult)
                  _buildNoMatchView(match.error)
                else
                  _buildSearchingView(myAvatarUrl, myName),

                const Spacer(),

                // ── Botón Inferior de Acción ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: _buildBottomAction(
                    isMatched,
                    isNoResult,
                    match.peer,
                    conversationId: match.conversationId,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(
    bool isMatched,
    bool isNoResult,
    Map<String, dynamic>? peer, {
    String? conversationId,
  }) {
    if (isMatched) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _startDirectChat(
                peer ?? const {},
                conversationId: conversationId,
              ),
              icon: _openingChat
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.chat_bubble_rounded, size: 18),
              label: Text(
                _openingChat ? 'Conectando...' : 'Iniciar Chat Privado 🚀',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentCrimson,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () =>
                ref.read(matchmakingControllerProvider.notifier).retry(),
            child: const Text(
              '🔄 Buscar a otra persona',
              style: TextStyle(
                color: Color(0xFF9E9EA8),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    if (isNoResult) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () =>
              ref.read(matchmakingControllerProvider.notifier).retry(),
          icon: const Icon(
            Icons.refresh_rounded,
            size: 16,
            color: AppColors.accentCyan,
          ),
          label: const Text(
            '🔄 Reintentar Búsqueda',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.accentCyan,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0x6600E5FF), width: 0.9),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _closeScreen,
        icon: const Icon(
          Icons.close_rounded,
          size: 16,
          color: Color(0xFFFF5252),
        ),
        label: const Text(
          'Cancelar Búsqueda',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFFFF5252),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0x66FF5252), width: 0.9),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ── Vista de Búsqueda con Radar y Pulso Neón ──────────────────────────────

  Widget _buildSearchingView(String? avatarUrl, String name) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildPulseWave(1.0, 0.45, AppColors.accentCyan),
                      _buildPulseWave(0.66, 0.60, AppColors.accentCrimson),
                      _buildPulseWave(0.33, 0.75, AppColors.accentPurple),
                    ],
                  );
                },
              ),

              AnimatedBuilder(
                animation: _radarController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _radarController.value * 2 * math.pi,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          center: Alignment.center,
                          colors: [
                            Colors.transparent,
                            AppColors.accentCyan.withValues(alpha: 0.25),
                          ],
                          stops: const [0.75, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              ),

              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.accentCrimson, AppColors.accentCyan],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentCyan.withValues(alpha: 0.6),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2.5),
                child: AppAvatar(imageUrl: avatarUrl, name: name, radius: 35),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Text(
          _statusTexts[_statusTextIndex],
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Filtro: $_selectedCategory',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.accentCyan,
          ),
        ),
      ],
    );
  }

  Widget _buildPulseWave(double phaseOffset, double maxRadius, Color color) {
    final progress = (_pulseController.value + phaseOffset) % 1.0;
    final size = 80.0 + (progress * 170.0);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity * 0.7),
          width: 1.2,
        ),
      ),
    );
  }

  // ── Vista de Match Encontrado (Transición Fluida) ─────────────────────────

  Widget _buildMatchFoundView(Map<String, dynamic> peer) {
    final displayName = peer['displayName'] as String? ?? 'Nuevo amigo';
    final username = peer['username'] as String? ?? '';
    final avatarUrl = peer['avatarUrl'] as String?;
    final level = peer['level'] as int? ?? 1;
    final bio = peer['bio'] as String? ?? '';
    final interests =
        (peer['interests'] as List?)?.cast<String>() ?? <String>[];
    final compatibility = 88 + (level % 11);

    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _matchFoundController,
        curve: Curves.elasticOut,
      ),
      child: FadeTransition(
        opacity: _matchFoundController,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161226),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.accentCyan.withValues(alpha: 0.7),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentCyan.withValues(alpha: 0.25),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF6D00)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: Colors.black,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '¡MATCH ENCONTRADO!',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF007F), Color(0xFF00E5FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentCrimson.withValues(alpha: 0.4),
                      blurRadius: 18,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const ColoredBox(
                            color: Color(0xFF2A2342),
                            child: Icon(
                              Icons.person_rounded,
                              color: Colors.white70,
                              size: 40,
                            ),
                          ),
                        )
                      : const ColoredBox(
                          color: Color(0xFF2A2342),
                          child: Icon(
                            Icons.person_rounded,
                            color: Colors.white70,
                            size: 40,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                username.isNotEmpty ? '@$username' : '',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accentCyan.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '⚡ $compatibility% Compatible',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentCyan,
                  ),
                ),
              ),

              if (bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  bio,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFFC0BECE),
                  ),
                ),
              ],

              if (interests.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  alignment: WrapAlignment.center,
                  children: interests.map((i) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF221C34),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$i',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD6D4E6),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Vista de "No encontrado" (timeout / cola vacía) ──────────────────────

  Widget _buildNoMatchView([String? error]) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF161226),
            border: Border.all(color: const Color(0xFF2E2746), width: 1),
          ),
          child: const Icon(
            Icons.sentiment_dissatisfied_rounded,
            size: 48,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          error ??
              'No encontramos a nadie disponible en este momento. ¡Intenta de nuevo más tarde!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Intenta de nuevo en un momento o cambia de categoría',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
