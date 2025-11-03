import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'datos/supabase/auth_repositorio.dart';
import 'datos/supabase/supabase_servicio.dart';
import 'modelos/usuario_modelo.dart';
import 'servicios/sesion_servicio.dart';
import 'sistema_diseno/identidad_visual.dart';
import 'vistas/login/login_vista.dart';
import 'vistas/login/pin_vista.dart';
import 'vistas/login/restablecer_contrasena_vista.dart';

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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSubscription;
  bool _mostrarRestablecerPendiente = false;
  bool _haMostradoRestablecer = false;
  String? _mensajeRecuperacion;

  @override
  void initState() {
    super.initState();
    _suscribirseCambiosAuth();
    _estadoInicial = _prepararEstadoInicial();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _suscribirseCambiosAuth() {
    _authSubscription ??= Supabase.instance.client.auth.onAuthStateChange
        .listen((AuthState data) {
          if (data.event == AuthChangeEvent.passwordRecovery) {
            _mostrarVistaRestablecer();
          }
        });
  }

  void _mostrarVistaRestablecer() {
    if (_haMostradoRestablecer) {
      return;
    }

    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator == null) {
      _mostrarRestablecerPendiente = true;
      return;
    }

    _mostrarRestablecerPendiente = false;
    _haMostradoRestablecer = true;
    _mensajeRecuperacion = null;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<Widget>(
        builder: (_) => const RestablecerContrasenaVista(),
      ),
      (_) => false,
    );
  }

  Future<_EstadoInicial> _prepararEstadoInicial() async {
    if (kIsWeb) {
      final _ResultadoRecuperacion resultado =
          await _procesarEnlaceRecuperacion();
      switch (resultado.estado) {
        case _RecuperacionEstado.mostrarFormulario:
          _mostrarVistaRestablecer();
          return const _EstadoInicial();
        case _RecuperacionEstado.error:
          _mensajeRecuperacion = resultado.mensaje;
          return const _EstadoInicial();
        case _RecuperacionEstado.ninguno:
          break;
      }
    }
    return _cargarEstadoInicial();
  }

  Future<_ResultadoRecuperacion> _procesarEnlaceRecuperacion() async {
    final Uri uri = Uri.base;
    final Map<String, String> parametros = _obtenerParametrosEnlace(uri);

    final String? error = parametros['error'];
    final String? codigoError = parametros['error_code'];
    final String? descripcionError =
        parametros['error_description'] ?? parametros['message'];

    if (error != null || codigoError != null) {
      final String mensaje = _mensajeErrorRecuperacion(
        codigoError ?? error,
        descripcionError,
      );
      return _ResultadoRecuperacion(
        _RecuperacionEstado.error,
        mensaje: mensaje,
      );
    }

    final bool tieneToken = parametros.containsKey('access_token');
    final String? tipo = parametros['type'];
    final bool esRecuperacion =
        tipo == 'recovery' ||
        tipo == 'passwordrecovery' ||
        tipo == 'passwordRecovery';

    if (!tieneToken && !esRecuperacion) {
      return const _ResultadoRecuperacion(_RecuperacionEstado.ninguno);
    }

    try {
      await SesionServicio.limpiarSesion();
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      return const _ResultadoRecuperacion(
        _RecuperacionEstado.mostrarFormulario,
      );
    } catch (_) {
      return _ResultadoRecuperacion(
        _RecuperacionEstado.error,
        mensaje: 'No se pudo procesar el enlace. Solicita uno nuevo.',
      );
    }
  }

  Map<String, String> _obtenerParametrosEnlace(Uri uri) {
    final Map<String, String> parametros = Map<String, String>.from(
      uri.queryParameters,
    );

    if (uri.fragment.isNotEmpty) {
      String fragmento = uri.fragment;
      if (fragmento.startsWith('#')) {
        fragmento = fragmento.substring(1);
      }
      if (fragmento.contains('?')) {
        fragmento = fragmento.split('?').last;
      }
      if (fragmento.isNotEmpty) {
        try {
          parametros.addAll(Uri.splitQueryString(fragmento));
        } catch (_) {
          // Ignoramos errores de parseo del fragmento.
        }
      }
    }

    return parametros;
  }

  String _mensajeErrorRecuperacion(String? codigo, String? descripcion) {
    switch (codigo) {
      case 'otp_expired':
        return 'El enlace ya expiró. Solicita un nuevo correo de recuperación.';
      case 'otp_invalid':
        return 'El enlace no es válido. Solicita un nuevo correo de recuperación.';
      default:
        if (descripcion != null && descripcion.isNotEmpty) {
          return descripcion;
        }
        return 'No se pudo procesar el enlace. Solicita un nuevo correo.';
    }
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
    return _EstadoInicial(
      usuario: usuario,
      requiereConfiguracionPin: requiereConfiguracionPin,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrarRestablecerPendiente && _navigatorKey.currentState != null) {
      _mostrarRestablecerPendiente = false;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _mostrarVistaRestablecer(),
      );
    }

    return MaterialApp(
      title: 'Economy Safe',
      navigatorKey: _navigatorKey,
      theme: TemasApp.obtenerTemaClaro(),
      darkTheme: TemasApp.obtenerTemaOscuro(),
      themeMode: ThemeMode.system,
      home: FutureBuilder<_EstadoInicial>(
        future: _estadoInicial,
        builder:
            (BuildContext context, AsyncSnapshot<_EstadoInicial> snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final _EstadoInicial estado =
                  snapshot.data ?? const _EstadoInicial();
              if (!estado.tieneSesion) {
                _haMostradoRestablecer = false;
                final String? mensaje = _mensajeRecuperacion;
                _mensajeRecuperacion = null;
                return LoginVista(mensajeInicial: mensaje);
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

enum _RecuperacionEstado { ninguno, mostrarFormulario, error }

class _ResultadoRecuperacion {
  const _ResultadoRecuperacion(this.estado, {this.mensaje});

  final _RecuperacionEstado estado;
  final String? mensaje;
}
