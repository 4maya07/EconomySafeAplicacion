import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controladores/login_controlador.dart';
import '../../servicios/sesion_servicio.dart';
import 'recuperar_contrasena_vista.dart';
import 'registro_vista.dart';
import '../principal/principal_vista.dart';

/// Pantalla inicial de autenticación para EconomySafe.
class LoginVista extends StatefulWidget {
  const LoginVista({super.key, this.mensajeInicial});

  final String? mensajeInicial;

  @override
  State<LoginVista> createState() => _LoginVistaState();
}

class _LoginVistaState extends State<LoginVista> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _correoCtrl = TextEditingController();
  final TextEditingController _contrasenaCtrl = TextEditingController();
  final LoginControlador _controlador = LoginControlador();

  bool _verContrasena = false;
  bool _recordarme = false;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    final String? mensaje = widget.mensajeInicial;
    if (mensaje != null && mensaje.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensaje)));
      });
    }
  }

  @override
  void dispose() {
    _correoCtrl.dispose();
    _contrasenaCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarFormulario() async {
    final FormState? estado = _formKey.currentState;
    if (estado == null || !estado.validate()) {
      return;
    }
    setState(() => _cargando = true);

    final ResultadoLogin resultado = await _controlador.iniciarSesion(
      correo: _correoCtrl.text.trim(),
      contrasena: _contrasenaCtrl.text,
    );

    if (!mounted) {
      return;
    }

    setState(() => _cargando = false);

    if (resultado.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resultado.error!)));
      return;
    }

    if (_recordarme) {
      final Session? sesion = Supabase.instance.client.auth.currentSession;
      if (sesion != null) {
        await SesionServicio.guardarSesion(sesion);
        await SesionServicio.guardarRecordarme(true);
      }
    } else {
      await SesionServicio.limpiarSesion();
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<Widget>(builder: (_) => const PrincipalVista()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tema.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: tema.colorScheme.primary,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text('EconomySafe', style: tema.textTheme.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Gestiona tus finanzas de forma inteligente',
                  style: tema.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'Iniciar Sesión',
                            style: tema.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _correoCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo Electrónico',
                              hintText: 'ejemplo@correo.com',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (String? valor) =>
                                _controlador.validarCorreo(valor ?? ''),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _contrasenaCtrl,
                            obscureText: !_verContrasena,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              hintText: 'Ingrese su contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _verContrasena = !_verContrasena;
                                  });
                                },
                                icon: Icon(
                                  _verContrasena
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                            validator: (String? valor) =>
                                _controlador.validarContrasena(valor ?? ''),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Checkbox(
                                    value: _recordarme,
                                    onChanged: (bool? valor) {
                                      setState(() {
                                        _recordarme = valor ?? false;
                                      });
                                    },
                                  ),
                                  const Text('Recordarme'),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<Widget>(
                                      builder: (_) =>
                                          const RecuperarContrasenaVista(),
                                    ),
                                  );
                                },
                                child: const Text('¿Olvidaste tu contraseña?'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _cargando ? null : _enviarFormulario,
                            child: _cargando
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Iniciar Sesión'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text('¿No tienes una cuenta?'),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<Widget>(
                            builder: (_) => const RegistroVista(),
                          ),
                        );
                      },
                      child: const Text('Regístrate'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
