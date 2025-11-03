import 'package:supabase_flutter/supabase_flutter.dart';

import '../modelos/cuenta_bancaria_modelo.dart';
import '../datos/supabase/supabase_servicio.dart';

/// Capa de acceso a datos remotos para la gestión de cuentas bancarias.
class CuentasServicio {
  CuentasServicio({SupabaseClient? cliente})
    : _cliente = cliente ?? SupabaseServicio.obtenerCliente();

  final SupabaseClient _cliente;

  static const String _tablaCuentas = 'cuentas_bancarias';
  static const String _tablaCatalogo = 'catalogo_bancos';
  static const String _vistaResumen = 'v_resumen_cuentas';

  Future<List<BancoCatalogoModelo>> obtenerCatalogoBancos() async {
    final List<dynamic> datos = await _cliente
        .from(_tablaCatalogo)
        .select()
        .eq('es_activo', true)
        .order('nombre');

    return datos
        .map(
          (dynamic item) =>
              BancoCatalogoModelo.desdeMapa(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<CuentaBancariaModelo>> obtenerCuentas(String usuarioId) async {
  final List<dynamic> datos = await _cliente
    .from(_tablaCuentas)
    .select('*, catalogo_bancos(nombre)')
    .eq('usuario_id', usuarioId)
    .order('creado_el', ascending: false);

    return datos
        .map(
          (dynamic item) =>
              CuentaBancariaModelo.desdeMapa(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<ResumenCuentasModelo?> obtenerResumen(String usuarioId) async {
    final Map<String, dynamic>? dato = await _cliente
        .from(_vistaResumen)
        .select()
        .eq('usuario_id', usuarioId)
        .maybeSingle();

    if (dato == null) {
      return null;
    }
    return ResumenCuentasModelo.desdeMapa(dato);
  }

  Future<CuentaBancariaModelo> crearCuenta(CuentaBancariaModelo cuenta) async {
    final Map<String, dynamic> respuesta = await _cliente
        .from(_tablaCuentas)
    .insert(cuenta.aMapaPersistencia(incluirUsuario: true))
    .select('*, catalogo_bancos(nombre)')
        .single();

    return CuentaBancariaModelo.desdeMapa(respuesta);
  }

  Future<CuentaBancariaModelo> actualizarCuenta(
    CuentaBancariaModelo cuenta,
  ) async {
    if (cuenta.id == null) {
      throw ArgumentError('La cuenta debe tener un id para actualizarse.');
    }

    final Map<String, dynamic> respuesta = await _cliente
        .from(_tablaCuentas)
        .update(cuenta.aMapaPersistencia())
        .eq('id', cuenta.id!)
    .select('*, catalogo_bancos(nombre)')
        .single();

    return CuentaBancariaModelo.desdeMapa(respuesta);
  }

  Future<void> eliminarCuenta(String cuentaId) async {
    await _cliente.from(_tablaCuentas).delete().eq('id', cuentaId);
  }
}
