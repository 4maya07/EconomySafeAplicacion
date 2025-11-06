# Documentación de Arquitectura y Módulos

Este documento describe la estructura global, funciones principales y flujos de EconomySafe.

---

## 1. Estructura de Carpetas

```
lib/
  modelos/           # Modelos de dominio (Usuario, Gasto, Ingreso, Cuenta, Categoría, Transacción)
  servicios/         # Lógica de negocio y persistencia (Gastos, Ingresos, Cuentas, Categorías, Sesión, Tema)
  controladores/     # Lógica de vistas y validaciones (Login, Perfil, Registro, PIN, Recuperación)
  datos/supabase/    # Repositorios y servicios de acceso a Supabase
  vistas/            # Vistas principales (Login, Registro, PIN, Dashboard, Perfil, Gastos, Ingresos, Cuentas, Categorías, Reportes, Ahorro)
  sistema_diseno/    # Identidad visual y temas
  utilidades/        # Validadores y utilidades generales
```

---

## 2. Flujos Principales

### Autenticación
- **Login por correo/contraseña:**
  1. Usuario ingresa credenciales.
  2. Se valida y navega directo al home si es correcto.
  3. Si marcó "Recordarme", la sesión se guarda y puede acceder luego con PIN.
- **Login por PIN:**
  1. Si hay sesión guardada y PIN configurado, puede acceder solo con PIN.
  2. Si olvida el PIN, puede recuperar acceso con correo/contraseña.

### Gestión de Categorías
- **Creación/edición:**
  1. Usuario define nombre, descripción, monto máximo, frecuencia y rango de fechas.
  2. Si la frecuencia es fija, los campos de monto gastado/adicional se ocultan y se guardan en cero.

### Registro de Gastos/Ingresos
- **Registro:**
  1. Usuario selecciona categoría, método de pago y fecha.
  2. Se valida el monto y se asocia correctamente.

### Dashboard
- **Resumen financiero:**
  1. Muestra KPIs, saldos, acceso rápido a registro y categorías.

### Reportes (En desarrollo)
- **Visualización:**
  1. Comparativo mes actual vs anterior, evolución anual, desglose por categoría.
  2. Filtros por rango, categoría, tipo, método de pago.
  3. Exportación a CSV, Excel, PDF.

### Ahorro (Pendiente)
- **Gestión de metas:**
  1. Definir objetivo, monto, plazo y progreso.
  2. Registrar movimientos de ahorro y visualizar avance.

### Notificaciones/IA (Planificado)
- **Alertas inteligentes:**
  1. Detectar incrementos, proyecciones, recordatorios y tips personalizados.
  2. Integrar IA para análisis y generación de recomendaciones.

---

## 3. Ejemplo de Uso: Registro de Gasto

```dart
final gasto = GastoModelo(
  usuarioId: usuario.id,
  categoriaId: categoria.id,
  monto: 120.0,
  metodoPago: 'Tarjeta',
  fecha: DateTime.now(),
);
await GastosServicio().registrarGasto(gasto);
```

---

## 4. Ejemplo de Flujo: Login y Acceso por PIN

```dart
// Login tradicional
await LoginControlador().iniciarSesion(correo: email, contrasena: pass);
// Si el usuario marcó "Recordarme", la próxima vez puede acceder con PIN
await PinControlador().verificarPin(usuarioId: usuario.id, pin: pin);
```

---

## 5. Recomendaciones de Mejora
- Modularizar reportes y ahorro en carpetas/vistas/servicios propios.
- Documentar cada función clave y agregar ejemplos de uso.
- Centralizar lógica de exportación y notificaciones.
- Planificar integración de IA y alertas desde el diseño de reportes.
- Ampliar cobertura de tests unitarios y de integración.

---

**Para detalles técnicos, consulta los archivos en `lib/` y los scripts de migración en `docs/supabase/`.**
