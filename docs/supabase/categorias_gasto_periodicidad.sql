-- Agrega soporte de periodicidad a la tabla de categorías de gasto.
-- Ejecutar en Supabase antes de utilizar la nueva funcionalidad en la app.

alter table public.categorias_gasto
  add column if not exists frecuencia text not null default 'ninguna',
  add column if not exists fecha_inicio timestamptz,
  add column if not exists fecha_fin timestamptz;

-- Asegura que solo se almacenen valores válidos en la columna frecuencia.
alter table public.categorias_gasto
  drop constraint if exists categorias_gasto_frecuencia_chk;

alter table public.categorias_gasto
  add constraint categorias_gasto_frecuencia_chk
  check (frecuencia in (
    'ninguna',
    'mensual',
    'bimestral',
    'trimestral',
    'cuatrimestral',
    'anual',
    'personalizada'
  ));

-- Garantiza que, cuando existan ambas fechas, el fin no sea anterior al inicio.
alter table public.categorias_gasto
  drop constraint if exists categorias_gasto_periodo_valido_chk;

alter table public.categorias_gasto
  add constraint categorias_gasto_periodo_valido_chk
  check (
    fecha_inicio is null
    or fecha_fin is null
    or fecha_fin >= fecha_inicio
  );
