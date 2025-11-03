import 'package:flutter/material.dart';

import '../../controladores/recuperar_contrasena_controlador.dart';

/// Permite solicitar el restablecimiento de contraseña.
class RecuperarContrasenaVista extends StatefulWidget {
  const RecuperarContrasenaVista({super.key});

  @override
  State<RecuperarContrasenaVista> createState() => _RecuperarContrasenaVistaState();
}

class _RecuperarContrasenaVistaState extends State<RecuperarContrasenaVista> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _correoCtrl = TextEditingController();
  final RecuperarContrasenaControlador _controlador = RecuperarContrasenaControlador();

  bool _enviando = false;

  @override
  void dispose() {
    _correoCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarSolicitud() async {
    final FormState? estado = _formKey.currentState;
    if (estado == null || !estado.validate()) {
      return;
    }
    setState(() => _enviando = true);

    final String? error = await _controlador.enviarRecuperacion(
      _correoCtrl.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() => _enviando = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Se envió un correo con instrucciones.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
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
                        '¿Olvidaste tu contraseña?',
                        style: tema.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ingresa tu correo y te enviaremos un enlace para restablecerla.',
                        style: tema.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _correoCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (String? valor) =>
                            _controlador.validarCorreo(valor ?? ''),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _enviando ? null : _enviarSolicitud,
                        child: _enviando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Enviar instrucciones'),
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
