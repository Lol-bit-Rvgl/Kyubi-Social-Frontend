import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/room_backgrounds.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/liquid_glass_container.dart';
import '../../../../models/circle.dart';
import '../../../../models/user.dart';
import '../../../../services/auth_controller.dart';
import '../../../../services/providers.dart';
import 'salas_controller.dart';

/// Configurador integral de sala en vivo (estilo Project Z).
///
/// Incluye header multimedia (banner + icono), campos de configuración,
/// selección de círculo y una sección para invitar panitas en el mismo paso.
/// Al crear la sala se envían las invitaciones seleccionadas de forma atómica
/// y se navega directamente al interior de la sala recién creada.
class CreateSalaScreen extends ConsumerStatefulWidget {
  const CreateSalaScreen({
    super.key,
    this.circleId,
    this.isPrivateInitial = false,
  });

  /// Círculo preseleccionado (si se abre desde un círculo).
  final String? circleId;

  /// Estado inicial de privacidad de la sala (Privada vs Pública).
  final bool isPrivateInitial;

  @override
  ConsumerState<CreateSalaScreen> createState() => _CreateSalaScreenState();
}

class _CreateSalaScreenState extends ConsumerState<CreateSalaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _capacityController = TextEditingController();
  final _friendSearchController = TextEditingController();

  late String _access;
  String? _circleId;
  bool _saving = false;

  List<Circle> _myCircles = const [];
  bool _circlesLoading = false;

  // ── Header multimedia ──
  RoomBackground? _selectedBackground;
  String? _bannerUrl; // imagen subida para el fondo de la sala
  String? _iconUrl; // imagen subida para el icono de la sala
  bool _uploadingBanner = false;
  bool _uploadingIcon = false;

  // ── Invitar panitas ──
  List<FollowItem> _friends = const <FollowItem>[];
  bool _friendsLoading = true;
  String? _friendsError;
  final Set<String> _selectedUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    _access = widget.isPrivateInitial ? 'PRIVATE' : 'PUBLIC';
    _circleId = widget.circleId;
    _loadMyCircles();
    _loadFriends();
    _friendSearchController.addListener(_onFriendSearchChanged);
  }

  @override
  void dispose() {
    _friendSearchController.removeListener(_onFriendSearchChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _capacityController.dispose();
    _friendSearchController.dispose();
    super.dispose();
  }

  void _onFriendSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMyCircles() async {
    setState(() => _circlesLoading = true);
    try {
      final circles = await ref.read(circleRepositoryProvider).getMyCircles();
      if (!mounted) return;
      setState(() => _myCircles = circles);
    } catch (_) {
      // Sin círculos o sin red: la sala pública no requiere círculo.
    } finally {
      if (mounted) setState(() => _circlesLoading = false);
    }
  }

  /// Carga los contactos del usuario (seguidos + seguidores) para invitarlos.
  Future<void> _loadFriends() async {
    setState(() {
      _friendsLoading = true;
      _friendsError = null;
    });
    try {
      final user = ref.read(authControllerProvider).user;
      final usernameOrId = user?.username ?? user?.id ?? 'me';
      final repo = ref.read(userRepositoryProvider);
      final following = await repo.getFollowing(usernameOrId, limit: 50);
      final followers = await repo.getFollowers(usernameOrId, limit: 50);

      final map = <String, FollowItem>{};
      for (final item in [...following.items, ...followers.items]) {
        if (item.id.isEmpty) continue;
        if (item.id == user?.id) continue;
        map.putIfAbsent(item.id, () => item);
      }

      if (!mounted) return;
      setState(() {
        _friends = map.values.toList(growable: false);
        _friendsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _friendsLoading = false;
        _friendsError = 'No se pudieron cargar tus contactos';
      });
    }
  }

  List<FollowItem> get _filteredFriends {
    final q = _friendSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return _friends;
    return _friends
        .where(
          (f) =>
              f.displayName.toLowerCase().contains(q) ||
              f.username.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  String? _validateCapacity(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = int.tryParse(text.trim());
    if (value == null) return 'Capacidad debe ser un número entero';
    if (value < 2) return 'Capacidad debe ser al menos 2';
    if (value > 100) return 'Capacidad máxima es 100';
    return null;
  }

  void _toggleUser(FollowItem friend) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedUserIds.contains(friend.id)) {
        _selectedUserIds.remove(friend.id);
      } else {
        _selectedUserIds.add(friend.id);
      }
    });
  }

  // ── Selección de imágenes ────────────────────────────────────────────

  Future<void> _pickBannerImage() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() => _uploadingBanner = true);
    try {
      final url = await ref
          .read(uploadRepositoryProvider)
          .uploadFile(
            'banner',
            bytes: bytes,
            filename: image.name,
            contentType: image.mimeType,
          );
      if (!mounted) return;
      setState(() {
        _bannerUrl = url;
        _selectedBackground = null;
      });
    } catch (_) {
      if (mounted) _snack('No se pudo subir el fondo de sala');
    } finally {
      if (mounted) setState(() => _uploadingBanner = false);
    }
  }

  Future<void> _pickIconImage() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() => _uploadingIcon = true);
    try {
      final url = await ref
          .read(uploadRepositoryProvider)
          .uploadFile(
            'avatar',
            bytes: bytes,
            filename: image.name,
            contentType: image.mimeType,
          );
      if (!mounted) return;
      setState(() => _iconUrl = url);
    } catch (_) {
      if (mounted) _snack('No se pudo subir el icono de la sala');
    } finally {
      if (mounted) setState(() => _uploadingIcon = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Bottom sheet con los gradientes cósmicos del catálogo + subir imagen.
  Future<void> _openBannerPicker() async {
    HapticFeedback.lightImpact();
    final choice = await showModalBottomSheet<Object?>(
      context: context,
      backgroundColor: const Color(0xFF14141B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A4A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Fondo de la sala',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: RoomBackgroundCatalog.all.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, index) {
                    final bg = RoomBackgroundCatalog.all[index];
                    return GestureDetector(
                      onTap: () => Navigator.pop(ctx, bg),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 150,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [bg.primaryColor, bg.secondaryColor],
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                bg.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.image_rounded,
                  color: AppColors.accentCyan,
                ),
                title: const Text(
                  'Subir imagen desde la galería',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(ctx, 'upload'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || choice == null) return;
    if (choice == 'upload') {
      await _pickBannerImage();
    } else if (choice is RoomBackground) {
      setState(() {
        _selectedBackground = choice;
        _bannerUrl = null;
      });
    }
  }

  /// Crea la sala, envía las invitaciones seleccionadas y navega a su interior.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_access == 'PRIVATE' && _circleId == null) {
      _snack('Las salas privadas deben pertenecer a un círculo');
      return;
    }
    final capacityError = _validateCapacity(_capacityController.text.trim());
    if (capacityError != null) {
      _snack(capacityError);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final banner =
        _bannerUrl ?? _selectedBackground?.assetPath; // URL o gradiente
    final capacity = int.tryParse(_capacityController.text.trim());
    final description = _descriptionController.text.trim();

    try {
      final room = await ref
          .read(roomRepositoryProvider)
          .createSala(
            name: _nameController.text.trim(),
            description: description.isEmpty ? null : description,
            imageUrl: _iconUrl,
            chatBackgroundUrl: banner,
            capacity: capacity,
            access: _access,
            circleId: _circleId,
          );
      if (!mounted) return;

      // ── Invitaciones atómicas dentro del mismo flujo de creación ──
      if (_selectedUserIds.isNotEmpty) {
        try {
          await ref
              .read(roomRepositoryProvider)
              .inviteUsers(room.id, _selectedUserIds.toList());
        } catch (_) {
          if (mounted) {
            _snack('La sala se creó, pero no se pudieron invitar a todos');
          }
        }
      }
      if (!mounted) return;

      ref.read(salasControllerProvider.notifier).refresh();
      context.pushReplacement('/salas/${room.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('No se pudo crear la sala: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear sala')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.md),
          children: [
            // ── Header multimedia: banner + icono ──
            _buildMediaHeader(),
            const SizedBox(height: AppDimens.md),

            TextFormField(
              controller: _nameController,
              maxLength: 30,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe un nombre' : null,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: '¿Cómo se llamará la sala?',
                prefixIcon: Icon(Icons.meeting_room_rounded),
              ),
            ),
            const SizedBox(height: AppDimens.sm),

            TextFormField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 6,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: '¿De qué se hablará en la sala?',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppDimens.sm),

            TextFormField(
              controller: _capacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Capacidad (opcional)',
                hintText: 'Máximo de participantes',
                prefixIcon: Icon(Icons.people_alt_outlined),
              ),
            ),
            const SizedBox(height: AppDimens.md),

            DropdownButtonFormField<String>(
              initialValue: _access,
              decoration: const InputDecoration(labelText: 'Acceso'),
              items: const [
                DropdownMenuItem(value: 'PUBLIC', child: Text('Pública')),
                DropdownMenuItem(value: 'PRIVATE', child: Text('Privada')),
              ],
              onChanged: (v) => setState(() => _access = v ?? 'PUBLIC'),
            ),
            const SizedBox(height: AppDimens.md),

            _buildCircleField(),
            const SizedBox(height: AppDimens.lg),

            // ── Invitar panitas ──
            _buildInviteSection(),
            const SizedBox(height: AppDimens.lg),

            AppButton(
              label: _selectedUserIds.isEmpty
                  ? 'Crear sala'
                  : 'Crear sala e invitar (${_selectedUserIds.length})',
              icon: Icons.add_rounded,
              loading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaHeader() {
    final scheme = Theme.of(context).colorScheme;
    return LiquidGlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 18,
      child: Column(
        children: [
          // ── Banner / Fondo de sala ──
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildBannerPreview(),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _buildGlassChip(
                    icon: Icons.wallpaper_rounded,
                    label: 'Fondo',
                    onTap: _openBannerPicker,
                  ),
                ),
              ],
            ),
          ),
          // ── Icono de sala sobrepuesto ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickIconImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF14141E),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.55),
                            width: 1.6,
                          ),
                          image: (_iconUrl != null && _iconUrl!.isNotEmpty)
                              ? DecorationImage(
                                  image: NetworkImage(_iconUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: (_iconUrl == null || _iconUrl!.isEmpty)
                            ? Icon(
                                Icons.meeting_room_rounded,
                                color: scheme.primary,
                                size: 26,
                              )
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary,
                        ),
                        child: _uploadingIcon
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.add_a_photo_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    (_iconUrl == null || _iconUrl!.isEmpty)
                        ? 'Añade un icono para tu sala'
                        : 'Icono de sala listo',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerPreview() {
    if (_uploadingBanner) {
      return const ColoredBox(
        color: Color(0xFF14141E),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    if (_bannerUrl != null && _bannerUrl!.isNotEmpty) {
      return Image.network(_bannerUrl!, fit: BoxFit.cover);
    }
    final bg = _selectedBackground;
    if (bg != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bg.primaryColor, bg.secondaryColor],
          ),
        ),
        child: Center(
          child: Text(
            bg.name,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    // Placeholder neutro para el estado vacío.
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14141E), Color(0xFF1E1B2E)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, color: Colors.white38, size: 26),
            SizedBox(height: 6),
            Text(
              'Elige un fondo cósmico',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.black.withValues(alpha: 0.42),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_friendsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_friendsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'No se pudieron cargar tus contactos',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ),
            TextButton(
              onPressed: _loadFriends,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final friends = _filteredFriends;
    if (friends.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Aún no tienes contactos que mostrar.\nTu sala se creará igualmente.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.only(top: 6),
        itemCount: friends.length,
        itemBuilder: (_, index) => _buildFriendTile(friends[index]),
      ),
    );
  }

  Widget _buildFriendTile(FollowItem friend) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = _selectedUserIds.contains(friend.id);
    final name = friend.displayName.isNotEmpty
        ? friend.displayName
        : friend.username;

    return InkWell(
      onTap: () => _toggleUser(friend),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            AppAvatar(
              imageUrl: friend.avatarUrl,
              name: name,
              radius: 20,
              showOnline: true,
              isOnline: friend.isOnline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '@${friend.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // ── Checkbox Liquid Glass toggleable ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: isSelected
                      ? scheme.primary
                      : Colors.white.withValues(alpha: 0.22),
                  width: 1.4,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded, size: 16, color: scheme.primary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteSection() {
    final scheme = Theme.of(context).colorScheme;
    return LiquidGlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_add_alt_1_rounded,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Invitar panitas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_selectedUserIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    '${_selectedUserIds.length} seleccionados',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Buscador inline de contactos ──
          TextField(
            controller: _friendSearchController,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
            cursorColor: scheme.primary,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Filtrar contactos...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: scheme.primary,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: scheme.primary.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: scheme.primary, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 6),

          _buildFriendsList(),
        ],
      ),
    );
  }

  Widget _buildCircleField() {
    if (_circlesLoading) {
      return const ListTile(
        dense: true,
        leading: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Cargando tus círculos...'),
        contentPadding: EdgeInsets.zero,
      );
    }
    if (_myCircles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimens.xs),
        child: Text(
          'Pertenece a un círculo para vincular la sala.',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }
    return DropdownButtonFormField<String?>(
      initialValue: _circleId,
      decoration: const InputDecoration(
        labelText: 'Círculo (opcional)',
        prefixIcon: Icon(Icons.workspaces_rounded),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Sin círculo'),
        ),
        for (final circle in _myCircles)
          DropdownMenuItem<String?>(
            value: circle.id,
            child: Text(circle.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => setState(() => _circleId = v),
    );
  }
}
