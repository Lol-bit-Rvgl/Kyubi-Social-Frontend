/// Utilidades de fecha e idioma completamente seguras y libres de excepciones.
class DateUtilsX {
  DateUtilsX._();

  static const _monthsShort = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static const _monthsLong = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// Formatea la fecha de membresía de manera defensiva (ej. "Miembro desde 24 nov 2024")
  static String formatMemberDate(DateTime? date) {
    if (date == null) return 'Miembro reciente';
    try {
      final month = _monthsShort[(date.month - 1).clamp(0, 11)];
      return 'Miembro desde ${date.day} $month ${date.year}';
    } catch (_) {
      return 'Miembro desde ${date.year}';
    }
  }

  /// Formatea la fecha completa (ej. "24 de noviembre de 2024")
  static String formatFullDate(DateTime? date) {
    if (date == null) return 'Fecha no disponible';
    try {
      final month = _monthsLong[(date.month - 1).clamp(0, 11)];
      return '${date.day} de $month de ${date.year}';
    } catch (_) {
      return '${date.year}';
    }
  }

  /// Formatea día y mes corto (ej. "24 nov")
  static String formatShortDate(DateTime? date) {
    if (date == null) return '';
    try {
      final month = _monthsShort[(date.month - 1).clamp(0, 11)];
      return '${date.day} $month';
    } catch (_) {
      return '${date.day}/${date.month}';
    }
  }

  /// Formatea día, mes y año corto (ej. "24 nov 2024")
  static String formatDayMonthYear(DateTime? date) {
    if (date == null) return '';
    try {
      final month = _monthsShort[(date.month - 1).clamp(0, 11)];
      return '${date.day} $month ${date.year}';
    } catch (_) {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  static String? isoToRelative(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return null;
    return relative(parsed);
  }

  static String relative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return 'hace $weeks sem';
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return 'hace $months mes${months > 1 ? 'es' : ''}';
    }
    final years = (diff.inDays / 365).floor();
    return 'hace $years año${years > 1 ? 's' : ''}';
  }
}
