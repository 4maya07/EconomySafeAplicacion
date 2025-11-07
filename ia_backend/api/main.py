import json
import os
from datetime import datetime
from typing import Any, Dict, Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from openai import OpenAI
from pydantic import BaseModel

from ia_backend.services.notificaciones_service import (
    crear_notificacion,
    consultar_notificaciones,
    detectar_eventos_financieros,
)
from ia_backend.services.reportes_service import (
    obtener_datos_financieros,
    obtener_resumen_para_prompt,
)

load_dotenv()

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

app = FastAPI()

# Permite que Flutter Web (localhost:3000) consuma la API sin errores CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://127.0.0.1",
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
    ],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class AnalisisRequest(BaseModel):
    resumen: dict
    categorias: list
    ahorro: list = []  # Opcional para el futuro módulo de ahorro

class ReportRequest(BaseModel):
    tipo: str
    parametros: dict

class NotificationRequest(BaseModel):
    user_id: str
    evento: str
    datos: dict


class DatosFinancierosRequest(BaseModel):
    user_id: str
    fecha_inicio: Optional[datetime] = None
    fecha_fin: Optional[datetime] = None
    categoria_id: Optional[str] = None
    tipo_gasto: Optional[str] = None
    metodo_pago: Optional[str] = None


def _respuesta_openai_json(prompt: str) -> dict:
    """Solicita a OpenAI un objeto JSON y lo convierte a dict."""
    completion = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": prompt}],
        response_format={"type": "json_object"},
    )

    contenido = _extraer_texto_de_mensaje(completion)

    try:
        return json.loads(contenido)
    except json.JSONDecodeError as exc:
        raise ValueError("OpenAI no devolvió JSON válido.") from exc


def _respuesta_openai_texto(prompt: str) -> str:
    """Solicita a OpenAI una respuesta en texto plano."""
    completion = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": prompt}],
    )

    return _extraer_texto_de_mensaje(completion).strip()


def _extraer_texto_de_mensaje(completion) -> str:
    """Extrae el contenido textual del primer mensaje devuelto por Chat Completions."""
    if not completion.choices:
        raise ValueError("OpenAI no devolvió opciones en la respuesta.")

    contenido = completion.choices[0].message.content

    if isinstance(contenido, str):
        return contenido

    if isinstance(contenido, list):
        fragmentos = []
        for parte in contenido:
            if isinstance(parte, str):
                fragmentos.append(parte)
            elif isinstance(parte, dict):
                valor = parte.get("text")
                if valor:
                    fragmentos.append(valor)
            else:
                valor = getattr(parte, "text", None)
                if valor:
                    fragmentos.append(valor)

        if fragmentos:
            return "".join(fragmentos)

    raise ValueError("No se pudo interpretar el contenido devuelto por OpenAI.")


def _parse_iso_datetime(valor: Optional[Any]) -> Optional[datetime]:
    if valor is None or valor == "":
        return None
    if isinstance(valor, datetime):
        return valor
    if isinstance(valor, (int, float)):
        raise ValueError("Las fechas deben venir en formato ISO 8601.")
    try:
        return datetime.fromisoformat(str(valor))
    except ValueError as exc:
        raise ValueError(f"Formato de fecha inválido: {valor}") from exc


@app.post("/analisis")
async def analizar_datos(request: AnalisisRequest):
    prompt = f"""
    Analiza estos datos financieros y devuelve JSON con:
    - variaciones destacadas
    - alertas de gasto
    - recomendaciones de ahorro
    Datos: {request.json()}
    """
    try:
        return _respuesta_openai_json(prompt)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Para probar: uvicorn api.main:app --reload

# Endpoint para reportes (comparativo, evolución, desglose, exportación)

# Reporte avanzado con análisis y recomendaciones
@app.post("/reportes")
async def generar_reporte(request: ReportRequest):
    try:
        parametros = request.parametros or {}

        user_id = parametros.get("usuario_id")
        fecha_inicio = _parse_iso_datetime(parametros.get("fecha_inicio"))
        fecha_fin = _parse_iso_datetime(parametros.get("fecha_fin"))
        categoria_id = parametros.get("categoria_id")
        tipo_gasto = parametros.get("tipo_gasto")
        metodo_pago = parametros.get("metodo_pago")

        datos_financieros: Optional[Dict[str, Any]] = None
        resumen_prompt: Optional[Dict[str, Any]] = None

        if user_id:
            datos_financieros = obtener_datos_financieros(
                user_id,
                fecha_inicio=fecha_inicio,
                fecha_fin=fecha_fin,
                categoria_id=categoria_id,
                tipo_gasto=tipo_gasto,
                metodo_pago=metodo_pago,
            )
            resumen_prompt = obtener_resumen_para_prompt(datos_financieros)

        prompt = (
            "Eres un analista financiero senior. Con base en los datos proporcionados, "
            "genera un reporte del tipo {tipo} para un usuario de finanzas personales. "
            "Adapta el contenido a los filtros seleccionados y sugiere acciones concretas."
        ).format(tipo=request.tipo)

        prompt += f"\n\nFiltros solicitados: {json.dumps(parametros, ensure_ascii=False)}."

        if resumen_prompt:
            prompt += (
                "\n\nDatos financieros resumidos (usa esta información como contexto principal): "
                f"{json.dumps(resumen_prompt, ensure_ascii=False)}"
            )
        else:
            prompt += (
                "\n\nNo se encontraron datos financieros previos. Proporciona un resumen genérico "
                "indicando que faltan movimientos registrados."
            )

        analisis = _respuesta_openai_json(prompt)

        return {
            "filtros": parametros,
            "datos_financieros": datos_financieros,
            "reporte_modelo": analisis,
        }
    except ValueError as err:
        raise HTTPException(status_code=400, detail=str(err))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/datos-financieros")
async def obtener_datos_financieros_endpoint(request: DatosFinancierosRequest):
    try:
        datos = obtener_datos_financieros(
            request.user_id,
            fecha_inicio=request.fecha_inicio,
            fecha_fin=request.fecha_fin,
            categoria_id=request.categoria_id,
            tipo_gasto=request.tipo_gasto,
            metodo_pago=request.metodo_pago,
        )
        return datos
    except ValueError as err:
        raise HTTPException(status_code=400, detail=str(err))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Endpoint para notificaciones inteligentes

# Crear notificación inteligente y guardarla en Supabase

# Endpoint para generar notificaciones automáticas según eventos financieros
@app.post("/notificaciones/auto")
async def generar_notificaciones_automaticas(request: AnalisisRequest, user_id: str):
    try:
        eventos = detectar_eventos_financieros(user_id, request.resumen, request.categorias, request.ahorro)
        return {"eventos_generados": eventos}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Mantener endpoint manual con OpenAI
@app.post("/notificaciones")
async def endpoint_crear_notificacion(request: NotificationRequest):
    prompt = f"Genera una notificación para el usuario {request.user_id} sobre el evento {request.evento} con datos: {request.datos}"
    try:
        mensaje = _respuesta_openai_texto(prompt)
        notificacion = crear_notificacion(
            user_id=request.user_id,
            tipo=request.evento,
            mensaje=mensaje,
            datos=request.datos
        )
        return {"notificacion": notificacion, "mensaje": mensaje}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Endpoint para consultar notificaciones (mock, integrar con Supabase en el futuro)

# Consultar notificaciones reales desde Supabase
@app.get("/notificaciones/{user_id}")
async def endpoint_consultar_notificaciones(user_id: str):
    try:
        notificaciones = consultar_notificaciones(user_id)
        return {"notificaciones": notificaciones}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
