import 'package:flutter/material.dart';

import '../../sistema_diseno/identidad_visual.dart';

/// Presenta el resumen financiero principal del usuario.
class DashboardVista extends StatelessWidget {
  const DashboardVista({
    super.key,
    required this.saldoTotal,
    required this.saldoEfectivo,
    required this.saldoCuentasBancarias,
    this.onCategoriasGasto,
    this.onNuevoGasto,
    this.onCategoriasIngreso,
    this.onNuevoIngreso,
  });

  final double saldoTotal;
  final double saldoEfectivo;
  final double saldoCuentasBancarias;
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
              final Widget bloqueGastos = Expanded(
                child: Column(
                  children: <Widget>[
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
                ),
              );
              final Widget bloqueIngresos = Expanded(
                child: Column(
                  children: <Widget>[
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
                ),
              );

              if (enUnaColumna) {
                return Column(
                  children: <Widget>[
                    bloqueGastos,
                    const SizedBox(height: 12),
                    bloqueIngresos,
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  bloqueGastos,
                  const SizedBox(width: 12),
                  bloqueIngresos,
                ],
              );
            },
          ),
        ],
      ),
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
