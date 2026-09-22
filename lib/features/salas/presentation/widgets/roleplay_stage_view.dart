import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/hexagon_avatar.dart';
import '../../../../models/role_character.dart';

/// Stage superior colapsable de Roleplay en vivo (Ref: Screenshot_20260731_112405).
class RoleplayStageView extends StatefulWidget {
  const RoleplayStageView({
    super.key,
    required this.roles,
    required this.onRoleTap,
    required this.onPlayTap,
    this.onAddRoleTap,
    this.onVacantSlotTap,
    this.onLeaveStageTap,
    this.isExpanded = false,
    this.onToggleExpanded,
    this.currentUserId,
    this.canPowerOff = false,
    this.onPowerOff,
    this.canManage = false,
    this.onOpenSettings,
  });

  final List<RoleCharacter> roles;
  final Function(RoleCharacter role) onRoleTap;
  final VoidCallback onPlayTap;
  final VoidCallback? onAddRoleTap;

  /// Callback para seleccionar y ocupar un slot vacante pasando su índice.
  final void Function(int? slotIndex)? onVacantSlotTap;
  final VoidCallback? onLeaveStageTap;

  /// Si el stage de roleplay se muestra expandido o minimizado.
  final bool isExpanded;
  final ValueChanged<bool>? onToggleExpanded;
  final String? currentUserId;

  /// Si el usuario local (host/admin) puede apagar la actividad de roleplay.
  final bool canPowerOff;

  /// Apaga la actividad: el padre emite `emitModeChange(roomId, 'standard')`.
  final VoidCallback? onPowerOff;

  /// Si el usuario tiene permisos de staff.
  final bool canManage;

  /// Abre la hoja modal de ajustes de roleplay para staff.
  final VoidCallback? onOpenSettings;

  @override
  State<RoleplayStageView> createState() => _RoleplayStageViewState();
}

