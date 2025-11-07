# Documentación de APIs de EconomySafe

Esta guía resume los servicios FastAPI alojados en `ia_backend/` para que nuevos desarrolladores puedan integrarse rápidamente. Incluye prerequisitos, cómo levantar el backend y el contrato de cada endpoint expuesto.

---

## 1. Prerequisitos
- **Python 3.11+** con entorno virtual (el proyecto usa `.venv`).
- **Dependencias backend** instaladas: `pip install -r ia_backend/requirements.txt` (crear el archivo si aún no existe).
- **Supabase**: credenciales de un proyecto con las tablas indicadas en `docs/supabase/*.sql` ya aplicadas.
- **OpenAI**: clave activa compatible con `chat.completions`.
- **Variables de entorno** definidas (ver sección siguiente).

## 2. Variables de entorno requeridas
Guárdalas en un archivo `.env` en la raíz del proyecto.

| Variable | Descripción |
| --- | --- |
| `SUPABASE_URL` | URL del proyecto Supabase. |
| `SUPABASE_SERVICE_KEY` | Service key con permisos para leer/escribir tablas financieras y de notificaciones. |
| `OPENAI_API_KEY` | Clave de OpenAI usada para generar reportes y notificaciones. |

> Consejo: después de modificar `.env`, reinicia el servidor de FastAPI para que cargue los valores.

## 3. Ejecución del backend
```powershell
cd C:\Users\Amayass\Desktop\EconomySafe\appeconomysafe
.\.venv\Scripts\Activate.ps1
python -m uvicorn api.main:app --reload --app-dir ia_backend
```
El servidor queda disponible en `http://127.0.0.1:8000`. La documentación interactiva está en `http://127.0.0.1:8000/docs`.

## 4. Esquema de datos de apoyo
Los servicios consumen y producen los mismos objetos que expone `reportes_service.py`:
- `ingresos.registros` y `gastos.registros` contienen movimientos con campos `id`, `categoria_id`, `monto`, `tipo`, `tipo_gasto`, `frecuencia`, `fecha`, `descripcion`, `cuenta_id`.
- Agrupaciones (`por_categoria`, `por_tipo`, `por_tipo_gasto`) devuelven pares `{ "valor": <id|clave>, "total": <float> }` ordenados descendentemente.
- `balance` incluye `neto`, `saldo_positivo` y `ratio_gastos_sobre_ingresos`.

Consulta `docs/supabase/*.sql` para revisar el diseño de tablas y vistas.

## 5. Endpoints disponibles
Todos los endpoints aceptan/retornan JSON. No hay autenticación a nivel API; valida `user_id` en el cliente antes de invocar.

### 5.1 POST `/datos-financieros`
Recupera ingresos y gastos de Supabase aplicando filtros opcionales.

**Request body**
```json
{
  "user_id": "uuid-obligatorio",
  "fecha_inicio": "2025-01-01T00:00:00",
  "fecha_fin": "2025-01-31T23:59:59",
  "categoria_id": "uuid o nombre de categoría",
  "tipo_gasto": "fijo | variable | ...",
  "metodo_pago": "efectivo | banco | tarjeta | transferencia"
}
```
Todos los campos salvo `user_id` son opcionales. Si `categoria_id` es un nombre, el backend lo traduce al UUID correspondiente.

**Response 200**
```json
{
  "usuario_id": "...",
  "periodo": { "inicio": "...", "fin": "..." },
  "ingresos": {
    "total": 1234.5,
    "por_categoria": [ { "valor": "categoria_uuid", "total": 500.0 } ],
    "por_tipo": [ { "valor": "salario", "total": 1234.5 } ],
    "registros": [ { "id": "...", "monto": 500.0, "fecha": "..." } ]
  },
  "gastos": {
    "total": 890.0,
    "por_categoria": [ { "valor": "categoria_uuid", "total": 300.0 } ],
    "por_tipo": [ { "valor": "banco", "total": 400.0 } ],
    "por_tipo_gasto": [ { "valor": "fijo", "total": 250.0 } ],
    "registros": [ { "id": "...", "monto": 120.0, "fecha": "..." } ]
  },
  "balance": {
    "neto": 344.5,
    "saldo_positivo": true,
    "ratio_gastos_sobre_ingresos": 0.7213
  }
}
```

