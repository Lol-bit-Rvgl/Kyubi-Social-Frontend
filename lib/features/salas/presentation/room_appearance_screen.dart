import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/room_backgrounds.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/kyubi_shimmer.dart';

const _appearanceColors = [
  Color(0xFF00E5FF), // Cian neón
  AppColors.primary, // Carmesí Kyubi
  AppColors.accentTeal, // Verde neón
  Color(0xFFD500F9), // Púrpura
  Color(0xFFFF9100), // Naranja
  Color(0xFFFFD600), // Amarillo
  Color(0xFF2979FF), // Azul eléctrico
];

/// Pantalla de Personalización y Apariencia de Sala (Ref: Screenshot_20260725_170403_Gallery.jpg).
class RoomAppearanceScreen extends StatefulWidget {
  const RoomAppearanceScreen({
    super.key,
    this.initialCoverUrl,
    this.initialBgUrl,
    this.initialThemeColor,
  });

  final String? initialCoverUrl;
  final String? initialBgUrl;
  final Color? initialThemeColor;

  @override
  State<RoomAppearanceScreen> createState() => _RoomAppearanceScreenState();
}

class _RoomAppearanceScreenState extends State<RoomAppearanceScreen> {
  String? _coverUrl;
  String? _bgUrl;
  String? _homeTabBgUrl;
  String? _menuBgUrl;
  Color _themeColor = const Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _coverUrl =
        widget.initialCoverUrl ??
        'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=500&auto=format&fit=crop&q=60';
    _bgUrl =
        widget.initialBgUrl ??
        'https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?w=500&auto=format&fit=crop&q=60';
    _themeColor = widget.initialThemeColor ?? const Color(0xFF00E5FF);
  }

  Future<void> _pickImage(Function(String) onPicked) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => onPicked(image.path));
    }
  }

  Future<void> _selectBackground() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14111F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF)),
              title: const Text(
                'Catálogo Jay Sen (Gradientes)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Fondos oficiales atmosféricos optimizados',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final selected = await showRoomBackgroundSelector(
                  context,
                  currentAsset: _bgUrl,
                  title: 'Fondo de Sala',
                );
                if (selected != null) {
                  setState(() {
                    _bgUrl = (selected.id == 'default' || selected.assetPath.isEmpty)
                        ? null
                        : selected.assetPath;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.white70),
              title: const Text(
                'Elegir de la galería',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage((path) => _bgUrl = path);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14141B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Theme Color',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: _appearanceColors.map((color) {
                final isSelected = _themeColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() => _themeColor = color);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.black,
                            size: 22,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0C16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0C16),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop({
            'coverUrl': _coverUrl,
            'bgUrl': _bgUrl,
            'themeColor': _themeColor,
          }),
        ),
        title: const Text(
          'Appearance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Opciones de personalización ──
            _settingTile(
              title: 'Cover Image',
              preview: _imagePreviewBox(_coverUrl),
              onTap: () => _pickImage((path) => _coverUrl = path),
            ),
            _settingTile(
              title: 'Background Image',
              preview: _imagePreviewBox(_bgUrl),
              onTap: _selectBackground,
            ),
            _settingTile(
              title: 'Home Tab Background',
              preview: _imagePreviewBox(
                _homeTabBgUrl,
                isNone: _homeTabBgUrl == null,
              ),
              onTap: () => _pickImage((path) => _homeTabBgUrl = path),
            ),
            _settingTile(
              title: 'Menu Background',
              preview: _imagePreviewBox(_menuBgUrl, isNone: _menuBgUrl == null),
              onTap: () => _pickImage((path) => _menuBgUrl = path),
            ),
            _settingTile(
              title: 'Theme Color',
              preview: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _themeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onTap: _showColorPicker,
            ),

            const SizedBox(height: 28),

            // ── Preview Section ──
            Text(
              'Preview',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildMiniPhoneFrame(isMenu: false),
                      const SizedBox(height: 8),
                      const Text(
                        'Main View',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _buildMiniPhoneFrame(isMenu: true),
                      const SizedBox(height: 8),
                      const Text(
                        'Menu View',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingTile({
    required String title,
    required Widget preview,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161322),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF242036), width: 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            preview,
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF6E6A82),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePreviewBox(String? url, {bool isNone = false}) {
    if (isNone || url == null || url.isEmpty) {
      return Container(
        width: 32,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1A2E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primary, width: 1.2),
        ),
        child: const Center(
          child: Icon(Icons.block_rounded, color: AppColors.primary, size: 16),
        ),
      );
    }
    return Container(
      width: 32,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF322C4A), width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.startsWith('assets/')
          ? Image.asset(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Container(color: const Color(0xFF261D36)),
            )
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => const KyubiShimmer(),
              errorWidget: (_, _, _) =>
                  Container(color: const Color(0xFF261D36)),
            ),
    );
  }

  Widget _buildMiniPhoneFrame({required bool isMenu}) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF13101E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2C2642), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo del frame
          if (_bgUrl != null && _bgUrl!.isNotEmpty)
            _bgUrl!.startsWith('assets/')
                ? Image.asset(
                    _bgUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(color: const Color(0xFF1A162B)),
                  )
                : CachedNetworkImage(
                    imageUrl: _bgUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) =>
                        Container(color: const Color(0xFF1A162B)),
                  )
          else
            Container(color: const Color(0xFF1A162B)),

          // Overlay oscuro translúcido
          Container(color: Colors.black.withValues(alpha: 0.45)),

          if (!isMenu)
            // Simulación Main View
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _themeColor, width: 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _coverUrl!,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 4,
                    width: 48,
                    decoration: BoxDecoration(
                      color: _themeColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(height: 3, width: 70, color: Colors.white24),
                  const SizedBox(height: 4),
                  Container(height: 3, width: 90, color: Colors.white12),
                  const Spacer(),
                  // Barra de botones inferior miniatura
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [_miniDot(), _miniDot(), _miniDot()],
                  ),
                ],
              ),
            )
          else
            // Simulación Menu View
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(width: 8, color: Colors.black38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              color: _themeColor,
                            ),
                            const SizedBox(width: 6),
                            Container(
                              height: 3,
                              width: 40,
                              color: Colors.white38,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _miniMenuItem(),
                        _miniMenuItem(),
                        _miniMenuItem(),
                        const Spacer(),
                        _miniMenuItem(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniDot() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _themeColor.withValues(alpha: 0.8),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _miniMenuItem() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _themeColor.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Container(height: 3, color: Colors.white24)),
        ],
      ),
    );
  }
}
