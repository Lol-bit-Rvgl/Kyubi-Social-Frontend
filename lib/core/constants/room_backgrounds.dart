import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_assets.dart';

/// Modelo de un fondo visual de sala o chat del catálogo oficial.
class RoomBackground {
  const RoomBackground({
    required this.id,
    required this.name,
    required this.assetPath,
    this.primaryColor = const Color(0xFF6C5CE7),
    this.secondaryColor = const Color(0xFF00E5FF),
  });

  final String id;
  final String name;
  final String assetPath;
  final Color primaryColor;
  final Color secondaryColor;
}

/// Catálogo central de fondos degradados oficiales Jay Sen.
class RoomBackgroundCatalog {
  RoomBackgroundCatalog._();

  static const RoomBackground jaySen1 = RoomBackground(
    id: 'jay_sen_1',
    name: 'Jay sen 1',
    assetPath: AppAssets.jaySen1,
    primaryColor: Color(0xFF1A0B2E),
    secondaryColor: Color(0xFF7B2CBF),
  );

  static const RoomBackground jaySen2 = RoomBackground(
    id: 'jay_sen_2',
    name: 'Jay sen 2',
    assetPath: AppAssets.jaySen2,
    primaryColor: Color(0xFF0D1B2A),
    secondaryColor: Color(0xFF415A77),
  );

  static const RoomBackground jaySen3 = RoomBackground(
    id: 'jay_sen_3',
    name: 'Jay sen 3',
    assetPath: AppAssets.jaySen3,
    primaryColor: Color(0xFF240046),
    secondaryColor: Color(0xFF9D4EDD),
  );

  static const RoomBackground jaySen4 = RoomBackground(
    id: 'jay_sen_4',
    name: 'Jay sen 4',
    assetPath: AppAssets.jaySen4,
    primaryColor: Color(0xFF03071E),
    secondaryColor: Color(0xFF6A040F),
  );

  static const RoomBackground jaySen5 = RoomBackground(
    id: 'jay_sen_5',
    name: 'Jay sen 5',
    assetPath: AppAssets.jaySen5,
    primaryColor: Color(0xFF001219),
    secondaryColor: Color(0xFF005F73),
  );

  static const RoomBackground jaySen6 = RoomBackground(
    id: 'jay_sen_6',
    name: 'Jay sen 6',
    assetPath: AppAssets.jaySen6,
    primaryColor: Color(0xFF10002B),
    secondaryColor: Color(0xFF5A189A),
  );

  /// Lista con todos los fondos oficiales disponibles.
  static const List<RoomBackground> all = [
    jaySen1,
    jaySen2,
    jaySen3,
    jaySen4,
    jaySen5,
    jaySen6,
  ];

  /// Busca un fondo por su identificador.
  static RoomBackground? findById(String? id) {
    if (id == null) return null;
    for (final bg in all) {
      if (bg.id == id) return bg;
    }
    return null;
  }

  /// Busca un fondo por su ruta de asset.
  static RoomBackground? findByAssetPath(String? path) {
    if (path == null) return null;
    for (final bg in all) {
      if (bg.assetPath == path) return bg;
    }
    return null;
  }
}

/// Muestra un modal tipo bottom sheet para seleccionar un fondo del catálogo Jay Sen.
Future<RoomBackground?> showRoomBackgroundSelector(
  BuildContext context, {
  String? currentAsset,
  String title = 'Personalizar Fondo',
  bool allowClear = true,
}) {
  return showModalBottomSheet<RoomBackground?>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _RoomBackgroundSelectorSheet(
      currentAsset: currentAsset,
      title: title,
      allowClear: allowClear,
    ),
  );
}

class _RoomBackgroundSelectorSheet extends StatefulWidget {
  const _RoomBackgroundSelectorSheet({
    required this.currentAsset,
    required this.title,
    required this.allowClear,
  });

  final String? currentAsset;
  final String title;
  final bool allowClear;

  @override
  State<_RoomBackgroundSelectorSheet> createState() =>
      _RoomBackgroundSelectorSheetState();
}

class _RoomBackgroundSelectorSheetState
    extends State<_RoomBackgroundSelectorSheet> {
  String? _selectedAsset;

  @override
  void initState() {
    super.initState();
    _selectedAsset = widget.currentAsset;
  }

  @override
  Widget build(BuildContext context) {
    final backgrounds = RoomBackgroundCatalog.all;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF14111F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Colección de gradientes atmosféricos Jay Sen',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.allowClear)
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop(const RoomBackground(
                        id: 'default',
                        name: 'Por defecto',
                        assetPath: '',
                      ));
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white70),
                    label: const Text(
                      'Restablecer',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 330),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: backgrounds.length,
                itemBuilder: (context, index) {
                  final bg = backgrounds[index];
                  final isSelected = _selectedAsset == bg.assetPath;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedAsset = bg.assetPath);
                      Navigator.of(context).pop(bg);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF00E5FF)
                              : Colors.white.withAlpha(25),
                          width: isSelected ? 2.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withAlpha(100),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            bg.assetPath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: bg.primaryColor,
                              child: const Icon(Icons.image_not_supported,
                                  color: Colors.white24),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withAlpha(180),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 6,
                            right: 6,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  bg.name,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? const Color(0xFF00E5FF)
                                        : Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00E5FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
