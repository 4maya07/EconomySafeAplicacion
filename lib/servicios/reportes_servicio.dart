import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Representa los filtros disponibles al solicitar un reporte.
class ReporteFiltro {
  const ReporteFiltro({
    required this.usuarioId,
    required this.tipo,
    this.fechaInicio,
    this.fechaFin,
    this.categoriaId,
    this.tipoGasto,
    this.metodoPago,
  });

  final String usuarioId;
  final String tipo;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final String? categoriaId;
  final String? tipoGasto;
  final String? metodoPago;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> parametros = <String, dynamic>{
      'tipo': tipo,
      'usuario_id': usuarioId,
    };

    if (fechaInicio != null) {
      parametros['fecha_inicio'] = fechaInicio!.toIso8601String();
    }
    if (fechaFin != null) {
      parametros['fecha_fin'] = fechaFin!.toIso8601String();
    }
    if (categoriaId != null && categoriaId!.isNotEmpty) {
      parametros['categoria_id'] = categoriaId;
    }
    if (tipoGasto != null && tipoGasto!.isNotEmpty) {
      parametros['tipo_gasto'] = tipoGasto;
    }
    if (metodoPago != null && metodoPago!.isNotEmpty) {
      parametros['metodo_pago'] = metodoPago;
    }

    return parametros;
  }
}

/// Encapsula la interacción con el backend de análisis y reportes (FastAPI).
class ReportesServicio {
  ReportesServicio({http.Client? cliente, String? baseUrl})
      : _cliente = cliente ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://127.0.0.1:8000',
            );

  final http.Client _cliente;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 30);

  Uri _resolverUri(String path) => Uri.parse('$_baseUrl$path');

  void dispose() {
    _cliente.close();
  }

  /// Solicita al backend la generación de un reporte y devuelve el contenido.
  Future<Map<String, dynamic>> generarReporte(ReporteFiltro filtro) async {
    final Uri uri = _resolverUri('/reportes');
    final Map<String, dynamic> cuerpo = <String, dynamic>{
      'tipo': filtro.tipo,
      'parametros': filtro.toJson(),
    };

    final http.Response respuesta = await _cliente
        .post(uri, body: jsonEncode(cuerpo), headers: <String, String>{'Content-Type': 'application/json'})
        .timeout(_timeout);

    if (respuesta.statusCode >= 400) {
      throw ReportesServicioException(
        'Error ${respuesta.statusCode} al generar el reporte: ${respuesta.body}',
      );
    }

    return _decodificarRespuesta(respuesta.body);
  }

  Future<Map<String, dynamic>> obtenerDatosFinancieros(ReporteFiltro filtro) async {
    final Uri uri = _resolverUri('/datos-financieros');
    final Map<String, dynamic> cuerpo = <String, dynamic>{
      'user_id': filtro.usuarioId,
      'fecha_inicio': filtro.fechaInicio?.toIso8601String(),
      'fecha_fin': filtro.fechaFin?.toIso8601String(),
      'categoria_id': filtro.categoriaId,
      'tipo_gasto': filtro.tipoGasto,
      'metodo_pago': filtro.metodoPago,
    }..removeWhere((String _, dynamic value) => value == null || (value is String && value.isEmpty));

    final http.Response respuesta = await _cliente
        .post(uri, body: jsonEncode(cuerpo), headers: <String, String>{'Content-Type': 'application/json'})
        .timeout(_timeout);

    if (respuesta.statusCode >= 400) {
      throw ReportesServicioException(
        'Error ${respuesta.statusCode} al consultar los datos financieros: ${respuesta.body}',
      );
    }

    return _decodificarRespuesta(respuesta.body);
  }

  /// Intenta interpretar el cuerpo JSON aún cuando llegue como string doblemente codificado.
  Map<String, dynamic> _decodificarRespuesta(String cuerpo) {
    dynamic contenido;
    try {
      contenido = jsonDecode(cuerpo);
    } catch (e, stack) {
      debugPrint('No se pudo decodificar la respuesta inicial: $e');
      debugPrintStack(stackTrace: stack);
      throw ReportesServicioException('No se pudo interpretar la respuesta del backend.');
    }

    if (contenido is String) {
      try {
        contenido = jsonDecode(contenido);
      } catch (e, stack) {
        debugPrint('La respuesta venía como string y no se pudo decodificar: $e');
        debugPrintStack(stackTrace: stack);
        throw ReportesServicioException('El backend devolvió un formato inesperado.');
      }
    }

    if (contenido is! Map<String, dynamic>) {
      throw ReportesServicioException('El backend devolvió un objeto inesperado.');
    }

    return contenido;
  }
}

class ReportesServicioException implements Exception {
  ReportesServicioException(this.mensaje);
  final String mensaje;

  @override
  String toString() => 'ReportesServicioException: $mensaje';
}
