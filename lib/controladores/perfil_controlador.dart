import 'dart:typed_data';

import '../datos/supabase/auth_repositorio.dart';
import '../modelos/usuario_modelo.dart';
import '../utilidades/validador_credenciales.dart';

/// Controlador para la gestión de datos del perfil de usuario.
class PerfilControlador {
  PerfilControlador({AuthRepositorio? repositorio})
    : _repositorio = repositorio ?? AuthRepositorio();

  final AuthRepositorio _repositorio;

  Future<UsuarioModelo?> cargarPerfil() {
    return _repositorio.obtenerUsuarioActual();
  }

  String? validarNombre(String valor) {
    if (valor.trim().isEmpty) {
      return 'Ingresa tu nombre completo.';
    }
    if (valor.trim().length < 3) {
      return 'El nombre debe tener al menos 3 caracteres.';
    }
    return null;
  }

  String? validarTelefono(String valor) {
    return ValidadorCredenciales.validarTelefono(valor);
  }

  String? validarCorreoSecundario(String valor) {
    if (valor.trim().isEmpty) {
      return null;
    }
    return ValidadorCredenciales.validarCorreo(valor);
  }

  Future<PerfilResultado> guardarCambios({
    required UsuarioModelo usuarioActual,
    required String nombreCompleto,
    required String telefono,
    String? correoSecundario,
    String? documentoIdentidad,
    String? paisResidencia,
    String? monedaPreferida,
  }) async {
    final Map<String, String?> camposActualizados = <String, String?>{};

    if (nombreCompleto.trim() != usuarioActual.nombreCompleto) {
      camposActualizados['nombreCompleto'] = nombreCompleto.trim();
    }

    if (telefono.trim() != usuarioActual.telefono) {
      camposActualizados['telefono'] = telefono.trim();
    }

    final String correoSecundarioNormalizado = correoSecundario?.trim() ?? '';
    if (correoSecundarioNormalizado != (usuarioActual.correoSecundario ?? '')) {
      camposActualizados['correoSecundario'] =
          correoSecundarioNormalizado.isEmpty
          ? ''
          : correoSecundarioNormalizado;
    }

    final String documentoNormalizado = documentoIdentidad?.trim() ?? '';
    if (documentoNormalizado != (usuarioActual.documentoIdentidad ?? '')) {
      camposActualizados['documentoIdentidad'] = documentoNormalizado;
    }

    final String paisNormalizado = paisResidencia?.trim() ?? '';
    if (paisNormalizado != (usuarioActual.paisResidencia ?? '')) {
      camposActualizados['paisResidencia'] = paisNormalizado;
    }

    final String monedaNormalizada =
        monedaPreferida?.trim().toUpperCase() ?? '';
    if (monedaNormalizada != (usuarioActual.monedaPreferida ?? '')) {
      camposActualizados['monedaPreferida'] = monedaNormalizada;
    }

    if (camposActualizados.isEmpty) {
      return PerfilResultado(
        usuario: usuarioActual,
        mensaje: 'No hay cambios para guardar.',
      );
    }

    try {
      final UsuarioModelo usuarioActualizado = await _repositorio
          .actualizarPerfil(
            usuarioId: usuarioActual.id,
            nombreCompleto: camposActualizados['nombreCompleto'],
            telefono: camposActualizados['telefono'],
            correoSecundario: camposActualizados['correoSecundario'],
            documentoIdentidad: camposActualizados['documentoIdentidad'],
            paisResidencia: camposActualizados['paisResidencia'],
            monedaPreferida: camposActualizados['monedaPreferida'],
          );

      return PerfilResultado(usuario: usuarioActualizado);
    } on AuthRepositorioException catch (error) {
      return PerfilResultado(error: error.mensaje, usuario: usuarioActual);
    } catch (error) {
      return PerfilResultado(
        error: 'No se pudo actualizar el perfil: $error',
        usuario: usuarioActual,
      );
    }
  }

  Future<PerfilResultado> actualizarFoto({
    required UsuarioModelo usuarioActual,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      final UsuarioModelo actualizado = await _repositorio.actualizarFotoPerfil(
        usuarioId: usuarioActual.id,
        bytes: bytes,
        contentType: contentType,
      );
      return PerfilResultado(usuario: actualizado);
    } on AuthRepositorioException catch (error) {
      return PerfilResultado(error: error.mensaje, usuario: usuarioActual);
    } catch (error) {
      return PerfilResultado(
        error: 'No se pudo actualizar la foto de perfil: $error',
        usuario: usuarioActual,
      );
    }
  }
}

class PerfilResultado {
  const PerfilResultado({this.usuario, this.error, this.mensaje});

  final UsuarioModelo? usuario;
  final String? error;
  final String? mensaje;

  bool get tieneError => error != null && error!.isNotEmpty;
}
