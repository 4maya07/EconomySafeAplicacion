import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../servicios/reportes_servicio.dart';
import '../sistema_diseno/identidad_visual.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ReportesScreenState createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  String tipoReporte = 'Comparativo';
  DateTimeRange? rangoFechas;
  String categoria = 'Todas';
  String tipoGasto = 'Todos';
  String metodoPago = 'Todos';
  bool _cargando = false;
  String? _error;
  Map<String, dynamic>? _respuestaBackend;
  Map<String, dynamic>? _datosFinancieros;
  final ReportesServicio _servicio = ReportesServicio();

  @override
  void dispose() {
    _servicio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reportes',
          style: TipografiaApp
              .obtenerTextTheme(Theme.of(context).brightness)
              .displayMedium,
        ),
        backgroundColor: ColoresAcciones.primario,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Tipo de reporte:',
            style: TipografiaApp
                .obtenerTextTheme(Theme.of(context).brightness)
                .headlineMedium,
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: tipoReporte,
            items: const <String>[
              'Comparativo',
              'Evolución anual',
              'Desglose por categoría',
            ]
                .map(
                  (String e) => DropdownMenuItem<String>(value: e, child: Text(e)),
                )
                .toList(),
            onChanged: (String? v) => setState(() => tipoReporte = v ?? tipoReporte),
          ),
          const SizedBox(height: 16),
          Text(
            'Rango de fechas:',
            style: TipografiaApp
                .obtenerTextTheme(Theme.of(context).brightness)
                .headlineMedium,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColoresAcciones.primario,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
              ),
            ),
            onPressed: _seleccionarRango,
            child: Text(
              rangoFechas == null
                  ? 'Seleccionar'
                  : '${_formatearFecha(rangoFechas!.start)} - ${_formatearFecha(rangoFechas!.end)}',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Filtrar por categoría:',
            style: TipografiaApp
                .obtenerTextTheme(Theme.of(context).brightness)
                .headlineMedium,
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: categoria,
            items: const <String>['Todas', 'Comida', 'Transporte', 'Salud', 'Ocio']
                .map(
                  (String e) => DropdownMenuItem<String>(value: e, child: Text(e)),
                )
                .toList(),
            onChanged: (String? v) => setState(() => categoria = v ?? categoria),
          ),
          const SizedBox(height: 16),
          Text(
            'Tipo de gasto:',
            style: TipografiaApp
                .obtenerTextTheme(Theme.of(context).brightness)
                .headlineMedium,
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: tipoGasto,
            items: const <String>['Todos', 'Fijo', 'Variable']
                .map(
                  (String e) => DropdownMenuItem<String>(value: e, child: Text(e)),
                )
                .toList(),
            onChanged: (String? v) => setState(() => tipoGasto = v ?? tipoGasto),
          ),
          const SizedBox(height: 16),
          Text(
            'Método de pago:',
            style: TipografiaApp
                .obtenerTextTheme(Theme.of(context).brightness)
                .headlineMedium,
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: metodoPago,
            items: const <String>['Todos', 'Efectivo', 'Tarjeta', 'Transferencia']
                .map(
                  (String e) => DropdownMenuItem<String>(value: e, child: Text(e)),
                )
                .toList(),
            onChanged: (String? v) => setState(() => metodoPago = v ?? metodoPago),
          ),
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColoresAcciones.primario,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
                  ),
                ),
                icon: const Icon(Icons.bar_chart),
                label: const Text('Ver gráfico'),
                onPressed: _cargando ? null : _generarReporte,
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColoresAcciones.secundario,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
                  ),
                ),
                icon: const Icon(Icons.download),
                label: const Text('Exportar'),
                onPressed: _mostrarAvisoExportacion,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _construirResultado(),
        ],
      ),
    );
  }

  Future<void> _seleccionarRango() async {
    final DateTimeRange? seleccionado = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (seleccionado != null) {
      setState(() => rangoFechas = seleccionado);
    }
  }

  Future<void> _generarReporte() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final User? usuario = Supabase.instance.client.auth.currentUser;
    if (usuario == null) {
      setState(() {
        _cargando = false;
        _error = 'Debes iniciar sesión para generar reportes.';
      });
      return;
    }

    try {
      final ReporteFiltro filtro = ReporteFiltro(
        usuarioId: usuario.id,
        tipo: _mapearTipoReporte(tipoReporte),
        fechaInicio: rangoFechas?.start,
        fechaFin: rangoFechas?.end,
        categoriaId: categoria == 'Todas' ? null : categoria,
        tipoGasto: _mapearTipoGasto(tipoGasto),
        metodoPago: _mapearMetodoPago(metodoPago),
      );

      final Map<String, dynamic> datosPrevios =
          await _servicio.obtenerDatosFinancieros(filtro);
      if (mounted) {
        setState(() => _datosFinancieros = datosPrevios);
      }

      final Map<String, dynamic> respuesta =
          await _servicio.generarReporte(filtro);
      setState(() {
        _respuestaBackend = respuesta;
        _datosFinancieros =
            (respuesta['datos_financieros'] as Map<String, dynamic>?) ??
                _datosFinancieros;
      });
    } on ReportesServicioException catch (e) {
      setState(() => _error = e.mensaje);
    } catch (e) {
      setState(() => _error = 'No fue posible generar el reporte: $e');
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _mostrarAvisoExportacion() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La exportación estará disponible próximamente.'),
      ),
    );
  }

  String _formatearFecha(DateTime fecha) =>
      '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

  String _mapearTipoReporte(String opcion) {
    switch (opcion) {
      case 'Evolución anual':
        return 'evolucion_anual';
      case 'Desglose por categoría':
        return 'desglose_categoria';
      case 'Comparativo':
      default:
        return 'comparativo';
    }
  }

  String? _mapearTipoGasto(String opcion) {
    switch (opcion) {
      case 'Fijo':
        return 'fijo';
      case 'Variable':
        return 'variable';
      default:
        return null;
    }
  }

  String? _mapearMetodoPago(String opcion) {
    switch (opcion) {
      case 'Efectivo':
        return 'efectivo';
      case 'Tarjeta':
        return 'tarjeta';
      case 'Transferencia':
        return 'transferencia';
      default:
        return null;
    }
  }

  Widget _construirResultado() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      final TextStyle baseError = TipografiaApp
              .obtenerTextTheme(Theme.of(context).brightness)
              .bodyLarge ??
          const TextStyle(fontSize: 16);
      return Card(
        color: AlertasColores.error.fondo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
          side: BorderSide(color: AlertasColores.error.borde),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: baseError.copyWith(color: AlertasColores.error.texto),
          ),
        ),
      );
    }
    if (_respuestaBackend == null && _datosFinancieros == null) {
      return Text(
        'Genera un reporte para visualizar los datos de esta sección.',
        style: TipografiaApp
            .obtenerTextTheme(Theme.of(context).brightness)
            .bodyMedium,
      );
    }

    final Map<String, dynamic>? datos = _datosFinancieros;
    final Map<String, dynamic>? analisis =
        _respuestaBackend?['reporte_modelo'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (datos != null) _construirResumenFinanciero(datos),
        if (analisis != null) ...<Widget>[
          const SizedBox(height: 16),
          _construirBloqueAnalisis(analisis),
        ],
      ],
    );
  }

  Widget _construirResumenFinanciero(Map<String, dynamic> datos) {
    final Map<String, dynamic> ingresos =
        (datos['ingresos'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic> gastos =
        (datos['gastos'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic> balance =
        (datos['balance'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final num totalIngresos = (ingresos['total'] as num?) ?? 0;
    final num totalGastos = (gastos['total'] as num?) ?? 0;
    final num balanceNeto = (balance['neto'] as num?) ?? 0;
    final double? ratio =
        (balance['ratio_gastos_sobre_ingresos'] as num?)?.toDouble();

    final List<Map<String, dynamic>> topGastos =
        (gastos['por_categoria'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .take(3)
            .toList();
    final List<Map<String, dynamic>> topIngresos =
        (ingresos['por_categoria'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .take(3)
            .toList();

    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
        side: const BorderSide(color: Bordes.bordeGeneral),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Resumen financiero del periodo',
              style: TipografiaApp
                  .obtenerTextTheme(Theme.of(context).brightness)
                  .headlineMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: <Widget>[
                _chipResumen('Ingresos', _formatearMoneda(totalIngresos)),
                _chipResumen('Gastos', _formatearMoneda(totalGastos)),
                _chipResumen('Balance', _formatearMoneda(balanceNeto),
                    destacado: balanceNeto >= 0),
                if (ratio != null)
                  _chipResumen(
                    'Gastos/Ingresos',
                    '${(ratio * 100).toStringAsFixed(1)}%',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (topGastos.isNotEmpty)
              _ListaTopCategorias(
                titulo: 'Top categorías de gasto',
                elementos: topGastos,
              ),
            if (topIngresos.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _ListaTopCategorias(
                titulo: 'Top categorías de ingreso',
                elementos: topIngresos,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _construirBloqueAnalisis(Map<String, dynamic> analisis) {
    final String contenidoFormato =
        const JsonEncoder.withIndent('  ').convert(analisis);

    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
        side: const BorderSide(color: Bordes.bordeGeneral),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Análisis generado por IA',
              style: TipografiaApp
                  .obtenerTextTheme(Theme.of(context).brightness)
                  .headlineMedium,
            ),
            const SizedBox(height: 12),
            SelectableText(
              contenidoFormato,
              style: TipografiaApp
                  .obtenerTextTheme(Theme.of(context).brightness)
                  .bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipResumen(String titulo, String valor, {bool destacado = false}) {
    final ThemeData tema = Theme.of(context);
    final ColorScheme esquema = tema.colorScheme;
    final Color fondo = destacado
        ? esquema.primary.withOpacity(0.15)
        : esquema.surfaceVariant.withOpacity(0.35);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
        border: Border.all(color: esquema.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            titulo,
            style: tema.textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatearMoneda(num valor) {
    final Locale locale = Localizations.localeOf(context);
    final NumberFormat formato =
        NumberFormat.simpleCurrency(locale: locale.toString());
    return formato.format(valor);
  }
}

class _ListaTopCategorias extends StatelessWidget {
  const _ListaTopCategorias({
    required this.titulo,
    required this.elementos,
  });

  final String titulo;
  final List<Map<String, dynamic>> elementos;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final TextTheme textos = TipografiaApp.obtenerTextTheme(tema.brightness);
    final NumberFormat formatoMoneda = NumberFormat.simpleCurrency(
      locale: Localizations.localeOf(context).toString(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          titulo,
          style: textos.titleMedium,
        ),
        const SizedBox(height: 8),
        ...elementos.map((Map<String, dynamic> item) {
          final String nombre = (item['valor'] ?? 'Sin categoría').toString();
          final num total = (item['total'] as num?) ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Text(
                    nombre,
                    style: textos.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatoMoneda.format(total),
                  style:
                      textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
