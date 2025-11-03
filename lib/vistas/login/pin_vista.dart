import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controladores/pin_controlador.dart';
import '../../modelos/usuario_modelo.dart';
import '../../servicios/sesion_servicio.dart';
import '../principal/principal_vista.dart';
import 'login_vista.dart';

/// Vista para configurar o validar el PIN de acceso.
class PinVista extends StatefulWidget {
  const PinVista.configurar({super.key, required this.usuario})
    : esConfiguracion = true;

  const PinVista.validar({super.key, required this.usuario})
    : esConfiguracion = false;

  final UsuarioModelo usuario;
  final bool esConfiguracion;

  @override
  State<PinVista> createState() => _PinVistaState();
}

class _PinVistaState extends State<PinVista> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _pinCtrl = TextEditingController();
  final TextEditingController _confirmacionCtrl = TextEditingController();
  final PinControlador _controlador = PinControlador();

  bool _procesando = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmacionCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final FormState? estado = _formKey.currentState;
    if (estado == null || !estado.validate()) {
      return;
    }
    setState(() => _procesando = true);

    String? error;
    if (widget.esConfiguracion) {
      error = await _controlador.guardarPin(
        usuarioId: widget.usuario.id,
        pin: _pinCtrl.text,
        confirmacion: _confirmacionCtrl.text,
      );
    } else {
      error = await _controlador.verificarPin(
        usuarioId: widget.usuario.id,
        pin: _pinCtrl.text,
      );
    }

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

    if (widget.esConfiguracion) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN configurado correctamente.')),
      );
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<Widget>(builder: (_) => const PrincipalVista()),
      (_) => false,
    );
  }

  Future<void> _manejarOlvidoPin() async {
    setState(() => _procesando = true);
    await Supabase.instance.client.auth.signOut();
    await SesionServicio.limpiarSesion();

    if (!mounted) {
      return;
    }

    setState(() => _procesando = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<Widget>(builder: (_) => const LoginVista()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.esConfiguracion ? 'Configurar PIN' : 'Ingresa tu PIN',
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
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
                        widget.esConfiguracion
                            ? 'Define un PIN de 4 a 6 dígitos para acceso rápido.'
                            : 'Ingresa tu PIN para continuar.',
                        style: tema.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _pinCtrl,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'PIN',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (String? valor) =>
                            _controlador.validarPin(valor ?? ''),
                      ),
                      if (widget.esConfiguracion) ...<Widget>[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmacionCtrl,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar PIN',
                            prefixIcon: Icon(Icons.check_circle_outline),
                          ),
                          validator: (String? valor) {
                            if (valor == null || valor.isEmpty) {
                              return 'Confirma tu PIN.';
                            }
                            if (valor != _pinCtrl.text) {
                              return 'Los PIN no coinciden.';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _procesando ? null : _enviar,
                        child: _procesando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.esConfiguracion
                                    ? 'Guardar PIN'
                                    : 'Ingresar',
                              ),
                      ),
                      if (!widget.esConfiguracion) ...<Widget>[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _procesando ? null : _manejarOlvidoPin,
                          child: const Text(
                            '¿Olvidaste tu PIN? Inicia sesión con correo.',
                          ),
                        ),
                      ],
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
