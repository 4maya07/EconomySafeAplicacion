import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../modelos/categoria_ingreso_modelo.dart' as cat_ingreso;
import '../../../modelos/cuenta_bancaria_modelo.dart';
import '../../../modelos/ingreso_modelo.dart';
import '../../../servicios/categorias_ingreso_servicio.dart';
import '../../../servicios/cuentas_servicio.dart';
import '../../../servicios/ingresos_servicio.dart';
import '../../../sistema_diseno/identidad_visual.dart';

enum _FiltroMedioIngreso { todos, efectivo, banco }

enum _FiltroFrecuenciaIngreso {
  todas,
  unaVez,
  semanal,
  mensual,
  trimestral,
  anual,
}

class IngresosVista extends StatefulWidget {
  const IngresosVista({
    super.key,
    this.abrirFormularioAlIniciar = false,
    this.onIngresosActualizados,
  });

  final bool abrirFormularioAlIniciar;
  final VoidCallback? onIngresosActualizados;

  @override
  State<IngresosVista> createState() => _IngresosVistaState();
}

class _IngresosVistaState extends State<IngresosVista> {
  final IngresosServicio _ingresosServicio = IngresosServicio();
  final CategoriasIngresoServicio _categoriasServicio =
      CategoriasIngresoServicio();
  final CuentasServicio _cuentasServicio = CuentasServicio();

  final List<IngresoModelo> _ingresos = <IngresoModelo>[];
  final List<cat_ingreso.CategoriaIngresoModelo> _categorias =
      <cat_ingreso.CategoriaIngresoModelo>[];
  final List<CuentaBancariaModelo> _cuentas = <CuentaBancariaModelo>[];
  final TextEditingController _buscadorCtrl = TextEditingController();

