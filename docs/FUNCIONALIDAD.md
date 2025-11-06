# Documentación General de Funcionalidades

Este documento describe las funciones principales implementadas en EconomySafe hasta noviembre 2025.

## 1. Autenticación y Seguridad
- **Login por correo y contraseña:** Permite iniciar sesión con credenciales tradicionales.
- **Login por PIN:** Si el usuario eligió "Recordarme", puede acceder con PIN en el mismo dispositivo.
- **Recuperación de contraseña:** Envío de enlace seguro al correo registrado para restablecer la contraseña.
- **Gestión de sesión:** Persistencia y restauración de sesión usando almacenamiento seguro.

## 2. Gestión de Categorías de Gasto
- **Creación/edición de categorías:** Permite definir nombre, descripción, monto máximo, frecuencia (mensual, bimestral, etc.), y rango de fechas.
- **Gastos fijos/prioritarios:** Si la frecuencia es distinta de "ninguna", los campos de monto gastado y adicional se ocultan y se guardan en cero.
- **Visualización:** Tarjetas y detalles muestran información relevante según el tipo de categoría.

## 3. Registro y Control de Gastos/Ingresos
- **Registro de gastos e ingresos:** Permite asociar cada movimiento a una categoría, método de pago y fecha.
- **Métodos de pago:** Soporte para efectivo, tarjeta, transferencia y otros.
- **Control de límites:** Alertas visuales si se supera el monto máximo de una categoría.

## 4. Reportes y Visualización
- **Reportes en desarrollo:** Pantalla dedicada para reportes comparativos, evolución anual, desglose por categoría y filtros avanzados.
- **Filtros:** Por rango de fechas, categoría, tipo (fijo/variable), método de pago.
- **Exportación (planificada):** CSV, Excel, PDF.

## 5. Notificaciones y Alertas (planificadas)
- **Alertas inteligentes:** Incrementos significativos, proyección de sobrepaso de presupuesto, recordatorios de registro, tips personalizados.
- **Integración IA:** Análisis de patrones y generación de recomendaciones usando modelos GPT.

## 6. Diseño y Usabilidad
- **Interfaz moderna:** Uso de temas claro/oscuro, navegación inferior y formularios responsivos.
- **Validaciones:** Mensajes claros y validaciones en todos los formularios.

---

**Nota:** Para detalles técnicos y ejemplos de código, consulta los archivos en la carpeta `lib/` y los scripts de migración en `docs/supabase/`.
