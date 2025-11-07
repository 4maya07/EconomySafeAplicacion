from ia_backend.services.supabase_client import get_supabase_client

supabase = get_supabase_client()

def crear_notificacion(user_id: str, tipo: str, mensaje: str, datos: dict):
    response = supabase.table("notificaciones").insert({
        "user_id": user_id,
        "tipo": tipo,
        "mensaje": mensaje,
        "datos": datos
    }).execute()
    return response.data

def consultar_notificaciones(user_id: str):
    response = supabase.table("notificaciones").select("*").eq("user_id", user_id).order("fecha_creacion", desc=True).execute()
    return response.data

def marcar_leida(notificacion_id: str):

    response = supabase.table("notificaciones").update({"leida": True, "fecha_leida": "now()"}).eq("id", notificacion_id).execute()
    return response.data

# Lógica avanzada: detección de eventos y generación automática
def detectar_eventos_financieros(user_id: str, resumen: dict, categorias: list, ahorro: list = []):
    eventos = []
    # Ejemplo: gasto excesivo
    for cat in categorias:
        if cat.get("gasto", 0) > cat.get("presupuesto", 0) * 1.2:
            eventos.append({
                "tipo": "alerta",
                "mensaje": f"Gasto excesivo en {cat['nombre']}: {cat['gasto']} supera el presupuesto.",
                "datos": cat
            })
    # Ejemplo: ahorro alcanzado
    for a in ahorro:
        if a.get("meta", 0) > 0 and a.get("monto", 0) >= a.get("meta", 0):
            eventos.append({
                "tipo": "logro",
                "mensaje": f"¡Meta de ahorro alcanzada! Has ahorrado {a['monto']}.",
                "datos": a
            })
    # Ejemplo: ingreso inusual
    if resumen.get("ingreso_inusual", False):
        eventos.append({
            "tipo": "sugerencia",
            "mensaje": "Ingreso inusual detectado. Revisa tus movimientos recientes.",
            "datos": resumen
        })
    # Guardar notificaciones en Supabase
    for evento in eventos:
        crear_notificacion(user_id, evento["tipo"], evento["mensaje"], evento["datos"])
    return eventos