**Errores comunes**
- `400` si `user_id` está vacío o las fechas están mal formateadas.
- `500` si Supabase u OpenAI no responden correctamente.

### 5.2 POST `/reportes`
Genera un reporte IA en base a los datos financieros extraídos automáticamente.

**Request body**
```json
{
  "tipo": "comparativo | evolucion | desglose | personalizado",
  "parametros": {
    "usuario_id": "uuid",
    "fecha_inicio": "2025-01-01T00:00:00",
    "fecha_fin": "2025-01-31T23:59:59",
    "categoria_id": "uuid o nombre",
    "tipo_gasto": "fijo",
    "metodo_pago": "banco"
  }
}
```

**Response 200**
```json
{
  "filtros": { ... },
  "datos_financieros": { ... mismo esquema que /datos-financieros ... },
  "reporte_modelo": {
    "resumen": "Texto generado",
    "alertas": ["..."],
    "recomendaciones": ["..."]
  }
}
```
> El contenido de `reporte_modelo` depende del prompt. Siempre se solicita a OpenAI un JSON válido; maneja `ValueError` si no llega en ese formato.

**Errores comunes**
- `400` cuando las fechas son inválidas.
- `500` cuando OpenAI no responde o no devuelve JSON válido.

### 5.3 POST `/analisis`
Analiza datos financieros ya calculados y devuelve un JSON con hallazgos.

**Request body** (`AnalisisRequest`)
```json
{
  "resumen": { "ingresos_totales": 1200, "gastos_totales": 900 },
  "categorias": [{ "nombre": "Alimentos", "gasto": 300, "presupuesto": 250 }],
  "ahorro": [{ "nombre": "Fondo emergencia", "meta": 1000, "monto": 600 }]
}
```
**Response 200**: objeto JSON arbitrario generado por OpenAI con variaciones, alertas y recomendaciones.

### 5.4 POST `/notificaciones/auto`
Genera eventos automáticos y los inserta en Supabase.

- **Body**: mismo formato que `/analisis`.
- **Query param**: `user_id` (obligatorio). Ejemplo: `POST /notificaciones/auto?user_id=<uuid>`.
- **Response 200**
```json
{ "eventos_generados": [ { "tipo": "alerta", "mensaje": "...", "datos": { ... } } ] }
```

### 5.5 POST `/notificaciones`
Crea una notificación usando OpenAI para redactar el mensaje final.

**Request body** (`NotificationRequest`)
```json
{
  "user_id": "uuid",
  "evento": "gasto_excesivo",
  "datos": { "categoria": "Alimentos", "monto": 450 }
}
```
**Response 200**
```json
{
  "notificacion": [{ "id": "...", "user_id": "...", "mensaje": "..." }],
  "mensaje": "Texto generado por OpenAI"
}
```

### 5.6 GET `/notificaciones/{user_id}`
Devuelve las notificaciones guardadas en Supabase para el usuario indicado.

**Response 200**
```json
{
  "notificaciones": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "tipo": "alerta",
      "mensaje": "...",
      "datos": { ... },
      "fecha_creacion": "2025-01-06T12:00:00"
    }
  ]
}
```

## 6. Pruebas manuales rápidas
Una vez levantado el servidor, puedes validar los endpoints con `Invoke-RestMethod` desde PowerShell:
```powershell
$body = @{ user_id = "<uuid>" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8000/datos-financieros" -Body $body -ContentType "application/json"
```

## 7. Integración con Flutter
- Las pantallas de reportes consumen `/datos-financieros` para obtener resúmenes y `/reportes` para el análisis IA.
- La URL base se inyecta desde Flutter con `--dart-define=API_BASE_URL=http://127.0.0.1:8000` o mediante variables de entorno en producción.
- Asegúrate de llamar a `/datos-financieros` antes de `/reportes` para mostrar resultados en la UI aún si la generación IA falla.

---

Para ampliar detalles sobre módulos, despliegue y supabase, revisa los otros documentos en `docs/`.
