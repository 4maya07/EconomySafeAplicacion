import 'package:flutter/material.dart';

import '../../sistema_diseno/identidad_visual.dart';
import '../../modelos/transaccion_financiera_modelo.dart';

/// Presenta el resumen financiero principal del usuario.
class DashboardVista extends StatelessWidget {
  const DashboardVista({
    super.key,
    required this.saldoTotal,
    required this.saldoEfectivo,
    required this.saldoCuentasBancarias,
    required this.transacciones,
    required this.cargandoTransacciones,
    this.onCategoriasGasto,
    this.onNuevoGasto,
    this.onCategoriasIngreso,
    this.onNuevoIngreso,
  });

  final double saldoTotal;
  final double saldoEfectivo;
  final double saldoCuentasBancarias;
  final List<TransaccionFinancieraModelo> transacciones;
  final bool cargandoTransacciones;
  final VoidCallback? onCategoriasGasto;
  final VoidCallback? onNuevoGasto;
  final VoidCallback? onCategoriasIngreso;
  final VoidCallback? onNuevoIngreso;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _TarjetaResumen(
            saldoTotal: saldoTotal,
            saldoEfectivo: saldoEfectivo,
            saldoCuentasBancarias: saldoCuentasBancarias,
          ),
          const SizedBox(height: 24),
          Text('Acciones rápidas', style: textos.headlineMedium),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool enUnaColumna = constraints.maxWidth < 600;
              final Widget bloqueGastos = _BloqueAcciones(
                acciones: <Widget>[
                  _AccionBoton(
                    etiqueta: 'Nuevo Gasto',
                    icono: Icons.remove_circle_outline,
                    colorBase: ColoresAcciones.error,
                    onPressed: onNuevoGasto,
                  ),
                  const SizedBox(height: 12),
                  _AccionBoton(
                    etiqueta: 'Categoría de Gastos',
                    icono: Icons.folder_open_outlined,
                    colorBase: ColoresAcciones.error,
                    onPressed: onCategoriasGasto,
                  ),
                ],
              );
              final Widget bloqueIngresos = _BloqueAcciones(
                acciones: <Widget>[
                  _AccionBoton(
                    etiqueta: 'Nuevo Ingreso',
                    icono: Icons.add_circle_outline,
                    colorBase: ColoresAcciones.exito,
                    onPressed: onNuevoIngreso,
                  ),
                  const SizedBox(height: 12),
                  _AccionBoton(
                    etiqueta: 'Categoría de Ingresos',
                    icono: Icons.list_alt_outlined,
                    colorBase: ColoresAcciones.exito,
                    onPressed: onCategoriasIngreso,
                  ),
                ],
              );

              if (enUnaColumna) {
                return Column(
                  children: <Widget>[
                    SizedBox(width: double.infinity, child: bloqueGastos),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: bloqueIngresos),
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Expanded(child: bloqueGastos),
                  const SizedBox(width: 12),
                  Expanded(child: bloqueIngresos),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _HistorialTransacciones(
            transacciones: transacciones,
            cargando: cargandoTransacciones,
          ),
        ],
      ),
    );
  }
}

class _BloqueAcciones extends StatelessWidget {
  const _BloqueAcciones({required this.acciones});

  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return Column(children: acciones);
  }
}

class _HistorialTransacciones extends StatelessWidget {
  const _HistorialTransacciones({
    required this.transacciones,
    required this.cargando,
  });

  final List<TransaccionFinancieraModelo> transacciones;
  final bool cargando;

  String _formatearFecha(DateTime fecha) {
    final DateTime local = fecha.toLocal();
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
    final String dia = local.day.toString().padLeft(2, '0');
    final String mes = meses[local.month - 1];
    final String hora = local.hour.toString().padLeft(2, '0');
    final String minuto = local.minute.toString().padLeft(2, '0');
    return '$dia $mes ${local.year} · $hora:$minuto';
  }

