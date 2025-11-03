import 'package:supabase_flutter/supabase_flutter.dart';

/// Gestiona la inicialización y acceso al cliente de Supabase.
class SupabaseServicio {
  static const String _url = 'https://gwtjjwsnzlvdmuisovys.supabase.co';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd3dGpqd3Nuemx2ZG11aXNvdnlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwMzI0NjIsImV4cCI6MjA3NzYwODQ2Mn0.GCis5xT41ZdYHzP09e5SeWTN35ev46kC0ouwmUTCg88';

  static bool _inicializado = false;

  static Future<void> iniciar() async {
    if (_inicializado) {
      return;
    }
    await Supabase.initialize(url: _url, anonKey: _anonKey);
    _inicializado = true;
  }

  static SupabaseClient obtenerCliente() {
    return Supabase.instance.client;
  }
}
