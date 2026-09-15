import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';

/// Menú lateral de configuración de un chat/sala (•••).
///
/// Incluye Tags (`#Add a Tag`), Círculos vinculados, Notificaciones, Color de
/// Burbuja, `Pin to My Chats` y el botón inferior para abandonar la sala.
/// A proposito NO incluye ninguna opción de "Search Chat History".
class ChatSettingsSheet extends StatefulWidget {
  const ChatSettingsSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.avatarUrl,
    this.avatarName,
    required this.tags,
    this.canEdit = true,
    this.onAddTag,
    this.onRemoveTag,
    required this.linkedCircles,
    this.onLinkCircle,
    required this.notificationsEnabled,
    required this.onToggleNotifications,
    required this.bubbleColor,
    required this.onBubbleColor,
    required this.pinned,
    required this.onTogglePinned,
    required this.onLeave,
    this.leaveLabel = 'Leave This Party / Leave Room',
  });

  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final String? avatarName;

  /// Etiquetas del chat (leídas del estado; editables solo para admins).
  final List<String> tags;
  final bool canEdit;
  final ValueChanged<String>? onAddTag;
  final ValueChanged<String>? onRemoveTag;

  /// Nombres de los círculos vinculados.
  final List<String> linkedCircles;
  final VoidCallback? onLinkCircle;

  final bool notificationsEnabled;
  final VoidCallback onToggleNotifications;

  final Color? bubbleColor;
  final ValueChanged<Color> onBubbleColor;

  final bool pinned;
  final VoidCallback onTogglePinned;

  final VoidCallback onLeave;
  final String leaveLabel;

  @override
  State<ChatSettingsSheet> createState() => _ChatSettingsSheetState();
}

class _ChatSettingsSheetState extends State<ChatSettingsSheet> {
  late List<String> _tags = List.of(widget.tags);
  late bool _pinned = widget.pinned;
  late bool _notifications = widget.notificationsEnabled;
  late Color? _bubbleColor = widget.bubbleColor;

  static const _palette = <Color?>[
    Color(0xFF00E5FF),
    Color(0xFFA594F9),
    Color(0xFFA855F7),
    AppColors.accentTeal,
    Color(0xFFFFB300),
    Colors.white,
  ];

  void _addTag() {
    if (widget.onAddTag == null) return;
    final controller = TextEditingController();
    showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1626),
            title: const Text(
              'Add a Tag',
              style: TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: '#Roleplay',
                hintStyle: TextStyle(color: Color(0xFF7A7A8E)),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                Navigator.pop(ctx, v.trim());
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3B2D60),
                ),
                child: const Text('Agregar'),
              ),
            ],
          ),
        )
        .then((value) {
          if (value == null || value.isEmpty) return;
          widget.onAddTag!(value);
          setState(() => _tags = [..._tags, '#${value.replaceAll('#', '')}']);
        })
        .whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13101E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Encabezado del chat ──
            Row(
              children: [
                AppAvatar(
                  imageUrl: widget.avatarUrl,
                  name: widget.avatarName ?? widget.title,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.subtitle != null &&
                          widget.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2E2744), height: 1),

            // ── Notificaciones ──
            _switchRow(
              icon: Icons.notifications_rounded,
              iconColor: const Color(0xFFFFB300),
              label: 'Notificaciones',
              value: _notifications,
              onChanged: (v) {
                setState(() => _notifications = v);
                widget.onToggleNotifications();
              },
            ),

            // ── Pin to My Chats ──
            _switchRow(
              icon: Icons.push_pin_rounded,
              iconColor: AppColors.accentCyan,
              label: 'Pin to My Chats',
              value: _pinned,
              onChanged: (v) {
                setState(() => _pinned = v);
                widget.onTogglePinned();
              },
            ),

            const SizedBox(height: 8),
            const Divider(color: Color(0xFF2E2744), height: 1),
            const SizedBox(height: 14),

            // ── Color de Burbuja ──
            const _SectionLabel('Bubble Color'),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final color in _palette) ...[
                  GestureDetector(
                    onTap: () {
                      final next = color ?? AppColors.accentCyan;
                      setState(() => _bubbleColor = next);
                      widget.onBubbleColor(next);
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(
                          color: _bubbleColor == color
                              ? Colors.white
                              : Colors.black38,
                          width: 2.5,
                        ),
                        boxShadow: _bubbleColor == color
                            ? [
                                BoxShadow(
                                  color: (color ?? Colors.white).withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: _bubbleColor == color
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.black,
                            )
                          : null,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2E2744), height: 1),
            const SizedBox(height: 14),

            // ── Tags (#Add a Tag) ──
            Row(
              children: [
                const _SectionLabel('#Tags'),
                const Spacer(),
                if (widget.canEdit)
                  _addLinkButton(label: 'Add a Tag', onTap: () => _addTag()),
              ],
            ),
            const SizedBox(height: 10),
            if (_tags.isEmpty)
              const Text(
                'Sin etiquetas todavía. Agrégalas para ordenar el chat.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.accentCyan.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentCyan,
                            ),
                          ),
                          if (widget.canEdit && widget.onRemoveTag != null) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() => _tags.remove(tag));
                                widget.onRemoveTag!(tag);
                              },
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2E2744), height: 1),
            const SizedBox(height: 14),

            // ── Linked Circles ──
            Row(
              children: [
                const _SectionLabel('Linked Circles'),
                const Spacer(),
                if (widget.canEdit)
                  _addLinkButton(label: 'Link', onTap: widget.onLinkCircle),
              ],
            ),
            const SizedBox(height: 10),
            if (widget.linkedCircles.isEmpty)
              const Text(
                'Sin círculos vinculados.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final circle in widget.linkedCircles)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181428),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF2C2544),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.circle_rounded,
                            size: 11,
                            color: Color(0xFF9B6FCB),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            circle,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 20),
            const Divider(color: Color(0xFF2E2744), height: 1),
            const SizedBox(height: 14),

            // ── Leave Room ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: widget.onLeave,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(
                  widget.leaveLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9B6FCB),
                  side: BorderSide(
                    color: const Color(0xFF9B6FCB).withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.accentCyan,
            inactiveThumbColor: AppColors.textSecondary,
            inactiveTrackColor: const Color(0xFF2A2A3A),
          ),
        ],
      ),
    );
  }

  Widget _addLinkButton({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.accentCyan.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.accentCyan.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_rounded,
              size: 14,
              color: AppColors.accentCyan,
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.accentCyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    );
  }
}
