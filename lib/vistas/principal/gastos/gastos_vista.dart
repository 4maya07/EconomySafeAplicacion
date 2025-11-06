import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../modelos/categoria_gasto_modelo.dart';
import '../../../modelos/cuenta_bancaria_modelo.dart';
import '../../../modelos/gasto_modelo.dart';
import '../../../servicios/categorias_gasto_servicio.dart';
import '../../../servicios/cuentas_servicio.dart';
import '../../../servicios/gastos_servicio.dart';
import '../../../sistema_diseno/identidad_visual.dart';

enum _FiltroMedio { todos, efectivo, banco }

class GastosVista extends StatefulWidget {
  const GastosVista({
    super.key,
    this.abrirFormularioAlIniciar = false,
    this.onGastosActualizados,
  });

  final bool abrirFormularioAlIniciar;
  final VoidCallback? onGastosActualizados;

  @override
  State<GastosVista> createState() => _GastosVistaState();
}

class _GastosVistaState extends State<GastosVista> {
  final GastosServicio _gastosServicio = GastosServicio();
  final CategoriasGastoServicio _categoriasServicio = CategoriasGastoServicio();
  final CuentasServicio _cuentasServicio = CuentasServicio();

  final List<GastoModelo> _gastos = <GastoModelo>[];
  final List<CategoriaGastoModelo> _categorias = <CategoriaGastoModelo>[];
  final List<CuentaBancariaModelo> _cuentas = <CuentaBancariaModelo>[];
  final TextEditingController _buscadorCtrl = TextEditingController();

  bool _cargando = true;
  bool _procesando = false;
  String? _error;
  _FiltroMedio _filtroMedio = _FiltroMedio.todos;
  String? _filtroCategoriaId;

  User? get _usuarioActual => Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _buscadorCtrl.addListener(_refrescarEstado);
    _cargarDatosIniciales();
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

