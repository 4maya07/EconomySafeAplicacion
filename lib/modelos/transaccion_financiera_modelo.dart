import 'package:flutter/foundation.dart';

import 'gasto_modelo.dart';
import 'ingreso_modelo.dart';

/// Tipo de movimiento para el historial financiero.
enum TipoTransaccion { ingreso, gasto }

/// Medio por el que se ejecutó la transacción.
enum MedioTransaccion { efectivo, banco }

/// Representa una transacción unificada (ingreso o gasto) para el dashboard.
@immutable
class TransaccionFinancieraModelo {
  const TransaccionFinancieraModelo({
    required this.id,
    required this.tipo,
    required this.medio,
    required this.monto,
    required this.fecha,
    this.titulo,
    this.descripcion,
    this.categoria,
    this.cuentaId,
    this.cuentaNombre,
    this.saldoAntes,
    this.saldoDespues,
  });

  factory TransaccionFinancieraModelo.desdeIngreso(IngresoModelo ingreso) {
    return TransaccionFinancieraModelo(
      id: 'ing-${ingreso.id ?? ingreso.fecha.millisecondsSinceEpoch}',
      tipo: TipoTransaccion.ingreso,
      medio: ingreso.medio == MedioIngreso.banco
          ? MedioTransaccion.banco
          : MedioTransaccion.efectivo,
      monto: ingreso.monto,
      fecha: ingreso.fecha,
      titulo: ingreso.categoriaNombre ?? 'Ingreso',
      descripcion: ingreso.descripcion,
      categoria: ingreso.categoriaNombre,
      cuentaId: ingreso.cuentaId,
      cuentaNombre: ingreso.cuentaNombre,
    );
  }

  factory TransaccionFinancieraModelo.desdeGasto(GastoModelo gasto) {
    return TransaccionFinancieraModelo(
      id: 'gas-${gasto.id ?? gasto.fecha.millisecondsSinceEpoch}',
      tipo: TipoTransaccion.gasto,
      medio: gasto.medioPago == MedioPagoGasto.banco
          ? MedioTransaccion.banco
          : MedioTransaccion.efectivo,
      monto: gasto.monto,
      fecha: gasto.fecha,
      titulo: gasto.categoriaNombre ?? 'Gasto',
      descripcion: gasto.descripcion,
      categoria: gasto.categoriaNombre,
      cuentaId: gasto.cuentaId,
      cuentaNombre: gasto.cuentaNombre,
    );
  }

  TransaccionFinancieraModelo copiarCon({
    double? saldoAntes,
    double? saldoDespues,
  }) {
    return TransaccionFinancieraModelo(
      id: id,
      tipo: tipo,
      medio: medio,
      monto: monto,
      fecha: fecha,
      titulo: titulo,
      descripcion: descripcion,
      categoria: categoria,
      cuentaId: cuentaId,
      cuentaNombre: cuentaNombre,
      saldoAntes: saldoAntes ?? this.saldoAntes,
      saldoDespues: saldoDespues ?? this.saldoDespues,
    );
  }

  /// Identificador único (compuesto) de la transacción.
  final String id;

  /// Informa si es un ingreso o un gasto.
  final TipoTransaccion tipo;

  /// Medio por el que se realizó (efectivo o banco).
  final MedioTransaccion medio;

  /// Importe del movimiento.
  final double monto;

  /// Fecha y hora del movimiento.
  final DateTime fecha;

  /// Título principal a mostrar (usualmente la categoría).
  final String? titulo;

  /// Descripción opcional proporcionada por el usuario.
  final String? descripcion;

  /// Nombre de la categoría asociada (si aplica).
  final String? categoria;

  /// Identificador de la cuenta bancaria asociada (si aplica).
  final String? cuentaId;

  /// Nombre de la cuenta bancaria asociada (si aplica).
  final String? cuentaNombre;

  /// Saldo previo al aplicar la transacción.
  final double? saldoAntes;

  /// Saldo resultante después de aplicar la transacción.
  final double? saldoDespues;

  /// Clave auxiliar para mapear el saldo según el medio.
  String get claveSaldo => medio == MedioTransaccion.efectivo
      ? 'efectivo'
      : 'cuenta_${cuentaId ?? 'desconocida'}';
}
