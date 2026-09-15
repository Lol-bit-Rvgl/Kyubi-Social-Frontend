import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyubi/core/utils/image_theme_extractor.dart';
import 'package:kyubi/core/widgets/liquid_glass_container.dart';
import 'package:kyubi/models/user.dart';

void main() {
  group('UserThemeSettings Model Tests', () {
    test('Default values match expected Discord Nitro-style palette', () {
      const theme = UserThemeSettings();
      expect(theme.primaryColor, '#BA68C8');
      expect(theme.accentColor, '#00E676');
      expect(theme.glassStyle, GlassStyle.frosted);
      expect(theme.primary, const Color(0xFFBA68C8));
      expect(theme.accent, const Color(0xFF00E676));
    });

    test('toJson and fromJson correctly serialize and deserialize theme settings', () {
      const original = UserThemeSettings(
        primaryColor: '#FF4081',
        accentColor: '#00E5FF',
        glassStyle: GlassStyle.transparent,
      );

      final json = original.toJson();
      expect(json['primaryColor'], '#FF4081');
      expect(json['accentColor'], '#00E5FF');
      expect(json['glassStyle'], 'transparent');

      final reconstructed = UserThemeSettings.fromJson(json);
      expect(reconstructed.primaryColor, '#FF4081');
      expect(reconstructed.accentColor, '#00E5FF');
      expect(reconstructed.glassStyle, GlassStyle.transparent);
      expect(reconstructed.primary, const Color(0xFFFF4081));
      expect(reconstructed.accent, const Color(0xFF00E5FF));
    });

    test('borderGradient produces correct LinearGradient between primary and accent colors', () {
      const theme = UserThemeSettings(
        primaryColor: '#9C27B0',
        accentColor: '#4CAF50',
      );

      final gradient = theme.borderGradient;
      expect(gradient.begin, Alignment.topLeft);
      expect(gradient.end, Alignment.bottomRight);
      expect(gradient.colors.length, 3);
      expect(gradient.colors[0], const Color(0xFF9C27B0).withValues(alpha: 0.55));
      expect(gradient.colors[1], const Color(0xFF9C27B0).withValues(alpha: 0.25));
      expect(gradient.colors[2], const Color(0xFF4CAF50).withValues(alpha: 0.40));
    });

    test('User model seamlessly parses themeSettings from Map or defaults cleanly', () {
      const userWithoutTheme = User(
        id: 'u-1',
        username: 'fox',
        displayName: 'Kitsune Fox',
      );
      expect(userWithoutTheme.themeSettings.primaryColor, '#BA68C8');
      expect(userWithoutTheme.themeSettings.glassStyle, GlassStyle.frosted);

      final userWithTheme = User.fromJson({
        'id': 'u-2',
        'username': 'cyber_fox',
        'themeSettings': {
          'primaryColor': '#7C4DFF',
          'accentColor': '#00E676',
          'glassStyle': 'transparent',
        },
      });
      expect(userWithTheme.themeSettings.primaryColor, '#7C4DFF');
      expect(userWithTheme.themeSettings.accentColor, '#00E676');
      expect(userWithTheme.themeSettings.glassStyle, GlassStyle.transparent);
    });
  });

  group('LiquidGlassContainer Custom Styling Tests', () {
    testWidgets('Renders frosted style with expected child and dimensions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiquidGlassContainer(
                style: GlassStyle.frosted,
                child: Text('Frosted Glass Mode'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Frosted Glass Mode'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders transparent crystal style with customBorderGradient', (tester) async {
      const customGradient = LinearGradient(
        colors: [Colors.purple, Colors.green],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiquidGlassContainer(
                style: GlassStyle.transparent,
                customBorderGradient: customGradient,
                child: Text('Crystal Transparent Mode'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Crystal Transparent Mode'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responds to onTap gesture when callback provided', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiquidGlassContainer(
                onTap: () => tapped = true,
                child: const Text('Tap Me'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('Inherits primary and accent colors from Theme.of(context) colorScheme', (tester) async {
      const customThemeScheme = ColorScheme.dark(
        primary: Color(0xFFFF1744),
        secondary: Color(0xFF00E5FF),
      );

      await tester.pumpWidget(
        Theme(
          data: ThemeData.dark().copyWith(colorScheme: customThemeScheme),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: LiquidGlassContainer(
                child: Text('Theme Adaptive'),
              ),
            ),
          ),
        ),
      );

      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);

      // Verify that the outermost container has the gradient containing the theme colors
      final containers = tester.widgetList<Container>(containerFinder);
      final borderContainer = containers.firstWhere(
        (c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).gradient is LinearGradient,
      );
      final gradient = (borderContainer.decoration as BoxDecoration).gradient as LinearGradient;
      expect(gradient.colors.first, const Color(0xFFFF1744).withValues(alpha: 0.55));
      expect(gradient.colors.last, const Color(0xFF00E5FF).withValues(alpha: 0.40));
    });

    testWidgets('Transparent mode has background opacity <= 0.15', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiquidGlassContainer(
                style: GlassStyle.transparent,
                child: Text('Translucid'),
              ),
            ),
          ),
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      final innerCard = containers.firstWhere(
        (c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).color != null,
      );
      final color = (innerCard.decoration as BoxDecoration).color!;
      expect(color.a, lessThanOrEqualTo(0.15));
    });
  });

  group('ImageThemeExtractor Tests', () {
    test('Returns default fallback palette when imageUrl and bytes are null', () async {
      final palette = await ImageThemeExtractor.extractPalette(
        imageUrl: null,
        bytes: null,
      );

      expect(palette.primaryHex, startsWith('#'));
      expect(palette.accentHex, startsWith('#'));
      expect(palette.primary, isNotNull);
      expect(palette.accent, isNotNull);
    });

    test('extractFromBytes handles synthetic test image bytes without crashing', () async {
      // 100 bytes of dummy image data to verify defensive fallback
      final dummyBytes = Uint8List(100);

      final palette = await ImageThemeExtractor.extractPalette(
        bytes: dummyBytes,
      );

      expect(palette.primaryHex, startsWith('#'));
      expect(palette.accentHex, startsWith('#'));
    });

    test('defaultHarmoniousPresets contains diverse, valid theme combinations', () {
      expect(ImageThemeExtractor.defaultHarmoniousPresets.length, greaterThanOrEqualTo(4));
      for (final p in ImageThemeExtractor.defaultHarmoniousPresets) {
        expect(p.primaryHex, startsWith('#'));
        expect(p.accentHex, startsWith('#'));
      }
    });
  });
}
