import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../modelos/usuario_modelo.dart';
import '../../utilidades/validador_credenciales.dart';
import 'supabase_servicio.dart';

/// Gestiona todas las operaciones de autenticación y perfiles en Supabase.
class AuthRepositorio {
  AuthRepositorio() : _cliente = SupabaseServicio.obtenerCliente();

  final SupabaseClient _cliente;
  static const String _tablaUsuarios = 'usuarios';
  static const String _bucketPerfiles = 'perfiles';

  Future<UsuarioModelo?> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    try {
      final AuthResponse respuesta = await _cliente.auth.signInWithPassword(
        email: correo,
        password: contrasena,
      );

      final User? usuario = respuesta.user;
      if (usuario == null) {
        return null;
      }

      final PostgrestMap? perfil = await _obtenerPerfil(usuario.id);
      if (perfil == null) {
        return UsuarioModelo(
          id: usuario.id,
          nombreCompleto:
              usuario.userMetadata?['nombre_completo'] as String? ?? '',
          correo: usuario.email ?? correo,
          telefono: usuario.userMetadata?['telefono'] as String? ?? '',
          terminosAceptados:
              usuario.userMetadata?['terminos_aceptados'] as bool? ?? false,
          correoSecundario:
              usuario.userMetadata?['correo_secundario'] as String?,
          documentoIdentidad:
              usuario.userMetadata?['documento_identidad'] as String?,
          paisResidencia: usuario.userMetadata?['pais_residencia'] as String?,
          monedaPreferida: usuario.userMetadata?['moneda_preferida'] as String?,
          fotoUrl: usuario.userMetadata?['foto_url'] as String?,
          pinHash: usuario.userMetadata?['pin_hash'] as String?,
        );
      }

      return _mapearUsuario(usuario, perfil);
    } on AuthApiException catch (error) {
      throw AuthRepositorioException(mensaje: error.message);
    } on PostgrestException catch (error) {
      throw AuthRepositorioException(mensaje: error.message);
    } catch (error) {
      throw AuthRepositorioException(mensaje: 'Error inesperado: $error');
    }
  }

  Future<UsuarioModelo?> obtenerUsuarioActual() async {
    final User? usuario = _cliente.auth.currentUser;
    if (usuario == null) {
      return null;
    }
    final PostgrestMap? perfil = await _obtenerPerfil(usuario.id);
    if (perfil == null) {
      return UsuarioModelo(
        id: usuario.id,
        nombreCompleto:
            usuario.userMetadata?['nombre_completo'] as String? ?? '',
        correo: usuario.email ?? '',
        telefono: usuario.userMetadata?['telefono'] as String? ?? '',
        terminosAceptados:
            usuario.userMetadata?['terminos_aceptados'] as bool? ?? false,
        correoSecundario: usuario.userMetadata?['correo_secundario'] as String?,
        documentoIdentidad:
            usuario.userMetadata?['documento_identidad'] as String?,
        paisResidencia: usuario.userMetadata?['pais_residencia'] as String?,
        monedaPreferida: usuario.userMetadata?['moneda_preferida'] as String?,
        fotoUrl: usuario.userMetadata?['foto_url'] as String?,
        pinHash: usuario.userMetadata?['pin_hash'] as String?,
      );
    }
    return _mapearUsuario(usuario, perfil);
  }

  Future<UsuarioModelo> registrarUsuario({
    required String nombreCompleto,
    required String correo,
    required String contrasena,
    required String telefono,
    required bool terminosAceptados,
  }) async {
    try {
      final AuthResponse respuesta = await _cliente.auth.signUp(
        email: correo,
        password: contrasena,
        data: <String, dynamic>{
          'nombre_completo': nombreCompleto,
          'telefono': telefono,
          'terminos_aceptados': terminosAceptados,
        },
      );

      final User usuario = respuesta.user!;

      await _cliente.from(_tablaUsuarios).upsert(<String, dynamic>{
        'usuario_id': usuario.id,
        'nombre_completo': nombreCompleto,
        'telefono': telefono,
        'terminos_aceptados': terminosAceptados,
      });

      final PostgrestMap? perfil = await _obtenerPerfil(usuario.id);
      return _mapearUsuario(usuario, perfil ?? <String, dynamic>{});
    } on AuthApiException catch (error) {
      throw AuthRepositorioException(mensaje: error.message);
    } on PostgrestException catch (error) {
      throw AuthRepositorioException(mensaje: error.message);
    } catch (error) {
      throw AuthRepositorioException(mensaje: 'Error inesperado: $error');
    }
  }

  Future<void> solicitarRecuperacionContrasena(String correo) async {
    try {
      await _cliente.auth.resetPasswordForEmail(
        correo,
        redirectTo:
            'https://4maya07.github.io/EconomySafeAplicacion/#/recuperar',
      );
    } on AuthApiException catch (error) {
      throw AuthRepositorioException(mensaje: error.message);
    } catch (error) {
      throw AuthRepositorioException(
        mensaje: 'No se pudo enviar el correo: $error',
      );
    }
  }

  Future<void> actualizarContrasena(String nuevaContrasena) async {
    try {
      await _cliente.auth.updateUser(UserAttributes(password: nuevaContrasena));
    } on AuthApiException catch (error) {
      throw AuthRepositorioException(mensaje: error.message);
    } catch (error) {
      throw AuthRepositorioException(
        mensaje: 'No se pudo actualizar la contraseña: $error',
      );
    }
  }

  Future<void> guardarPin({
    required String usuarioId,
    required String pin,
  }) async {
    final String pinHash = _hashPin(pin);
    try {
      final PostgrestMap? perfil = await _obtenerPerfil(usuarioId);
      if (perfil == null) {
        throw AuthRepositorioException(
          mensaje:
              'No se encontró el perfil del usuario. Completa el registro antes de configurar el PIN.',
        );
      }

      await _cliente
          .from(_tablaUsuarios)
          .update(<String, dynamic>{'pin_hash': pinHash})
          .eq('usuario_id', usuarioId);
    } on PostgrestException catch (error) {
      throw AuthRepositorioException(mensaje: error.message);
    } catch (error) {
      throw AuthRepositorioException(
        mensaje: 'No se pudo guardar el PIN: $error',
      );
    }
  }

  Future<bool> validarPin({
    required String usuarioId,
    required String pin,
  }) async {
    final PostgrestMap? perfil = await _obtenerPerfil(usuarioId);
    if (perfil == null || perfil['pin_hash'] == null) {
      return false;
    }
    final String pinHash = _hashPin(pin);
    return perfil['pin_hash'] == pinHash;
  }

  Future<void> cerrarSesion() async {
    await _cliente.auth.signOut();
  }

  Future<PostgrestMap?> _obtenerPerfil(String usuarioId) async {
    final List<PostgrestMap> resultado = await _cliente
        .from(_tablaUsuarios)
        .select()
        .eq('usuario_id', usuarioId)
        .limit(1);
    if (resultado.isEmpty) {
      return null;
    }
    return resultado.first;
  }

  Future<UsuarioModelo> actualizarPerfil({
    required String usuarioId,
    String? nombreCompleto,
    String? telefono,
    String? correoSecundario,
    String? documentoIdentidad,
    String? paisResidencia,
    String? monedaPreferida,
  }) async {
    final Map<String, dynamic> datosActualizados = <String, dynamic>{
      if (nombreCompleto != null) 'nombre_completo': nombreCompleto,
      if (telefono != null) 'telefono': telefono,
      if (correoSecundario != null) 'correo_secundario': correoSecundario,
      if (documentoIdentidad != null) 'documento_identidad': documentoIdentidad,
      if (paisResidencia != null) 'pais_residencia': paisResidencia,
      if (monedaPreferida != null) 'moneda_preferida': monedaPreferida,
    };

    if (datosActualizados.isEmpty) {
      throw AuthRepositorioException(
        mensaje: 'No se proporcionaron cambios para actualizar.',
      );
    }

    final User? usuarioActual = _cliente.auth.currentUser;
    if (usuarioActual == null || usuarioActual.id != usuarioId) {
      throw AuthRepositorioException(
        mensaje: 'No se encontró una sesión activa para actualizar el perfil.',
      );
    }

    _validarDatosPerfil(
      nombreCompleto: nombreCompleto,
      telefono: telefono,
      correoSecundario: correoSecundario,
    );

    try {
      await _cliente
          .from(_tablaUsuarios)
          .update(datosActualizados)
          .eq('usuario_id', usuarioId);

      final Map<String, dynamic> metadata = <String, dynamic>{
        if (nombreCompleto != null) 'nombre_completo': nombreCompleto,
        if (telefono != null) 'telefono': telefono,
        if (correoSecundario != null) 'correo_secundario': correoSecundario,
        if (documentoIdentidad != null)
          'documento_identidad': documentoIdentidad,
        if (paisResidencia != null) 'pais_residencia': paisResidencia,
        if (monedaPreferida != null) 'moneda_preferida': monedaPreferida,
      };

      if (metadata.isNotEmpty) {
        await _cliente.auth.updateUser(UserAttributes(data: metadata));
      }

      final PostgrestMap? perfil = await _obtenerPerfil(usuarioId);
      return _mapearUsuario(usuarioActual, perfil ?? <String, dynamic>{});
    } on PostgrestException catch (error) {
      throw AuthRepositorioException(mensaje: error.message);
    } catch (error) {
      throw AuthRepositorioException(
        mensaje: 'No se pudo actualizar el perfil: $error',
      );
    }
  }

  Future<UsuarioModelo> actualizarFotoPerfil({
    required String usuarioId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final User? usuarioActual = _cliente.auth.currentUser;
    if (usuarioActual == null || usuarioActual.id != usuarioId) {
      throw AuthRepositorioException(
        mensaje: 'No se encontró una sesión activa para actualizar la foto.',
      );
    }

    final String extension = _obtenerExtension(contentType);
    final String nombreArchivo =
        'perfil-${DateTime.now().millisecondsSinceEpoch}.$extension';
    final String ruta = '$usuarioId/$nombreArchivo';

    try {
      await _cliente.storage
          .from(_bucketPerfiles)
          .uploadBinary(
            ruta,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: contentType,
            ),
          );

      final String urlPublica = _cliente.storage
          .from(_bucketPerfiles)
          .getPublicUrl(ruta);

      await _cliente
          .from(_tablaUsuarios)
          .update(<String, dynamic>{'foto_url': urlPublica})
          .eq('usuario_id', usuarioId);

      await _cliente.auth.updateUser(
        UserAttributes(data: <String, dynamic>{'foto_url': urlPublica}),
      );

      final PostgrestMap? perfil = await _obtenerPerfil(usuarioId);
      return _mapearUsuario(usuarioActual, perfil ?? <String, dynamic>{});
    } on StorageException catch (error) {
      final String mensaje = error.message;
      if (mensaje.toLowerCase().contains('bucket')) {
        throw AuthRepositorioException(
          mensaje:
              'No se encontró el bucket "$_bucketPerfiles" en Supabase Storage. '
              'Crea uno con acceso público antes de volver a intentarlo.',
        );
      }
      throw AuthRepositorioException(mensaje: mensaje);
    } on PostgrestException catch (error) {
      throw AuthRepositorioException(mensaje: error.message);
    } catch (error) {
      throw AuthRepositorioException(
        mensaje: 'No se pudo actualizar la foto de perfil: $error',
      );
    }
  }

  void _validarDatosPerfil({
    String? nombreCompleto,
    String? telefono,
    String? correoSecundario,
  }) {
    if (nombreCompleto != null && nombreCompleto.trim().length < 3) {
      throw AuthRepositorioException(
        mensaje: 'El nombre completo debe tener al menos 3 caracteres.',
      );
    }

    if (telefono != null) {
      final String? errorTelefono = ValidadorCredenciales.validarTelefono(
        telefono,
      );
      if (errorTelefono != null) {
        throw AuthRepositorioException(mensaje: errorTelefono);
      }
    }

    if (correoSecundario != null && correoSecundario.isNotEmpty) {
      final String? errorCorreo = ValidadorCredenciales.validarCorreo(
        correoSecundario,
      );
      if (errorCorreo != null) {
        throw AuthRepositorioException(mensaje: errorCorreo);
      }
    }
  }

  String _obtenerExtension(String contentType) {
    final List<String> partes = contentType.split('/');
    if (partes.length == 2 && partes.last.isNotEmpty) {
      return partes.last;
    }
    return 'jpg';
  }

  UsuarioModelo _mapearUsuario(User usuario, PostgrestMap perfil) {
    final Map<String, dynamic> metadata =
        usuario.userMetadata ?? <String, dynamic>{};
    return UsuarioModelo(
      id: usuario.id,
      nombreCompleto:
          (perfil['nombre_completo'] as String?) ??
          metadata['nombre_completo'] as String? ??
          '',
      correo: usuario.email ?? '',
      telefono:
          (perfil['telefono'] as String?) ??
          metadata['telefono'] as String? ??
          '',
      terminosAceptados:
          (perfil['terminos_aceptados'] as bool?) ??
          metadata['terminos_aceptados'] as bool? ??
          false,
      correoSecundario:
          (perfil['correo_secundario'] as String?) ??
          metadata['correo_secundario'] as String?,
      documentoIdentidad:
          (perfil['documento_identidad'] as String?) ??
          metadata['documento_identidad'] as String?,
      paisResidencia:
          (perfil['pais_residencia'] as String?) ??
          metadata['pais_residencia'] as String?,
      monedaPreferida:
          (perfil['moneda_preferida'] as String?) ??
          metadata['moneda_preferida'] as String?,
      fotoUrl:
          (perfil['foto_url'] as String?) ?? metadata['foto_url'] as String?,
      pinHash:
          (perfil['pin_hash'] as String?) ?? metadata['pin_hash'] as String?,
    );
  }

  String _hashPin(String pin) {
    final List<int> bytes = utf8.encode(pin);
    final Digest digest = sha256.convert(bytes);
    return digest.toString();
  }
}

class AuthRepositorioException implements Exception {
  AuthRepositorioException({required this.mensaje});

  final String mensaje;

  @override
  String toString() => 'AuthRepositorioException: $mensaje';
}
