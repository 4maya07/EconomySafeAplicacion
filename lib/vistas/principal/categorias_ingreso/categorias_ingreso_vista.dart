import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../modelos/categoria_ingreso_modelo.dart';
import '../../../servicios/categorias_ingreso_servicio.dart';
import '../../../sistema_diseno/identidad_visual.dart';

enum _FiltroFrecuencia { todas, fija, variable }

class CategoriasIngresoVista extends StatefulWidget {
  const CategoriasIngresoVista({super.key});

  @override
  State<CategoriasIngresoVista> createState() => _CategoriasIngresoVistaState();
}

class _CategoriasIngresoVistaState extends State<CategoriasIngresoVista> {
  final CategoriasIngresoServicio _servicio = CategoriasIngresoServicio();
  final List<CategoriaIngresoModelo> _categorias = <CategoriaIngresoModelo>[];
  final TextEditingController _buscadorCtrl = TextEditingController();

  bool _cargando = true;
  bool _procesando = false;
  String? _error;
  _FiltroFrecuencia _filtro = _FiltroFrecuencia.todas;
  FrecuenciaIngreso? _frecuenciaSeleccionada;

  User? get _usuarioActual => Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _buscadorCtrl.addListener(_refrescarEstado);
    _cargarCategorias();
  }

  @override
  void dispose() {
    _buscadorCtrl.dispose();
    super.dispose();
  }

  void _refrescarEstado() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _cargarCategorias() async {
    final User? usuario = _usuarioActual;
    if (usuario == null) {
      setState(() {
        _cargando = false;
        _error = 'Debes iniciar sesión para gestionar tus categorías.';
      });
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final List<CategoriaIngresoModelo> datos = await _servicio
          .obtenerCategorias(usuario.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _categorias
          ..clear()
          ..addAll(datos);
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar las categorías.';
      });
    }
  }

  Iterable<CategoriaIngresoModelo> get _categoriasFiltradas {
    final String termino = _buscadorCtrl.text.trim().toLowerCase();
    return _categorias.where((CategoriaIngresoModelo categoria) {
      final bool coincideBusqueda =
          termino.isEmpty ||
          categoria.nombre.toLowerCase().contains(termino) ||
          (categoria.descripcion ?? '').toLowerCase().contains(termino);

      if (!coincideBusqueda) {
        return false;
      }

      if (_frecuenciaSeleccionada != null &&
          categoria.frecuencia != _frecuenciaSeleccionada) {
        return false;
      }

      switch (_filtro) {
        case _FiltroFrecuencia.todas:
          return true;
        case _FiltroFrecuencia.fija:
          return categoria.frecuencia == FrecuenciaIngreso.quincenal ||
              categoria.frecuencia == FrecuenciaIngreso.mensual;
        case _FiltroFrecuencia.variable:
          return categoria.frecuencia != FrecuenciaIngreso.quincenal &&
              categoria.frecuencia != FrecuenciaIngreso.mensual;
      }
    });
  }

  Map<FrecuenciaIngreso, int> get _totalesPorFrecuencia {
    final Map<FrecuenciaIngreso, int> conteo = <FrecuenciaIngreso, int>{};
    for (final CategoriaIngresoModelo categoria in _categorias) {
      conteo[categoria.frecuencia] = (conteo[categoria.frecuencia] ?? 0) + 1;
    }
    return conteo;
  }

  Future<void> _abrirFormularioNuevaCategoria() async {
    final User? usuario = _usuarioActual;
    if (usuario == null) {
      _mostrarMensaje('Debes iniciar sesión para crear categorías.');
      return;
    }

    final CategoriaIngresoModelo? nueva =
        await showModalBottomSheet<CategoriaIngresoModelo>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return _FormularioCategoriaIngreso(usuarioId: usuario.id);
          },
        );

    if (nueva == null) {
      return;
    }

    setState(() => _procesando = true);

    try {
      final CategoriaIngresoModelo creada = await _servicio.crearCategoria(
        nueva,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _categorias.insert(0, creada);
        _procesando = false;
      });
      _mostrarMensaje('Categoría creada correctamente.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _procesando = false);
      _mostrarMensaje('No se pudo crear la categoría.');
    }
  }

  Future<void> _abrirFormularioEditarCategoria(
    CategoriaIngresoModelo categoria,
  ) async {
    final CategoriaIngresoModelo? actualizada =
        await showModalBottomSheet<CategoriaIngresoModelo>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return _FormularioCategoriaIngreso(
              usuarioId: categoria.usuarioId,
              categoriaInicial: categoria,
            );
          },
        );

    if (actualizada == null || actualizada.id == null) {
      return;
    }

    setState(() => _procesando = true);

    try {
      final CategoriaIngresoModelo modificada = await _servicio
          .actualizarCategoria(actualizada);
      if (!mounted) {
        return;
      }
      setState(() {
        final int indice = _categorias.indexWhere(
          (CategoriaIngresoModelo elemento) => elemento.id == modificada.id,
        );
        if (indice != -1) {
          _categorias[indice] = modificada;
        }
        _procesando = false;
      });
      _mostrarMensaje('Categoría actualizada.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _procesando = false);
      _mostrarMensaje('No se pudo actualizar la categoría.');
    }
  }

  Future<void> _eliminarCategoria(CategoriaIngresoModelo categoria) async {
    if (categoria.id == null) {
      _mostrarMensaje('La categoría seleccionada no es válida.');
      return;
    }

    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar categoría'),
          content: Text(
            '¿Eliminar definitivamente "${categoria.nombre}"? Esta acción no se puede deshacer.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmado != true) {
      return;
    }

    setState(() => _procesando = true);

    try {
      await _servicio.eliminarCategoria(categoria.id!);
      if (!mounted) {
        return;
      }
      setState(() {
        _categorias.removeWhere(
          (CategoriaIngresoModelo elemento) => elemento.id == categoria.id,
        );
        _procesando = false;
      });
      _mostrarMensaje('Categoría eliminada.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _procesando = false);
      _mostrarMensaje('No se pudo eliminar la categoría.');
    }
  }

  Future<void> _mostrarDetallesCategoria(
    CategoriaIngresoModelo categoria,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _DetalleCategoriaIngreso(categoria: categoria);
      },
    );
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías de ingreso'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _procesando ? null : _cargarCategorias,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _procesando ? null : _abrirFormularioNuevaCategoria,
        icon: const Icon(Icons.add),
        label: const Text('Nueva categoría'),
      ),
      body: RefreshIndicator(onRefresh: _cargarCategorias, child: _cuerpo()),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _EstadoError(mensaje: _error!, onReintentar: _cargarCategorias);
    }

    final List<CategoriaIngresoModelo> datos = _categoriasFiltradas.toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ResumenCategorias(totales: _totalesPorFrecuencia),
          const SizedBox(height: 16),
          _BarraFiltros(
            controlador: _buscadorCtrl,
            filtroActual: _filtro,
            frecuenciaSeleccionada: _frecuenciaSeleccionada,
            onFiltroChanged: (_FiltroFrecuencia valor) {
              setState(() => _filtro = valor);
            },
            onFrecuenciaChanged: (FrecuenciaIngreso? valor) {
              setState(() => _frecuenciaSeleccionada = valor);
            },
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: datos.isEmpty
                ? const _EstadoVacio()
                : Column(
                    key: ValueKey<int>(datos.length),
                    children: <Widget>[
                      for (int i = 0; i < datos.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i == datos.length - 1 ? 0 : 12,
                          ),
                          child: _TarjetaCategoriaIngreso(
                            categoria: datos[i],
                            onVer: () => _mostrarDetallesCategoria(datos[i]),
                            onEditar: _procesando
                                ? null
                                : () =>
                                      _abrirFormularioEditarCategoria(datos[i]),
                            onEliminar: _procesando
                                ? null
                                : () => _eliminarCategoria(datos[i]),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResumenCategorias extends StatelessWidget {
  const _ResumenCategorias({required this.totales});

  final Map<FrecuenciaIngreso, int> totales;

  int get totalGeneral => totales.values.fold(0, (int a, int b) => a + b);

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;
    final bool modoOscuro = tema.brightness == Brightness.dark;

    final Color fondo = modoOscuro
        ? ColoresBaseOscuro.fondoTarjetas
        : ColoresBase.fondoTarjetas;
    final Color borde = Bordes.bordeGeneral.withValues(
      alpha: modoOscuro ? 0.2 : 0.55,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
        border: Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Resumen de categorías', style: textos.titleMedium),
          const SizedBox(height: 12),
          Text(
            '$totalGeneral categorías registradas',
            style: textos.headlineMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: FrecuenciaIngreso.values.map((FrecuenciaIngreso freq) {
              final int conteo = totales[freq] ?? 0;
              return Chip(
                label: Text('${frecuenciaIngresoATexto(freq)}: $conteo'),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TarjetaCategoriaIngreso extends StatelessWidget {
  const _TarjetaCategoriaIngreso({
    required this.categoria,
    this.onVer,
    this.onEditar,
    this.onEliminar,
  });

  final CategoriaIngresoModelo categoria;
  final VoidCallback? onVer;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;
    final bool modoOscuro = tema.brightness == Brightness.dark;
    final String descripcion = categoria.descripcion?.trim() ?? '';

    final Color fondo = modoOscuro
        ? ColoresBaseOscuro.fondoTarjetas
        : ColoresBase.fondoTarjetas;
    final Color borde = Bordes.bordeGeneral.withValues(
      alpha: modoOscuro ? 0.2 : 0.55,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
        border: Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(categoria.nombre, style: textos.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      descripcion.isNotEmpty ? descripcion : 'Sin descripción',
                      style: textos.bodySmall,
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  IconButton.outlined(
                    tooltip: 'Ver detalles',
                    onPressed: onVer,
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                  IconButton.outlined(
                    tooltip: 'Editar categoría',
                    onPressed: onEditar,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton.outlined(
                    tooltip: 'Eliminar categoría',
                    onPressed: onEliminar,
                    style: IconButton.styleFrom(
                      foregroundColor: tema.colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Chip(
                avatar: const Icon(Icons.schedule_outlined, size: 18),
                label: Text(frecuenciaIngresoATexto(categoria.frecuencia)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarraFiltros extends StatelessWidget {
  const _BarraFiltros({
    required this.controlador,
    required this.filtroActual,
    required this.frecuenciaSeleccionada,
    required this.onFiltroChanged,
    required this.onFrecuenciaChanged,
  });

  final TextEditingController controlador;
  final _FiltroFrecuencia filtroActual;
  final FrecuenciaIngreso? frecuenciaSeleccionada;
  final ValueChanged<_FiltroFrecuencia> onFiltroChanged;
  final ValueChanged<FrecuenciaIngreso?> onFrecuenciaChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: controlador,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar por nombre o descripción',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            DropdownButtonFormField<_FiltroFrecuencia>(
              initialValue: filtroActual,
              decoration: const InputDecoration(labelText: 'Filtro rápido'),
              items: const <DropdownMenuItem<_FiltroFrecuencia>>[
                DropdownMenuItem(
                  value: _FiltroFrecuencia.todas,
                  child: Text('Todas'),
                ),
                DropdownMenuItem(
                  value: _FiltroFrecuencia.fija,
                  child: Text('Frecuencias fijas'),
                ),
                DropdownMenuItem(
                  value: _FiltroFrecuencia.variable,
                  child: Text('Frecuencias variables'),
                ),
              ],
              onChanged: (_FiltroFrecuencia? valor) {
                if (valor != null) {
                  onFiltroChanged(valor);
                }
              },
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<FrecuenciaIngreso?>(
                initialValue: frecuenciaSeleccionada,
                decoration: const InputDecoration(labelText: 'Frecuencia'),
                items: <DropdownMenuItem<FrecuenciaIngreso?>>[
                  const DropdownMenuItem<FrecuenciaIngreso?>(
                    value: null,
                    child: Text('Todas las frecuencias'),
                  ),
                  ...FrecuenciaIngreso.values.map(
                    (FrecuenciaIngreso frecuencia) =>
                        DropdownMenuItem<FrecuenciaIngreso?>(
                          value: frecuencia,
                          child: Text(frecuenciaIngresoATexto(frecuencia)),
                        ),
                  ),
                ],
                onChanged: onFrecuenciaChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EstadoError extends StatelessWidget {
  const _EstadoError({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Column(
      children: <Widget>[
        const SizedBox(height: 48),
        Icon(
          Icons.inbox_outlined,
          size: 72,
          color: tema.colorScheme.primary.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 16),
        Text(
          'Aún no registras categorías de ingreso',
          style: tema.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Crea una categoría para organizar mejor tus ingresos.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FormularioCategoriaIngreso extends StatefulWidget {
  const _FormularioCategoriaIngreso({
    required this.usuarioId,
    this.categoriaInicial,
  });

  final String usuarioId;
  final CategoriaIngresoModelo? categoriaInicial;

  @override
  State<_FormularioCategoriaIngreso> createState() =>
      _FormularioCategoriaIngresoState();
}

class _FormularioCategoriaIngresoState
    extends State<_FormularioCategoriaIngreso> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  FrecuenciaIngreso _frecuencia = FrecuenciaIngreso.unaVez;

  @override
  void initState() {
    super.initState();
    final CategoriaIngresoModelo? inicial = widget.categoriaInicial;
    _nombreCtrl = TextEditingController(text: inicial?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: inicial?.descripcion ?? '');
    _frecuencia = inicial?.frecuencia ?? FrecuenciaIngreso.unaVez;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  void _enviar() {
    final FormState? estado = _formKey.currentState;
    if (estado == null) {
      return;
    }
    if (!estado.validate()) {
      return;
    }

    final CategoriaIngresoModelo resultado = CategoriaIngresoModelo(
      id: widget.categoriaInicial?.id,
      usuarioId: widget.usuarioId,
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim(),
      frecuencia: _frecuencia,
    );

    Navigator.of(context).pop(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: padding.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(Bordes.radioTarjetas),
            topRight: Radius.circular(Bordes.radioTarjetas),
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  widget.categoriaInicial == null
                      ? 'Nueva categoría de ingreso'
                      : 'Editar categoría de ingreso',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                  validator: (String? valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'Ingresa el nombre de la categoría';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Ej. Sueldos, comisiones, intereses...',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<FrecuenciaIngreso>(
                  initialValue: _frecuencia,
                  decoration: const InputDecoration(labelText: 'Frecuencia *'),
                  items: FrecuenciaIngreso.values
                      .map(
                        (FrecuenciaIngreso frecuencia) => DropdownMenuItem(
                          value: frecuencia,
                          child: Text(frecuenciaIngresoATexto(frecuencia)),
                        ),
                      )
                      .toList(),
                  onChanged: (FrecuenciaIngreso? valor) {
                    if (valor != null) {
                      setState(() => _frecuencia = valor);
                    }
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  onPressed: _enviar,
                  label: Text(
                    widget.categoriaInicial == null
                        ? 'Guardar categoría'
                        : 'Guardar cambios',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetalleCategoriaIngreso extends StatelessWidget {
  const _DetalleCategoriaIngreso({required this.categoria});

  final CategoriaIngresoModelo categoria;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: padding.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(Bordes.radioTarjetas),
            topRight: Radius.circular(Bordes.radioTarjetas),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                categoria.nombre,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                categoria.descripcion?.isNotEmpty == true
                    ? categoria.descripcion!
                    : 'Sin descripción disponible.',
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  const Icon(Icons.schedule_outlined),
                  const SizedBox(width: 8),
                  Text(frecuenciaIngresoATexto(categoria.frecuencia)),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Registrada el ${categoria.creadoEl?.toLocal().toIso8601String().substring(0, 10) ?? 'sin fecha'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
