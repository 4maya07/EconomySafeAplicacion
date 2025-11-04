-- Configuración de la tabla para gestionar las categorías de ingreso.
-- Ejecutar este script en el proyecto de Supabase asociado a EconomySafe.

create table if not exists public.categorias_ingreso (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references auth.users (id) on delete cascade,
  nombre text not null,
  descripcion text,
  frecuencia text not null check (frecuencia in ('unaVez', 'semanal', 'quincenal', 'mensual', 'trimestral', 'otro')),
  created_at timestamptz not null default timezone('UTC', now()),
  updated_at timestamptz not null default timezone('UTC', now())
);

comment on table public.categorias_ingreso is 'Clasificaciones que agrupan los diferentes ingresos del usuario.';
comment on column public.categorias_ingreso.frecuencia is 'Frecuencia sugerida para los ingresos pertenecientes a la categoría.';

create index if not exists idx_categorias_ingreso_usuario on public.categorias_ingreso (usuario_id, created_at desc);
create index if not exists idx_categorias_ingreso_frecuencia on public.categorias_ingreso (frecuencia);

alter table public.categorias_ingreso enable row level security;

drop policy if exists "categorias_ingreso_select_propias" on public.categorias_ingreso;
create policy "categorias_ingreso_select_propias"
  on public.categorias_ingreso
  for select
  using (auth.uid() = usuario_id);

drop policy if exists "categorias_ingreso_insert_propias" on public.categorias_ingreso;
create policy "categorias_ingreso_insert_propias"
  on public.categorias_ingreso
  for insert
  with check (auth.uid() = usuario_id);

drop policy if exists "categorias_ingreso_update_propias" on public.categorias_ingreso;
create policy "categorias_ingreso_update_propias"
  on public.categorias_ingreso
  for update
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

drop policy if exists "categorias_ingreso_delete_propias" on public.categorias_ingreso;
create policy "categorias_ingreso_delete_propias"
  on public.categorias_ingreso
  for delete
  using (auth.uid() = usuario_id);
