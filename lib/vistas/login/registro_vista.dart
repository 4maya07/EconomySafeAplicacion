import 'package:flutter/material.dart';

import '../../controladores/registro_controlador.dart';

/// Vista para registrar un nuevo usuario.
class RegistroVista extends StatefulWidget {
  const RegistroVista({super.key});

  @override
  State<RegistroVista> createState() => _RegistroVistaState();
}

class _RegistroVistaState extends State<RegistroVista> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _correoCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final TextEditingController _contrasenaCtrl = TextEditingController();
  final RegistroControlador _controlador = RegistroControlador();

  bool _aceptaTerminos = false;
  bool _mostrarContrasena = false;
  bool _procesando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _contrasenaCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    final FormState? estado = _formKey.currentState;
    if (estado == null || !estado.validate()) {
      return;
    }
    setState(() => _procesando = true);

    final RegistroResultado resultado = await _controlador.registrar(
      nombre: _nombreCtrl.text.trim(),
      correo: _correoCtrl.text.trim(),
      contrasena: _contrasenaCtrl.text,
      telefono: _telefonoCtrl.text.trim(),
      terminosAceptados: _aceptaTerminos,
    );

    if (!mounted) {
      return;
    }

    setState(() => _procesando = false);

    if (resultado.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(resultado.error!)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro completado. Inicia sesión para continuar.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Regístrate en EconomySafe',
                        style: tema.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nombreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (String? valor) =>
                            _controlador.validarNombre(valor ?? ''),
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _telefonoCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        validator: (String? valor) =>
                            _controlador.validarTelefono(valor ?? ''),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contrasenaCtrl,
                        obscureText: !_mostrarContrasena,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _mostrarContrasena
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _mostrarContrasena = !_mostrarContrasena;
                              });
                            },
                          ),
                        ),
                        validator: (String? valor) =>
                            _controlador.validarContrasena(valor ?? ''),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Checkbox(
                            value: _aceptaTerminos,
                            onChanged: (bool? valor) {
                              setState(() {
                                _aceptaTerminos = valor ?? false;
                              });
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Acepto los términos y condiciones',
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _procesando ? null : _registrar,
                        child: _procesando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Crear cuenta'),
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
