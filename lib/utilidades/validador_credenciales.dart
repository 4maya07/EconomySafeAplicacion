/// Métodos de validación simples para las credenciales de acceso.
class ValidadorCredenciales {
  static String? validarCorreo(String correo) {
    if (correo.isEmpty) {
      return 'Ingresa tu correo electrónico.';
    }
    final RegExp patron = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!patron.hasMatch(correo)) {
      return 'Correo inválido.';
    }
    return null;
  }

  static String? validarContrasena(String contrasena) {
    if (contrasena.isEmpty) {
      return 'Ingresa tu contraseña.';
    }
    if (contrasena.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return null;
  }

  static String? validarTelefono(String telefono) {
    if (telefono.isEmpty) {
      return 'Ingresa tu número telefónico.';
    }
    final RegExp patron = RegExp(r'^[0-9]{8}$');
    if (!patron.hasMatch(telefono)) {
      return 'Número telefónico inválido.';
    }
    return null;
  }

  static String? validarPin(String pin) {
    if (pin.isEmpty) {
      return 'Ingresa tu PIN.';
    }
    final RegExp patron = RegExp(r'^\d{4,6}$');
    if (!patron.hasMatch(pin)) {
      return 'El PIN debe ser numérico de 4 a 6 dígitos.';
    }
    return null;
  }
}
