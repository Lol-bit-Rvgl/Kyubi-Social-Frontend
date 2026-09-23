import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/room_backgrounds.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/fullscreen_image_viewer.dart';
import '../../../../models/chat_message.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';
import 'conversation_controller.dart';
import 'conversations_controller.dart';
import 'widgets/chat_bubble.dart';

/// Pantalla detallada de información y gamificación del chat directo (DM).
class ConversationInfoScreen extends ConsumerStatefulWidget {
  const ConversationInfoScreen({
    super.key,
    required this.conversationId,
    this.onWallpaperChanged,
  });

  final String conversationId;
  final ValueChanged<String?>? onWallpaperChanged;

  static Future<void> show(
    BuildContext context, {
    required String conversationId,
    ValueChanged<String?>? onWallpaperChanged,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ConversationInfoScreen(
          conversationId: conversationId,
          onWallpaperChanged: onWallpaperChanged,
        ),
      ),
    );
  }

  @override
  ConsumerState<ConversationInfoScreen> createState() =>
      _ConversationInfoScreenState();
}

class _ConversationInfoScreenState extends ConsumerState<ConversationInfoScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _scaleAnim;
  Animation<double>? _glowAnim;
  String? _chatBgAsset;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );

    _glowAnim = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );

    _loadWallpaper();
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  Future<void> _loadWallpaper() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _chatBgAsset = prefs.getString('chat_bg_${widget.conversationId}');
      });
    } catch (_) {}
  }

  Future<void> _changeWallpaper() async {
    HapticFeedback.lightImpact();
    final selected = await showRoomBackgroundSelector(
      context,
      currentAsset: _chatBgAsset,
      title: 'Fondo del Chat',
    );
    if (selected != null) {
      final prefs = await SharedPreferences.getInstance();
      if (selected.id == 'default' || selected.assetPath.isEmpty) {
        await prefs.remove('chat_bg_${widget.conversationId}');
        if (mounted) setState(() => _chatBgAsset = null);
        widget.onWallpaperChanged?.call(null);
      } else {
        await prefs.setString(
          'chat_bg_${widget.conversationId}',
          selected.assetPath,
        );
        if (mounted) setState(() => _chatBgAsset = selected.assetPath);
        widget.onWallpaperChanged?.call(selected.assetPath);
      }
    }
  }

  int _calculateStreakFromMessages(List<Message> messages) {
    if (messages.isEmpty) return 0;
    final daysSet = <String>{};
    for (final m in messages) {
      if (m.isDeleted) continue;
      final d = m.createdAt.toLocal();
      daysSet.add(
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      );
    }
    if (daysSet.isEmpty) return 0;
    final now = DateTime.now();
    var current = DateTime(now.year, now.month, now.day);
    var checkStr =
        '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';

    if (!daysSet.contains(checkStr)) {
      current = current.subtract(const Duration(days: 1));
      checkStr =
          '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
      if (!daysSet.contains(checkStr)) {
        return 0;
      }
    }

    int streak = 0;
    while (daysSet.contains(checkStr)) {
      streak++;
      current = current.subtract(const Duration(days: 1));
      checkStr =
          '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
    }
    return streak;
  }

  double _calculateLevelProgress(int days, int level) {
    if (level >= 7 || days >= 360) return 1.0;
    final thresholds = [0, 1, 3, 15, 30, 60, 180, 360];
    if (level < 1 || level >= thresholds.length - 1) return 0.2;
    final currentMin = thresholds[level];
    final nextMin = thresholds[level + 1];
    final span = nextMin - currentMin;
    if (span <= 0) return 1.0;
    final progress = (days - currentMin) / span;
    return progress.clamp(0.08, 1.0);
  }

  void _confirmDeleteConversation() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF14141B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Eliminar conversación',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          '¿Deseas eliminar esta conversación? Los mensajes se borrarán de tu bandeja.',
          style: TextStyle(color: Color(0xFF9E9EA8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Color(0xFF7A7A8A)),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              _deleteConversation();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Eliminar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteConversation() async {
    final repo = ref.read(chatRepositoryProvider);
    final notifier = ref.read(conversationsControllerProvider.notifier);
    try {
      await repo.deleteConversation(widget.conversationId);
      notifier.removeConversation(widget.conversationId);
      if (!mounted) return;
      // Cerrar la pantalla de información
      Navigator.of(context).pop();
      // Si la pantalla anterior puede cerrarse (el DM), volver a la lista principal
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/app/messages');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar la conversación')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationChatProvider(widget.conversationId));
    final conversation = state.conversation;
    final currentUserId = ref.watch(authControllerProvider).user?.id ?? '';
    final currentUser = ref.watch(authControllerProvider).user;
    final other = (conversation != null)
        ? (conversation.resolveOtherMember(currentUserId) ??
            conversation.otherMember)
        : null;

    final displayName = (other != null && other.displayName.isNotEmpty)
        ? other.displayName
        : (other != null && other.username.isNotEmpty)
            ? other.username
            : (conversation?.displayName.isNotEmpty ?? false)
                ? conversation!.displayName
                : 'Usuario';
    final username = (other != null && other.username.isNotEmpty)
        ? other.username
        : 'usuario';
    final avatarUrl = other?.avatarUrl ?? conversation?.avatarUrl;
    final isOnline = other?.isOnline ?? false;

    // Gamificación: Racha y Nivel
    final rawStreak = conversation?.streakDays ?? 0;
    var streakDays = rawStreak > 0
        ? rawStreak
        : _calculateStreakFromMessages(state.messages);
    if (streakDays <= 0) {
      streakDays = 1; // Nivel 1 por defecto
    }

    final streakLevel =
        AppFriendshipIcons.levelForStreakDays(streakDays).clamp(1, 7);
    final streakIcon =
        AppFriendshipIcons.iconForStreakDays(streakDays) ??
        AppFriendshipIcons.level1;
    final streakTitle = AppFriendshipIcons.titleForLevel(streakLevel);
    final nextDays = AppFriendshipIcons.daysUntilNextLevel(streakDays);
    final levelProgress = _calculateLevelProgress(streakDays, streakLevel);

    // Multimedia compartida
    final sharedImages = <String>[];
    for (final m in state.messages) {
      if (m.isDeleted) continue;
      final url = m.media?.url ?? m.mediaUrl;
      if (url != null && url.isNotEmpty) {
        if (m.mediaType == 'image' ||
            DirectChatMessageBubble.isLikelyImageUrl(url)) {
          sharedImages.add(url);
        }
      } else if (m.body.startsWith('http') &&
          DirectChatMessageBubble.isLikelyImageUrl(m.body)) {
        sharedImages.add(m.body.trim());
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0912),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12101C),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Detalles del Chat',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── SECCIÓN A: CABECERA DE USUARIO & WALLPAPER ──────────────────
            _buildUserHeader(
              displayName: displayName,
              username: username,
              avatarUrl: avatarUrl,
              isOnline: isOnline,
              userId: other?.id ?? '',
            ),
            const SizedBox(height: 18),
            _buildWallpaperCard(),

            const SizedBox(height: 28),

            // ── SECCIÓN B: GAMIFICACIÓN (RACHA DE AMISTAD / NIVEL) ─────────
            _buildGamificationSection(
              streakDays: streakDays,
              streakLevel: streakLevel,
              streakIcon: streakIcon,
              streakTitle: streakTitle,
              nextDays: nextDays,
              levelProgress: levelProgress,
            ),

            const SizedBox(height: 28),

            // ── SECCIÓN C: MULTIMEDIA COMPARTIDA ────────────────────────────
            _buildMultimediaSection(sharedImages),

            const SizedBox(height: 28),

            // ── SECCIÓN D: PARTICIPANTES & ACCIONES ─────────────────────────
            _buildParticipantsSection(
              currentUser: currentUser,
              other: other,
              otherDisplayName: displayName,
              otherUsername: username,
              otherAvatarUrl: avatarUrl,
              otherIsOnline: isOnline,
            ),

            const SizedBox(height: 24),

            // Botón destructivo: Eliminar conversación
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _confirmDeleteConversation,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                label: const Text(
                  'Eliminar conversación',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.danger.withValues(alpha: 0.08),
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ── WIDGETS PRIVADOS DE APOYO ─────────────────────────────────────────────

  Widget _buildUserHeader({
    required String displayName,
    required String username,
    required String? avatarUrl,
    required bool isOnline,
    required String userId,
  }) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isOnline
                      ? AppColors.accentTeal
                      : const Color(0xFF382F56),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isOnline
                        ? AppColors.accentTeal.withValues(alpha: 0.35)
                        : const Color(0xFF6C5CE7).withValues(alpha: 0.25),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: AppAvatar(
                imageUrl: avatarUrl,
                name: displayName,
                radius: 46,
                showOnline: false,
              ),
            ),
            if (isOnline)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.accentTeal,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0A0912),
                      width: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          displayName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '@$username',
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white60,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (username.isNotEmpty) {
              context.push('/profile/$username');
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1A2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF3D325E), width: 0.8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFFA594F9),
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'Ver perfil completo',
                  style: TextStyle(
                    color: Color(0xFFA594F9),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWallpaperCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13111E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF26203D), width: 1),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF3B325A), width: 1),
              ),
              child: _chatBgAsset != null && _chatBgAsset!.isNotEmpty
                  ? Image.asset(
                      _chatBgAsset!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _defaultWallpaperPreview(),
                    )
                  : _defaultWallpaperPreview(),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fondo del chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Personaliza el wallpaper...',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _changeWallpaper,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFA594F9),
              side: const BorderSide(color: Color(0xFF6C5CE7)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text(
              'Cambiar',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultWallpaperPreview() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1035), Color(0xFF0F0A1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.wallpaper_rounded,
          color: Color(0xFFA594F9),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildGamificationSection({
    required int streakDays,
    required int streakLevel,
    required String streakIcon,
    required String streakTitle,
    required int? nextDays,
    required double levelProgress,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13111E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF26203D), width: 1),
      ),
      child: Column(
        children: [
          // Insignia Central Animada
          AnimatedBuilder(
            animation: _pulseController ?? const AlwaysStoppedAnimation(0),
            builder: (context, _) {
              final scale = _scaleAnim?.value ?? 1.0;
              final glow = _glowAnim?.value ?? 0.5;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFA594F9).withValues(alpha: 0.40 * glow),
                          const Color(0xFF6C5CE7).withValues(alpha: 0.15 * glow),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFA594F9).withValues(alpha: 0.35 * glow),
                            blurRadius: 18 * glow,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        streakIcon,
                        width: 86,
                        height: 86,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFFA594F9),
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Detalle del Nivel
          Text(
            'Racha de amistad: $streakDays ${streakDays == 1 ? "día" : "días"} (Nivel $streakLevel) — $streakTitle',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),

          // Tarjeta de progreso
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0E17),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF231E35), width: 0.8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$streakDays ${streakDays == 1 ? "día consecutivo" : "días consecutivos"} enviándose mensajes',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (nextDays != null) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        color: Color(0xFF5BC8AF),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Faltan $nextDays ${nextDays == 1 ? "día" : "días"} para desbloquear el Nivel ${streakLevel + 1}',
                          style: const TextStyle(
                            color: Color(0xFF5BC8AF),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: levelProgress,
                      minHeight: 7,
                      backgroundColor: const Color(0xFF26203D),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF5BC8AF),
                      ),
                    ),
                  ),
                ] else ...[
                  const Row(
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFFFFD700),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '¡Han alcanzado el nivel máximo de amistad!',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: const LinearProgressIndicator(
                      value: 1.0,
                      minHeight: 7,
                      backgroundColor: Color(0xFF26203D),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFD700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultimediaSection(List<String> sharedImages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Multimedia',
          badgeText: sharedImages.isNotEmpty ? '${sharedImages.length}' : null,
        ),
        const SizedBox(height: 12),
        if (sharedImages.isNotEmpty)
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sharedImages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final url = sharedImages[index];
                return GestureDetector(
                  onTap: () => showFullscreenImage(context, url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 96,
                      height: 96,
                      color: const Color(0xFF13111E),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFA594F9),
                          ),
                        ),
                        errorWidget: (_, _, _) => const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white24,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF13111E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF26203D), width: 0.8),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  color: Colors.white24,
                  size: 32,
                ),
                SizedBox(height: 8),
                Text(
                  'No hay fotos compartidas',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildParticipantsSection({
    required dynamic currentUser,
    required ChatAuthor? other,
    required String otherDisplayName,
    required String otherUsername,
    required String? otherAvatarUrl,
    required bool otherIsOnline,
  }) {
    final myDisplayName = (currentUser?.displayName?.isNotEmpty ?? false)
        ? currentUser!.displayName
        : (currentUser?.username?.isNotEmpty ?? false)
            ? currentUser!.username
            : 'Tú';
    final myUsername = currentUser?.username ?? 'yo';
    final myAvatarUrl = currentUser?.avatarUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title: 'Participantes', badgeText: '2'),
        const SizedBox(height: 12),
        Row(
          children: [
            // Participante 1: Yo
            Expanded(
              child: _buildParticipantCard(
                displayName: myDisplayName,
                username: myUsername,
                avatarUrl: myAvatarUrl,
                badgeLabel: 'Tú',
                isOnline: true,
                onTap: () {
                  if (myUsername.isNotEmpty) {
                    context.push('/profile/$myUsername');
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            // Participante 2: Destinatario
            Expanded(
              child: _buildParticipantCard(
                displayName: otherDisplayName,
                username: otherUsername,
                avatarUrl: otherAvatarUrl,
                badgeLabel: null,
                isOnline: otherIsOnline,
                onTap: () {
                  if (otherUsername.isNotEmpty) {
                    context.push('/profile/$otherUsername');
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildParticipantCard({
    required String displayName,
    required String username,
    required String? avatarUrl,
    required String? badgeLabel,
    required bool isOnline,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF13111E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF26203D), width: 1),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppAvatar(
                  imageUrl: avatarUrl,
                  name: displayName,
                  radius: 26,
                  showOnline: false,
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF13111E),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (badgeLabel != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2447),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
                        color: Color(0xFFA594F9),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '@$username',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? badgeText,
  }) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFFA594F9),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA594F9).withValues(alpha: 0.5),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        if (badgeText != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF231E38),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF3B325A), width: 0.8),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                color: Color(0xFFA594F9),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
