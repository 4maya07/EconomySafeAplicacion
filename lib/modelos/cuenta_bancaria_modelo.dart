import 'package:flutter/foundation.dart';

/// Enumeración base para los tipos de cuenta disponibles en la plataforma.
enum TipoCuenta { nomina, negocios, ahorro, credito }

/// Convierte un valor almacenado en Supabase al [TipoCuenta] correspondiente.
TipoCuenta tipoCuentaDesdeString(String valor) {
  return TipoCuenta.values.firstWhere(
    (TipoCuenta tipo) => tipo.name == valor,
    orElse: () => TipoCuenta.ahorro,
  );
}

/// Modelo que representa una fila de la tabla `catalogo_bancos`.
@immutable
class BancoCatalogoModelo {
  const BancoCatalogoModelo({
    required this.id,
    required this.nombre,
    this.pais,
    required this.esActivo,
  });

  factory BancoCatalogoModelo.desdeMapa(Map<String, dynamic> datos) {
    return BancoCatalogoModelo(
      id: datos['id'] as String,
      nombre: datos['nombre'] as String,
      pais: datos['pais'] as String?,
      esActivo: (datos['es_activo'] as bool?) ?? true,
    );
  }

  final String id;
  final String nombre;
  final String? pais;
  final bool esActivo;
}

/// Modelo que representa una cuenta bancaria gestionada por el usuario.
@immutable
class CuentaBancariaModelo {
  const CuentaBancariaModelo({
    this.id,
    required this.usuarioId,
    required this.titular,
    this.catalogoBancoId,
    this.catalogoBancoNombre,
    this.bancoPersonalizado,
    required this.numeroCuenta,
    required this.tipo,
    required this.montoDisponible,
    this.limiteCredito,
    this.fechaCorte,
    this.fechaPago,
    this.notas,
    this.creadoEl,
    this.actualizadoEl,
  });

  factory CuentaBancariaModelo.desdeMapa(Map<String, dynamic> datos) {
    return CuentaBancariaModelo(
      id: datos['id'] as String?,
      usuarioId: datos['usuario_id'] as String,
      titular: datos['titular'] as String,
      catalogoBancoId: datos['catalogo_banco_id'] as String?,
  catalogoBancoNombre: _obtenerNombreBanco(datos['catalogo_bancos']),
      bancoPersonalizado: datos['banco_personalizado'] as String?,
      numeroCuenta: datos['numero_cuenta'] as String,
      tipo: tipoCuentaDesdeString(datos['tipo'] as String? ?? 'ahorro'),
      montoDisponible: _aDouble(datos['monto_disponible']) ?? 0,
      limiteCredito: _aDouble(datos['limite_credito']),
      fechaCorte: _aFecha(datos['fecha_corte']),
      fechaPago: _aFecha(datos['fecha_pago']),
      notas: datos['notas'] as String?,
      creadoEl: _aFecha(datos['creado_el']),
      actualizadoEl: _aFecha(datos['actualizado_el']),
    );
  }

  Map<String, dynamic> aMapaPersistencia({bool incluirUsuario = false}) {
    final Map<String, dynamic> mapa = <String, dynamic>{
      'titular': titular,
      'catalogo_banco_id': catalogoBancoId,
      'banco_personalizado': bancoPersonalizado,
      'numero_cuenta': numeroCuenta,
      'tipo': tipo.name,
      'monto_disponible': montoDisponible,
      'limite_credito': limiteCredito,
      'fecha_corte': fechaCorte?.toIso8601String(),
      'fecha_pago': fechaPago?.toIso8601String(),
      'notas': notas,
    };

    if (incluirUsuario) {
      mapa['usuario_id'] = usuarioId;
    }

    return mapa;
  }

  CuentaBancariaModelo copiarCon({
    String? id,
    String? usuarioId,
    String? titular,
    String? catalogoBancoId,
    String? bancoPersonalizado,
    String? numeroCuenta,
    TipoCuenta? tipo,
    double? montoDisponible,
    double? limiteCredito,
    DateTime? fechaCorte,
    DateTime? fechaPago,
    String? notas,
    DateTime? creadoEl,
    DateTime? actualizadoEl,
  }) {
    return CuentaBancariaModelo(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      titular: titular ?? this.titular,
      catalogoBancoId: catalogoBancoId ?? this.catalogoBancoId,
      bancoPersonalizado: bancoPersonalizado ?? this.bancoPersonalizado,
      numeroCuenta: numeroCuenta ?? this.numeroCuenta,
      tipo: tipo ?? this.tipo,
      montoDisponible: montoDisponible ?? this.montoDisponible,
      limiteCredito: limiteCredito ?? this.limiteCredito,
      fechaCorte: fechaCorte ?? this.fechaCorte,
      fechaPago: fechaPago ?? this.fechaPago,
      notas: notas ?? this.notas,
      creadoEl: creadoEl ?? this.creadoEl,
      actualizadoEl: actualizadoEl ?? this.actualizadoEl,
    );
  }

