import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../modelos/cuenta_bancaria_modelo.dart';
import '../../modelos/ingreso_modelo.dart';
import '../../servicios/cuentas_servicio.dart';
import '../../servicios/ingresos_servicio.dart';
import 'categorias_gasto/categorias_gasto_vista.dart';
import 'categorias_ingreso/categorias_ingreso_vista.dart';
import 'cuentas/cuentas_vista.dart';
import 'dashboard_vista.dart';
import 'gastos/gastos_vista.dart';
import 'ingresos/ingresos_vista.dart';

/// Contenedor principal con navegación inferior y dashboard financiero.
class PrincipalVista extends StatefulWidget {
  const PrincipalVista({super.key});

  @override
  State<PrincipalVista> createState() => _PrincipalVistaState();
}

class _PrincipalVistaState extends State<PrincipalVista> {
  int _indiceActual = 0;
  double _saldoEfectivo = 0;
  double _saldoCuentasBancarias = 0;
  final CuentasServicio _cuentasServicio = CuentasServicio();
  final IngresosServicio _ingresosServicio = IngresosServicio();
  final ValueNotifier<int> _recargaCuentasNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _refrescarResumenFinanzas();
  }

  @override
  void dispose() {
    _recargaCuentasNotifier.dispose();
    super.dispose();
  }

  void _cambiarIndice(int nuevoIndice) {
    setState(() => _indiceActual = nuevoIndice);
  }

  void _actualizarResumenCuentas(ResumenCuentasModelo resumen) {
    setState(() {
      _saldoCuentasBancarias = resumen.totalDepositos;
    });
    _refrescarSaldoEfectivo();
  }

  Future<void> _abrirCategoriasGasto() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CategoriasGastoVista()),
    );
    await _refrescarResumenFinanzas();
  }

  Future<void> _abrirCategoriasIngreso() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CategoriasIngresoVista()),
    );
    await _refrescarResumenFinanzas();
  }

  Future<void> _abrirGastos({bool abrirFormulario = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GastosVista(abrirFormularioAlIniciar: abrirFormulario),
      ),
    );
    await _refrescarResumenFinanzas();
  }

  Future<void> _abrirIngresos({bool abrirFormulario = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            IngresosVista(
          abrirFormularioAlIniciar: abrirFormulario,
          onIngresosActualizados: _notificarCambiosFinancieros,
        ),
      ),
    );
    await _refrescarResumenFinanzas();
  }

  void _notificarCambiosFinancieros() {
    _refrescarResumenFinanzas();
    _recargaCuentasNotifier.value = _recargaCuentasNotifier.value + 1;
  }

  Future<void> _refrescarSaldoEfectivo() async {
    final User? usuario = Supabase.instance.client.auth.currentUser;
    if (usuario == null) {
      return;
    }

    try {
      final double totalEfectivo = await _ingresosServicio.obtenerTotalPorMedio(
        usuario.id,
        medio: MedioIngreso.efectivo,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _saldoEfectivo = totalEfectivo;
      });
    } catch (_) {
      // Se ignoran errores para mantener la experiencia fluida.
    }
  }

  Future<void> _refrescarResumenFinanzas() async {
    final User? usuario = Supabase.instance.client.auth.currentUser;
    if (usuario == null) {
      return;
    }

    try {
      final List<dynamic> resultados = await Future.wait<dynamic>(
        <Future<dynamic>>[
          _cuentasServicio.obtenerResumen(usuario.id),
          _ingresosServicio.obtenerTotalPorMedio(
            usuario.id,
            medio: MedioIngreso.efectivo,
          ),
        ],
      );

      if (!mounted) {
        return;
      }

      final ResumenCuentasModelo? resumen =
          resultados[0] as ResumenCuentasModelo?;
      final double saldoEfectivo = resultados[1] as double;

      setState(() {
        _saldoCuentasBancarias = resumen?.totalDepositos ?? 0;
        _saldoEfectivo = saldoEfectivo;
      });
    } catch (_) {
      // Ignorar errores silenciosamente para no interrumpir la navegación.
    }
  }

  @override
  Widget build(BuildContext context) {
    final double saldoTotal = _saldoEfectivo + _saldoCuentasBancarias;
    final List<Widget> secciones = <Widget>[
      DashboardVista(
        saldoTotal: saldoTotal,
        saldoEfectivo: _saldoEfectivo,
        saldoCuentasBancarias: _saldoCuentasBancarias,
        onCategoriasGasto: _abrirCategoriasGasto,
        onCategoriasIngreso: _abrirCategoriasIngreso,
        onNuevoGasto: () => _abrirGastos(abrirFormulario: true),
        onNuevoIngreso: () => _abrirIngresos(abrirFormulario: true),
      ),
      CuentasVista(
        key: const PageStorageKey<String>('cuentas'),
        onResumenActualizado: _actualizarResumenCuentas,
        recargaNotifier: _recargaCuentasNotifier,
      ),
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
