import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'datos/supabase/auth_repositorio.dart';
import 'datos/supabase/supabase_servicio.dart';
import 'modelos/usuario_modelo.dart';
import 'servicios/sesion_servicio.dart';
import 'sistema_diseno/identidad_visual.dart';
import 'vistas/login/login_vista.dart';
import 'vistas/login/pin_vista.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseServicio.iniciar();
  SesionServicio.iniciarEscucha();
  runApp(const EconomySafeApp());
}

class EconomySafeApp extends StatefulWidget {
  const EconomySafeApp({super.key});

  @override
  State<EconomySafeApp> createState() => _EconomySafeAppState();
}

class _EconomySafeAppState extends State<EconomySafeApp> {
  late Future<_EstadoInicial> _estadoInicial;

  @override
  void initState() {
    super.initState();
    _estadoInicial = _cargarEstadoInicial();
  }

  Future<_EstadoInicial> _cargarEstadoInicial() async {
    final bool recordarme = await SesionServicio.obtenerRecordarme();
    if (!recordarme) {
      return const _EstadoInicial();
    }

    final Session? sesion = await SesionServicio.restaurarSesion();
    if (sesion == null) {
      return const _EstadoInicial();
    }

    final AuthRepositorio repositorio = AuthRepositorio();
    final UsuarioModelo? usuario = await repositorio.obtenerUsuarioActual();
    if (usuario == null) {
      await SesionServicio.limpiarSesion();
      return const _EstadoInicial();
    }

    final bool requiereConfiguracionPin = (usuario.pinHash ?? '').isEmpty;
    return _EstadoInicial(usuario: usuario, requiereConfiguracionPin: requiereConfiguracionPin);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Economy Safe',
      theme: TemasApp.obtenerTemaClaro(),
      darkTheme: TemasApp.obtenerTemaOscuro(),
      themeMode: ThemeMode.system,
      home: FutureBuilder<_EstadoInicial>(
        future: _estadoInicial,
        builder: (BuildContext context, AsyncSnapshot<_EstadoInicial> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final _EstadoInicial estado = snapshot.data ?? const _EstadoInicial();
          if (!estado.tieneSesion) {
            return const LoginVista();
          }

          if (estado.requiereConfiguracionPin) {
            return PinVista.configurar(usuario: estado.usuario!);
          }

          return PinVista.validar(usuario: estado.usuario!);
        },
      ),
    );
  }
}

class _EstadoInicial {
  const _EstadoInicial({this.usuario, this.requiereConfiguracionPin = false});

  final UsuarioModelo? usuario;
  final bool requiereConfiguracionPin;

  bool get tieneSesion => usuario != null;
}
