# IA Backend para EconomySafe

Este backend minimalista permite integrar la API de OpenAI para análisis de reportes y notificaciones inteligentes, comunicándose con Supabase y tu app Flutter.

## Estructura de carpetas

```
ia_backend/
  api/        # Endpoints principales (ej: /analisis, /notificaciones)
  config/     # Configuración y variables de entorno (API Key, URLs)
  services/   # Lógica para OpenAI y consultas a Supabase
  utils/      # Funciones auxiliares (formateo, validación)
```

## Flujo general
1. Tu app Flutter solicita análisis o recomendaciones.
2. El microservicio IA recibe la petición en un endpoint (ej: POST /analisis).
3. Consulta/agrega datos desde Supabase si es necesario.
4. Prepara el prompt y llama a OpenAI usando la API Key.
5. Procesa la respuesta y la devuelve a la app.
6. La app muestra reportes, alertas o tips inteligentes.

## Siguiente paso
Implementa el microservicio en Python (FastAPI) o Node.js (Express) dentro de esta estructura.
