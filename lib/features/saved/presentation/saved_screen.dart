import 'package:flutter/material.dart';
import 'widgets/saved_posts_list.dart';

/// Pantalla de publicaciones guardadas.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guardados')),
      body: const SavedPostsList(),
    );
  }
}
