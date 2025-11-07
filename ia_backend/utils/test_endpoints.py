import requests
import os

API_URL = os.getenv("API_URL", "http://localhost:8000")

# Prueba: Crear notificación manual
resp = requests.post(f"{API_URL}/notificaciones", json={
    "user_id": "test-user-uuid",
    "evento": "alerta",
    "datos": {"gasto": 1500, "presupuesto": 1000, "nombre": "Comida"}
})
print("Crear notificación manual:", resp.json())

# Prueba: Consultar notificaciones
resp = requests.get(f"{API_URL}/notificaciones/test-user-uuid")
print("Consultar notificaciones:", resp.json())

# Prueba: Generar notificaciones automáticas
resp = requests.post(f"{API_URL}/notificaciones/auto?user_id=test-user-uuid", json={
    "resumen": {"ingreso_inusual": True},
    "categorias": [
        {"nombre": "Comida", "gasto": 1500, "presupuesto": 1000},
        {"nombre": "Transporte", "gasto": 300, "presupuesto": 500}
    ],
    "ahorro": [
        {"meta": 1000, "monto": 1200}
    ]
})
print("Generar notificaciones automáticas:", resp.json())

# Prueba: Generar reporte avanzado
resp = requests.post(f"{API_URL}/reportes", json={
    "tipo": "comparativo",
    "parametros": {"periodo": "mensual", "categorias": ["Comida", "Transporte"]}
})
print("Generar reporte avanzado:", resp.json())
