import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Modal para crear encuestas rápidas en la sala de rol.
class PollCreationModal extends StatefulWidget {
  const PollCreationModal({super.key, required this.onCreated});

  final Function(String question, List<String> options) onCreated;

  @override
  State<PollCreationModal> createState() => _PollCreationModalState();
}

class _PollCreationModalState extends State<PollCreationModal> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 5) return;
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _submit() {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa la pregunta de la encuesta'),
          backgroundColor: Color(0xFF2A121E),
        ),
      );
      return;
    }

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa al menos 2 opciones con texto'),
          backgroundColor: Color(0xFF2A121E),
        ),
      );
      return;
    }

    Navigator.pop(context);
    widget.onCreated(question, options);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13101E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
            const SizedBox(height: 14),

            const Text(
              'Crear Encuesta',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _questionController,
              maxLength: 80,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '¿Cuál es la pregunta?',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                counterStyle: const TextStyle(
                  color: Color(0xFF9E9EAF),
                  fontSize: 11,
                ),
                filled: true,
                fillColor: const Color(0xFF1B162B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF2C2544),
                    width: 0.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Opciones',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            ..._optionControllers.asMap().entries.map((entry) {
              final idx = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: controller,
                  maxLength: 20,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Opción ${idx + 1}',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    counterStyle: const TextStyle(
                      color: Color(0xFF9E9EAF),
                      fontSize: 11,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1B162B),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF2C2544),
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
              );
            }),

            if (_optionControllers.length < 5)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: AppColors.accentCyan,
                ),
                label: const Text(
                  'Agregar opción',
                  style: TextStyle(color: AppColors.accentCyan, fontSize: 13),
                ),
              ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCrimson,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Publicar Encuesta',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
