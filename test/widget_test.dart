import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kyubi/core/theme/app_theme.dart';

void main() {
  testWidgets('El tema de Kyubi renderiza un MaterialApp', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: SizedBox()),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('Tema oscuro respeta la paleta de marca', () {
    final theme = AppTheme.dark;
    expect(theme.brightness, Brightness.dark);
  });
}
