import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Representa el par de colores armónicos (Primario y Acento) para el tema del usuario.
class BannerPalette {
  final String primaryHex;
  final String accentHex;

  const BannerPalette({
    required this.primaryHex,
    required this.accentHex,
  });

  Color get primary => _parseHex(primaryHex, fallback: const Color(0xFFBA68C8));
  Color get accent => _parseHex(accentHex, fallback: const Color(0xFF00E676));

  static Color _parseHex(String hex, {required Color fallback}) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) return Color(0xFF000000 | val);
    }
    return fallback;
  }
}

/// Extractor de paletas temáticas dominantes para banners de perfil,
/// inspirado en la detección y personalización de perfiles de Discord Nitro.
class ImageThemeExtractor {
  static const List<BannerPalette> defaultHarmoniousPresets = [
    BannerPalette(primaryHex: '#BA68C8', accentHex: '#00E676'), // Kyubi Classic
    BannerPalette(primaryHex: '#7C4DFF', accentHex: '#00E5FF'), // Cosmic Cyber
    BannerPalette(primaryHex: '#FF4081', accentHex: '#FFD700'), // Sunset Neon
    BannerPalette(primaryHex: '#2979FF', accentHex: '#1DE9B6'), // Azure Emerald
    BannerPalette(primaryHex: '#FF1744', accentHex: '#00E5FF'), // Crimson Cyan
    BannerPalette(primaryHex: '#651FFF', accentHex: '#FF5252'), // Deep Violet Flame
  ];

  /// Extrae o sugiere una paleta armónica a partir de bytes de imagen o URL.
  static Future<BannerPalette> extractPalette({
    Uint8List? bytes,
    String? imageUrl,
  }) async {
    if (bytes != null && bytes.length > 50) {
      final fromBytes = _extractFromBytes(bytes);
      if (fromBytes != null) return fromBytes;
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      final hash = imageUrl.hashCode.abs();
      return defaultHarmoniousPresets[hash % defaultHarmoniousPresets.length];
    }

    return defaultHarmoniousPresets.first;
  }

  /// Muestreo simple de bytes de imagen para extraer tonos dominantes sin bloqueos.
  static BannerPalette? _extractFromBytes(Uint8List bytes) {
    try {
      int rSum = 0, gSum = 0, bSum = 0, count = 0;
      final step = (bytes.length / 200).floor().clamp(4, 500);

      // Muestrear valores RGB a lo largo del payload
      for (int i = 0; i < bytes.length - 3; i += step) {
        final r = bytes[i];
        final g = bytes[i + 1];
        final b = bytes[i + 2];

        // Ignorar colores excesivamente oscuros o extremadamente blancos
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;
        if (lum > 30 && lum < 235) {
          rSum += r;
          gSum += g;
          bSum += b;
          count++;
        }
      }

      if (count > 10) {
        final avgR = (rSum / count).round().clamp(0, 255);
        final avgG = (gSum / count).round().clamp(0, 255);
        final avgB = (bSum / count).round().clamp(0, 255);

        final primaryHex = _rgbToHex(avgR, avgG, avgB);
        final accentHex = _generateVibrantAccent(avgR, avgG, avgB);
        return BannerPalette(primaryHex: primaryHex, accentHex: accentHex);
      }
    } catch (_) {
      // Fallback a presets
    }

    final hash = bytes.length.hashCode.abs();
    return defaultHarmoniousPresets[hash % defaultHarmoniousPresets.length];
  }

  static String _rgbToHex(int r, int g, int b) {
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  static String _generateVibrantAccent(int r, int g, int b) {
    if (r > (g + b) / 2) {
      return '#00E5FF'; // Cian vibrante
    } else if (b > (r + g) / 2) {
      return '#00E676'; // Verde esmeralda
    } else {
      return '#FF4081'; // Neón rosa
    }
  }
}
