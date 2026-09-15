import 'package:flutter/material.dart';

/// Widget que notifica cuando el usuario llega al final de la lista.
class EndReachedNotifier extends StatelessWidget {
  const EndReachedNotifier({
    super.key,
    required this.child,
    required this.onEndReached,
    this.triggerOffset = 400,
  });

  final Widget child;
  final VoidCallback onEndReached;
  final double triggerOffset;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - triggerOffset) {
          onEndReached();
        }
        return false;
      },
      child: child,
    );
  }
}

/// Indicador de fin de lista con spinner.
class ListEndIndicator extends StatelessWidget {
  const ListEndIndicator({super.key, this.hasMore = false});

  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}