  final String? id;
  final String usuarioId;
  final String titular;
  final String? catalogoBancoId;
  final String? catalogoBancoNombre;
  final String? bancoPersonalizado;
  final String numeroCuenta;
  final TipoCuenta tipo;
  final double montoDisponible;
  final double? limiteCredito;
  final DateTime? fechaCorte;
  final DateTime? fechaPago;
  final String? notas;
  final DateTime? creadoEl;
  final DateTime? actualizadoEl;

  String get nombreBanco =>
      bancoPersonalizado ?? catalogoBancoNombre ?? 'Banco no especificado';

  bool get esCredito => tipo == TipoCuenta.credito;

  /// Etiqueta legible del tipo de cuenta (Ahorro, Crédito, etc.).
  String get etiquetaTipo => _etiquetaTipo(tipo);

  /// Texto descriptivo para desplegables y listados compactos.
  String get descripcionSeleccion => construirDescripcion(
        catalogoBancoNombre: catalogoBancoNombre,
        bancoPersonalizado: bancoPersonalizado,
        titular: titular,
        tipo: tipo,
        numeroCuenta: numeroCuenta,
      );

  /// Construye una descripción resumida reutilizando los mismos criterios.
  static String construirDescripcion({
    String? catalogoBancoNombre,
    String? bancoPersonalizado,
    String? titular,
    TipoCuenta? tipo,
    String? tipoPlano,
    String? numeroCuenta,
  }) {
    final List<String> partes = <String>[];

    final String? nombreBanco =
        bancoPersonalizado?.trim().isNotEmpty == true
            ? bancoPersonalizado
            : catalogoBancoNombre;
    if ((nombreBanco ?? '').trim().isNotEmpty) {
      partes.add(nombreBanco!.trim());
    }

    final TipoCuenta tipoDetectado = tipo ??
        (tipoPlano != null ? tipoCuentaDesdeString(tipoPlano) : TipoCuenta.ahorro);
    partes.add(_etiquetaTipo(tipoDetectado));

    final String? sufijoCuenta = _mascaraNumero(numeroCuenta);
    if (sufijoCuenta != null) {
      partes.add(sufijoCuenta);
    }

    if ((titular ?? '').trim().isNotEmpty) {
      partes.add(titular!.trim());
    }

    if (partes.isEmpty) {
      return 'Cuenta sin identificar';
    }
    return partes.join(' · ');
  }
}

/// Modelo auxiliar que representa la vista `v_resumen_cuentas`.
@immutable
class ResumenCuentasModelo {
  const ResumenCuentasModelo({
    required this.totalGeneral,
    required this.totalDepositos,
    required this.totalCredito,
    required this.totalCuentas,
  });

  factory ResumenCuentasModelo.desdeMapa(Map<String, dynamic> datos) {
    return ResumenCuentasModelo(
      totalGeneral: _aDouble(datos['total_general']) ?? 0,
      totalDepositos: _aDouble(datos['total_depositos']) ?? 0,
      totalCredito: _aDouble(datos['total_credito']) ?? 0,
      totalCuentas: (datos['total_cuentas'] as num?)?.toInt() ?? 0,
    );
  }

  final double totalGeneral;
  final double totalDepositos;
  final double totalCredito;
  final int totalCuentas;
}

double? _aDouble(dynamic valor) {
  if (valor == null) return null;
  if (valor is num) return valor.toDouble();
  return double.tryParse(valor.toString());
}

String? _obtenerNombreBanco(dynamic valor) {
  if (valor == null) {
    return null;
  }
  if (valor is Map<String, dynamic>) {
    return valor['nombre'] as String?;
  }
  return valor.toString();
}

DateTime? _aFecha(dynamic valor) {
  if (valor == null) return null;
  if (valor is DateTime) return valor;
  return DateTime.tryParse(valor.toString());
}

String _etiquetaTipo(TipoCuenta tipo) {
  switch (tipo) {
    case TipoCuenta.nomina:
      return 'Nómina';
    case TipoCuenta.negocios:
      return 'Negocios';
    case TipoCuenta.ahorro:
      return 'Ahorro';
    case TipoCuenta.credito:
      return 'Crédito';
  }
}

String? _mascaraNumero(String? numero) {
  if (numero == null) {
    return null;
  }
  final String limpio = numero.replaceAll(RegExp(r'\D'), '');
  if (limpio.isEmpty) {
    final String recortado = numero.trim();
    return recortado.isEmpty ? null : recortado;
  }
  if (limpio.length <= 4) {
    return '****$limpio';
  }
  final String ultimos = limpio.substring(limpio.length - 4);
  return '****$ultimos';
}
