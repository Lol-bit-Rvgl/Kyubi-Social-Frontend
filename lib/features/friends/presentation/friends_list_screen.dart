import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import 'friends_controller.dart';
import 'friends_list_sheet.dart';

/// Pantalla dedicada de Amigos (seguimiento bilateral mutuo).
///
/// Expone la misma lista que [FriendsListSheet] pero como ruta propia
/// (`/friends`), útil para deep links y pantallas grandes.
class FriendsListScreen extends ConsumerWidget {
  const FriendsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(friendsControllerProvider);
    final subtitle = state.friends.isEmpty
        ? 'Seguimiento mutuo'
        : '${state.friends.length} ${state.friends.length == 1 ? 'amigo' : 'amigos'} con seguimiento mutuo';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13101E),
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Amigos',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 17,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMutedNebulae,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: const FriendsListView(),
    );
  }
}