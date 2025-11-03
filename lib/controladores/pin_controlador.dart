import '../datos/supabase/auth_repositorio.dart';
import '../utilidades/validador_credenciales.dart';

/// Gestiona la lógica de configuración y validación del PIN.
class PinControlador {
  PinControlador({AuthRepositorio? repositorio})
      : _repositorio = repositorio ?? AuthRepositorio();

  final AuthRepositorio _repositorio;

  String? validarPin(String pin) => ValidadorCredenciales.validarPin(pin);

  Future<String?> guardarPin({
    required String usuarioId,
    required String pin,
    required String confirmacion,
  }) async {
    final String? error = validarPin(pin);
    if (error != null) {
      return error;
    }
    if (pin != confirmacion) {
      return 'Los PIN ingresados no coinciden.';
    }
    try {
      await _repositorio.guardarPin(usuarioId: usuarioId, pin: pin);
      return null;
    } on AuthRepositorioException catch (e) {
      return e.mensaje;
    } catch (error) {
      return 'No se pudo guardar el PIN: $error';
    }
  }

  Future<String?> verificarPin({
    required String usuarioId,
    required String pin,
  }) async {
    final String? error = validarPin(pin);
    if (error != null) {
      return error;
    }
    final bool esValido = await _repositorio.validarPin(
      usuarioId: usuarioId,
      pin: pin,
    );
    if (!esValido) {
      return 'PIN incorrecto. Intenta nuevamente.';
    }
    return null;
  }
}
