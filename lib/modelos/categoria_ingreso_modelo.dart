import 'package:flutter/foundation.dart';

enum FrecuenciaIngreso {
  unaVez,
  semanal,
  quincenal,
  mensual,
  trimestral,
  otro,
}

FrecuenciaIngreso frecuenciaIngresoDesdeString(String valor) {
  return FrecuenciaIngreso.values.firstWhere(
    (FrecuenciaIngreso frecuencia) => frecuencia.name == valor,
    orElse: () => FrecuenciaIngreso.unaVez,
  );
}

String frecuenciaIngresoATexto(FrecuenciaIngreso frecuencia) {
  switch (frecuencia) {
    case FrecuenciaIngreso.unaVez:
      return 'Una vez';
    case FrecuenciaIngreso.semanal:
      return 'Semanal';
    case FrecuenciaIngreso.quincenal:
      return 'Quincenal';
    case FrecuenciaIngreso.mensual:
      return 'Mensual';
    case FrecuenciaIngreso.trimestral:
      return 'Trimestral';
    case FrecuenciaIngreso.otro:
      return 'Otra frecuencia';
  }
}

@immutable
class CategoriaIngresoModelo {
  const CategoriaIngresoModelo({
    this.id,
    required this.usuarioId,
    required this.nombre,
    this.descripcion,
    required this.frecuencia,
    this.creadoEl,
    this.actualizadoEl,
  });

  factory CategoriaIngresoModelo.desdeMapa(Map<String, dynamic> datos) {
    return CategoriaIngresoModelo(
      id: datos['id'] as String?,
      usuarioId: datos['usuario_id'] as String,
      nombre: datos['nombre'] as String? ?? '',
      descripcion: datos['descripcion'] as String?,
      frecuencia: frecuenciaIngresoDesdeString(
        datos['frecuencia'] as String? ?? 'unaVez',
      ),
      creadoEl: _aFecha(datos['created_at']),
      actualizadoEl: _aFecha(datos['updated_at']),
    );
  }

  Map<String, dynamic> aMapaPersistencia({bool incluirUsuario = false}) {
    final Map<String, dynamic> mapa = <String, dynamic>{
      'nombre': nombre,
      'descripcion': descripcion,
      'frecuencia': frecuencia.name,
    };

    if (incluirUsuario) {
      mapa['usuario_id'] = usuarioId;
    }

    return mapa;
  }

  CategoriaIngresoModelo copiarCon({
    String? id,
    String? usuarioId,
    String? nombre,
    String? descripcion,
    FrecuenciaIngreso? frecuencia,
    DateTime? creadoEl,
    DateTime? actualizadoEl,
  }) {
    return CategoriaIngresoModelo(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      frecuencia: frecuencia ?? this.frecuencia,
      creadoEl: creadoEl ?? this.creadoEl,
      actualizadoEl: actualizadoEl ?? this.actualizadoEl,
    );
  }

  final String? id;
  final String usuarioId;
  final String nombre;
  final String? descripcion;
  final FrecuenciaIngreso frecuencia;
  final DateTime? creadoEl;
  final DateTime? actualizadoEl;
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
