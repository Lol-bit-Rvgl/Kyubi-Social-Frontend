import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/image_theme_extractor.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/liquid_glass_container.dart';
import '../../../../models/user.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';
import 'widgets/hex_color_picker_tile.dart';

Color _parseColorHex(String hex, Color fallback) {
  final clean = hex.replaceAll('#', '').trim();
  if (clean.length == 6) {
    final val = int.tryParse(clean, radix: 16);
    if (val != null) return Color(0xFF000000 | val);
  }
  return fallback;
}

/// Build context-aware input decoration for edit profile form.
InputDecoration _kyubiInputDecoration({
  required BuildContext context,
  required String labelText,
  String? helperText,
  Widget? prefixIcon,
  String? prefixText,
  Widget? suffixIcon,
}) {
  final scheme = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: labelText,
    helperText: helperText,
    prefixIcon: prefixIcon != null
        ? Padding(padding: const EdgeInsets.all(12), child: prefixIcon)
        : null,
    prefixText: prefixText,
    suffixIcon: suffixIcon != null
        ? Padding(padding: const EdgeInsets.all(12), child: suffixIcon)
        : null,
    filled: true,
    fillColor: scheme.surfaceContainerHighest,
    labelStyle: TextStyle(color: scheme.onSurfaceVariant),
    floatingLabelStyle: TextStyle(color: scheme.primary),
    helperStyle: TextStyle(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
      fontSize: 12,
    ),
    prefixIconColor: scheme.onSurfaceVariant.withValues(alpha: 0.7),
    prefixStyle: TextStyle(color: scheme.onSurface),
    suffixIconColor: scheme.onSurfaceVariant.withValues(alpha: 0.7),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppDimens.md,
      vertical: 16,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide(color: scheme.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide(color: scheme.error, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide(color: scheme.error, width: 2),
    ),
    errorStyle: TextStyle(color: scheme.error, fontSize: 12),
  );
}

