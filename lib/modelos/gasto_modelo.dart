import 'package:flutter/foundation.dart';

import 'cuenta_bancaria_modelo.dart';

enum MedioPagoGasto { efectivo, banco }

enum FrecuenciaGasto { unaVez, semanal, mensual, trimestral, otro }

enum ClasificacionGasto { fijo, variable }

MedioPagoGasto medioPagoDesdeString(String valor) {
  return MedioPagoGasto.values.firstWhere(
    (MedioPagoGasto elemento) => elemento.name == valor,
    orElse: () => MedioPagoGasto.efectivo,
  );
}

FrecuenciaGasto frecuenciaDesdeString(String valor) {
  return FrecuenciaGasto.values.firstWhere(
    (FrecuenciaGasto elemento) => elemento.name == valor,
    orElse: () => FrecuenciaGasto.unaVez,
  );
}

ClasificacionGasto tipoGastoDesdeString(String valor) {
  return ClasificacionGasto.values.firstWhere(
    (ClasificacionGasto elemento) => elemento.name == valor,
    orElse: () => ClasificacionGasto.variable,
  );
}

@immutable
class GastoModelo {
  const GastoModelo({
    this.id,
    required this.usuarioId,
    required this.categoriaId,
    this.categoriaNombre,
    this.cuentaId,
    this.cuentaNombre,
    required this.monto,
    this.descripcion,
    required this.medioPago,
    required this.frecuencia,
    required this.tipoGasto,
    required this.fecha,
    this.fotoUrl,
    this.creadoEl,
    this.actualizadoEl,
  });

  factory GastoModelo.desdeMapa(Map<String, dynamic> datos) {
    final Map<String, dynamic>? categoriaDatos =
        datos['categorias_gasto'] as Map<String, dynamic>?;
    final Map<String, dynamic>? cuentaDatos =
        datos['cuentas_bancarias'] as Map<String, dynamic>?;

    return GastoModelo(
      id: datos['id'] as String?,
      usuarioId: datos['usuario_id'] as String,
      categoriaId: datos['categoria_id'] as String,
      categoriaNombre: categoriaDatos == null
          ? null
          : categoriaDatos['nombre'] as String?,
      cuentaId: datos['cuenta_id'] as String?,
      cuentaNombre:
          cuentaDatos == null ? null : _resolverNombreCuenta(cuentaDatos),
      monto: _aDouble(datos['monto']) ?? 0,
      descripcion: datos['descripcion'] as String?,
      medioPago: medioPagoDesdeString(datos['tipo'] as String? ?? 'efectivo'),
      frecuencia:
          frecuenciaDesdeString(datos['frecuencia'] as String? ?? 'unaVez'),
      tipoGasto:
          tipoGastoDesdeString(datos['tipo_gasto'] as String? ?? 'variable'),
      fecha: _aFecha(datos['fecha']) ?? DateTime.now(),
      fotoUrl: datos['foto_url'] as String?,
      creadoEl: _aFecha(datos['created_at']),
      actualizadoEl: _aFecha(datos['updated_at']),
    );
  }

  Map<String, dynamic> aMapaPersistencia({bool incluirUsuario = false}) {
    final Map<String, dynamic> mapa = <String, dynamic>{
      'categoria_id': categoriaId,
      'cuenta_id': cuentaId,
      'monto': monto,
      'descripcion': descripcion,
      'tipo': medioPago.name,
      'frecuencia': frecuencia.name,
      'tipo_gasto': tipoGasto.name,
      'fecha': fecha.toIso8601String(),
      'foto_url': fotoUrl,
    };

    if (incluirUsuario) {
      mapa['usuario_id'] = usuarioId;
    }

    return mapa;
  }

  GastoModelo copiarCon({
    String? id,
    String? usuarioId,
    String? categoriaId,
    String? cuentaId,
    String? categoriaNombre,
    String? cuentaNombre,
    double? monto,
    String? descripcion,
    MedioPagoGasto? medioPago,
    FrecuenciaGasto? frecuencia,
    ClasificacionGasto? tipoGasto,
    DateTime? fecha,
    String? fotoUrl,
    DateTime? creadoEl,
    DateTime? actualizadoEl,
  }) {
    return GastoModelo(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      categoriaId: categoriaId ?? this.categoriaId,
      categoriaNombre: categoriaNombre ?? this.categoriaNombre,
      cuentaId: cuentaId ?? this.cuentaId,
      cuentaNombre: cuentaNombre ?? this.cuentaNombre,
      monto: monto ?? this.monto,
      descripcion: descripcion ?? this.descripcion,
      medioPago: medioPago ?? this.medioPago,
      frecuencia: frecuencia ?? this.frecuencia,
      tipoGasto: tipoGasto ?? this.tipoGasto,
      fecha: fecha ?? this.fecha,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      creadoEl: creadoEl ?? this.creadoEl,
      actualizadoEl: actualizadoEl ?? this.actualizadoEl,
    );
  }

  final String? id;
  final String usuarioId;
  final String categoriaId;
  final String? categoriaNombre;
  final String? cuentaId;
  final String? cuentaNombre;
  final double monto;
  final String? descripcion;
  final MedioPagoGasto medioPago;
  final FrecuenciaGasto frecuencia;
  final ClasificacionGasto tipoGasto;
  final DateTime fecha;
  final String? fotoUrl;
  final DateTime? creadoEl;
  final DateTime? actualizadoEl;
}

double? _aDouble(dynamic valor) {
  if (valor == null) {
    return null;
  }
  if (valor is num) {
    return valor.toDouble();
  }
  return double.tryParse(valor.toString());
}

DateTime? _aFecha(dynamic valor) {
  if (valor == null) {
    return null;
  }
  if (valor is DateTime) {
    return valor;
  }
  return DateTime.tryParse(valor.toString());
}

String _resolverNombreCuenta(Map<String, dynamic> datos) {
  final Map<String, dynamic>? banco =
      datos['catalogo_bancos'] as Map<String, dynamic>?;
  return CuentaBancariaModelo.construirDescripcion(
    catalogoBancoNombre: banco?['nombre'] as String?,
    bancoPersonalizado: datos['banco_personalizado'] as String?,
    titular: datos['titular'] as String?,
    tipoPlano: datos['tipo'] as String?,
    numeroCuenta: datos['numero_cuenta'] as String?,
  );
}