  String _formatearMonto(double monto) => '\$${monto.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Historial de transacciones', style: textos.headlineMedium),
        const SizedBox(height: 12),
        if (cargando)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          )
        else if (transacciones.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
              border: Border.all(
                color: Bordes.bordeGeneral.withValues(alpha: 0.4),
              ),
              color: tema.colorScheme.surface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: tema.colorScheme.primary.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  'No hay movimientos recientes',
                  style: textos.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Registra ingresos o gastos para verlos en esta sección.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Column(
            children: <Widget>[
              for (final TransaccionFinancieraModelo transaccion
                  in transacciones.take(20))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TarjetaTransaccion(
                    transaccion: transaccion,
                    formatearFecha: _formatearFecha,
                    formatearMonto: _formatearMonto,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _TarjetaTransaccion extends StatelessWidget {
  const _TarjetaTransaccion({
    required this.transaccion,
    required this.formatearFecha,
    required this.formatearMonto,
  });

  final TransaccionFinancieraModelo transaccion;
  final String Function(DateTime) formatearFecha;
  final String Function(double) formatearMonto;

  Color _colorMonto(ThemeData tema) {
    return transaccion.tipo == TipoTransaccion.ingreso
        ? tema.colorScheme.primary
        : tema.colorScheme.error;
  }

  IconData _iconoMovimiento() {
    return transaccion.tipo == TipoTransaccion.ingreso
        ? Icons.arrow_circle_up_outlined
        : Icons.arrow_circle_down_outlined;
  }

  String _textoMedio() {
    if (transaccion.medio == MedioTransaccion.efectivo) {
      return 'Efectivo';
    }
    return transaccion.cuentaNombre ?? 'Cuenta bancaria';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;
    final Color colorMonto = _colorMonto(tema);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tema.colorScheme.surface,
        borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
        border: Border.all(
          color: Bordes.bordeGeneral.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                _iconoMovimiento(),
                color: colorMonto,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      transaccion.titulo ??
                          (transaccion.tipo == TipoTransaccion.ingreso
                              ? 'Ingreso'
                              : 'Gasto'),
                      style: textos.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _textoMedio(),
                      style: textos.bodySmall,
                    ),
                    if ((transaccion.descripcion ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        transaccion.descripcion!,
                        style: textos.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    formatearMonto(transaccion.monto),
                    style: textos.titleMedium?.copyWith(
                      color: colorMonto,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatearFecha(transaccion.fecha),
                    style: textos.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _LineaSaldos(
            formatearMonto: formatearMonto,
            saldoAntes: transaccion.saldoAntes,
            saldoDespues: transaccion.saldoDespues,
            monto: transaccion.monto,
            tipo: transaccion.tipo,
          ),
        ],
      ),
    );
  }
}

class _LineaSaldos extends StatelessWidget {
  const _LineaSaldos({
    required this.formatearMonto,
    required this.saldoAntes,
    required this.saldoDespues,
    required this.monto,
    required this.tipo,
  });

  final String Function(double) formatearMonto;
  final double? saldoAntes;
  final double? saldoDespues;
  final double monto;
  final TipoTransaccion tipo;

  @override
  Widget build(BuildContext context) {
    final TextTheme textos = Theme.of(context).textTheme;

    if (saldoAntes == null || saldoDespues == null) {
      return Text(
        tipo == TipoTransaccion.ingreso
            ? 'Se registró un ingreso de ${formatearMonto(monto)}.'
            : 'Se registró un gasto de ${formatearMonto(monto)}.',
        style: textos.bodySmall,
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: <Widget>[
        Text('Antes: ${formatearMonto(saldoAntes!)}',
            style: textos.bodySmall),
        Text('Monto: ${formatearMonto(monto)}', style: textos.bodySmall),
        Text('Después: ${formatearMonto(saldoDespues!)}',
            style: textos.bodySmall),
      ],
    );
  }
}

class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({
    required this.saldoTotal,
    required this.saldoEfectivo,
    required this.saldoCuentasBancarias,
  });

  final double saldoTotal;
  final double saldoEfectivo;
  final double saldoCuentasBancarias;

  String _formatearSaldo(double monto) {
    return '\$${monto.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;
    final bool modoOscuro = tema.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: modoOscuro
            ? ColoresBaseOscuro.fondoTarjetas
            : ColoresBase.fondoTarjetas,
        borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: modoOscuro
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Resumen general', style: textos.headlineMedium),
          const SizedBox(height: 12),
          Text(
            _formatearSaldo(saldoTotal),
            style: textos.displayMedium?.copyWith(
              color: tema.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text('Saldo total', style: textos.bodyMedium),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: _ItemSaldo(
                  titulo: 'Saldo en efectivo',
                  monto: _formatearSaldo(saldoEfectivo),
                  icono: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ItemSaldo(
                  titulo: 'Saldo bancario',
                  monto: _formatearSaldo(saldoCuentasBancarias),
                  icono: Icons.account_balance_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemSaldo extends StatelessWidget {
  const _ItemSaldo({
    required this.titulo,
    required this.monto,
    required this.icono,
  });

  final String titulo;
  final String monto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = tema.textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tema.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Bordes.radioTarjetas / 1.5),
      ),
      child: Row(
        children: <Widget>[
          Icon(icono, color: tema.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(titulo, style: textos.bodySmall),
                const SizedBox(height: 4),
                Text(
                  monto,
                  style: textos.labelLarge?.copyWith(
                    color: tema.colorScheme.onSurface,
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

class _AccionBoton extends StatelessWidget {
  const _AccionBoton({
    required this.etiqueta,
    required this.icono,
    required this.colorBase,
    this.onPressed,
  });

  final String etiqueta;
  final IconData icono;
  final Color colorBase;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final Color fondo = colorBase.withValues(alpha: 0.16);
    final Color borde = colorBase.withValues(alpha: 0.4);
    final Color iconoFondo = colorBase.withValues(alpha: 0.24);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
        onTap: onPressed ?? () => _mostrarNotificacionPlaceholder(context),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            color: fondo,
            border: Border.all(color: borde, width: 1.2),
            borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconoFondo,
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: colorBase),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  etiqueta,
                  style: tema.textTheme.labelLarge?.copyWith(color: colorBase),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorBase.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarNotificacionPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidad en desarrollo.')),
    );
  }
}
