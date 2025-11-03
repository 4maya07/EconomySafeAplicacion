import '../datos/supabase/auth_repositorio.dart';
import '../utilidades/validador_credenciales.dart';

/// Controla el flujo de recuperación de contraseña.
class RecuperarContrasenaControlador {
  RecuperarContrasenaControlador({AuthRepositorio? repositorio})
      : _repositorio = repositorio ?? AuthRepositorio();

  final AuthRepositorio _repositorio;

  String? validarCorreo(String correo) => ValidadorCredenciales.validarCorreo(correo);

  Future<String?> enviarRecuperacion(String correo) async {
    try {
      await _repositorio.solicitarRecuperacionContrasena(correo);
      return null;
    } on AuthRepositorioException catch (error) {
      return error.mensaje;
    } catch (error) {
      return 'No se pudo enviar el correo: $error';
    }
  }
}
