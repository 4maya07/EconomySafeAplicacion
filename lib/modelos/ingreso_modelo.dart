import 'package:flutter/foundation.dart';

import 'cuenta_bancaria_modelo.dart';

enum MedioIngreso { efectivo, banco }

enum PeriodicidadIngreso { unaVez, semanal, mensual, trimestral, anual }

MedioIngreso medioIngresoDesdeString(String? valor) {
  return MedioIngreso.values.firstWhere(
    (MedioIngreso item) => item.name == valor,
    orElse: () => MedioIngreso.efectivo,
  );
}

PeriodicidadIngreso periodicidadIngresoDesdeString(String? valor) {
  return PeriodicidadIngreso.values.firstWhere(
    (PeriodicidadIngreso item) => item.name == valor,
    orElse: () => PeriodicidadIngreso.unaVez,
  );
}

@immutable
class IngresoModelo {
  const IngresoModelo({
    this.id,
    required this.usuarioId,
    required this.categoriaId,
    this.categoriaNombre,
    this.cuentaId,
    this.cuentaNombre,
    required this.monto,
    this.descripcion,
    required this.medio,
    required this.periodicidad,
    required this.fecha,
    this.creadoEl,
    this.actualizadoEl,
  });

  factory IngresoModelo.desdeMapa(Map<String, dynamic> datos) {
    final Map<String, dynamic>? categoria =
        datos['categorias_ingreso'] as Map<String, dynamic>?;
    final Map<String, dynamic>? cuenta =
        datos['cuentas_bancarias'] as Map<String, dynamic>?;

    return IngresoModelo(
      id: datos['id'] as String?,
      usuarioId: datos['usuario_id'] as String,
      categoriaId: datos['categoria_id'] as String,
      categoriaNombre: categoria?['nombre'] as String?,
      cuentaId: datos['cuenta_id'] as String?,
      cuentaNombre: cuenta == null ? null : _resolverNombreCuenta(cuenta),
      monto: _aDouble(datos['monto']) ?? 0,
      descripcion: datos['descripcion'] as String?,
      medio: medioIngresoDesdeString(datos['tipo'] as String?),
      periodicidad: periodicidadIngresoDesdeString(
        datos['frecuencia'] as String?,
      ),
      fecha: _aFecha(datos['fecha']) ?? DateTime.now(),
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
      'tipo': medio.name,
      'frecuencia': periodicidad.name,
      'fecha': fecha.toIso8601String(),
    };

    if (incluirUsuario) {
      mapa['usuario_id'] = usuarioId;
    }

    return mapa;
  }

  IngresoModelo copiarCon({
    String? id,
    String? usuarioId,
    String? categoriaId,
    String? categoriaNombre,
    String? cuentaId,
    String? cuentaNombre,
    double? monto,
    String? descripcion,
    MedioIngreso? medio,
    PeriodicidadIngreso? periodicidad,
    DateTime? fecha,
    DateTime? creadoEl,
    DateTime? actualizadoEl,
  }) {
    return IngresoModelo(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      categoriaId: categoriaId ?? this.categoriaId,
      categoriaNombre: categoriaNombre ?? this.categoriaNombre,
      cuentaId: cuentaId ?? this.cuentaId,
      cuentaNombre: cuentaNombre ?? this.cuentaNombre,
      monto: monto ?? this.monto,
      descripcion: descripcion ?? this.descripcion,
      medio: medio ?? this.medio,
      periodicidad: periodicidad ?? this.periodicidad,
      fecha: fecha ?? this.fecha,
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
  final MedioIngreso medio;
  final PeriodicidadIngreso periodicidad;
  final DateTime fecha;
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