  bool _cargando = true;
  bool _procesando = false;
  String? _error;
  _FiltroMedioIngreso _filtroMedio = _FiltroMedioIngreso.todos;
  _FiltroFrecuenciaIngreso _filtroFrecuencia = _FiltroFrecuenciaIngreso.todas;
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
        _error = 'Debes iniciar sesión para gestionar tus ingresos.';
      });
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final List<dynamic> respuestas = await Future.wait(<Future<dynamic>>[
        _ingresosServicio.obtenerIngresos(usuario.id),
        _categoriasServicio.obtenerCategorias(usuario.id),
        _cuentasServicio.obtenerCuentas(usuario.id),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _ingresos
          ..clear()
          ..addAll(respuestas[0] as List<IngresoModelo>);
        _categorias
          ..clear()
          ..addAll(respuestas[1] as List<cat_ingreso.CategoriaIngresoModelo>);
        _cuentas
          ..clear()
          ..addAll(respuestas[2] as List<CuentaBancariaModelo>);
        _cargando = false;
      });

      if (widget.abrirFormularioAlIniciar && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await _abrirFormularioNuevoIngreso();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar los ingresos. Intenta nuevamente.';
      });
    }
  }

  Future<void> _recargarIngresos() async {
    final User? usuario = _usuarioActual;
    if (usuario == null) {
      return;
    }
    try {
      final List<IngresoModelo> datos = await _ingresosServicio.obtenerIngresos(
        usuario.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _ingresos
          ..clear()
          ..addAll(datos);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _mostrarMensaje('No se pudieron actualizar los ingresos.');
    }
  }

  Iterable<IngresoModelo> get _ingresosFiltrados {
    final String termino = _buscadorCtrl.text.trim().toLowerCase();
    return _ingresos.where((IngresoModelo ingreso) {
      final bool coincideBusqueda =
          termino.isEmpty ||
          (ingreso.descripcion ?? '').toLowerCase().contains(termino) ||
          ingreso.categoriaNombre?.toLowerCase().contains(termino) == true ||
          ingreso.cuentaNombre?.toLowerCase().contains(termino) == true;

      if (!coincideBusqueda) {
        return false;
      }

      if (_filtroCategoriaId != null &&
          ingreso.categoriaId != _filtroCategoriaId) {
        return false;
      }

      switch (_filtroMedio) {
        case _FiltroMedioIngreso.todos:
          break;
        case _FiltroMedioIngreso.efectivo:
          if (ingreso.medio != MedioIngreso.efectivo) {
            return false;
          }
          break;
        case _FiltroMedioIngreso.banco:
          if (ingreso.medio != MedioIngreso.banco) {
            return false;
          }
          break;
      }

      if (_filtroFrecuencia != _FiltroFrecuenciaIngreso.todas) {
        final String frecuenciaSeleccionada = _filtroFrecuencia.name;
        if (ingreso.periodicidad.name != frecuenciaSeleccionada) {
          return false;
        }
      }

      return true;
    });
  }

  double get _totalIngresos => _ingresos.fold(
    0,
    (double total, IngresoModelo item) => total + item.monto,
  );

  Map<PeriodicidadIngreso, double> get _totalesPorFrecuencia {
    final Map<PeriodicidadIngreso, double> totales =
        <PeriodicidadIngreso, double>{
          for (final PeriodicidadIngreso frecuencia
              in PeriodicidadIngreso.values)
            frecuencia: 0,
        };
    for (final IngresoModelo ingreso in _ingresos) {
      totales[ingreso.periodicidad] =
          (totales[ingreso.periodicidad] ?? 0) + ingreso.monto;
    }
    return totales;
  }

  Future<void> _abrirFormularioNuevoIngreso() async {
    final User? usuario = _usuarioActual;
    if (usuario == null) {
      _mostrarMensaje('Debes iniciar sesión para registrar ingresos.');
      return;
    }

    if (_categorias.isEmpty) {
      _mostrarMensaje('Primero crea una categoría de ingreso.');
      return;
    }

    final IngresoModelo? creado = await showModalBottomSheet<IngresoModelo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _FormularioIngresoSheet(
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
      final IngresoModelo nuevo = await _ingresosServicio.crearIngreso(creado);
      if (!mounted) {
        return;
      }
      setState(() {
        _ingresos.insert(0, nuevo);
        _procesando = false;
      });
      _mostrarMensaje('Ingreso registrado correctamente.');
      widget.onIngresosActualizados?.call();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _procesando = false);
      _mostrarMensaje('No se pudo registrar el ingreso.');
    }
  }

  Future<void> _abrirFormularioEditarIngreso(IngresoModelo ingreso) async {
    final IngresoModelo? actualizado =
        await showModalBottomSheet<IngresoModelo>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return _FormularioIngresoSheet(
              usuarioId: ingreso.usuarioId,
              categorias: _categorias,
              cuentas: _cuentas,
              ingresoInicial: ingreso,
            );
          },
        );

    if (actualizado == null || actualizado.id == null) {
      return;
    }

    setState(() => _procesando = true);

    try {
      final IngresoModelo modificado = await _ingresosServicio
          .actualizarIngreso(actualizado);
      if (!mounted) {
        return;
      }
      setState(() {
        final int indice = _ingresos.indexWhere(
          (IngresoModelo item) => item.id == modificado.id,
        );
        if (indice != -1) {
          _ingresos[indice] = modificado;
        }
        _procesando = false;
      });
      _mostrarMensaje('Ingreso actualizado.');
      widget.onIngresosActualizados?.call();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _procesando = false);
      _mostrarMensaje('No se pudo actualizar el ingreso.');
    }
  }

  Future<void> _eliminarIngreso(IngresoModelo ingreso) async {
    if (ingreso.id == null) {
      _mostrarMensaje('El ingreso seleccionado no es válido.');
      return;
    }

    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar ingreso'),
          content: const Text(
            'Se revertirá el saldo de la cuenta vinculada. ¿Deseas continuar?',
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
      await _ingresosServicio.eliminarIngreso(
        ingresoId: ingreso.id!,
        usuarioId: ingreso.usuarioId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _ingresos.removeWhere((IngresoModelo item) => item.id == ingreso.id);
        _procesando = false;
      });
      _mostrarMensaje('Ingreso eliminado.');
      widget.onIngresosActualizados?.call();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _procesando = false);
      _mostrarMensaje('No se pudo eliminar el ingreso.');
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
        title: const Text('Ingresos'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _procesando ? null : _recargarIngresos,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _procesando ? null : _abrirFormularioNuevoIngreso,
        icon: const Icon(Icons.add),
        label: const Text('Registrar ingreso'),
      ),
      body: RefreshIndicator(onRefresh: _recargarIngresos, child: _cuerpo()),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _EstadoError(
        mensaje: _error!,
        onReintentar: _cargarDatosIniciales,
      );
    }

    final List<IngresoModelo> datos = _ingresosFiltrados.toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ResumenIngresos(
            total: _totalIngresos,
            totalesPorFrecuencia: _totalesPorFrecuencia,
          ),
          const SizedBox(height: 24),
          _BarraFiltros(
            controladorBusqueda: _buscadorCtrl,
            categorias: _categorias,
            filtroMedio: _filtroMedio,
            filtroFrecuencia: _filtroFrecuencia,
            categoriaSeleccionada: _filtroCategoriaId,
            onMedioChanged: (_FiltroMedioIngreso valor) {
              setState(() => _filtroMedio = valor);
            },
            onCategoriaChanged: (String? id) {
              setState(() => _filtroCategoriaId = id);
            },
            onFrecuenciaChanged: (_FiltroFrecuenciaIngreso valor) {
              setState(() => _filtroFrecuencia = valor);
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
                          child: _TarjetaIngreso(
                            ingreso: datos[i],
                            onEditar: _procesando
                                ? null
                                : () => _abrirFormularioEditarIngreso(datos[i]),
                            onEliminar: _procesando
                                ? null
                                : () => _eliminarIngreso(datos[i]),
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

class _ResumenIngresos extends StatelessWidget {
  const _ResumenIngresos({
    required this.total,
    required this.totalesPorFrecuencia,
  });

  final double total;
  final Map<PeriodicidadIngreso, double> totalesPorFrecuencia;

  String _formatearMonto(double monto) => '\\${monto.toStringAsFixed(2)}';

  String _labelFrecuencia(PeriodicidadIngreso frecuencia) =>
      switch (frecuencia) {
        PeriodicidadIngreso.unaVez => 'Una vez',
        PeriodicidadIngreso.semanal => 'Semanal',
        PeriodicidadIngreso.mensual => 'Mensual',
        PeriodicidadIngreso.trimestral => 'Trimestral',
        PeriodicidadIngreso.anual => 'Anual',
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;
    final bool modoOscuro = tema.brightness == Brightness.dark;

    final Color fondo = modoOscuro
        ? ColoresBaseOscuro.fondoTarjetas
        : ColoresBase.fondoTarjetas;
    final Color borde = Bordes.bordeGeneral.withValues(
      alpha: modoOscuro ? 0.18 : 0.4,
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
          Text('Total de ingresos', style: textos.headlineSmall),
          const SizedBox(height: 8),
          Text(
            _formatearMonto(total),
            style: textos.displaySmall?.copyWith(
              color: tema.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: PeriodicidadIngreso.values.map((
              PeriodicidadIngreso freq,
            ) {
              final double monto = totalesPorFrecuencia[freq] ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: tema.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(
                    Bordes.radioTarjetas / 1.6,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(_labelFrecuencia(freq), style: textos.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      _formatearMonto(monto),
                      style: textos.labelLarge?.copyWith(
                        color: tema.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TarjetaIngreso extends StatelessWidget {
  const _TarjetaIngreso({
    required this.ingreso,
    this.onEditar,
    this.onEliminar,
  });

  final IngresoModelo ingreso;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  String _formatearMonto(double monto) => '\\${monto.toStringAsFixed(2)}';

  String _formatearFecha(DateTime fecha) {
    const List<String> meses = <String>[
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
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
                      ingreso.categoriaNombre ?? 'Sin categoría',
                      style: textos.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ingreso.descripcion?.isNotEmpty == true
                          ? ingreso.descripcion!
                          : 'Sin descripción',
                      style: textos.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Icon(
                          ingreso.medio == MedioIngreso.banco
                              ? Icons.account_balance_wallet_outlined
                              : Icons.payments_outlined,
                          size: 18,
                          color: tema.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ingreso.cuentaNombre ??
                                (ingreso.medio == MedioIngreso.banco
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
                    _formatearMonto(ingreso.monto),
                    style: textos.titleLarge?.copyWith(
                      color: tema.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_formatearFecha(ingreso.fecha), style: textos.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    _etiquetaFrecuencia(ingreso.periodicidad),
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

  String _etiquetaFrecuencia(PeriodicidadIngreso frecuencia) =>
      switch (frecuencia) {
        PeriodicidadIngreso.unaVez => 'Ingreso único',
        PeriodicidadIngreso.semanal => 'Ingreso semanal',
        PeriodicidadIngreso.mensual => 'Ingreso mensual',
        PeriodicidadIngreso.trimestral => 'Ingreso trimestral',
        PeriodicidadIngreso.anual => 'Ingreso anual',
      };
}

class _BarraFiltros extends StatelessWidget {
  const _BarraFiltros({
    required this.controladorBusqueda,
    required this.categorias,
    required this.filtroMedio,
    required this.filtroFrecuencia,
    required this.categoriaSeleccionada,
    required this.onMedioChanged,
    required this.onCategoriaChanged,
    required this.onFrecuenciaChanged,
  });

  final TextEditingController controladorBusqueda;
  final List<cat_ingreso.CategoriaIngresoModelo> categorias;
  final _FiltroMedioIngreso filtroMedio;
  final _FiltroFrecuenciaIngreso filtroFrecuencia;
  final String? categoriaSeleccionada;
  final ValueChanged<_FiltroMedioIngreso> onMedioChanged;
  final ValueChanged<String?> onCategoriaChanged;
  final ValueChanged<_FiltroFrecuenciaIngreso> onFrecuenciaChanged;

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
            DropdownButtonFormField<_FiltroMedioIngreso>(
              initialValue: filtroMedio,
              decoration: const InputDecoration(labelText: 'Medio'),
              items: const <DropdownMenuItem<_FiltroMedioIngreso>>[
                DropdownMenuItem(
                  value: _FiltroMedioIngreso.todos,
                  child: Text('Todos'),
                ),
                DropdownMenuItem(
                  value: _FiltroMedioIngreso.efectivo,
                  child: Text('Efectivo'),
                ),
                DropdownMenuItem(
                  value: _FiltroMedioIngreso.banco,
                  child: Text('Bancarios'),
                ),
              ],
              onChanged: (_FiltroMedioIngreso? valor) {
                if (valor != null) {
                  onMedioChanged(valor);
                }
              },
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                initialValue: categoriaSeleccionada,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas las categorías'),
                  ),
                  ...categorias.map(
                    (cat_ingreso.CategoriaIngresoModelo categoria) =>
                        DropdownMenuItem<String?>(
                          value: categoria.id,
                          child: Text(categoria.nombre),
                        ),
                  ),
                ],
                onChanged: onCategoriaChanged,
              ),
            ),
            DropdownButtonFormField<_FiltroFrecuenciaIngreso>(
              initialValue: filtroFrecuencia,
              decoration: const InputDecoration(labelText: 'Frecuencia'),
              items: const <DropdownMenuItem<_FiltroFrecuenciaIngreso>>[
                DropdownMenuItem(
                  value: _FiltroFrecuenciaIngreso.todas,
                  child: Text('Todas'),
                ),
                DropdownMenuItem(
                  value: _FiltroFrecuenciaIngreso.unaVez,
                  child: Text('Una vez'),
                ),
                DropdownMenuItem(
                  value: _FiltroFrecuenciaIngreso.semanal,
                  child: Text('Semanal'),
                ),
                DropdownMenuItem(
                  value: _FiltroFrecuenciaIngreso.mensual,
                  child: Text('Mensual'),
                ),
                DropdownMenuItem(
                  value: _FiltroFrecuenciaIngreso.trimestral,
                  child: Text('Trimestral'),
                ),
                DropdownMenuItem(
                  value: _FiltroFrecuenciaIngreso.anual,
                  child: Text('Anual'),
                ),
              ],
              onChanged: (_FiltroFrecuenciaIngreso? valor) {
                if (valor != null) {
                  onFrecuenciaChanged(valor);
                }
              },
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
          Icons.attach_money_outlined,
          size: 72,
          color: tema.colorScheme.primary.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 16),
        Text('Aún no registras ingresos', style: tema.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Registra tu primer ingreso para analizar el flujo de efectivo.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FormularioIngresoSheet extends StatefulWidget {
  const _FormularioIngresoSheet({
    required this.usuarioId,
    required this.categorias,
    required this.cuentas,
    this.ingresoInicial,
  });

  final String usuarioId;
  final List<cat_ingreso.CategoriaIngresoModelo> categorias;
  final List<CuentaBancariaModelo> cuentas;
  final IngresoModelo? ingresoInicial;

  @override
  State<_FormularioIngresoSheet> createState() =>
      _FormularioIngresoSheetState();
}

class _FormularioIngresoSheetState extends State<_FormularioIngresoSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _montoCtrl;
  late final TextEditingController _descripcionCtrl;

  String? _categoriaId;
  String? _cuentaId;
  MedioIngreso _medio = MedioIngreso.efectivo;
  PeriodicidadIngreso _frecuencia = PeriodicidadIngreso.unaVez;
  DateTime _fecha = DateTime.now();

  @override
  void initState() {
    super.initState();
    final IngresoModelo? inicial = widget.ingresoInicial;
    _categoriaId = inicial?.categoriaId;
    _cuentaId = inicial?.cuentaId;
    _medio = inicial?.medio ?? MedioIngreso.efectivo;
    _frecuencia = inicial?.periodicidad ?? PeriodicidadIngreso.unaVez;
    _fecha = inicial?.fecha ?? DateTime.now();

    _montoCtrl = TextEditingController(
      text: inicial != null ? inicial.monto.toStringAsFixed(2) : '',
    );
    _descripcionCtrl = TextEditingController(text: inicial?.descripcion ?? '');
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _descripcionCtrl.dispose();
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
    if (estado == null || !estado.validate()) {
      return;
    }

    final double monto = double.parse(_montoCtrl.text.replaceAll(',', '.'));
    final MedioIngreso medio = _medio;
    final String? cuentaSeleccionada = medio == MedioIngreso.banco
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

    final IngresoModelo resultado = IngresoModelo(
      id: widget.ingresoInicial?.id,
      usuarioId: widget.usuarioId,
      categoriaId: _categoriaId!,
      categoriaNombre: widget.categorias
          .firstWhere(
            (cat_ingreso.CategoriaIngresoModelo cat) => cat.id == _categoriaId,
          )
          .nombre,
      cuentaId: cuentaSeleccionada,
  cuentaNombre: cuentaSeleccionadaModelo?.descripcionSeleccion,
      monto: monto,
      descripcion: _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim(),
      medio: medio,
      periodicidad: _frecuencia,
      fecha: _fecha,
    );

    Navigator.of(context).pop(resultado);
  }

  String _textoFecha(DateTime fecha) {
    const List<String> meses = <String>[
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
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
                  widget.ingresoInicial == null
                      ? 'Registrar ingreso'
                      : 'Editar ingreso',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _categoriaId,
                  decoration: const InputDecoration(labelText: 'Categoría *'),
                  items: widget.categorias
                      .map(
                        (cat_ingreso.CategoriaIngresoModelo categoria) =>
                            DropdownMenuItem<String>(
                              value: categoria.id,
                              child: Text(categoria.nombre),
                            ),
                      )
                      .toList(),
                  onChanged: (String? valor) =>
                      setState(() => _categoriaId = valor),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (String? valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'Ingresa el monto del ingreso';
                    }
                    final double? monto = double.tryParse(
                      valor.replaceAll(',', '.'),
                    );
                    if (monto == null || monto <= 0) {
                      return 'Ingresa un monto válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<MedioIngreso>(
                  initialValue: _medio,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de ingreso *',
                  ),
                  items: const <DropdownMenuItem<MedioIngreso>>[
                    DropdownMenuItem(
                      value: MedioIngreso.efectivo,
                      child: Text('Efectivo'),
                    ),
                    DropdownMenuItem(
                      value: MedioIngreso.banco,
                      child: Text('Cuenta bancaria'),
                    ),
                  ],
                  onChanged: (MedioIngreso? valor) {
                    if (valor == null) {
                      return;
                    }
                    setState(() {
                      _medio = valor;
                      if (valor == MedioIngreso.efectivo) {
                        _cuentaId = null;
                      }
                    });
                  },
                ),
                if (_medio == MedioIngreso.banco) ...<Widget>[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _cuentaId,
                    decoration: const InputDecoration(
                      labelText: 'Cuenta bancaria *',
                    ),
                    items: widget.cuentas
                        .map(
                          (CuentaBancariaModelo cuenta) =>
                              DropdownMenuItem<String>(
                                value: cuenta.id,
                                child: Text(cuenta.descripcionSeleccion),
                              ),
                        )
                        .toList(),
                    onChanged: (String? valor) =>
                        setState(() => _cuentaId = valor),
                    validator: (String? valor) {
                      if (_medio == MedioIngreso.banco &&
                          (valor == null || valor.isEmpty)) {
                        return 'Selecciona la cuenta que recibe el ingreso';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<PeriodicidadIngreso>(
                  initialValue: _frecuencia,
                  decoration: const InputDecoration(labelText: 'Frecuencia *'),
                  items: <DropdownMenuItem<PeriodicidadIngreso>>[
                    DropdownMenuItem(
                      value: PeriodicidadIngreso.unaVez,
                      child: Text('Una vez'),
                    ),
                    DropdownMenuItem(
                      value: PeriodicidadIngreso.semanal,
                      child: Text('Semanal'),
                    ),
                    DropdownMenuItem(
                      value: PeriodicidadIngreso.mensual,
                      child: Text('Mensual'),
                    ),
                    DropdownMenuItem(
                      value: PeriodicidadIngreso.trimestral,
                      child: Text('Trimestral'),
                    ),
                    DropdownMenuItem(
                      value: PeriodicidadIngreso.anual,
                      child: Text('Anual'),
                    ),
                  ],
                  onChanged: (PeriodicidadIngreso? valor) {
                    if (valor != null) {
                      setState(() => _frecuencia = valor);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Ej. Salario mensual',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha del ingreso'),
                  subtitle: Text(_textoFecha(_fecha)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _seleccionarFecha,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  onPressed: _enviar,
                  label: Text(
                    widget.ingresoInicial == null
                        ? 'Guardar ingreso'
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
