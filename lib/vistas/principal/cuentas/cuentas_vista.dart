import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../modelos/cuenta_bancaria_modelo.dart';
import '../../../servicios/cuentas_servicio.dart';
import '../../../sistema_diseno/identidad_visual.dart';

class CuentasVista extends StatefulWidget {
  const CuentasVista({
    super.key,
    this.onResumenActualizado,
    this.recargaNotifier,
  });

  final ValueChanged<ResumenCuentasModelo>? onResumenActualizado;
  final ValueNotifier<int>? recargaNotifier;

  @override
  State<CuentasVista> createState() => _CuentasVistaState();
}

class _CuentasVistaState extends State<CuentasVista> {
  final CuentasServicio _servicio = CuentasServicio();
  final List<CuentaBancariaModelo> _cuentas = <CuentaBancariaModelo>[];

  ValueNotifier<int>? _recargaNotifier;
  VoidCallback? _recargaListener;

  List<BancoCatalogoModelo> _catalogo = <BancoCatalogoModelo>[];
  ResumenCuentasModelo? _resumenRemoto;
  bool _cargando = true;
  bool _procesando = false;
  String? _error;

  User? get _usuarioActual => Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _instalarRecarga(widget.recargaNotifier);
    _cargarDatos();
  }

  @override
  void didUpdateWidget(CuentasVista oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recargaNotifier != widget.recargaNotifier) {
      _desinstalarRecarga(oldWidget.recargaNotifier);
      _instalarRecarga(widget.recargaNotifier);
    }
  }

  @override
  void dispose() {
    _desinstalarRecarga(_recargaNotifier);
    super.dispose();
  }

  void _instalarRecarga(ValueNotifier<int>? notifier) {
    if (notifier == null) {
      return;
    }
    _recargaNotifier = notifier;
    _recargaListener = _recargaListener ?? () => _cargarDatos();
    notifier.addListener(_recargaListener!);
  }

  void _desinstalarRecarga(ValueNotifier<int>? notifier) {
    if (notifier == null || _recargaListener == null) {
      return;
    }
    notifier.removeListener(_recargaListener!);
    if (identical(_recargaNotifier, notifier)) {
      _recargaNotifier = null;
    }
  }

  Future<void> _cargarDatos() async {
    final User? usuario = _usuarioActual;
    if (usuario == null) {
      setState(() {
        _cargando = false;
        _error = 'Debes iniciar sesión para ver tus cuentas.';
      });
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final List<dynamic> resultados =
          await Future.wait<dynamic>(<Future<dynamic>>[
            _servicio.obtenerCuentas(usuario.id),
            _servicio.obtenerResumen(usuario.id),
            _servicio.obtenerCatalogoBancos(),
          ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _cuentas
          ..clear()
          ..addAll(resultados[0] as List<CuentaBancariaModelo>);
        _resumenRemoto = resultados[1] as ResumenCuentasModelo?;
        _catalogo = resultados[2] as List<BancoCatalogoModelo>;
        _cargando = false;
      });
      _emitirResumen();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar las cuentas. Inténtalo de nuevo.';
      });
    }
  }

  Future<void> _refrescarResumen(String usuarioId) async {
    try {
      final ResumenCuentasModelo? resumen = await _servicio.obtenerResumen(
        usuarioId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _resumenRemoto = resumen;
      });
      _emitirResumen();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _resumenRemoto = null);
      _emitirResumen();
    }
  }

  ResumenCuentasModelo _obtenerResumen() {
    final ResumenCuentasModelo? remoto = _resumenRemoto;
    if (remoto != null) {
      return ResumenCuentasModelo(
        totalGeneral: remoto.totalGeneral,
        totalDepositos: remoto.totalDepositos,
        totalCredito: remoto.totalCredito,
        totalCuentas: _cuentas.length,
      );
    }

    double depositos = 0;
    double credito = 0;
    for (final CuentaBancariaModelo cuenta in _cuentas) {
      if (cuenta.esCredito) {
        credito += cuenta.limiteCredito ?? 0;
      } else {
        depositos += cuenta.montoDisponible;
      }
    }

    return ResumenCuentasModelo(
      totalGeneral: depositos + credito,
      totalDepositos: depositos,
      totalCredito: credito,
      totalCuentas: _cuentas.length,
    );
  }

  String _formatearMonto(double monto) => '\$${monto.toStringAsFixed(2)}';

  Future<void> _abrirFormularioNuevaCuenta() async {
    final User? usuario = _usuarioActual;
    if (usuario == null) {
      _mostrarMensaje('Debes iniciar sesión para gestionar tus cuentas.');
      return;
    }

    final CuentaBancariaModelo? nuevaCuenta =
        await showModalBottomSheet<CuentaBancariaModelo>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return _ModalFormularioCuenta(
              usuarioId: usuario.id,
              bancos: _catalogo,
            );
          },
        );

    if (nuevaCuenta == null) {
      return;
    }

    setState(() => _procesando = true);

    try {
      final CuentaBancariaModelo creada = await _servicio.crearCuenta(
        nuevaCuenta,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _cuentas.insert(0, creada);
        _procesando = false;
      });
      _emitirResumen();
      await _refrescarResumen(usuario.id);
      if (!mounted) {
        return;
      }
      _mostrarMensaje('Cuenta agregada correctamente.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _procesando = false);
      _mostrarMensaje('No se pudo crear la cuenta. Inténtalo de nuevo.');
    }
  }

  Future<void> _abrirFormularioEditarCuenta(CuentaBancariaModelo cuenta) async {
    final User? usuario = _usuarioActual;
    if (usuario == null) {
      _mostrarMensaje('Debes iniciar sesión para gestionar tus cuentas.');
      return;
    }

    final CuentaBancariaModelo? cuentaActualizada =
        await showModalBottomSheet<CuentaBancariaModelo>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return _ModalFormularioCuenta(
              usuarioId: usuario.id,
              bancos: _catalogo,
              cuentaInicial: cuenta,
            );
          },
        );

    if (cuentaActualizada == null || cuentaActualizada.id == null) {
      return;
    }

    setState(() => _procesando = true);

    try {
      final CuentaBancariaModelo modificada = await _servicio.actualizarCuenta(
        cuentaActualizada,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final int indice = _cuentas.indexWhere(
          (CuentaBancariaModelo elemento) => elemento.id == modificada.id,
        );
        if (indice != -1) {
          _cuentas[indice] = modificada;
        }
        _procesando = false;
      });
      _emitirResumen();
      await _refrescarResumen(usuario.id);
      if (!mounted) {
        return;
      }
      _mostrarMensaje('Cuenta actualizada correctamente.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _procesando = false);
      _mostrarMensaje('No se pudo actualizar la cuenta. Inténtalo de nuevo.');
    }
  }

  Future<void> _eliminarCuenta(CuentaBancariaModelo cuenta) async {
    final User? usuario = _usuarioActual;
    if (usuario == null) {
      _mostrarMensaje('Debes iniciar sesión para gestionar tus cuentas.');
      return;
    }

    if (cuenta.id == null) {
      _mostrarMensaje('La cuenta seleccionada no es válida.');
      return;
    }

    setState(() => _procesando = true);

    try {
      await _servicio.eliminarCuenta(cuenta.id!);
      if (!mounted) {
        return;
      }
      setState(() {
        _cuentas.removeWhere(
          (CuentaBancariaModelo elemento) => elemento.id == cuenta.id,
        );
        _procesando = false;
      });
      _emitirResumen();
      await _refrescarResumen(usuario.id);
      if (!mounted) {
        return;
      }
      _mostrarMensaje('Cuenta eliminada correctamente.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _procesando = false);
      _mostrarMensaje('No se pudo eliminar la cuenta.');
    }
  }

  void _emitirResumen() {
    final ValueChanged<ResumenCuentasModelo>? callback =
        widget.onResumenActualizado;
    if (callback == null) {
      return;
    }
    callback(_obtenerResumen());
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
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;

    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _EstadoError(mensaje: _error!, onReintentar: _cargarDatos);
    }

    final ResumenCuentasModelo resumen = _obtenerResumen();

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _ResumenCuentas(
                key: ValueKey<String>(
                  '${resumen.totalGeneral}-${resumen.totalCuentas}',
                ),
                totalGeneral: _formatearMonto(resumen.totalGeneral),
                totalDepositos: _formatearMonto(resumen.totalDepositos),
                totalCredito: _formatearMonto(resumen.totalCredito),
                totalCuentas: resumen.totalCuentas,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Cuentas registradas',
                    style: textos.headlineMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _procesando ? null : _abrirFormularioNuevaCuenta,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _cuentas.isEmpty
                  ? _EmptyState(
                      key: const ValueKey<String>('empty'),
                      textos: textos,
                    )
                  : Column(
                      key: ValueKey<int>(_cuentas.length),
                      children: <Widget>[
                        for (int i = 0; i < _cuentas.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == _cuentas.length - 1 ? 0 : 12,
                            ),
                            child: _TarjetaCuenta(
                              cuenta: _cuentas[i],
                              onEditar: _procesando
                                  ? null
                                  : () => _abrirFormularioEditarCuenta(
                                      _cuentas[i],
                                    ),
                              onEliminar: _procesando
                                  ? null
                                  : () => _eliminarCuenta(_cuentas[i]),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumenCuentas extends StatelessWidget {
  const _ResumenCuentas({
    super.key,
    required this.totalGeneral,
    required this.totalDepositos,
    required this.totalCredito,
    required this.totalCuentas,
  });

  final String totalGeneral;
  final String totalDepositos;
  final String totalCredito;
  final int totalCuentas;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;
    final ColorScheme esquema = tema.colorScheme;
    final bool modoOscuro = tema.brightness == Brightness.dark;

    final Gradient gradiente = LinearGradient(
      colors: modoOscuro
          ? <Color>[
              esquema.primary.withValues(alpha: 0.65),
              esquema.secondary.withValues(alpha: 0.55),
            ]
          : <Color>[
              esquema.primary.withValues(alpha: 0.9),
              esquema.primaryContainer.withValues(alpha: 0.8),
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final Color textoPrincipal = esquema.onPrimary;
    final Color fondoIndicadores = Colors.white.withValues(
      alpha: modoOscuro ? 0.16 : 0.2,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradiente,
        borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: modoOscuro ? 0.4 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Resumen de cuentas',
            style: textos.headlineMedium?.copyWith(
              color: textoPrincipal.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            totalGeneral,
            style: textos.displayMedium?.copyWith(
              color: textoPrincipal,
              fontWeight: FontWeight.w700,
              shadows: <Shadow>[
                Shadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  offset: const Offset(0, 3),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total general disponible',
            style: textos.bodyMedium?.copyWith(
              color: textoPrincipal.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: textoPrincipal.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: <Widget>[
              _IndicadorResumen(
                icono: Icons.account_balance_wallet_outlined,
                titulo: 'Depósitos disponibles',
                valor: totalDepositos,
                colorTexto: textoPrincipal,
                colorFondo: fondoIndicadores,
              ),
              _IndicadorResumen(
                icono: Icons.credit_card_outlined,
                titulo: 'Crédito disponible',
                valor: totalCredito,
                colorTexto: textoPrincipal,
                colorFondo: fondoIndicadores,
              ),
              _IndicadorResumen(
                icono: Icons.format_list_numbered,
                titulo: 'Cuentas registradas',
                valor: '$totalCuentas',
                colorTexto: textoPrincipal,
                colorFondo: fondoIndicadores,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IndicadorResumen extends StatelessWidget {
  const _IndicadorResumen({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.colorTexto,
    required this.colorFondo,
  });

  final IconData icono;
  final String titulo;
  final String valor;
  final Color colorTexto;
  final Color colorFondo;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
      ),
      child: Row(
        children: <Widget>[
          Icon(icono, color: colorTexto),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  titulo,
                  style: textos.labelMedium?.copyWith(
                    color: colorTexto.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: textos.bodyLarge?.copyWith(
                    color: colorTexto,
                    fontWeight: FontWeight.w600,
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

class _TarjetaCuenta extends StatelessWidget {
  const _TarjetaCuenta({required this.cuenta, this.onEditar, this.onEliminar});

  final CuentaBancariaModelo cuenta;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  String _formatearMonto(double monto) => '\$${monto.toStringAsFixed(2)}';

  String? _formatearFecha(DateTime? fecha) {
    if (fecha == null) {
      return null;
    }
    final String dia = fecha.day.toString().padLeft(2, '0');
    final String mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: <Color>[
                      tema.colorScheme.primary.withValues(alpha: 0.14),
                      tema.colorScheme.secondary.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(cuenta.tipo.icono, color: tema.colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(cuenta.nombreBanco, style: textos.titleMedium),
                    const SizedBox(height: 4),
                    Text(cuenta.titular, style: textos.bodyMedium),
                    const SizedBox(height: 6),
                    Chip(
                      avatar: Icon(
                        cuenta.tipo.icono,
                        size: 16,
                        color: tema.colorScheme.primary,
                      ),
                      label: Text(cuenta.tipo.etiqueta),
                      backgroundColor: tema.colorScheme.primary.withValues(
                        alpha: 0.08,
                      ),
                      side: BorderSide(
                        color: tema.colorScheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
              if (onEditar != null || onEliminar != null) ...<Widget>[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (onEditar != null)
                      IconButton.outlined(
                        tooltip: 'Editar cuenta',
                        onPressed: onEditar,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    if (onEliminar != null)
                      IconButton.outlined(
                        tooltip: 'Eliminar cuenta',
                        style: IconButton.styleFrom(
                          foregroundColor: tema.colorScheme.error,
                        ),
                        onPressed: onEliminar,
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: <Widget>[
              _DetalleCuenta(
                titulo: 'Número de cuenta',
                valor: cuenta.numeroCuenta,
                icono: Icons.confirmation_number_outlined,
              ),
              _DetalleCuenta(
                titulo: cuenta.esCredito
                    ? 'Saldo disponible'
                    : 'Monto disponible',
                valor: _formatearMonto(cuenta.montoDisponible),
                icono: Icons.payments_outlined,
              ),
              if (cuenta.esCredito && cuenta.limiteCredito != null)
                _DetalleCuenta(
                  titulo: 'Crédito asignado',
                  valor: _formatearMonto(cuenta.limiteCredito!),
                  icono: Icons.account_balance_wallet_outlined,
                ),
              if (cuenta.esCredito)
                _DetalleCuenta(
                  titulo: 'Fecha de corte',
                  valor: _formatearFecha(cuenta.fechaCorte) ?? 'Sin definir',
                  icono: Icons.calendar_month_outlined,
                ),
              if (cuenta.esCredito)
                _DetalleCuenta(
                  titulo: 'Fecha de pago',
                  valor: _formatearFecha(cuenta.fechaPago) ?? 'Sin definir',
                  icono: Icons.event_available_outlined,
                ),
            ],
          ),
          if (cuenta.esCredito &&
              cuenta.limiteCredito != null &&
              cuenta.limiteCredito! > 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _IndicadorCredito(
                disponible: cuenta.montoDisponible,
                limite: cuenta.limiteCredito!,
                formatearMonto: _formatearMonto,
              ),
            ),
          if ((cuenta.notas ?? '').isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tema.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.note_alt_outlined,
                    size: 18,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(cuenta.notas!, style: textos.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _IndicadorCredito extends StatelessWidget {
  const _IndicadorCredito({
    required this.disponible,
    required this.limite,
    required this.formatearMonto,
  });

  final double disponible;
  final double limite;
  final String Function(double) formatearMonto;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    double porcentajeDisponible = 0;
    if (limite > 0) {
      porcentajeDisponible = disponible / limite;
      porcentajeDisponible = math.max(0, math.min(1, porcentajeDisponible));
    }
    final double usado = math.max(0, limite - disponible);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Disponible vs crédito', style: tema.textTheme.labelMedium),
            Text(
              '${(porcentajeDisponible * 100).round()}% disponible',
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: porcentajeDisponible,
            minHeight: 8,
            backgroundColor: tema.colorScheme.primary.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(tema.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: <Widget>[
            _EtiquetaValor(
              etiqueta: 'Disponible',
              valor: formatearMonto(disponible),
            ),
            _EtiquetaValor(etiqueta: 'Utilizado', valor: formatearMonto(usado)),
            _EtiquetaValor(etiqueta: 'Límite', valor: formatearMonto(limite)),
          ],
        ),
      ],
    );
  }
}

class _EtiquetaValor extends StatelessWidget {
  const _EtiquetaValor({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(etiqueta, style: textos.labelMedium),
        Text(
          valor,
          style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DetalleCuenta extends StatelessWidget {
  const _DetalleCuenta({
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
      width: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icono, color: tema.colorScheme.primary, size: 20),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key, required this.textos});

  final TextTheme textos;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
        border: Border.all(color: Bordes.bordeGeneral.withValues(alpha: 0.4)),
        color: tema.colorScheme.surface,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.account_balance_outlined,
            size: 72,
            color: tema.colorScheme.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text('No hay cuentas registradas', style: textos.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Agrega tus cuentas bancarias para visualizar saldos y fechas de corte.',
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
    final ThemeData tema = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 48,
              color: tema.colorScheme.error.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalFormularioCuenta extends StatefulWidget {
  const _ModalFormularioCuenta({
    required this.usuarioId,
    required this.bancos,
    this.cuentaInicial,
  });

  final String usuarioId;
  final List<BancoCatalogoModelo> bancos;
  final CuentaBancariaModelo? cuentaInicial;

  @override
  State<_ModalFormularioCuenta> createState() => _ModalFormularioCuentaState();
}

class _ModalFormularioCuentaState extends State<_ModalFormularioCuenta> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titularCtrl = TextEditingController();
  final TextEditingController _numeroCuentaCtrl = TextEditingController();
  final TextEditingController _montoDisponibleCtrl = TextEditingController();
  final TextEditingController _limiteCreditoCtrl = TextEditingController();
  final TextEditingController _bancoOtroCtrl = TextEditingController();
  final TextEditingController _notasCtrl = TextEditingController();

  static const String _valorOtroBanco = 'otro';

  String? _bancoSeleccionadoId;
  TipoCuenta? _tipoSeleccionado;
  DateTime? _fechaCorte;
  DateTime? _fechaPago;

  bool get _esEdicion => widget.cuentaInicial != null;

  @override
  void initState() {
    super.initState();
    final CuentaBancariaModelo? cuenta = widget.cuentaInicial;
    if (cuenta != null) {
      _titularCtrl.text = cuenta.titular;
      _numeroCuentaCtrl.text = cuenta.numeroCuenta;
      _montoDisponibleCtrl.text = cuenta.montoDisponible.toStringAsFixed(2);
      _tipoSeleccionado = cuenta.tipo;
      _notasCtrl.text = cuenta.notas ?? '';
      _fechaCorte = cuenta.fechaCorte;
      _fechaPago = cuenta.fechaPago;
      if (cuenta.limiteCredito != null) {
        _limiteCreditoCtrl.text = cuenta.limiteCredito!.toStringAsFixed(2);
      }
      if (cuenta.catalogoBancoId != null) {
        _bancoSeleccionadoId = cuenta.catalogoBancoId;
      } else if (cuenta.bancoPersonalizado != null) {
        _bancoSeleccionadoId = _valorOtroBanco;
        _bancoOtroCtrl.text = cuenta.bancoPersonalizado!;
      }
    }
  }

  @override
  void dispose() {
    _titularCtrl.dispose();
    _numeroCuentaCtrl.dispose();
    _montoDisponibleCtrl.dispose();
    _limiteCreditoCtrl.dispose();
    _bancoOtroCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: tema.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Bordes.radioTarjetas),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        _esEdicion
                            ? 'Editar cuenta bancaria'
                            : 'Nueva cuenta bancaria',
                        style: textos.headlineMedium,
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titularCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del titular',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (String? valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Ingresa el nombre del titular';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _bancoSeleccionadoId,
                    decoration: const InputDecoration(labelText: 'Banco'),
                    items: <DropdownMenuItem<String>>[
                      for (final BancoCatalogoModelo banco in widget.bancos)
                        DropdownMenuItem<String>(
                          value: banco.id,
                          child: Text(banco.nombre),
                        ),
                      const DropdownMenuItem<String>(
                        value: _valorOtroBanco,
                        child: Text('Otro'),
                      ),
                    ],
                    onChanged: (String? valor) {
                      setState(() => _bancoSeleccionadoId = valor);
                    },
                    validator: (String? valor) {
                      if (valor == null || valor.isEmpty) {
                        return 'Selecciona un banco';
                      }
                      if (valor == _valorOtroBanco &&
                          _bancoOtroCtrl.text.trim().isEmpty) {
                        return 'Indica el nombre del banco';
                      }
                      return null;
                    },
                  ),
                  if (_bancoSeleccionadoId == _valorOtroBanco) ...<Widget>[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bancoOtroCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del banco',
                      ),
                      validator: (String? valor) {
                        if (_bancoSeleccionadoId == _valorOtroBanco &&
                            (valor == null || valor.trim().isEmpty)) {
                          return 'Ingresa el nombre del banco';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _numeroCuentaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Número de cuenta',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (String? valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Ingresa el número de cuenta';
                      }
                      if (valor.replaceAll(RegExp(r'\D'), '').length < 6) {
                        return 'Revisa el número ingresado';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _montoDisponibleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Monto disponible',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (String? valor) {
                      final double? monto = _parseMonto(valor);
                      if (monto == null) {
                        return 'Ingresa un monto válido';
                      }
                      if (monto < 0) {
                        return 'El monto no puede ser negativo';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TipoCuenta>(
                    initialValue: _tipoSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de cuenta',
                    ),
                    items: TipoCuenta.values
                        .map(
                          (TipoCuenta tipo) => DropdownMenuItem<TipoCuenta>(
                            value: tipo,
                            child: Text(tipo.etiqueta),
                          ),
                        )
                        .toList(),
                    onChanged: (TipoCuenta? valor) {
                      setState(() {
                        _tipoSeleccionado = valor;
                        if (valor != TipoCuenta.credito) {
                          _limiteCreditoCtrl.clear();
                          _fechaCorte = null;
                          _fechaPago = null;
                        }
                      });
                    },
                    validator: (TipoCuenta? valor) {
                      if (valor == null) {
                        return 'Selecciona el tipo de cuenta';
                      }
                      return null;
                    },
                  ),
                  if (_tipoSeleccionado == TipoCuenta.credito) ...<Widget>[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _limiteCreditoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Crédito máximo',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (String? valor) {
                        if (_tipoSeleccionado != TipoCuenta.credito) {
                          return null;
                        }
                        final double? monto = _parseMonto(valor);
                        if (monto == null) {
                          return 'Ingresa un monto válido';
                        }
                        if (monto <= 0) {
                          return 'Debe ser mayor a 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _CampoFecha(
                            etiqueta: 'Fecha de corte',
                            fecha: _fechaCorte,
                            onSeleccionar: (DateTime fecha) =>
                                setState(() => _fechaCorte = fecha),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CampoFecha(
                            etiqueta: 'Fecha de pago',
                            fecha: _fechaPago,
                            onSeleccionar: (DateTime fecha) =>
                                setState(() => _fechaPago = fecha),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notasCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _guardar,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        _esEdicion ? 'Guardar cambios' : 'Guardar cuenta',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _guardar() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final TipoCuenta tipo = _tipoSeleccionado ?? TipoCuenta.ahorro;
    final double montoDisponible =
        _parseMonto(_montoDisponibleCtrl.text.trim()) ?? 0;

    double? limiteCredito;
    DateTime? fechaCorte;
    DateTime? fechaPago;

    if (tipo == TipoCuenta.credito) {
      limiteCredito = _parseMonto(_limiteCreditoCtrl.text.trim());
      if (limiteCredito == null || limiteCredito <= 0) {
        _mostrarErrorContextual('Revisa el monto de crédito ingresado.');
        return;
      }
      if (_fechaCorte == null || _fechaPago == null) {
        _mostrarErrorContextual('Selecciona las fechas de corte y pago.');
        return;
      }
      fechaCorte = _fechaCorte;
      fechaPago = _fechaPago;
    }

    final bool esOtroBanco = _bancoSeleccionadoId == _valorOtroBanco;
    final String? catalogoBancoId = esOtroBanco ? null : _bancoSeleccionadoId;
    final String? bancoPersonalizado;
    if (esOtroBanco) {
      final String nombreBanco = _bancoOtroCtrl.text.trim();
      bancoPersonalizado = nombreBanco.isEmpty ? null : nombreBanco;
    } else {
      bancoPersonalizado = null;
    }

    final CuentaBancariaModelo cuenta = CuentaBancariaModelo(
      id: widget.cuentaInicial?.id,
      usuarioId: widget.cuentaInicial?.usuarioId ?? widget.usuarioId,
      titular: _titularCtrl.text.trim(),
      catalogoBancoId: catalogoBancoId,
      bancoPersonalizado: bancoPersonalizado,
      numeroCuenta: _numeroCuentaCtrl.text.trim(),
      tipo: tipo,
      montoDisponible: montoDisponible,
      limiteCredito: limiteCredito,
      fechaCorte: fechaCorte,
      fechaPago: fechaPago,
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
    );

    Navigator.of(context).pop(cuenta);
  }

  void _mostrarErrorContextual(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }
}

double? _parseMonto(String? valor) {
  if (valor == null) {
    return null;
  }
  final String limpio = valor
      .replaceAll(RegExp(r'[^0-9,.-]'), '')
      .replaceAll(',', '.');
  return double.tryParse(limpio);
}

class _CampoFecha extends StatelessWidget {
  const _CampoFecha({
    required this.etiqueta,
    required this.fecha,
    required this.onSeleccionar,
  });

  final String etiqueta;
  final DateTime? fecha;
  final ValueChanged<DateTime> onSeleccionar;

  String? get _fechaFormateada {
    if (fecha == null) {
      return null;
    }
    final String dia = fecha!.day.toString().padLeft(2, '0');
    final String mes = fecha!.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha!.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;

    return OutlinedButton.icon(
      onPressed: () async {
        final DateTime now = DateTime.now();
        final DateTime? seleccion = await showDatePicker(
          context: context,
          initialDate: fecha ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 5),
        );
        if (seleccion != null) {
          onSeleccionar(seleccion);
        }
      },
      icon: const Icon(Icons.event_outlined),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(etiqueta, style: textos.labelMedium),
            const SizedBox(height: 4),
            Text(
              _fechaFormateada ?? 'Seleccionar fecha',
              style: textos.bodyMedium,
            ),
          ],
        ),
      ),
      style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
    );
  }
}

extension TipoCuentaUi on TipoCuenta {
  String get etiqueta {
    switch (this) {
      case TipoCuenta.nomina:
        return 'Nómina';
      case TipoCuenta.negocios:
        return 'Negocios';
      case TipoCuenta.ahorro:
        return 'Ahorro';
      case TipoCuenta.credito:
        return 'Crédito';
    }
  }

  IconData get icono {
    switch (this) {
      case TipoCuenta.nomina:
        return Icons.work_outline;
      case TipoCuenta.negocios:
        return Icons.storefront_outlined;
      case TipoCuenta.ahorro:
        return Icons.savings_outlined;
      case TipoCuenta.credito:
        return Icons.credit_card_outlined;
    }
  }
}