/// Edición del perfil del usuario autenticado (PATCH /users/me).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  User? _user;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _usernameAvailable = true;
  bool? _usernameChecked;
  String? _gender;
  bool _showGender = true;
  Set<String> _interests = {};
  String? _usernameColor;
  String _themePrimaryColor = '#BA68C8';
  String _themeAccentColor = '#00E676';
  GlassStyle _themeGlassStyle = GlassStyle.frosted;
  BannerPalette? _suggestedBannerPalette;
  // Cache key from server timestamps (persists across sessions).
  // Falls back to local epoch millis if backend hasn't been updated yet.
  int _localCacheVersion = 0;
  Uint8List? _avatarBytes;
  String? _avatarFilename;
  Uint8List? _wallpaperBytes;
  String? _wallpaperFilename;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = ref.read(authControllerProvider);
    final user = auth.user;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    final initialColor = user.nameColor ?? user.usernameColor;
    final themeSettings = user.themeSettings;
    setState(() {
      _user = user;
      _nameController.text = user.displayName;
      _usernameController.text = user.username;
      _bioController.text = user.bio ?? '';
      _gender = user.gender;
      _showGender = user.showGender;
      _interests = {...user.interests};
      _usernameColor = initialColor;
      _themePrimaryColor = themeSettings.primaryColor;
      _themeAccentColor = themeSettings.accentColor ?? '#00E676';
      _themeGlassStyle = themeSettings.glassStyle;
      _loading = false;
    });
    if (user.effectiveBannerUrl != null && user.effectiveBannerUrl!.isNotEmpty) {
      _analyzeBanner(bannerUrl: user.effectiveBannerUrl);
    }
  }

  Future<void> _analyzeBanner({Uint8List? bytes, String? bannerUrl}) async {
    final palette = await ImageThemeExtractor.extractPalette(
      bytes: bytes,
      imageUrl: bannerUrl,
    );
    if (!mounted) return;
    setState(() {
      _suggestedBannerPalette = palette;
    });
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarFilename = picked.name;
      });
    } catch (_) {
      if (!mounted) return;
      _snack('No se pudo cargar la imagen');
    }
  }

  Future<void> _pickWallpaper() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _wallpaperBytes = bytes;
        _wallpaperFilename = picked.name;
      });
      _analyzeBanner(bytes: bytes);
    } catch (_) {
      if (!mounted) return;
      _snack('No se pudo cargar la imagen');
    }
  }

  Future<void> _checkUsername() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty || username == _user?.username) {
      setState(() {
        _usernameChecked = null;
        _usernameAvailable = true;
      });
      return;
    }
    setState(() => _usernameChecked = null);
    try {
      final result = await ref
          .read(userRepositoryProvider)
          .checkUsername(username);
      if (!mounted) return;
      setState(() {
        _usernameChecked = true;
        _usernameAvailable = result['available'] as bool? ?? false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _usernameChecked = null);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _user;
    if (user == null) return;

    if (_usernameController.text.trim() != user.username &&
        !_usernameAvailable) {
      _snack('Ese nombre de usuario no está disponible');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(userRepositoryProvider);

      final usernameChanged = _usernameController.text.trim() != user.username;
      final avatarChanged = _avatarBytes != null;

      // PATCH /users/me/setup (multipart): username y/o avatar.
      if (usernameChanged || avatarChanged) {
        await repo.setupProfile(
          username: usernameChanged ? _usernameController.text.trim() : null,
          avatarBytes: _avatarBytes,
          avatarFilename: _avatarFilename,
        );
      }

      // Fondo del perfil (wallpaper): subir imagen y asignarla como bannerUrl.
      if (_wallpaperBytes != null) {
        final wallpaperUrl = await ref
            .read(uploadRepositoryProvider)
            .uploadFile(
              'banner',
              bytes: _wallpaperBytes!,
              filename: _wallpaperFilename ?? 'wallpaper.jpg',
            );
        await repo.updateProfile(bannerUrl: wallpaperUrl);
      }

      // PATCH /users/me (JSON): resto de campos.
      final bio = _bioController.text.trim();
      final data = <String, dynamic>{};
      if (_nameController.text.trim() != user.displayName) {
        data['displayName'] = _nameController.text.trim();
      }
      if (bio != (user.bio ?? '')) {
        data['bio'] = bio.isEmpty ? null : bio;
      }
      if (_gender != user.gender) {
        data['gender'] = _gender;
      }
      if (_showGender != user.showGender) {
        data['showGender'] = _showGender;
      }
      if (_interests.toList() != user.interests) {
        data['interests'] = _interests.toList();
      }
      if (_usernameColor != user.usernameColor ||
          _usernameColor != user.nameColor) {
        data['usernameColor'] = _usernameColor;
        data['nameColor'] = _usernameColor;
      }
      final themeSettingsPayload = {
        'primaryColor': _themePrimaryColor,
        'accentColor': _themeAccentColor,
        'glassStyle': _themeGlassStyle.toValue(),
      };
      data['themeSettings'] = themeSettingsPayload;

      if (data.isNotEmpty) {
        await repo.updateMe(data);
      }

      // Siempre obtener el usuario definitivo del servidor para
      // asegurar que la URL del avatar recién subido queda reflejada.
      final updated = await repo.getMe();

      if (!mounted) return;
      _localCacheVersion = DateTime.now().millisecondsSinceEpoch;
      // Limpiar bytes/filename pendientes para que una subida ya persistida no
      // se vuelva a subir (ni quede "pegada") en guardados posteriores.
      _avatarBytes = null;
      _avatarFilename = null;
      _wallpaperBytes = null;
      _wallpaperFilename = null;
      _saving = false;
      // Forzar la actualización del provider antes de cerrar: el perfil, el
      // drawer y las tarjetas se repintan de inmediato con el nuevo color.
      final updatedThemeSettings = UserThemeSettings(
        primaryColor: _themePrimaryColor,
        accentColor: _themeAccentColor,
        glassStyle: _themeGlassStyle,
      );
      final finalUser = updated.copyWith(
        usernameColor: _usernameColor ?? updated.usernameColor,
        extensions: {
          ...?updated.extensions,
          'nameColor': _usernameColor ?? updated.nameColor,
          'themeColor': _themePrimaryColor,
          'themeSettings': updatedThemeSettings.toJson(),
        },
      );
      ref.read(authControllerProvider.notifier).updateUser(finalUser);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
      _snack('No se pudo guardar el perfil');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Sección "Cambiar fondo del perfil": tarjeta compacta con preview y chip.
  Widget _buildWallpaperPicker(User user) {
    final currentUrl = user.effectiveBannerUrl;
    final hasWallpaper =
        _wallpaperBytes != null ||
        (currentUrl != null && currentUrl.isNotEmpty);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        color: AppColors.surfaceCards,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: AppColors.borderGlass, width: 1),
      ),
      child: Row(
        children: [
          // Izquierda: miniatura 48x48 (imagen actual/seleccionada).
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: SizedBox(
              width: 48,
              height: 48,
              child: _wallpaperBytes != null
                  ? Image.memory(_wallpaperBytes!, fit: BoxFit.cover)
                  : hasWallpaper
                  ? CachedNetworkImage(imageUrl: currentUrl!, fit: BoxFit.cover)
                  : const ColoredBox(
                      color: Color(0xFF1B1230),
                      child: Icon(
                        Icons.image_outlined,
                        size: 22,
                        color: Colors.white38,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Centro: título + subtítulo (Expand para que el texto fluya
          // horizontalmente y nunca se comprima en vertical).
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Fondo del perfil',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Personaliza el wallpaper de tu perfil',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Derecha: chip "Cambiar" en Magenta Nebulæ.
          GestureDetector(
            onTap: _saving ? null : _pickWallpaper,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppDimens.radiusChip),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.upload_file_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Cambiar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
          tooltip: 'Cancelar',
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final user = _user;
    if (user == null) {
      return const Center(child: Text('No hay sesión activa'));
    }
    final scheme = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: ListView(
        padding: AppDimens.pagePadding,
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                if (_avatarBytes != null)
                  ClipOval(
                    child: Image.memory(
                      _avatarBytes!,
                      width: AppDimens.avatarXl,
                      height: AppDimens.avatarXl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => AppAvatar(
                        name: user.displayName,
                        radius: AppDimens.avatarXl / 2,
                        cacheVersion: _localCacheVersion,
                      ),
                    ),
                  )
                else
                  AppAvatar(
                    imageUrl: user.effectiveAvatarUrl,
                    name: user.displayName,
                    radius: AppDimens.avatarXl / 2,
                    cacheVersion: _localCacheVersion,
                  ),
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.lg),
          _buildWallpaperPicker(user),
          // Separación clara entre la tarjeta de "Fondo del perfil" y el
          // formulario de campos de texto (Nombre, etc.) para que no colisionen.
          const SizedBox(height: AppDimens.xl),
          TextFormField(
            controller: _nameController,
            maxLength: 30,
            validator: Validators.displayName,
            decoration: _kyubiInputDecoration(
              context: context,
              labelText: 'Nombre',
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          TextFormField(
            controller: _usernameController,
            maxLength: 30,
            validator: Validators.username,
            onChanged: (_) => _checkUsername(),
            decoration: _kyubiInputDecoration(
              context: context,
              labelText: 'Nombre de usuario',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              suffixIcon: _usernameController.text.trim() == user.username
                  ? null
                  : _usernameChecked == null
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Icon(
                      _usernameAvailable
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: _usernameAvailable ? scheme.primary : scheme.error,
                    ),
            ),
          ),
          if (_usernameChecked != null && !_usernameAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                'Ese nombre de usuario no está disponible',
                style: TextStyle(fontSize: 12, color: scheme.error),
              ),
            ),
          const SizedBox(height: AppDimens.sm),
          TextFormField(
            controller: _bioController,
            validator: Validators.bio,
            minLines: 3,
            maxLines: 5,
            maxLength: 300,
            decoration: _kyubiInputDecoration(
              context: context,
              labelText: 'Biografía',
              helperText: 'Máximo 300 caracteres',
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          Text(
            'Género',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimens.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.genderOptions
                .map(
                  (option) => ChoiceChip(
                    label: Text(option),
                    selected: _gender == option,
                    onSelected: (_) => setState(() => _gender = option),
                  ),
                )
                .toList(),
          ),
          SwitchListTile(
            value: _showGender,
            onChanged: (v) => setState(() => _showGender = v),
            title: const Text('Mostrar género en mi perfil'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.trailing,
          ),
          const SizedBox(height: AppDimens.sm),
          Text(
            'Intereses',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimens.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.interestSuggestions
                .map(
                  (interest) => FilterChip(
                    label: Text(interest),
                    selected: _interests.contains(interest),
                    onSelected: (_) => _toggleInterest(interest),
                    selectedColor: scheme.primary.withValues(alpha: 0.25),
                    checkmarkColor: scheme.primary,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppDimens.md),
          Text(
            'Color de tu nombre',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppDimens.xs),
          HexColorPickerTile(
            initialColor: _usernameColor,
            previewName: _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : user.displayName,
            onColorChanged: (color) {
              setState(() {
                _usernameColor = color;
                _themePrimaryColor = color;
              });
            },
          ),
          const SizedBox(height: AppDimens.md),

          // ── Personalización de Perfil (Estilo Discord Nitro) ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF140F24).withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF2A2A38),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFA594F9),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tema y Estilo de Cristal (Liquid Glass)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Personaliza el estilo de tus tarjetas de perfil y adapta tus tonos automáticamente.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9E9EA8),
                  ),
                ),
                const SizedBox(height: 14),

                // Selector de Estilo de Cristal (Frosted vs Transparent)
                Text(
                  'Estilo de Tarjetas',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        key: const Key('glass_style_frosted'),
                        onTap: () => setState(() => _themeGlassStyle = GlassStyle.frosted),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _themeGlassStyle == GlassStyle.frosted
                                ? const Color(0xFFA594F9).withValues(alpha: 0.20)
                                : const Color(0xFF1E1833),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _themeGlassStyle == GlassStyle.frosted
                                  ? const Color(0xFFA594F9)
                                  : Colors.white.withValues(alpha: 0.12),
                              width: _themeGlassStyle == GlassStyle.frosted ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.blur_on_rounded,
                                size: 18,
                                color: _themeGlassStyle == GlassStyle.frosted
                                    ? const Color(0xFFA594F9)
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Difuminado',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        key: const Key('glass_style_transparent'),
                        onTap: () => setState(() => _themeGlassStyle = GlassStyle.transparent),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _themeGlassStyle == GlassStyle.transparent
                                ? const Color(0xFF00E676).withValues(alpha: 0.20)
                                : const Color(0xFF1E1833),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _themeGlassStyle == GlassStyle.transparent
                                  ? const Color(0xFF00E676)
                                  : Colors.white.withValues(alpha: 0.12),
                              width: _themeGlassStyle == GlassStyle.transparent ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.blur_off_rounded,
                                size: 18,
                                color: _themeGlassStyle == GlassStyle.transparent
                                    ? const Color(0xFF00E676)
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Transparente',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Sugerencia de colores del banner
                if (_suggestedBannerPalette != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18132B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _suggestedBannerPalette!.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white38, width: 1),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _suggestedBannerPalette!.accent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white38, width: 1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Tonos sugeridos del banner',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('apply_banner_palette_btn'),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFA594F9).withValues(alpha: 0.18),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _themePrimaryColor = _suggestedBannerPalette!.primaryHex;
                              _themeAccentColor = _suggestedBannerPalette!.accentHex;
                              _usernameColor = _themePrimaryColor;
                            });
                          },
                          icon: const Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: Color(0xFFA594F9),
                          ),
                          label: const Text(
                            'Aplicar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFA594F9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Color de acento del tema
                Text(
                  'Color de Acento',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '#00E676', '#00E5FF', '#FFD700', '#FF4081',
                    '#FF5722', '#7C4DFF', '#BA68C8', '#FFFFFF',
                  ].map((hex) {
                    final color = _parseColorHex(hex, const Color(0xFF00E676));
                    final isSelected = _themeAccentColor.toUpperCase() == hex.toUpperCase();
                    return InkWell(
                      key: Key('theme_accent_$hex'),
                      onTap: () => setState(() => _themeAccentColor = hex),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.black45,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Vista previa en vivo del contenedor temático
                LiquidGlassContainer(
                  width: double.infinity,
                  style: _themeGlassStyle,
                  primaryColor: _parseColorHex(_themePrimaryColor, const Color(0xFFBA68C8)),
                  accentColor: _parseColorHex(_themeAccentColor, const Color(0xFF00E676)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  borderRadius: 14,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _parseColorHex(_themePrimaryColor, const Color(0xFFBA68C8))
                              .withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.brush_rounded,
                          size: 16,
                          color: _parseColorHex(_themePrimaryColor, const Color(0xFFBA68C8)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vista previa (${_themeGlassStyle == GlassStyle.transparent ? 'Transparente' : 'Difuminado'})',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Primario: $_themePrimaryColor · Acento: $_themeAccentColor',
                              style: TextStyle(
                                fontSize: 11,
                                color: _parseColorHex(_themeAccentColor, const Color(0xFF00E676)),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.xl),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.sm),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancelar',
                  icon: Icons.close_rounded,
                  isOutlined: true,
                  onPressed: _saving ? null : () => context.pop(),
                ),
              ),
              const SizedBox(width: AppDimens.sm),
              Expanded(
                child: AppButton(
                  label: 'Guardar',
                  icon: Icons.check_rounded,
                  loading: _saving,
                  onPressed: _save,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.lg),
        ],
      ),
    );
  }
}
