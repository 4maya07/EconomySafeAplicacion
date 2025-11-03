import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gestiona la persistencia de sesión y la preferencia "recordarme".
class SesionServicio {
  SesionServicio._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _claveSesion = 'sesion_supabase';
  static const String _claveRecordarme = 'recordarme';
  static StreamSubscription<AuthState>? _suscripcion;

  static void iniciarEscucha() {
    _suscripcion ??= Supabase.instance.client.auth.onAuthStateChange.listen(
      (AuthState data) async {
        switch (data.event) {
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.signedIn:
            final Session? sesion = data.session;
            if (sesion != null && await obtenerRecordarme()) {
              await guardarSesion(sesion);
            }
            break;
          case AuthChangeEvent.signedOut:
            await limpiarSesion();
            break;
          default:
            break;
        }
      },
    );
  }

  static Future<void> guardarSesion(Session sesion) async {
    final Map<String, dynamic> datos = <String, dynamic>{
      'refresh_token': sesion.refreshToken,
    };
    await _secureStorage.write(
      key: _claveSesion,
      value: jsonEncode(datos),
    );
  }

  static Future<Session?> restaurarSesion() async {
    final String? datos = await _secureStorage.read(key: _claveSesion);
    if (datos == null) {
      return null;
    }

    try {
      final Map<String, dynamic> mapa =
          jsonDecode(datos) as Map<String, dynamic>;
      final String? refreshToken = mapa['refresh_token'] as String?;
      if (refreshToken == null) {
        await limpiarSesion();
        return null;
      }

      final SupabaseClient cliente = Supabase.instance.client;
      final AuthResponse respuesta = await cliente.auth.setSession(refreshToken);
      if (respuesta.session == null) {
        await limpiarSesion();
      }
      return respuesta.session;
    } catch (_) {
      await limpiarSesion();
      return null;
    }
  }

  static Future<void> guardarRecordarme(bool valor) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveRecordarme, valor);
  }

  static Future<bool> obtenerRecordarme() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_claveRecordarme) ?? false;
  }

  static Future<void> limpiarSesion() async {
    await _secureStorage.delete(key: _claveSesion);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveRecordarme);
  }

  static Future<void> cerrar() async {
    await _suscripcion?.cancel();
    _suscripcion = null;
  }
}
