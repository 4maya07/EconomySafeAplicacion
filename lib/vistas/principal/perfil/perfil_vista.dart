import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:appeconomysafe/main.dart';

import '../../../controladores/perfil_controlador.dart';
import '../../../modelos/usuario_modelo.dart';
import '../../../servicios/sesion_servicio.dart';
import '../../login/login_vista.dart';
import '../../login/pin_vista.dart';

class PerfilVista extends StatefulWidget {
  const PerfilVista({super.key});

  @override
  State<PerfilVista> createState() => _PerfilVistaState();
}

class _PerfilVistaState extends State<PerfilVista> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final PerfilControlador _controlador = PerfilControlador();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _correoCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();
  final TextEditingController _correoSecundarioCtrl = TextEditingController();
  final TextEditingController _documentoCtrl = TextEditingController();
  final TextEditingController _paisCtrl = TextEditingController();
  final TextEditingController _monedaCtrl = TextEditingController();

  UsuarioModelo? _usuario;
  bool _cargando = true;
  bool _guardando = false;
  bool _actualizandoFoto = false;
  bool _cambiandoTema = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoSecundarioCtrl.dispose();
    _documentoCtrl.dispose();
    _paisCtrl.dispose();
    _monedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    setState(() => _cargando = true);
    final UsuarioModelo? usuario = await _controlador.cargarPerfil();
    if (!mounted) {
      return;
    }
    setState(() {
      _usuario = usuario;
      _cargando = false;
    });
    if (usuario != null) {
      _sincronizarCampos(usuario);
    }
  }

  void _sincronizarCampos(UsuarioModelo usuario) {
    _nombreCtrl.text = usuario.nombreCompleto;
    _correoCtrl.text = usuario.correo;
    _telefonoCtrl.text = usuario.telefono;
    _correoSecundarioCtrl.text = usuario.correoSecundario ?? '';
    _documentoCtrl.text = usuario.documentoIdentidad ?? '';
    _paisCtrl.text = usuario.paisResidencia ?? '';
    _monedaCtrl.text = usuario.monedaPreferida ?? '';
  }

  Future<void> _guardarCambios() async {
    final UsuarioModelo? usuarioActual = _usuario;
    if (usuarioActual == null) {
      return;
    }

    final FormState? estado = _formKey.currentState;
    if (estado == null || !estado.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);

    final PerfilResultado resultado = await _controlador.guardarCambios(
      usuarioActual: usuarioActual,
      nombreCompleto: _nombreCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      correoSecundario: _correoSecundarioCtrl.text.trim(),
      documentoIdentidad: _documentoCtrl.text.trim(),
      paisResidencia: _paisCtrl.text.trim(),
      monedaPreferida: _monedaCtrl.text.trim().toUpperCase(),
    );

    if (!mounted) {
      return;
    }

    setState(() => _guardando = false);

    if (resultado.tieneError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resultado.error!)));
      return;
    }

    if (resultado.mensaje != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resultado.mensaje!)));
      return;
    }

    if (resultado.usuario != null) {
      setState(() {
        _usuario = resultado.usuario;
      });
      _sincronizarCampos(resultado.usuario!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente.')),
      );
    }
  }

  Future<void> _seleccionarFoto() async {
    final UsuarioModelo? usuarioActual = _usuario;
    if (usuarioActual == null || _actualizandoFoto) {
      return;
    }

    final XFile? archivo = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (archivo == null) {
      return;
    }

    final Uint8List bytes = await archivo.readAsBytes();
    final String contentType = _inferContentType(archivo.name);

    setState(() => _actualizandoFoto = true);

    final PerfilResultado resultado = await _controlador.actualizarFoto(
      usuarioActual: usuarioActual,
      bytes: bytes,
      contentType: contentType,
    );

    if (!mounted) {
      return;
    }

    setState(() => _actualizandoFoto = false);

    if (resultado.tieneError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resultado.error!)));
      return;
    }

    if (resultado.usuario != null) {
      setState(() {
        _usuario = resultado.usuario;
      });
      _sincronizarCampos(resultado.usuario!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada.')),
      );
    }
  }

  Future<void> _irAConfiguracionPin() async {
    final UsuarioModelo? usuarioActual = _usuario;
    if (usuarioActual == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PinVista.configurar(usuario: usuarioActual),
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    setState(() => _guardando = true);
    await Supabase.instance.client.auth.signOut();
    await SesionServicio.limpiarSesion();

    if (!mounted) {
      return;
    }

    setState(() => _guardando = false);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<Widget>(builder: (_) => const LoginVista()),
      (_) => false,
    );
  }

  String _inferContentType(String nombreArchivo) {
    final String extension = nombreArchivo.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _alternarTema(bool activarOscuro) async {
    final EconomySafeAppController? controlador = EconomySafeApp.controller(
      context,
    );
    if (controlador == null) {
      return;
    }

    setState(() => _cambiandoTema = true);
    final ThemeMode modo = activarOscuro ? ThemeMode.dark : ThemeMode.light;
    await controlador.actualizarThemeMode(modo);
    if (!mounted) {
      return;
    }
    setState(() => _cambiandoTema = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final UsuarioModelo? usuario = _usuario;
    if (usuario == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.person_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('No pudimos cargar tu perfil en este momento.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _cargarPerfil,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final ThemeData tema = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _cargarPerfil,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool esPantallaAncha = constraints.maxWidth > 600;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(esPantallaAncha ? 32 : 24),
                        child: Column(
                          children: <Widget>[
                            _AvatarPerfil(
                              usuario: usuario,
                              procesando: _actualizandoFoto,
                              onCambiarFoto: _seleccionarFoto,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Administra tu información para mantener tu cuenta segura y personalizada.',
                              style: tema.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(esPantallaAncha ? 32 : 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(
                                'Datos de contacto',
                                style: tema.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _nombreCtrl,
                                textCapitalization: TextCapitalization.words,
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
                                enabled: false,
                                decoration: const InputDecoration(
                                  labelText: 'Correo principal',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _correoSecundarioCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Correo secundario (opcional)',
                                  prefixIcon: Icon(Icons.alternate_email),
                                ),
                                validator: (String? valor) => _controlador
                                    .validarCorreoSecundario(valor ?? ''),
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
                              const SizedBox(height: 24),
                              Text(
                                'Detalles adicionales',
                                style: tema.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _documentoCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Documento de identidad',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _paisCtrl,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'País de residencia',
                                  prefixIcon: Icon(Icons.public),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _monedaCtrl,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Moneda preferida (ej. USD, PEN)',
                                  prefixIcon: Icon(
                                    Icons.monetization_on_outlined,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: _guardando ? null : _guardarCambios,
                                icon: _guardando
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  _guardando ? 'Guardando…' : 'Guardar cambios',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: <Widget>[
                          _TemaListTile(
                            cambiando: _cambiandoTema,
                            onCambio: _alternarTema,
                          ),
                          const Divider(height: 0),
                          ListTile(
                            leading: const Icon(Icons.lock_outline),
                            title: const Text('Configurar PIN de seguridad'),
                            subtitle: Text(
                              usuario.pinHash == null
                                  ? 'Activa un PIN para agilizar tu ingreso de forma segura.'
                                  : 'Actualiza tu PIN en cualquier momento para reforzar la seguridad.',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _irAConfiguracionPin,
                          ),
                          const Divider(height: 0),
                          ListTile(
                            leading: const Icon(Icons.logout),
                            title: const Text('Cerrar sesión'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _guardando ? null : _cerrarSesion,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AvatarPerfil extends StatelessWidget {
  const _AvatarPerfil({
    required this.usuario,
    required this.procesando,
    required this.onCambiarFoto,
  });

  final UsuarioModelo usuario;
  final bool procesando;
  final VoidCallback onCambiarFoto;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final String? fotoUrl = usuario.fotoUrl;

    return Column(
      children: <Widget>[
        Stack(
          alignment: Alignment.center,
          children: <Widget>[
            CircleAvatar(
              radius: 54,
              backgroundColor: tema.colorScheme.primary.withValues(alpha: 0.15),
              backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty
                  ? NetworkImage(fotoUrl)
                  : null,
              child: (fotoUrl == null || fotoUrl.isEmpty)
                  ? Icon(
                      Icons.person_outline,
                      size: 52,
                      color: tema.colorScheme.primary,
                    )
                  : null,
            ),
            if (procesando)
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: tema.colorScheme.surface.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: procesando ? null : onCambiarFoto,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Cambiar foto'),
        ),
      ],
    );
  }
}

class _TemaListTile extends StatelessWidget {
  const _TemaListTile({required this.cambiando, required this.onCambio});

  final bool cambiando;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) {
    final EconomySafeAppController? controlador = EconomySafeApp.controller(
      context,
    );
    final ThemeMode modoActual = controlador?.themeMode ?? ThemeMode.system;
    final Brightness brilloSistema = MediaQuery.of(context).platformBrightness;
    bool estaOscuro;
    if (modoActual == ThemeMode.dark) {
      estaOscuro = true;
    } else if (modoActual == ThemeMode.light) {
      estaOscuro = false;
    } else {
      estaOscuro = brilloSistema == Brightness.dark;
    }

    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: const Text('Tema oscuro'),
      subtitle: Text(
        estaOscuro
            ? 'Activa un contraste suave para ambientes con poca luz.'
            : 'Usa colores claros ideales para espacios bien iluminados.',
      ),
      trailing: cambiando
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch.adaptive(value: estaOscuro, onChanged: onCambio),
    );
  }
}
