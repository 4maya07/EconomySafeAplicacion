"""Funciones para consultar y resumir datos financieros desde Supabase."""

from __future__ import annotations

from collections import defaultdict
from datetime import datetime
from decimal import Decimal
import re
from typing import Any, Dict, Iterable, List, Optional

from ia_backend.services.supabase_client import get_supabase_client

supabase = get_supabase_client()


_UUID_REGEX = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
)


def _resolver_categoria_id(
    *,
    tabla: str,
    user_id: str,
    categoria_id: Optional[str],
) -> Optional[str]:
    """Devuelve un UUID válido para la categoría indicada.

    Si ya es un UUID lo retorna sin cambios; de lo contrario intenta buscarla por nombre
    (insensible a mayúsculas/minúsculas) para el usuario dado. Devuelve ``None`` si no
    se encuentra coincidencia.
    """

    if not categoria_id:
        return None

    if _UUID_REGEX.fullmatch(categoria_id):
        return categoria_id

    termino = categoria_id.strip()

    respuesta = (
        supabase.table(tabla)
        .select("id, nombre")
        .eq("usuario_id", user_id)
        .ilike("nombre", f"%{termino}%")
        .limit(1)
        .execute()
    )

    registros = respuesta.data or []
    if not registros:
        return None

    return registros[0].get("id")


def obtener_datos_financieros(
    user_id: str,
    fecha_inicio: Optional[datetime] = None,
    fecha_fin: Optional[datetime] = None,
    categoria_id: Optional[str] = None,
    tipo_gasto: Optional[str] = None,
    metodo_pago: Optional[str] = None,
    limite: int = 200,
) -> Dict[str, Any]:
    """Recupera ingresos y gastos del usuario aplicando los filtros dados."""

    if not user_id:
        raise ValueError("user_id es obligatorio para consultar datos financieros.")

    gastos = _consultar_gastos(
        user_id,
        fecha_inicio=fecha_inicio,
        fecha_fin=fecha_fin,
        categoria_id=categoria_id,
        tipo_gasto=tipo_gasto,
        metodo_pago=metodo_pago,
        limite=limite,
    )

    ingresos = _consultar_ingresos(
        user_id,
        fecha_inicio=fecha_inicio,
        fecha_fin=fecha_fin,
        categoria_id=categoria_id,
        limite=limite,
    )

    total_gastos = _sumar_montos(gastos)
    total_ingresos = _sumar_montos(ingresos)
    balance = round(total_ingresos - total_gastos, 2)

    return {
        "usuario_id": user_id,
        "periodo": _serializar_periodo(fecha_inicio, fecha_fin),
        "ingresos": {
            "total": total_ingresos,
            "por_categoria": _agrupar_por_clave(ingresos, "categoria_id"),
            "por_tipo": _agrupar_por_clave(ingresos, "tipo"),
            "registros": ingresos,
        },
        "gastos": {
            "total": total_gastos,
            "por_categoria": _agrupar_por_clave(gastos, "categoria_id"),
            "por_tipo": _agrupar_por_clave(gastos, "tipo"),
            "por_tipo_gasto": _agrupar_por_clave(gastos, "tipo_gasto"),
            "registros": gastos,
        },
        "balance": {
            "neto": balance,
            "saldo_positivo": balance >= 0,
            "ratio_gastos_sobre_ingresos": _ratio(total_gastos, total_ingresos),
        },
    }


def _consultar_gastos(
    user_id: str,
    *,
    fecha_inicio: Optional[datetime],
    fecha_fin: Optional[datetime],
    categoria_id: Optional[str],
    tipo_gasto: Optional[str],
    metodo_pago: Optional[str],
    limite: int,
) -> List[Dict[str, Any]]:
    categoria_filtrada = _resolver_categoria_id(
        tabla="categorias_gasto",
        user_id=user_id,
        categoria_id=categoria_id,
    )

    query = (
        supabase.table("gastos")
        .select(
            "id, categoria_id, monto, tipo, tipo_gasto, frecuencia, fecha, descripcion, cuenta_id",
        )
        .eq("usuario_id", user_id)
        .order("fecha", desc=True)
        .limit(limite)
    )

    if fecha_inicio:
        query = query.gte("fecha", fecha_inicio.isoformat())
    if fecha_fin:
        query = query.lte("fecha", fecha_fin.isoformat())
    if categoria_filtrada:
        query = query.eq("categoria_id", categoria_filtrada)
    if tipo_gasto:
        query = query.eq("tipo_gasto", tipo_gasto)
    if metodo_pago:
        query = query.eq("tipo", _normalizar_metodo_pago(metodo_pago))

    response = query.execute()
    datos = response.data or []
    return [_normalizar_registro(item) for item in datos]


