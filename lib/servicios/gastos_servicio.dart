import 'package:supabase_flutter/supabase_flutter.dart';

import '../datos/supabase/supabase_servicio.dart';
import '../modelos/gasto_modelo.dart';

/// Gestiona las operaciones remotas relacionadas con la tabla `gastos`.
class GastosServicio {
  GastosServicio({SupabaseClient? cliente})
    : _cliente = cliente ?? SupabaseServicio.obtenerCliente();

  final SupabaseClient _cliente;

  static const String _tablaGastos = 'gastos';
  static const String _camposDetalle =
      '*, categorias_gasto(nombre), cuentas_bancarias(banco_personalizado, numero_cuenta, catalogo_bancos(nombre))';

  Future<List<GastoModelo>> obtenerGastos(
    String usuarioId, {
    DateTime? desde,
    DateTime? hasta,
    String? categoriaId,
    String? cuentaId,
  }) async {
    var consulta = _cliente
        .from(_tablaGastos)
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
    if (cuentaId != null) {
      consulta = consulta.eq('cuenta_id', cuentaId);
    }

    final List<dynamic> datos = await consulta
        .order('fecha', ascending: false)
        .order('created_at', ascending: false);

    return datos
        .map(
          (dynamic item) =>
              GastoModelo.desdeMapa(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<GastoModelo?> obtenerGastoPorId(String gastoId) async {
    final Map<String, dynamic>? dato = await _cliente
        .from(_tablaGastos)
        .select(_camposDetalle)
        .eq('id', gastoId)
        .maybeSingle();

    if (dato == null) {
      return null;
    }
    return GastoModelo.desdeMapa(dato);
  }

  Future<GastoModelo> crearGasto(GastoModelo gasto) async {
    final Map<String, dynamic> respuesta = await _cliente.rpc(
      'fn_gastos_crear',
      params: <String, dynamic>{
        'p_usuario_id': gasto.usuarioId,
        'p_categoria_id': gasto.categoriaId,
        'p_cuenta_id': gasto.cuentaId,
        'p_monto': gasto.monto,
        'p_descripcion': gasto.descripcion,
        'p_tipo': gasto.medioPago.name,
        'p_frecuencia': gasto.frecuencia.name,
        'p_tipo_gasto': gasto.tipoGasto.name,
        'p_fecha': gasto.fecha.toIso8601String(),
        'p_foto_url': gasto.fotoUrl,
      },
    );

    final String gastoId = (respuesta['id'] as String?) ??
        (throw StateError('No se recibió el identificador del gasto creado.'));

    final GastoModelo? conDetalles = await obtenerGastoPorId(gastoId);
    if (conDetalles == null) {
      throw StateError('El gasto creado no se pudo recuperar.');
    }
    return conDetalles;
  }

  Future<GastoModelo> actualizarGasto(GastoModelo gasto) async {
    if (gasto.id == null) {
      throw ArgumentError('El gasto debe tener un id para actualizarse.');
    }

    final Map<String, dynamic> respuesta = await _cliente.rpc(
      'fn_gastos_actualizar',
      params: <String, dynamic>{
        'p_id': gasto.id,
        'p_usuario_id': gasto.usuarioId,
        'p_categoria_id': gasto.categoriaId,
        'p_cuenta_id': gasto.cuentaId,
        'p_monto': gasto.monto,
        'p_descripcion': gasto.descripcion,
        'p_tipo': gasto.medioPago.name,
        'p_frecuencia': gasto.frecuencia.name,
        'p_tipo_gasto': gasto.tipoGasto.name,
        'p_fecha': gasto.fecha.toIso8601String(),
        'p_foto_url': gasto.fotoUrl,
      },
    );

    final String gastoId = (respuesta['id'] as String?) ?? gasto.id!;

    final GastoModelo? conDetalles = await obtenerGastoPorId(gastoId);
    if (conDetalles == null) {
      throw StateError('El gasto actualizado no se pudo recuperar.');
    }
    return conDetalles;
  }

  Future<void> eliminarGasto({
    required String gastoId,
    required String usuarioId,
  }) async {
    await _cliente.rpc(
      'fn_gastos_eliminar',
      params: <String, dynamic>{
        'p_id': gastoId,
        'p_usuario_id': usuarioId,
      },
    );
  }
}
