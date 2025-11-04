import 'package:supabase_flutter/supabase_flutter.dart';

import '../datos/supabase/supabase_servicio.dart';
import '../modelos/ingreso_modelo.dart';

/// Gestiona las operaciones remotas relacionadas con la tabla `ingresos`.
class IngresosServicio {
  IngresosServicio({SupabaseClient? cliente})
    : _cliente = cliente ?? SupabaseServicio.obtenerCliente();

  final SupabaseClient _cliente;

  static const String _tabla = 'ingresos';
  static const String _camposDetalle =
      '*, categorias_ingreso(nombre, frecuencia), cuentas_bancarias(banco_personalizado, numero_cuenta, catalogo_bancos(nombre))';

  Future<double> obtenerTotalPorMedio(
    String usuarioId, {
    required MedioIngreso medio,
  }) async {
    final List<IngresoModelo> ingresos = await obtenerIngresos(
      usuarioId,
      medio: medio,
    );

    return ingresos.fold<double>(
      0,
      (double acumulado, IngresoModelo ingreso) => acumulado + ingreso.monto,
    );
  }

  Future<List<IngresoModelo>> obtenerIngresos(
    String usuarioId, {
    DateTime? desde,
    DateTime? hasta,
    String? categoriaId,
    MedioIngreso? medio,
    PeriodicidadIngreso? periodicidad,
  }) async {
    var consulta = _cliente
        .from(_tabla)
        .select(_camposDetalle)
        .eq('usuario_id', usuarioId);

    if (desde != null) {
      consulta = consulta.gte('fecha', desde.toIso8601String());
    }
    if (hasta != null) {
      consulta = consulta.lte('fecha', hasta.toIso8601String());
    }
    if (categoriaId != null) {
      consulta = consulta.eq('categoria_id', categoriaId);
    }
    if (medio != null) {
      consulta = consulta.eq('tipo', medio.name);
    }
    if (periodicidad != null) {
      consulta = consulta.eq('frecuencia', periodicidad.name);
    }

    final List<dynamic> datos = await consulta
        .order('fecha', ascending: false)
        .order('created_at', ascending: false);

    return datos
        .map(
          (dynamic item) =>
              IngresoModelo.desdeMapa(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<IngresoModelo?> obtenerIngresoPorId(String ingresoId) async {
    final Map<String, dynamic>? dato = await _cliente
        .from(_tabla)
        .select(_camposDetalle)
        .eq('id', ingresoId)
        .maybeSingle();

    if (dato == null) {
      return null;
    }
    return IngresoModelo.desdeMapa(dato);
  }

  Future<IngresoModelo> crearIngreso(IngresoModelo ingreso) async {
    final Map<String, dynamic> respuesta = await _cliente.rpc(
      'fn_ingresos_crear',
      params: <String, dynamic>{
        'p_usuario_id': ingreso.usuarioId,
        'p_categoria_id': ingreso.categoriaId,
        'p_cuenta_id': ingreso.cuentaId,
        'p_monto': ingreso.monto,
        'p_descripcion': ingreso.descripcion,
        'p_tipo': ingreso.medio.name,
        'p_frecuencia': ingreso.periodicidad.name,
        'p_fecha': ingreso.fecha.toIso8601String(),
      },
    );

    final String ingresoId =
        (respuesta['id'] as String?) ??
        (throw StateError('No se recibió el identificador del ingreso.'));

    final IngresoModelo? conDetalles = await obtenerIngresoPorId(ingresoId);
    if (conDetalles == null) {
      throw StateError('El ingreso creado no se pudo recuperar.');
    }
    return conDetalles;
  }

  Future<IngresoModelo> actualizarIngreso(IngresoModelo ingreso) async {
    if (ingreso.id == null) {
      throw ArgumentError('El ingreso debe tener un id para actualizarse.');
    }

    final Map<String, dynamic> respuesta = await _cliente.rpc(
      'fn_ingresos_actualizar',
      params: <String, dynamic>{
        'p_id': ingreso.id,
        'p_usuario_id': ingreso.usuarioId,
        'p_categoria_id': ingreso.categoriaId,
        'p_cuenta_id': ingreso.cuentaId,
        'p_monto': ingreso.monto,
        'p_descripcion': ingreso.descripcion,
        'p_tipo': ingreso.medio.name,
        'p_frecuencia': ingreso.periodicidad.name,
        'p_fecha': ingreso.fecha.toIso8601String(),
      },
    );

    final String ingresoId = (respuesta['id'] as String?) ?? ingreso.id!;

    final IngresoModelo? conDetalles = await obtenerIngresoPorId(ingresoId);
    if (conDetalles == null) {
      throw StateError('El ingreso actualizado no se pudo recuperar.');
    }
    return conDetalles;
  }

  Future<void> eliminarIngreso({
    required String ingresoId,
    required String usuarioId,
  }) async {
    await _cliente.rpc(
      'fn_ingresos_eliminar',
      params: <String, dynamic>{'p_id': ingresoId, 'p_usuario_id': usuarioId},
    );
  }
}