  Future<void> _cargarDatosIniciales() async {
    final User? usuario = _usuarioActual;
    if (usuario == null) {
      setState(() {
        _cargando = false;
        _error = 'Debes iniciar sesión para gestionar tus gastos.';
      });
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final List<dynamic> respuestas = await Future.wait(<Future<dynamic>>[
        _gastosServicio.obtenerGastos(usuario.id),
        _categoriasServicio.obtenerCategorias(usuario.id),
        _cuentasServicio.obtenerCuentas(usuario.id),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _gastos
          ..clear()
          ..addAll(respuestas[0] as List<GastoModelo>);
        _categorias
          ..clear()
          ..addAll(respuestas[1] as List<CategoriaGastoModelo>);
        _cuentas
          ..clear()
          ..addAll(respuestas[2] as List<CuentaBancariaModelo>);
        _cargando = false;
      });

      if (widget.abrirFormularioAlIniciar && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await _abrirFormularioNuevoGasto();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar los gastos. Intenta nuevamente.';
      });
    }
  }

  Future<void> _recargarGastos() async {
    final User? usuario = _usuarioActual;
    if (usuario == null) {
      return;
    }
    try {
      final List<GastoModelo> datos =
          await _gastosServicio.obtenerGastos(usuario.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _gastos
          ..clear()
          ..addAll(datos);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _mostrarMensaje('No se pudieron actualizar los gastos.');
    }
  }

  Iterable<GastoModelo> get _gastosFiltrados {
    final String termino = _buscadorCtrl.text.trim().toLowerCase();
    return _gastos.where((GastoModelo gasto) {
      final bool coincideBusqueda = termino.isEmpty ||
          (gasto.descripcion ?? '').toLowerCase().contains(termino) ||
          gasto.categoriaNombre?.toLowerCase().contains(termino) == true ||
          gasto.cuentaNombre?.toLowerCase().contains(termino) == true;

      if (!coincideBusqueda) {
        return false;
      }

      if (_filtroCategoriaId != null && gasto.categoriaId != _filtroCategoriaId) {
        return false;
      }

      switch (_filtroMedio) {
        case _FiltroMedio.todos:
          return true;
        case _FiltroMedio.efectivo:
          return gasto.medioPago == MedioPagoGasto.efectivo;
        case _FiltroMedio.banco:
          return gasto.medioPago == MedioPagoGasto.banco;
      }
    });
  }

  Future<void> _abrirFormularioNuevoGasto() async {
    final User? usuario = _usuarioActual;
    if (usuario == null) {
      _mostrarMensaje('Debes iniciar sesión para registrar gastos.');
      return;
    }

    if (_categorias.isEmpty) {
      _mostrarMensaje('Primero crea una categoría de gasto.');
      return;
    }

    final GastoModelo? creado = await showModalBottomSheet<GastoModelo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _FormularioGastoSheet(
          usuarioId: usuario.id,
          categorias: _categorias,
          cuentas: _cuentas,
        );
      },
    );

    if (creado == null) {
      return;
    }

    setState(() => _procesando = true);

    try {
      final GastoModelo nuevo = await _gastosServicio.crearGasto(creado);
      if (!mounted) {
        return;
      }
      setState(() {
        _gastos.insert(0, nuevo);
        _procesando = false;
      });
      _mostrarMensaje('Gasto registrado correctamente.');
      widget.onGastosActualizados?.call();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _procesando = false);
      _mostrarMensaje('No se pudo registrar el gasto.');
    }
  }

  Future<void> _abrirFormularioEditarGasto(GastoModelo gasto) async {
    final GastoModelo? actualizado = await showModalBottomSheet<GastoModelo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _FormularioGastoSheet(
          usuarioId: gasto.usuarioId,
          categorias: _categorias,
          cuentas: _cuentas,
          gastoInicial: gasto,
        );
      },
    );

    if (actualizado == null || actualizado.id == null) {
      return;
    }

    setState(() => _procesando = true);

    try {
      final GastoModelo modificado =
          await _gastosServicio.actualizarGasto(actualizado);
      if (!mounted) {
        return;
      }
      setState(() {
        final int indice =
            _gastos.indexWhere((GastoModelo item) => item.id == modificado.id);
        if (indice != -1) {
          _gastos[indice] = modificado;
        }
        _procesando = false;
      });
      _mostrarMensaje('Gasto actualizado.');
      widget.onGastosActualizados?.call();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _procesando = false);
      _mostrarMensaje('No se pudo actualizar el gasto.');
    }
  }

  Future<void> _eliminarGasto(GastoModelo gasto) async {
    if (gasto.id == null) {
      _mostrarMensaje('El gasto seleccionado no es válido.');
      return;
    }

    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar gasto'),
          content: const Text(
            'Esta acción revertirá los saldos relacionados. ¿Deseas continuar?',
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
      await _gastosServicio.eliminarGasto(
        gastoId: gasto.id!,
        usuarioId: gasto.usuarioId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _gastos.removeWhere((GastoModelo item) => item.id == gasto.id);
        _procesando = false;
      });
      _mostrarMensaje('Gasto eliminado.');
      widget.onGastosActualizados?.call();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _procesando = false);
      _mostrarMensaje('No se pudo eliminar el gasto.');
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
        title: const Text('Gastos'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _procesando ? null : _recargarGastos,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _procesando ? null : _abrirFormularioNuevoGasto,
        icon: const Icon(Icons.add),
        label: const Text('Registrar gasto'),
      ),
      body: RefreshIndicator(onRefresh: _recargarGastos, child: _cuerpo()),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _EstadoError(mensaje: _error!, onReintentar: _cargarDatosIniciales);
    }

    final List<GastoModelo> datos = _gastosFiltrados.toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _BarraFiltros(
            controladorBusqueda: _buscadorCtrl,
            categorias: _categorias,
            filtroMedio: _filtroMedio,
            categoriaSeleccionada: _filtroCategoriaId,
            onMedioChanged: (_FiltroMedio valor) {
              setState(() => _filtroMedio = valor);
            },
            onCategoriaChanged: (String? id) {
              setState(() => _filtroCategoriaId = id);
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
                          child: _TarjetaGasto(
                            gasto: datos[i],
                            onEditar: _procesando
                                ? null
                                : () => _abrirFormularioEditarGasto(datos[i]),
                            onEliminar: _procesando
                                ? null
                                : () => _eliminarGasto(datos[i]),
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

class _TarjetaGasto extends StatelessWidget {
  const _TarjetaGasto({
    required this.gasto,
    this.onEditar,
    this.onEliminar,
  });

  final GastoModelo gasto;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  String _formatearMonto(double monto) => '\\${monto.toStringAsFixed(2)}';

  String _formatearFecha(DateTime fecha) {
    const List<String> meses = <String>[
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${fecha.day.toString().padLeft(2, '0')} ${meses[fecha.month - 1]} ${fecha.year}';
  }

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      gasto.categoriaNombre ?? 'Sin categoría',
                      style: textos.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      gasto.descripcion?.isNotEmpty == true
                          ? gasto.descripcion!
                          : 'Sin descripción',
                      style: textos.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Icon(
                          gasto.medioPago == MedioPagoGasto.banco
                              ? Icons.account_balance_wallet_outlined
                              : Icons.payments_outlined,
                          size: 18,
                          color: tema.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            gasto.cuentaNombre ??
                                (gasto.medioPago == MedioPagoGasto.banco
                                    ? 'Cuenta desconocida'
                                    : 'Efectivo'),
                            style: textos.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    _formatearMonto(gasto.monto),
                    style: textos.titleLarge?.copyWith(
                      color: tema.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_formatearFecha(gasto.fecha), style: textos.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    gasto.tipoGasto == ClasificacionGasto.fijo
                        ? 'Gasto fijo'
                        : 'Gasto variable',
                    style: textos.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton.icon(
                onPressed: onEditar,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onEliminar,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar'),
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
    required this.controladorBusqueda,
    required this.categorias,
    required this.filtroMedio,
    required this.categoriaSeleccionada,
    required this.onMedioChanged,
    required this.onCategoriaChanged,
  });

  final TextEditingController controladorBusqueda;
  final List<CategoriaGastoModelo> categorias;
  final _FiltroMedio filtroMedio;
  final String? categoriaSeleccionada;
  final ValueChanged<_FiltroMedio> onMedioChanged;
  final ValueChanged<String?> onCategoriaChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: controladorBusqueda,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar por descripción, categoría o cuenta',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            DropdownButtonFormField<_FiltroMedio>(
              initialValue: filtroMedio,
              decoration: const InputDecoration(labelText: 'Medio de pago'),
              items: const <DropdownMenuItem<_FiltroMedio>>[
                DropdownMenuItem(
                  value: _FiltroMedio.todos,
                  child: Text('Todos'),
                ),
                DropdownMenuItem(
                  value: _FiltroMedio.efectivo,
                  child: Text('Efectivo'),
                ),
                DropdownMenuItem(
                  value: _FiltroMedio.banco,
                  child: Text('Bancarios'),
                ),
              ],
              onChanged: (_FiltroMedio? valor) {
                if (valor != null) {
                  onMedioChanged(valor);
                }
              },
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String?>(
                initialValue: categoriaSeleccionada,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                ),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas las categorías'),
                  ),
                  ...categorias.map(
                    (CategoriaGastoModelo categoria) => DropdownMenuItem<String>(
                      value: categoria.id,
                      child: Text(categoria.nombre),
                    ),
                  ),
                ],
                onChanged: onCategoriaChanged,
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
            FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
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
          Icons.receipt_long_outlined,
          size: 72,
          color: tema.colorScheme.primary.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 16),
        Text(
          'Aún no registras gastos',
          style: tema.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Comienza registrando tu primer gasto para controlar mejor tu presupuesto.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FormularioGastoSheet extends StatefulWidget {
  const _FormularioGastoSheet({
    required this.usuarioId,
    required this.categorias,
    required this.cuentas,
    this.gastoInicial,
  });

  final String usuarioId;
  final List<CategoriaGastoModelo> categorias;
  final List<CuentaBancariaModelo> cuentas;
  final GastoModelo? gastoInicial;

  @override
  State<_FormularioGastoSheet> createState() => _FormularioGastoSheetState();
}

class _FormularioGastoSheetState extends State<_FormularioGastoSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _montoCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _fotoUrlCtrl;

  String? _categoriaId;
  String? _cuentaId;
  MedioPagoGasto _medioPago = MedioPagoGasto.efectivo;
  FrecuenciaGasto _frecuencia = FrecuenciaGasto.unaVez;
  ClasificacionGasto _tipoGasto = ClasificacionGasto.variable;
  DateTime _fecha = DateTime.now();

  @override
  void initState() {
    super.initState();
    final GastoModelo? inicial = widget.gastoInicial;
    _categoriaId = inicial?.categoriaId;
    _cuentaId = inicial?.cuentaId;
    _medioPago = inicial?.medioPago ?? MedioPagoGasto.efectivo;
    _frecuencia = inicial?.frecuencia ?? FrecuenciaGasto.unaVez;
    _tipoGasto = inicial?.tipoGasto ?? ClasificacionGasto.variable;
    _fecha = inicial?.fecha ?? DateTime.now();

    _montoCtrl = TextEditingController(
      text: inicial != null ? inicial.monto.toStringAsFixed(2) : '',
    );
    _descripcionCtrl = TextEditingController(text: inicial?.descripcion ?? '');
    _fotoUrlCtrl = TextEditingController(text: inicial?.fotoUrl ?? '');
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _descripcionCtrl.dispose();
    _fotoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? seleccionada = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (seleccionada != null) {
      setState(() => _fecha = seleccionada);
    }
  }

  void _enviar() {
    final FormState? estado = _formKey.currentState;
    if (estado == null) {
      return;
    }
    if (!estado.validate()) {
      return;
    }

    final double monto = double.parse(_montoCtrl.text.replaceAll(',', '.'));
    final MedioPagoGasto medio = _medioPago;
    final String? cuentaSeleccionada = medio == MedioPagoGasto.banco
        ? _cuentaId
        : null;

    CuentaBancariaModelo? cuentaSeleccionadaModelo;
    if (cuentaSeleccionada != null) {
      for (final CuentaBancariaModelo cuenta in widget.cuentas) {
        if (cuenta.id == cuentaSeleccionada) {
          cuentaSeleccionadaModelo = cuenta;
          break;
        }
      }
    }

    final GastoModelo resultado = GastoModelo(
      id: widget.gastoInicial?.id,
      usuarioId: widget.usuarioId,
      categoriaId: _categoriaId!,
      categoriaNombre: widget.categorias
          .firstWhere((CategoriaGastoModelo cat) => cat.id == _categoriaId)
          .nombre,
      cuentaId: cuentaSeleccionada,
    cuentaNombre: cuentaSeleccionadaModelo?.descripcionSeleccion,
      monto: monto,
      descripcion: _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim(),
      medioPago: medio,
      frecuencia: _frecuencia,
      tipoGasto: _tipoGasto,
      fecha: _fecha,
      fotoUrl: _fotoUrlCtrl.text.trim().isEmpty
          ? null
          : _fotoUrlCtrl.text.trim(),
    );

    Navigator.of(context).pop(resultado);
  }

  String _textoFecha(DateTime fecha) {
    const List<String> meses = <String>[
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}';
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
                  widget.gastoInicial == null
                      ? 'Registrar gasto'
                      : 'Editar gasto',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _categoriaId,
                  decoration: const InputDecoration(labelText: 'Categoría *'),
                  items: widget.categorias
                      .map(
                        (CategoriaGastoModelo categoria) => DropdownMenuItem<String>(
                          value: categoria.id,
                          child: Text(categoria.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (String? valor) => setState(() => _categoriaId = valor),
                  validator: (String? valor) {
                    if (valor == null || valor.isEmpty) {
                      return 'Selecciona una categoría';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _montoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Monto *',
                    prefixText: '\\',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (String? valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'Ingresa el monto del gasto';
                    }
                    final double? monto =
                        double.tryParse(valor.replaceAll(',', '.'));
                    if (monto == null || monto <= 0) {
                      return 'Ingresa un monto válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<MedioPagoGasto>(
                  initialValue: _medioPago,
                  decoration: const InputDecoration(labelText: 'Medio de pago *'),
                  items: const <DropdownMenuItem<MedioPagoGasto>>[
                    DropdownMenuItem(
                      value: MedioPagoGasto.efectivo,
                      child: Text('Efectivo'),
                    ),
                    DropdownMenuItem(
                      value: MedioPagoGasto.banco,
                      child: Text('Cuenta bancaria'),
                    ),
                  ],
                  onChanged: (MedioPagoGasto? valor) {
                    if (valor == null) {
                      return;
                    }
                    setState(() {
                      _medioPago = valor;
                      if (valor == MedioPagoGasto.efectivo) {
                        _cuentaId = null;
                      }
                    });
                  },
                ),
                if (_medioPago == MedioPagoGasto.banco) ...<Widget>[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _cuentaId,
                    decoration: const InputDecoration(labelText: 'Cuenta bancaria *'),
                    items: widget.cuentas
                        .map(
                          (CuentaBancariaModelo cuenta) => DropdownMenuItem<String>(
                            value: cuenta.id,
                            child: Text(cuenta.descripcionSeleccion),
                          ),
                        )
                        .toList(),
                    onChanged: (String? valor) => setState(() => _cuentaId = valor),
                    validator: (String? valor) {
                      if (_medioPago == MedioPagoGasto.banco &&
                          (valor == null || valor.isEmpty)) {
                        return 'Selecciona la cuenta utilizada';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<FrecuenciaGasto>(
                  initialValue: _frecuencia,
                  decoration: const InputDecoration(labelText: 'Frecuencia *'),
                  items: const <DropdownMenuItem<FrecuenciaGasto>>[
                    DropdownMenuItem(
                      value: FrecuenciaGasto.unaVez,
                      child: Text('Una vez'),
                    ),
                    DropdownMenuItem(
                      value: FrecuenciaGasto.semanal,
                      child: Text('Semanal'),
                    ),
                    DropdownMenuItem(
                      value: FrecuenciaGasto.mensual,
                      child: Text('Mensual'),
                    ),
                    DropdownMenuItem(
                      value: FrecuenciaGasto.trimestral,
                      child: Text('Trimestral'),
                    ),
                    DropdownMenuItem(
                      value: FrecuenciaGasto.otro,
                      child: Text('Otro'),
                    ),
                  ],
                  onChanged: (FrecuenciaGasto? valor) {
                    if (valor != null) {
                      setState(() => _frecuencia = valor);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ClasificacionGasto>(
                  initialValue: _tipoGasto,
                  decoration: const InputDecoration(labelText: 'Tipo de gasto *'),
                  items: const <DropdownMenuItem<ClasificacionGasto>>[
                    DropdownMenuItem(
                      value: ClasificacionGasto.fijo,
                      child: Text('Fijo'),
                    ),
                    DropdownMenuItem(
                      value: ClasificacionGasto.variable,
                      child: Text('Variable'),
                    ),
                  ],
                  onChanged: (ClasificacionGasto? valor) {
                    if (valor != null) {
                      setState(() => _tipoGasto = valor);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Ej. Pago de servicio de internet',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fotoUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL del comprobante',
                    hintText: 'Opcional. Enlace a la foto del recibo',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha del gasto'),
                  subtitle: Text(_textoFecha(_fecha)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _seleccionarFecha,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  onPressed: _enviar,
                  label: Text(widget.gastoInicial == null
                      ? 'Guardar gasto'
                      : 'Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