def _consultar_ingresos(
    user_id: str,
    *,
    fecha_inicio: Optional[datetime],
    fecha_fin: Optional[datetime],
    categoria_id: Optional[str],
    limite: int,
) -> List[Dict[str, Any]]:
    categoria_filtrada = _resolver_categoria_id(
        tabla="categorias_ingreso",
        user_id=user_id,
        categoria_id=categoria_id,
    )

    query = (
        supabase.table("ingresos")
        .select(
            "id, categoria_id, monto, tipo, frecuencia, fecha, descripcion, cuenta_id",
        )
        .eq("usuario_id", user_id)
        .order("fecha", desc=True)
        .limit(limite)
    )

    if fecha_inicio:
        query = query.gte("fecha", fecha_inicio.isoformat())
    if fecha_fin:
        query = query.lte("fecha", fecha_fin.isoformat())
    if categoria_filtrada:
        query = query.eq("categoria_id", categoria_filtrada)

    response = query.execute()
    datos = response.data or []
    return [_normalizar_registro(item) for item in datos]


def _normalizar_registro(registro: Dict[str, Any]) -> Dict[str, Any]:
    monto = _to_float(registro.get("monto"))
    fecha = registro.get("fecha")
    return {
        **registro,
        "monto": monto,
        "fecha": _normalizar_fecha(fecha),
    }


def _normalizar_fecha(valor: Any) -> Optional[str]:
    if valor is None:
        return None
    if isinstance(valor, datetime):
        return valor.isoformat()
    return str(valor)


def _to_float(valor: Any) -> float:
    if valor is None:
        return 0.0
    if isinstance(valor, (float, int)):
        return round(float(valor), 2)
    if isinstance(valor, Decimal):
        return round(float(valor), 2)
    try:
        return round(float(valor), 2)
    except (TypeError, ValueError):
        return 0.0


def _sumar_montos(registros: Iterable[Dict[str, Any]]) -> float:
    total = sum(item.get("monto", 0.0) for item in registros)
    return round(float(total), 2)


def _agrupar_por_clave(
    registros: Iterable[Dict[str, Any]],
    clave: str,
) -> List[Dict[str, Any]]:
    acumulado: Dict[str, float] = defaultdict(float)
    for item in registros:
        valor = str(item.get(clave) or "sin_dato")
        acumulado[valor] += item.get("monto", 0.0)

    return [
        {"valor": key, "total": round(total, 2)}
        for key, total in sorted(
            acumulado.items(),
            key=lambda par: par[1],
            reverse=True,
        )
    ]


def _serializar_periodo(
    fecha_inicio: Optional[datetime],
    fecha_fin: Optional[datetime],
) -> Dict[str, Optional[str]]:
    return {
        "inicio": fecha_inicio.isoformat() if fecha_inicio else None,
        "fin": fecha_fin.isoformat() if fecha_fin else None,
    }


def _ratio(dividendo: float, divisor: float) -> Optional[float]:
    if divisor == 0:
        return None
    return round(dividendo / divisor, 4)


def _normalizar_metodo_pago(valor: str) -> str:
    valor_normalizado = valor.lower()
    if valor_normalizado in {"tarjeta", "transferencia", "banco"}:
        return "banco"
    return valor_normalizado


def obtener_resumen_para_prompt(datos: Dict[str, Any]) -> Dict[str, Any]:
    """Prepara un subconjunto compacto ideal para enviar al modelo."""
    ingresos = datos.get("ingresos", {})
    gastos = datos.get("gastos", {})
    balance = datos.get("balance", {})

    return {
        "periodo": datos.get("periodo"),
        "totales": {
            "ingresos": ingresos.get("total", 0.0),
            "gastos": gastos.get("total", 0.0),
            "balance": balance.get("neto", 0.0),
            "ratio_gastos_sobre_ingresos": balance.get(
                "ratio_gastos_sobre_ingresos",
            ),
        },
        "top_categorias_gasto": gastos.get("por_categoria", [])[:5],
        "top_categorias_ingreso": ingresos.get("por_categoria", [])[:5],
        "distribucion_tipo_gasto": gastos.get("por_tipo_gasto", []),
    }
