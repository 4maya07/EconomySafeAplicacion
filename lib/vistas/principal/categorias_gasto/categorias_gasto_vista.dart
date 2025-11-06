import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../modelos/categoria_gasto_modelo.dart';
import '../../../servicios/categorias_gasto_servicio.dart';
import '../../../sistema_diseno/identidad_visual.dart';

enum _FiltroCategoria { todas, dentroLimite, sobreLimite }

class CategoriasGastoVista extends StatefulWidget {
  const CategoriasGastoVista({super.key});

  @override
  State<CategoriasGastoVista> createState() => _CategoriasGastoVistaState();
}

class _CategoriasGastoVistaState extends State<CategoriasGastoVista> {
  final CategoriasGastoServicio _servicio = CategoriasGastoServicio();
  final List<CategoriaGastoModelo> _categorias = <CategoriaGastoModelo>[];
  final TextEditingController _buscadorCtrl = TextEditingController();

  bool _cargando = true;
  bool _procesando = false;
  String? _error;
  _FiltroCategoria _filtro = _FiltroCategoria.todas;
  User? get _usuarioActual => Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
    _buscadorCtrl.addListener(_refrescarEstado);
  }

  @override
  void dispose() {
    _buscadorCtrl.dispose();
    super.dispose();
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
      final List<CategoriaGastoModelo> datos = await _servicio
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

  void _refrescarEstado() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Iterable<CategoriaGastoModelo> get _categoriasFiltradas {
    final String termino = _buscadorCtrl.text.trim().toLowerCase();
    return _categorias.where((CategoriaGastoModelo categoria) {
      final bool coincideBusqueda =
          termino.isEmpty ||
          categoria.nombre.toLowerCase().contains(termino) ||
          (categoria.descripcion ?? '').toLowerCase().contains(termino);

      if (!coincideBusqueda) {
        return false;
      }

      switch (_filtro) {
        case _FiltroCategoria.todas:
          return true;
        case _FiltroCategoria.dentroLimite:
          return !categoria.sobreLimite;
        case _FiltroCategoria.sobreLimite:
          return categoria.sobreLimite;
      }
    });
  }

  Future<void> _abrirFormularioNuevaCategoria() async {
    final User? usuario = _usuarioActual;
    if (usuario == null) {
      _mostrarMensaje('Debes iniciar sesión para crear categorías.');
      return;
    }

    final CategoriaGastoModelo? nueva =
        await showModalBottomSheet<CategoriaGastoModelo>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return _ModalFormularioCategoriaGasto(usuarioId: usuario.id);
          },
        );

    if (nueva == null) {
      return;
    }

    setState(() => _procesando = true);

    try {
      final CategoriaGastoModelo creada = await _servicio.crearCategoria(nueva);
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
      _mostrarMensaje('No se pudo crear la categoría. Inténtalo nuevamente.');
    }
  }

  Future<void> _abrirFormularioEditarCategoria(
    CategoriaGastoModelo categoria,
  ) async {
    final CategoriaGastoModelo? actualizada =
        await showModalBottomSheet<CategoriaGastoModelo>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return _ModalFormularioCategoriaGasto(
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
      final CategoriaGastoModelo modificada = await _servicio
          .actualizarCategoria(actualizada);
      if (!mounted) {
        return;
      }
      setState(() {
        final int indice = _categorias.indexWhere(
          (CategoriaGastoModelo elemento) => elemento.id == modificada.id,
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

  Future<void> _mostrarDetallesCategoria(CategoriaGastoModelo categoria) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _DetalleCategoriaSheet(categoria: categoria);
      },
    );
  }

  Future<void> _eliminarCategoria(CategoriaGastoModelo categoria) async {
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
          (CategoriaGastoModelo elemento) => elemento.id == categoria.id,
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
        title: const Text('Categorías de gasto'),
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

    final List<CategoriaGastoModelo> datos = _categoriasFiltradas.toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _BarraBusquedaFiltros(
            controlador: _buscadorCtrl,
            filtroActual: _filtro,
            onFiltroChanged: (_FiltroCategoria valor) {
              setState(() => _filtro = valor);
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
                          child: _TarjetaCategoriaGasto(
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

class _TarjetaCategoriaGasto extends StatelessWidget {
  const _TarjetaCategoriaGasto({
    required this.categoria,
    this.onVer,
    this.onEditar,
    this.onEliminar,
  });

  final CategoriaGastoModelo categoria;
  final VoidCallback? onVer;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  String _formatear(double monto) => '\\${monto.toStringAsFixed(2)}';
  String _formatearFecha(DateTime fecha) {
    final String dia = fecha.day.toString().padLeft(2, '0');
    final String mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  String? _periodoTexto(CategoriaGastoModelo categoria) {
    if (!categoria.tieneRangoFechas) {
      return null;
    }
    return '${_formatearFecha(categoria.fechaInicio!)} → ${_formatearFecha(categoria.fechaFin!)}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;
    final bool modoOscuro = tema.brightness == Brightness.dark;
    final double porcentaje = categoria.porcentajeConsumido;
    final bool esGastoFijo = categoria.frecuencia != CategoriaFrecuencia.ninguna;

    final Color fondo = modoOscuro
        ? ColoresBaseOscuro.fondoTarjetas
        : ColoresBase.fondoTarjetas;
    final Color borde = Bordes.bordeGeneral.withValues(
      alpha: modoOscuro ? 0.2 : 0.55,
    );
    final Color progresoColor = categoria.sobreLimite
        ? tema.colorScheme.error
        : tema.colorScheme.primary;

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
                    if ((categoria.descripcion ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(categoria.descripcion!, style: textos.bodySmall),
                    ],
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  IconButton.outlined(
                    tooltip: 'Ver detalles',
                    onPressed: onVer,
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                  IconButton.outlined(
                    tooltip: 'Editar',
                    onPressed: onEditar,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton.outlined(
                    tooltip: 'Eliminar',
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
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: porcentaje.isFinite ? porcentaje.clamp(0, 1.2) : 0,
              minHeight: 8,
              backgroundColor: progresoColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(progresoColor),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: <Widget>[
              _DetalleDato(
                titulo: 'Monto máximo',
                valor: _formatear(categoria.montoMaximo),
                icono: Icons.flag_outlined,
              ),
              if (!esGastoFijo)
                _DetalleDato(
                  titulo: 'Gastado',
                  valor: _formatear(categoria.montoGastado),
                  icono: Icons.payments_outlined,
                ),
              if (!esGastoFijo)
                _DetalleDato(
                  titulo: 'Extra permitido',
                  valor: _formatear(categoria.montoAdicionalPermitido),
                  icono: Icons.trending_up_outlined,
                ),
              _DetalleDato(
                titulo: 'Porcentaje consumido',
                valor: '${(porcentaje * 100).toStringAsFixed(1)}%',
                icono: Icons.percent,
              ),
              _DetalleDato(
                titulo: 'Frecuencia',
                valor: categoria.etiquetaFrecuencia,
                icono: Icons.event_repeat_outlined,
              ),
              if (_periodoTexto(categoria) != null)
                _DetalleDato(
                  titulo: 'Periodo',
                  valor: _periodoTexto(categoria)!,
                  icono: Icons.calendar_month_outlined,
                ),
            ],
          ),
          if (categoria.sobreLimite)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tema.colorScheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_outlined,
                    color: tema.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Has excedido el monto máximo definido para esta categoría.',
                      style: textos.bodySmall?.copyWith(
                        color: tema.colorScheme.error,
                      ),
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

class _DetalleDato extends StatelessWidget {
  const _DetalleDato({
    required this.titulo,
    required this.valor,
    required this.icono,
  });

  final String titulo;
  final String valor;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;

    return SizedBox(
      width: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icono, size: 20, color: tema.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(titulo, style: textos.labelMedium),
                const SizedBox(height: 2),
                Text(valor, style: textos.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraBusquedaFiltros extends StatelessWidget {
  const _BarraBusquedaFiltros({
    required this.controlador,
    required this.filtroActual,
    required this.onFiltroChanged,
  });

  final TextEditingController controlador;
  final _FiltroCategoria filtroActual;
  final ValueChanged<_FiltroCategoria> onFiltroChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final ColorScheme esquema = tema.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: controlador,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Buscar por nombre o descripción',
            suffixIcon: controlador.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar',
                    onPressed: controlador.clear,
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: <Widget>[
            ChoiceChip(
              label: const Text('Todas'),
              selected: filtroActual == _FiltroCategoria.todas,
              onSelected: (_) => onFiltroChanged(_FiltroCategoria.todas),
            ),
            ChoiceChip(
              label: const Text('Dentro del límite'),
              selected: filtroActual == _FiltroCategoria.dentroLimite,
              onSelected: (_) => onFiltroChanged(_FiltroCategoria.dentroLimite),
            ),
            ChoiceChip(
              label: const Text('Sobre el límite'),
              selected: filtroActual == _FiltroCategoria.sobreLimite,
              onSelected: (_) => onFiltroChanged(_FiltroCategoria.sobreLimite),
              selectedColor: esquema.error.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: filtroActual == _FiltroCategoria.sobreLimite
                    ? esquema.error
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
        border: Border.all(color: Bordes.bordeGeneral.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.category_outlined,
            size: 48,
            color: tema.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin categorías registradas',
            style: textos.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tus primeras categorías para controlar tus gastos por rubro.',
            style: textos.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EstadoError extends StatelessWidget {
  const _EstadoError({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 16),
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

class _DetalleCategoriaSheet extends StatelessWidget {
  const _DetalleCategoriaSheet({required this.categoria});

  final CategoriaGastoModelo categoria;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;
    final bool esGastoFijo = categoria.frecuencia != CategoriaFrecuencia.ninguna;

    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(categoria.nombre, style: textos.headlineSmall),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if ((categoria.descripcion ?? '').isNotEmpty)
                Text(categoria.descripcion!, style: textos.bodyMedium),
              const SizedBox(height: 16),
              _DetalleDato(
                titulo: 'Monto máximo',
                valor: '\\${categoria.montoMaximo.toStringAsFixed(2)}',
                icono: Icons.flag_outlined,
              ),
              const SizedBox(height: 8),
              if (!esGastoFijo) ...<Widget>[
                _DetalleDato(
                  titulo: 'Gastado',
                  valor: '\\${categoria.montoGastado.toStringAsFixed(2)}',
                  icono: Icons.payments_outlined,
                ),
                const SizedBox(height: 8),
                _DetalleDato(
                  titulo: 'Extra permitido',
                  valor:
                      '\\${categoria.montoAdicionalPermitido.toStringAsFixed(2)}',
                  icono: Icons.trending_up_outlined,
                ),
                const SizedBox(height: 8),
              ],
              _DetalleDato(
                titulo: 'Porcentaje consumido',
                valor:
                    '${(categoria.porcentajeConsumido * 100).toStringAsFixed(1)}%',
                icono: Icons.percent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalFormularioCategoriaGasto extends StatefulWidget {
  const _ModalFormularioCategoriaGasto({
    required this.usuarioId,
    this.categoriaInicial,
  });

  final String usuarioId;
  final CategoriaGastoModelo? categoriaInicial;

  @override
  State<_ModalFormularioCategoriaGasto> createState() =>
      _ModalFormularioCategoriaGastoState();
}

class _ModalFormularioCategoriaGastoState
    extends State<_ModalFormularioCategoriaGasto> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _descripcionCtrl = TextEditingController();
  final TextEditingController _montoMaximoCtrl = TextEditingController();
  final TextEditingController _montoGastadoCtrl = TextEditingController();
  final TextEditingController _montoAdicionalCtrl = TextEditingController();
  final TextEditingController _fechaInicioCtrl = TextEditingController();
  final TextEditingController _fechaFinCtrl = TextEditingController();

  CategoriaFrecuencia _frecuencia = CategoriaFrecuencia.ninguna;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  bool get _esEdicion => widget.categoriaInicial != null;

  @override
  void initState() {
    super.initState();
    final CategoriaGastoModelo? categoria = widget.categoriaInicial;
    if (categoria != null) {
      _nombreCtrl.text = categoria.nombre;
      _descripcionCtrl.text = categoria.descripcion ?? '';
      _montoMaximoCtrl.text = categoria.montoMaximo.toStringAsFixed(2);
      _montoGastadoCtrl.text = categoria.montoGastado.toStringAsFixed(2);
      _montoAdicionalCtrl.text = categoria.montoAdicionalPermitido
          .toStringAsFixed(2);
      _frecuencia = categoria.frecuencia;
      _fechaInicio = categoria.fechaInicio;
      _fechaFin = categoria.fechaFin;
      if (_fechaInicio != null) {
        _fechaInicioCtrl.text = _formatearFecha(_fechaInicio!);
      }
      if (_fechaFin != null) {
        _fechaFinCtrl.text = _formatearFecha(_fechaFin!);
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _montoMaximoCtrl.dispose();
    _montoGastadoCtrl.dispose();
    _montoAdicionalCtrl.dispose();
    _fechaInicioCtrl.dispose();
    _fechaFinCtrl.dispose();
    super.dispose();
  }

  double? _obtenerMonto(String valor) {
    return double.tryParse(valor.replaceAll(',', '.'));
  }

  String _formatearFecha(DateTime fecha) {
    final String dia = fecha.day.toString().padLeft(2, '0');
    final String mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  Future<void> _seleccionarFecha({required bool esInicio}) async {
    final DateTime now = DateTime.now();
    final DateTime? seleccionada = await showDatePicker(
      context: context,
      initialDate: esInicio ? (_fechaInicio ?? now) : (_fechaFin ?? now),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      locale: Localizations.localeOf(context),
    );

    if (seleccionada == null) {
      return;
    }

    setState(() {
      if (esInicio) {
        _fechaInicio = seleccionada;
        _fechaInicioCtrl.text = _formatearFecha(seleccionada);
        if (_fechaFin != null && _fechaFin!.isBefore(seleccionada)) {
          _fechaFin = seleccionada;
          _fechaFinCtrl.text = _formatearFecha(seleccionada);
        }
      } else {
        _fechaFin = seleccionada;
        _fechaFinCtrl.text = _formatearFecha(seleccionada);
      }
    });
  }

  void _guardar() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final bool esGastoFijo = _frecuencia != CategoriaFrecuencia.ninguna;

    if (esGastoFijo) {
      if (_fechaInicio == null || _fechaFin == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Define la fecha de inicio y fin para la categoría.'),
          ),
        );
        return;
      }
      if (_fechaFin!.isBefore(_fechaInicio!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La fecha fin debe ser posterior a la fecha inicio.'),
          ),
        );
        return;
      }
    } else {
      _fechaInicio = null;
      _fechaFin = null;
    }

    final double montoMaximo = _obtenerMonto(_montoMaximoCtrl.text) ?? 0;
    final double montoGastado = esGastoFijo
        ? 0
        : _obtenerMonto(_montoGastadoCtrl.text) ?? 0;
    final double montoAdicional = esGastoFijo
        ? 0
        : _obtenerMonto(_montoAdicionalCtrl.text) ?? 0;

    if (esGastoFijo) {
      _montoGastadoCtrl.text = '0.00';
      _montoAdicionalCtrl.text = '0.00';
    }

    final CategoriaGastoModelo base =
        widget.categoriaInicial ??
        CategoriaGastoModelo(
          usuarioId: widget.usuarioId,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim().isEmpty
              ? null
              : _descripcionCtrl.text.trim(),
          montoMaximo: montoMaximo,
          montoGastado: montoGastado,
          montoAdicionalPermitido: montoAdicional,
          frecuencia: _frecuencia,
          fechaInicio: _fechaInicio,
          fechaFin: _fechaFin,
        );

    final CategoriaGastoModelo resultado = base.copiarCon(
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim(),
      montoMaximo: montoMaximo,
      montoGastado: montoGastado,
      montoAdicionalPermitido: montoAdicional,
      frecuencia: _frecuencia,
      fechaInicio: _fechaInicio,
      fechaFin: _fechaFin,
    );

    Navigator.of(context).pop(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final bool esGastoFijo = _frecuencia != CategoriaFrecuencia.ninguna;

    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: tema.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      _esEdicion
                          ? 'Editar categoría de gasto'
                          : 'Nueva categoría de gasto',
                      style: tema.textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la categoría',
                  ),
                  validator: (String? valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'Ingresa un nombre válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CategoriaFrecuencia>(
                  value: _frecuencia,
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia / periodicidad',
                  ),
                  items: const <DropdownMenuItem<CategoriaFrecuencia>>[
                    DropdownMenuItem(
                      value: CategoriaFrecuencia.ninguna,
                      child: Text('Sin periodicidad'),
                    ),
                    DropdownMenuItem(
                      value: CategoriaFrecuencia.mensual,
                      child: Text('Mensual'),
                    ),
                    DropdownMenuItem(
                      value: CategoriaFrecuencia.bimestral,
                      child: Text('Bimestral'),
                    ),
                    DropdownMenuItem(
                      value: CategoriaFrecuencia.trimestral,
                      child: Text('Trimestral'),
                    ),
                    DropdownMenuItem(
                      value: CategoriaFrecuencia.cuatrimestral,
                      child: Text('Cuatrimestral'),
                    ),
                    DropdownMenuItem(
                      value: CategoriaFrecuencia.anual,
                      child: Text('Anual'),
                    ),
                    DropdownMenuItem(
                      value: CategoriaFrecuencia.personalizada,
                      child: Text('Rango personalizado'),
                    ),
                  ],
                  onChanged: (CategoriaFrecuencia? valor) {
                    if (valor == null) {
                      return;
                    }
                    setState(() {
                      _frecuencia = valor;
                      if (_frecuencia != CategoriaFrecuencia.ninguna) {
                        _montoGastadoCtrl.text = '0.00';
                        _montoAdicionalCtrl.text = '0.00';
                      }
                    });
                  },
                ),
                if (esGastoFijo) ...<Widget>[
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _fechaInicioCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Fecha de inicio',
                            hintText: 'Selecciona la fecha inicial',
                          ),
                          onTap: () => _seleccionarFecha(esInicio: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _fechaFinCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Fecha de fin',
                            hintText: 'Selecciona la fecha final',
                          ),
                          onTap: () => _seleccionarFecha(esInicio: false),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _montoMaximoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Monto máximo de gasto',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (String? valor) {
                    final double? monto = _obtenerMonto(valor ?? '');
                    if (monto == null || monto <= 0) {
                      return 'Ingresa un monto mayor a cero';
                    }
                    return null;
                  },
                ),
                if (!esGastoFijo) ...<Widget>[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _montoGastadoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Monto gastado a la fecha',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (String? valor) {
                      final double? monto = _obtenerMonto(valor ?? '');
                      if (monto == null || monto < 0) {
                        return 'Ingresa un monto válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _montoAdicionalCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Monto adicional permitido',
                      helperText:
                          'Cantidad extra que puedes gastar si sobrepasas el límite.',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (String? valor) {
                      if ((valor ?? '').trim().isEmpty) {
                        return null;
                      }
                      final double? monto = _obtenerMonto(valor!);
                      if (monto == null || monto < 0) {
                        return 'Ingresa un monto adicional válido';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _guardar,
                    icon: Icon(_esEdicion ? Icons.save_outlined : Icons.add),
                    label: Text(_esEdicion ? 'Guardar cambios' : 'Crear'),
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
