import 'package:flutter/material.dart';

import '../../modelos/cuenta_bancaria_modelo.dart';
import 'cuentas/cuentas_vista.dart';
import 'dashboard_vista.dart';

/// Contenedor principal con navegación inferior y dashboard financiero.
class PrincipalVista extends StatefulWidget {
  const PrincipalVista({super.key});

  @override
  State<PrincipalVista> createState() => _PrincipalVistaState();
}

class _PrincipalVistaState extends State<PrincipalVista> {
  int _indiceActual = 0;
  final double _saldoEfectivo = 1250.50;
  double _saldoCuentasBancarias = 0;

  void _cambiarIndice(int nuevoIndice) {
    setState(() => _indiceActual = nuevoIndice);
  }

  void _actualizarResumenCuentas(ResumenCuentasModelo resumen) {
    setState(() {
      _saldoCuentasBancarias = resumen.totalDepositos;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double saldoTotal = _saldoEfectivo + _saldoCuentasBancarias;
    final List<Widget> secciones = <Widget>[
      DashboardVista(
        saldoTotal: saldoTotal,
        saldoEfectivo: _saldoEfectivo,
        saldoCuentasBancarias: _saldoCuentasBancarias,
      ),
      CuentasVista(onResumenActualizado: _actualizarResumenCuentas),
      const _SeccionPlaceholder(titulo: 'Ahorro'),
      const _SeccionPlaceholder(titulo: 'Reportes'),
      const _SeccionPlaceholder(titulo: 'Perfil'),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _indiceActual, children: secciones),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: _cambiarIndice,
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_outlined),
            label: 'Cuentas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.savings_outlined),
            label: 'Ahorro',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline),
            label: 'Reportes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _SeccionPlaceholder extends StatelessWidget {
  const _SeccionPlaceholder({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.construction_outlined,
            size: 64,
            color: tema.colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            '$titulo en desarrollo',
            style: tema.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pronto podrás consultar tus datos de $titulo.',
            style: tema.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
