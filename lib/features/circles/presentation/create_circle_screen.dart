import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../services/providers.dart';

/// Formulario de creación de un círculo.
class CreateCircleScreen extends ConsumerStatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  ConsumerState<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends ConsumerState<CreateCircleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPrivate = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final circle = await ref
          .read(circleRepositoryProvider)
          .createCircle(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            isPrivate: _isPrivate,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Círculo creado')));
      context.go('/circles/${circle.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear el círculo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear círculo')),
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
                hintText: '¿Cómo se llamará el círculo?',
                prefixIcon: Icon(Icons.workspaces_rounded),
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
                hintText: '¿De qué trata este círculo?',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppDimens.md),
            SwitchListTile(
              value: _isPrivate,
              onChanged: (v) => setState(() => _isPrivate = v),
              title: const Text('Círculo privado'),
              subtitle: const Text(
                'Solo visible para sus miembros; para unirse se requiere invitación.',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppDimens.lg),
            AppButton(
              label: 'Crear círculo',
              icon: Icons.add_rounded,
              loading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
