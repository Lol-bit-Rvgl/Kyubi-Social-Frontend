/// Validaciones reutilizables para formularios.
class Validators {
  Validators._();

  static final RegExp _usernameRegExp = RegExp(r'^[a-zA-Z0-9._-]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu correo';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Correo inválido';
    }
    return null;
  }

  static String? username(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa un nombre de usuario';
    if (v.length < 3) return 'Mínimo 3 caracteres';
    if (v.length > 30) return 'Máximo 30 caracteres';
    if (!_usernameRegExp.hasMatch(v)) {
      return 'Solo letras, números, punto y guion';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Ingresa una contraseña';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    if (v.length > 128) return 'Máximo 128 caracteres';
    return null;
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu nombre';
    if (v.length > 30) return 'Máximo 30 caracteres';
    return null;
  }

  static String? required(String? value, {String label = 'Este campo'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label es obligatorio';
    return null;
  }

  static String? bio(String? value) {
    final v = value ?? '';
    if (v.length > 300) return 'Máximo 300 caracteres';
    return null;
  }
}
