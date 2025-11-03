import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../modelos/usuario_modelo.dart';
import 'supabase_servicio.dart';

/// Gestiona todas las operaciones de autenticación y perfiles en Supabase.
class AuthRepositorio {
  AuthRepositorio() : _cliente = SupabaseServicio.obtenerCliente();

  final SupabaseClient _cliente;
  static const String _tablaUsuarios = 'usuarios';

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

  UsuarioModelo _mapearUsuario(User usuario, PostgrestMap perfil) {
    return UsuarioModelo(
      id: usuario.id,
      nombreCompleto: (perfil['nombre_completo'] as String?) ?? '',
      correo: usuario.email ?? '',
      telefono: (perfil['telefono'] as String?) ?? '',
      terminosAceptados: (perfil['terminos_aceptados'] as bool?) ?? false,
      pinHash: perfil['pin_hash'] as String?,
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
