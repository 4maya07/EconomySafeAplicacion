import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controladores/restablecer_contrasena_controlador.dart';
import '../../servicios/sesion_servicio.dart';
import 'login_vista.dart';

/// Vista que permite definir una nueva contraseña tras recibir el enlace de recuperación.
class RestablecerContrasenaVista extends StatefulWidget {
  const RestablecerContrasenaVista({super.key});

  @override
  State<RestablecerContrasenaVista> createState() =>
      _RestablecerContrasenaVistaState();
}

class _RestablecerContrasenaVistaState
    extends State<RestablecerContrasenaVista> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nuevaCtrl = TextEditingController();
  final TextEditingController _confirmacionCtrl = TextEditingController();
  final RestablecerContrasenaControlador _controlador =
      RestablecerContrasenaControlador();

  bool _procesando = false;

  @override
  void dispose() {
    _nuevaCtrl.dispose();
    _confirmacionCtrl.dispose();
    super.dispose();
  }

  Future<void> _actualizar() async {
    final FormState? estado = _formKey.currentState;
    if (estado == null || !estado.validate()) {
      return;
    }

    setState(() => _procesando = true);
    final String? error = await _controlador.actualizarContrasena(
      _nuevaCtrl.text,
    );

    if (!mounted) {
      return;
    }

    setState(() => _procesando = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    await Supabase.instance.client.auth.signOut();
    await SesionServicio.limpiarSesion();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contraseña actualizada. Inicia sesión de nuevo.'),
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<Widget>(builder: (_) => const LoginVista()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Crea una nueva contraseña para tu cuenta.',
                        style: tema.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nuevaCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Nueva contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (String? valor) =>
                            _controlador.validarContrasena(valor ?? ''),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmacionCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contraseña',
                          prefixIcon: Icon(Icons.check_circle_outline),
                        ),
                        validator: (String? valor) {
                          if (valor == null || valor.isEmpty) {
                            return 'Confirma tu nueva contraseña.';
                          }
                          if (valor != _nuevaCtrl.text) {
                            return 'Las contraseñas no coinciden.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _procesando ? null : _actualizar,
                        child: _procesando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Guardar contraseña'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
