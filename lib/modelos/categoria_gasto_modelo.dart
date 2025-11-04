import 'package:flutter/foundation.dart';

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
  final DateTime? creadoEl;
  final DateTime? actualizadoEl;

  double get porcentajeConsumido {
    if (montoMaximo <= 0) {
      return 0;
    }
    return (montoGastado / montoMaximo).clamp(0, double.infinity);
  }

  bool get sobreLimite => montoGastado > montoMaximo;
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
