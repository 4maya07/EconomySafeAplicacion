import 'package:flutter/foundation.dart';

/// Periodicidad configurada para una categoría de gasto.
enum CategoriaFrecuencia {
  ninguna,
  mensual,
  bimestral,
  trimestral,
  cuatrimestral,
  anual,
  personalizada,
}

CategoriaFrecuencia _frecuenciaDesdeString(String? valor) {
  if (valor == null || valor.isEmpty) {
    return CategoriaFrecuencia.ninguna;
  }
  return CategoriaFrecuencia.values.firstWhere(
    (CategoriaFrecuencia item) => item.name == valor,
    orElse: () => CategoriaFrecuencia.ninguna,
  );
}

String _frecuenciaAString(CategoriaFrecuencia frecuencia) => frecuencia.name;

String _etiquetaFrecuencia(CategoriaFrecuencia frecuencia) {
  switch (frecuencia) {
    case CategoriaFrecuencia.ninguna:
      return 'Sin periodicidad';
    case CategoriaFrecuencia.mensual:
      return 'Mensual';
    case CategoriaFrecuencia.bimestral:
      return 'Bimestral';
    case CategoriaFrecuencia.trimestral:
      return 'Trimestral';
    case CategoriaFrecuencia.cuatrimestral:
      return 'Cuatrimestral';
    case CategoriaFrecuencia.anual:
      return 'Anual';
    case CategoriaFrecuencia.personalizada:
      return 'Rango personalizado';
  }
}

/// Representa una categoría de gasto configurada por el usuario.
@immutable
class CategoriaGastoModelo {
  const CategoriaGastoModelo({
    this.id,
    required this.usuarioId,
    required this.nombre,
    this.descripcion,
    required this.montoMaximo,
    this.montoGastado = 0,
    this.montoAdicionalPermitido = 0,
    this.frecuencia = CategoriaFrecuencia.ninguna,
    this.fechaInicio,
    this.fechaFin,
    this.creadoEl,
    this.actualizadoEl,
  });

  factory CategoriaGastoModelo.desdeMapa(Map<String, dynamic> datos) {
    return CategoriaGastoModelo(
      id: datos['id'] as String?,
      usuarioId: datos['usuario_id'] as String,
      nombre: datos['nombre'] as String? ?? '',
      descripcion: datos['descripcion'] as String?,
      montoMaximo: _aDouble(datos['monto_maximo']) ?? 0,
      montoGastado: _aDouble(datos['monto_gastado']) ?? 0,
      montoAdicionalPermitido:
          _aDouble(datos['monto_adicional_permitido']) ?? 0,
      frecuencia: _frecuenciaDesdeString(datos['frecuencia'] as String?),
      fechaInicio: _aFecha(datos['fecha_inicio']),
      fechaFin: _aFecha(datos['fecha_fin']),
      creadoEl: _aFecha(datos['created_at']),
      actualizadoEl: _aFecha(datos['updated_at']),
    );
  }

  Map<String, dynamic> aMapaPersistencia({bool incluirUsuario = false}) {
    final Map<String, dynamic> mapa = <String, dynamic>{
      'nombre': nombre,
      'descripcion': descripcion,
      'monto_maximo': montoMaximo,
      'monto_gastado': montoGastado,
      'monto_adicional_permitido': montoAdicionalPermitido,
      'frecuencia': _frecuenciaAString(frecuencia),
      'fecha_inicio': fechaInicio?.toIso8601String(),
      'fecha_fin': fechaFin?.toIso8601String(),
    };

    if (incluirUsuario) {
      mapa['usuario_id'] = usuarioId;
    }

    return mapa;
  }

  CategoriaGastoModelo copiarCon({
    String? id,
    String? usuarioId,
    String? nombre,
    String? descripcion,
    double? montoMaximo,
    double? montoGastado,
    double? montoAdicionalPermitido,
    CategoriaFrecuencia? frecuencia,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    DateTime? creadoEl,
    DateTime? actualizadoEl,
  }) {
    return CategoriaGastoModelo(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      montoMaximo: montoMaximo ?? this.montoMaximo,
      montoGastado: montoGastado ?? this.montoGastado,
      montoAdicionalPermitido:
          montoAdicionalPermitido ?? this.montoAdicionalPermitido,
      frecuencia: frecuencia ?? this.frecuencia,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      creadoEl: creadoEl ?? this.creadoEl,
      actualizadoEl: actualizadoEl ?? this.actualizadoEl,
    );
  }

  final String? id;
  final String usuarioId;
  final String nombre;
  final String? descripcion;
  final double montoMaximo;
  final double montoGastado;
  final double montoAdicionalPermitido;
  final CategoriaFrecuencia frecuencia;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final DateTime? creadoEl;
  final DateTime? actualizadoEl;

  double get porcentajeConsumido {
    if (montoMaximo <= 0) {
      return 0;
    }
    return (montoGastado / montoMaximo).clamp(0, double.infinity);
  }

  bool get sobreLimite => montoGastado > montoMaximo;

  bool get tieneRangoFechas => fechaInicio != null && fechaFin != null;

  String get etiquetaFrecuencia => _etiquetaFrecuencia(frecuencia);
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
