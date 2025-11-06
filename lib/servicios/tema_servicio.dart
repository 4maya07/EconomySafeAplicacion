import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestiona la preferencia de tema seleccionada por el usuario.
class TemaServicio {
  TemaServicio._();

  static const String _claveTema = 'preferencia_tema';

  static Future<void> guardarModo(ThemeMode modo) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveTema, _serializarModo(modo));
  }

  static Future<ThemeMode> obtenerModo() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? valor = prefs.getString(_claveTema);
    return _deserializarModo(valor);
  }

  static String _serializarModo(ThemeMode modo) {
    switch (modo) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _deserializarModo(String? valor) {
    switch (valor) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }
}
