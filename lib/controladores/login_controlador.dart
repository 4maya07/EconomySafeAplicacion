import '../datos/supabase/auth_repositorio.dart';
import '../modelos/usuario_modelo.dart';
import '../utilidades/validador_credenciales.dart';

/// Contiene el resultado de un intento de inicio de sesión.
class ResultadoLogin {
  ResultadoLogin({this.usuario, this.error});

  final UsuarioModelo? usuario;
  final String? error;
}

/// Controla la lógica de la vista de inicio de sesión.
class LoginControlador {
  LoginControlador({AuthRepositorio? repositorio})
      : _repositorio = repositorio ?? AuthRepositorio();

  final AuthRepositorio _repositorio;

  String? validarCorreo(String correo) {
    return ValidadorCredenciales.validarCorreo(correo);
  }

  String? validarContrasena(String contrasena) {
    return ValidadorCredenciales.validarContrasena(contrasena);
  }

  Future<ResultadoLogin> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    try {
      final UsuarioModelo? usuario = await _repositorio.iniciarSesion(
        correo: correo,
        contrasena: contrasena,
      );
      if (usuario == null) {
        return ResultadoLogin(error: 'No se pudo obtener la información del usuario.');
      }
      return ResultadoLogin(usuario: usuario);
    } on AuthRepositorioException catch (error) {
      return ResultadoLogin(error: error.mensaje);
    } catch (_) {
      return ResultadoLogin(error: 'No se pudo iniciar sesión. Intenta nuevamente.');
    }
  }
}