class _RoleplayStageViewState extends State<RoleplayStageView> {
  late bool _expanded;
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isExpanded;
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(RoleplayStageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpanded != widget.isExpanded) {
      setState(() {
        _expanded = widget.isExpanded;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validRoles = widget.roles
        .where((r) => r.isValid)
        .toList();
    final allSlots = [
      for (int i = 0; i < validRoles.length; i++)
        _buildRoleItem(validRoles[i], slotIndex: i),
      _buildEmptySlot(slotIndex: validRoles.length),
    ];
    const int pageSize = 6;
    final totalPages = (allSlots.length / pageSize).ceil();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppColors.glassGradient,
        borderRadius: BorderRadius.circular(_expanded ? 20 : 16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header del Stage: 🎭 Roleplay ▶ + Expand/Collapse (Cero engranaje en Stage) ──
          Row(
            children: [
              Image.asset(
                AppAssets.iconRoleplay,
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 6),
              const Text(
                'Roleplay Stage',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (!_expanded && widget.roles.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD600).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFFFD600),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '${widget.roles.length} en escena',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFD600),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if ((widget.canPowerOff || widget.canManage) && widget.onOpenSettings != null) ...[
                GestureDetector(
                  onTap: widget.onOpenSettings,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      size: 16,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (widget.canPowerOff) ...[
                GestureDetector(
                  onTap: widget.onPowerOff,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0x22D50000),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD50000),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.power_settings_new_rounded,
                      size: 16,
                      color: Color(0xFFFF6B6B),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              GestureDetector(
                onTap: () {
                  final next = !_expanded;
                  setState(() => _expanded = next);
                  widget.onToggleExpanded?.call(next);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          if (_expanded) ...[
            const SizedBox(height: 12),

            // ── Grid / Paginación Horizontal (2 filas × 4 columnas por página) ──
            if (validRoles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _buildEmptySlot(slotIndex: 0),
              )
            else if (totalPages > 1)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Flecha Izquierda <
                      GestureDetector(
                        onTap: _currentPage > 0
                            ? () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            : null,
                        child: Container(
                          width: 24,
                          height: 60,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.chevron_left_rounded,
                            color: _currentPage > 0
                                ? Colors.white
                                : Colors.white24,
                            size: 24,
                          ),
                        ),
                      ),

                      // PageView 2x3 (6 por página)
                      Expanded(
                        child: SizedBox(
                          height: 204,
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (i) =>
                                setState(() => _currentPage = i),
                            itemCount: totalPages,
                            itemBuilder: (context, pageIndex) {
                              final start = pageIndex * pageSize;
                              final end = math.min(start + pageSize, allSlots.length);
                              final pageSlots = allSlots.sublist(start, end);

                              return Align(
                                alignment: Alignment.topCenter,
                                child: _buildPageGrid(pageSlots),
                              );
                            },
                          ),
                        ),
                      ),

                      // Flecha Derecha >
                      GestureDetector(
                        onTap: _currentPage < totalPages - 1
                            ? () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            : null,
                        child: Container(
                          width: 24,
                          height: 60,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: _currentPage < totalPages - 1
                                ? Colors.white
                                : Colors.white24,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),
                  // Dots indicadores
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(totalPages, (index) {
                      final isSelected = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isSelected ? 14 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentCyan
                              : const Color(0xFF332B4F),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ],
              )
            else
              _buildPageGrid(allSlots),

            const SizedBox(height: 12),

            // ── Controles Inferiores del Stage: [ ✋ Subir al Stage ] / [ 🎲 Tu Turno / Jugar ] + [ 🔻 Bajar ] ──
            _buildStageActionButtons(validRoles),
          ],
        ],
      ),
    );
  }

  Widget _buildPageGrid(List<Widget> slots) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (int i = 0; i < 3; i++)
              if (i < slots.length) slots[i] else const SizedBox(width: 68),
          ],
        ),
        if (slots.length > 3) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 3; i < 6; i++)
                if (i < slots.length) slots[i] else const SizedBox(width: 68),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStageActionButtons(List<RoleCharacter> validRoles) {
    final isOnStage = widget.currentUserId != null &&
        validRoles.any((r) =>
            r.takenByUserId == widget.currentUserId ||
            r.occupiedBy == widget.currentUserId ||
            r.id == widget.currentUserId);

    if (!isOnStage) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              // Gamefeel: impacto medio al unirse al stage (acción principal).
              HapticFeedback.mediumImpact();
              if (widget.onVacantSlotTap != null) {
                widget.onVacantSlotTap!(null);
              } else {
                widget.onAddRoleTap?.call();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.mintTurquoise,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentTeal.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Unirse',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: widget.onPlayTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: AppColors.mintTurquoise,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentTeal.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.casino_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'Tu Turno',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            if (widget.onVacantSlotTap != null) {
              widget.onVacantSlotTap!(null);
            } else {
              widget.onAddRoleTap?.call();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.accentCyan.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: AppColors.accentCyan, size: 16),
                SizedBox(width: 6),
                Text(
                  '+ Unirse',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accentCyan,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onLeaveStageTap?.call();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accentCrimson.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.accentCrimson.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: AppColors.accentCrimson,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'Bajar',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentCrimson,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleItem(RoleCharacter role, {required int slotIndex}) {
    final isVacant = !role.isTaken;
    final occupantName = role.takenByUsername ?? role.occupiedByName;
    return GestureDetector(
      key: ValueKey('slot_${slotIndex}_${role.id}'),
      onTap: () {
        HapticFeedback.selectionClick();
        if (isVacant && widget.onVacantSlotTap != null) {
          widget.onVacantSlotTap!(slotIndex);
        } else {
          widget.onRoleTap(role);
        }
      },
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                HexagonAvatar(
                  size: 54,
                  imageUrl: role.avatarUrl,
                  name: role.name,
                  borderColor: isVacant
                      ? role.color.withValues(alpha: 0.5)
                      : role.color,
                  borderWidth: 2,
                  hasActiveMic: role.hasActiveMic,
                ),
                // Badge de estado: vacante (＋) u ocupado (✓)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isVacant
                          ? const Color(0xFF1E1A2E)
                          : const Color(0xFF0F3A3A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isVacant ? Colors.white24 : AppColors.accentTeal,
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      isVacant ? Icons.add_rounded : Icons.check_rounded,
                      size: 11,
                      color: isVacant ? Colors.white54 : AppColors.accentTeal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Container(
              width: 68,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: isVacant
                    ? role.color.withValues(alpha: 0.15)
                    : role.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                role.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  height: 1.1,
                ),
              ),
            ),
            if (!isVacant && occupantName != null && occupantName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '@$occupantName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySlot({int? slotIndex}) {
    return GestureDetector(
      key: ValueKey('empty_slot_${slotIndex ?? -1}'),
      onTap: () {
        // Gamefeel: impacto medio al ocupar un slot "+ Unirse"
        HapticFeedback.mediumImpact();
        if (widget.onVacantSlotTap != null) {
          widget.onVacantSlotTap!(slotIndex);
        } else {
          widget.onAddRoleTap?.call();
        }
      },
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            HexagonAvatar(
              size: 54,
              isDashed: true,
              borderColor: AppColors.accentCyan.withValues(alpha: 0.6),
              borderWidth: 1.5,
              child: Container(
                color: const Color(0x2200E5FF),
                child: const Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: AppColors.accentCyan,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: 68,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accentCyan.withValues(alpha: 0.4),
                  width: 0.7,
                ),
              ),
              child: const Text(
                '+ Unirse',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accentCyan,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
