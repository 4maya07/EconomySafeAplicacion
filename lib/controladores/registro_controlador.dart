import '../datos/supabase/auth_repositorio.dart';
import '../modelos/usuario_modelo.dart';
import '../utilidades/validador_credenciales.dart';

/// Controlador encargado de la lógica de registro.
class RegistroControlador {
  RegistroControlador({AuthRepositorio? repositorio})
      : _repositorio = repositorio ?? AuthRepositorio();

  final AuthRepositorio _repositorio;

  String? validarNombre(String nombre) {
    if (nombre.isEmpty) {
      return 'Ingresa tu nombre completo.';
    }
    if (nombre.length < 3) {
      return 'El nombre es demasiado corto.';
    }
    return null;
  }

  String? validarCorreo(String correo) => ValidadorCredenciales.validarCorreo(correo);

  String? validarContrasena(String contrasena) =>
      ValidadorCredenciales.validarContrasena(contrasena);

  String? validarTelefono(String telefono) =>
      ValidadorCredenciales.validarTelefono(telefono);

  Future<RegistroResultado> registrar({
    required String nombre,
    required String correo,
    required String contrasena,
    required String telefono,
    required bool terminosAceptados,
  }) async {
    if (!terminosAceptados) {
      return RegistroResultado(error: 'Debes aceptar los términos y condiciones.');
    }

    try {
      final UsuarioModelo usuario = await _repositorio.registrarUsuario(
        nombreCompleto: nombre,
        correo: correo,
        contrasena: contrasena,
        telefono: telefono,
        terminosAceptados: terminosAceptados,
      );
      return RegistroResultado(usuario: usuario);
    } on AuthRepositorioException catch (error) {
      return RegistroResultado(error: error.mensaje);
    } catch (error) {
      return RegistroResultado(error: 'No se pudo completar el registro: $error');
    }
  }
}

class RegistroResultado {
  RegistroResultado({this.usuario, this.error});

  final UsuarioModelo? usuario;
  final String? error;
}
