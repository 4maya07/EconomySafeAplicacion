import '../datos/supabase/auth_repositorio.dart';
import '../utilidades/validador_credenciales.dart';

/// Gestiona la actualización de contraseña tras abrir el enlace de recuperación.
class RestablecerContrasenaControlador {
  RestablecerContrasenaControlador({AuthRepositorio? repositorio})
    : _repositorio = repositorio ?? AuthRepositorio();

  final AuthRepositorio _repositorio;

  String? validarContrasena(String contrasena) =>
      ValidadorCredenciales.validarContrasena(contrasena);

  Future<String?> actualizarContrasena(String nuevaContrasena) async {
    try {
      await _repositorio.actualizarContrasena(nuevaContrasena);
      return null;
    } on AuthRepositorioException catch (error) {
      return error.mensaje;
    } catch (error) {
      return 'No se pudo actualizar la contraseña: $error';
    }
  }
}
