import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../models/circle.dart';
import '../../../../services/providers.dart';
import 'salas_controller.dart';

/// Formulario de creación de una sala.
class CreateSalaScreen extends ConsumerStatefulWidget {
  const CreateSalaScreen({super.key, this.circleId});

  /// Círculo preseleccionado (si se abre desde un círculo).
  final String? circleId;

  @override
  ConsumerState<CreateSalaScreen> createState() => _CreateSalaScreenState();
}

class _CreateSalaScreenState extends ConsumerState<CreateSalaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _capacityController = TextEditingController();
  String _access = 'PUBLIC';
  String? _circleId;
  bool _saving = false;

  List<Circle> _myCircles = const [];
  bool _circlesLoading = false;

  @override
  void initState() {
    super.initState();
    _circleId = widget.circleId;
    _loadMyCircles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _capacityController.dispose();
    super.dispose();
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

  String? _validateCapacity(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = int.tryParse(text.trim());
    if (value == null) return 'Capacidad debe ser un número entero';
    if (value < 1) return 'Capacidad debe ser al menos 1';
    if (value > 100) return 'Capacidad máxima es 100';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_access == 'PRIVATE' && _circleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las salas privadas deben pertenecer a un círculo'),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final capacityValid = _validateCapacity(_capacityController.text.trim());
    if (capacityValid != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(capacityValid)));
      return;
    }
    final capacity = int.tryParse(_capacityController.text.trim());
    try {
      final room = await ref
          .read(roomRepositoryProvider)
          .createSala(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            capacity: capacity,
            access: _access,
            circleId: _circleId,
          );
      if (!mounted) return;
      // Persiste la sala creada en la lista real para que aparezca en My Chats.
      ref.read(salasControllerProvider.notifier).upsertRoom(room);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sala creada')));
      // Navega directo a la sala en modo conectado manteniendo el stack de navegación.
      context.pushReplacement('/salas/${room.id}', extra: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo crear la sala: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear sala')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppDimens.pagePadding,
          children: [
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
            AppButton(
              label: 'Crear sala',
              icon: Icons.add_rounded,
              loading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
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
