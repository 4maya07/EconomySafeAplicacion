-- Configuración de la tabla y lógica de negocios para gestionar los gastos de los usuarios.
-- Ejecutar este script en el proyecto de Supabase asociado a EconomySafe.

-- Dependencias necesarias
create extension if not exists "pgcrypto";

-- Tabla principal de gastos
create table if not exists public.gastos (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references auth.users (id) on delete cascade,
  categoria_id uuid not null references public.categorias_gasto (id) on delete restrict,
  cuenta_id uuid references public.cuentas_bancarias (id) on delete set null,
  monto numeric(12, 2) not null check (monto > 0),
  descripcion text,
  tipo text not null check (tipo in ('efectivo', 'banco')),
  frecuencia text not null check (frecuencia in ('unaVez', 'semanal', 'mensual', 'trimestral', 'otro')),
  tipo_gasto text not null check (tipo_gasto in ('fijo', 'variable')),
  fecha timestamptz not null default timezone('UTC', now()),
  foto_url text,
  created_at timestamptz not null default timezone('UTC', now()),
  updated_at timestamptz not null default timezone('UTC', now())
);

comment on table public.gastos is 'Registra los movimientos de gasto ingresados por los usuarios.';
comment on column public.gastos.usuario_id is 'Referencia al usuario de Supabase que creó el gasto.';
comment on column public.gastos.categoria_id is 'Categoría a la que se imputa el gasto.';
comment on column public.gastos.cuenta_id is 'Cuenta bancaria (opcional) desde la que se realizó el gasto.';
comment on column public.gastos.monto is 'Importe del gasto en moneda local.';
comment on column public.gastos.tipo is 'Medio de pago utilizado: efectivo o banco.';
comment on column public.gastos.frecuencia is 'Frecuencia declarada del gasto.';
comment on column public.gastos.tipo_gasto is 'Clasificación financiera del gasto (fijo o variable).';
comment on column public.gastos.fecha is 'Fecha efectiva del movimiento.';
comment on column public.gastos.foto_url is 'URL opcional con el comprobante del gasto.';

-- Índices para consultas frecuentes
create index if not exists idx_gastos_usuario_fecha on public.gastos (usuario_id, fecha desc);
create index if not exists idx_gastos_categoria on public.gastos (categoria_id);
create index if not exists idx_gastos_cuenta on public.gastos (cuenta_id);

-- Reglas de seguridad por fila
alter table public.gastos enable row level security;

drop policy if exists "gastos_select_propios" on public.gastos;
create policy "gastos_select_propios"
  on public.gastos
  for select
  using (auth.uid() = usuario_id);

drop policy if exists "gastos_insert_propios" on public.gastos;
create policy "gastos_insert_propios"
  on public.gastos
  for insert
  with check (auth.uid() = usuario_id);

drop policy if exists "gastos_update_propios" on public.gastos;
create policy "gastos_update_propios"
  on public.gastos
  for update
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

drop policy if exists "gastos_delete_propios" on public.gastos;
create policy "gastos_delete_propios"
  on public.gastos
  for delete
  using (auth.uid() = usuario_id);

-- Función auxiliar para crear gastos y actualizar saldos relacionados
create or replace function public.fn_gastos_crear(
  p_usuario_id uuid,
  p_categoria_id uuid,
  p_monto numeric,
  p_tipo text,
  p_frecuencia text,
  p_tipo_gasto text,
  p_fecha timestamptz,
  p_cuenta_id uuid default null,
  p_descripcion text default null,
  p_foto_url text default null
) returns public.gastos
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_gasto public.gastos;
begin
  if auth.uid() is null then
    raise exception 'Acceso no autorizado.';
  end if;

  if p_usuario_id is distinct from auth.uid() then
    raise exception 'No puedes registrar gastos para otro usuario.';
  end if;

  insert into public.gastos (
    usuario_id,
    categoria_id,
    monto,
    tipo,
    frecuencia,
    tipo_gasto,
    fecha,
    cuenta_id,
    descripcion,
    foto_url
  ) values (
    p_usuario_id,
    p_categoria_id,
    round(p_monto::numeric, 2),
    p_tipo,
    p_frecuencia,
    p_tipo_gasto,
    p_fecha,
    p_cuenta_id,
    p_descripcion,
    p_foto_url
  )
  returning * into v_gasto;

  update public.categorias_gasto
    set monto_gastado = coalesce(monto_gastado, 0) + v_gasto.monto,
        updated_at = timezone('UTC', now())
    where id = v_gasto.categoria_id;

  if v_gasto.cuenta_id is not null then
    update public.cuentas_bancarias
      set monto_disponible = monto_disponible - v_gasto.monto,
          actualizado_el = timezone('UTC', now())
      where id = v_gasto.cuenta_id;
  end if;

  return v_gasto;
end;
$$;

grant execute on function public.fn_gastos_crear(
  uuid,
  uuid,
  numeric,
  text,
  text,
  text,
  timestamptz,
  uuid,
  text,
  text
) to authenticated;

-- Función para actualizar gastos existentes
create or replace function public.fn_gastos_actualizar(
  p_id uuid,
  p_usuario_id uuid,
  p_categoria_id uuid,
  p_monto numeric,
  p_tipo text,
  p_frecuencia text,
  p_tipo_gasto text,
  p_fecha timestamptz,
  p_cuenta_id uuid default null,
  p_descripcion text default null,
  p_foto_url text default null
) returns public.gastos
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_anterior public.gastos;
  v_actual public.gastos;
begin
  if auth.uid() is null then
    raise exception 'Acceso no autorizado.';
  end if;

  select *
    into v_anterior
    from public.gastos
   where id = p_id;

  if not found then
    raise exception 'El gasto indicado no existe.';
  end if;

  if v_anterior.usuario_id is distinct from auth.uid() or
     p_usuario_id is distinct from auth.uid() then
    raise exception 'No tienes permisos para actualizar este gasto.';
  end if;

  update public.gastos
     set categoria_id = p_categoria_id,
         monto = round(p_monto::numeric, 2),
         tipo = p_tipo,
         frecuencia = p_frecuencia,
         tipo_gasto = p_tipo_gasto,
         fecha = p_fecha,
         cuenta_id = p_cuenta_id,
         descripcion = p_descripcion,
         foto_url = p_foto_url,
         updated_at = timezone('UTC', now())
   where id = p_id
  returning * into v_actual;

  -- Ajuste de las categorías
  if v_anterior.categoria_id = v_actual.categoria_id then
    update public.categorias_gasto
       set monto_gastado = coalesce(monto_gastado, 0) - v_anterior.monto + v_actual.monto,
           updated_at = timezone('UTC', now())
     where id = v_actual.categoria_id;
  else
    update public.categorias_gasto
       set monto_gastado = greatest(0, coalesce(monto_gastado, 0) - v_anterior.monto),
           updated_at = timezone('UTC', now())
     where id = v_anterior.categoria_id;

    update public.categorias_gasto
       set monto_gastado = coalesce(monto_gastado, 0) + v_actual.monto,
           updated_at = timezone('UTC', now())
     where id = v_actual.categoria_id;
  end if;

  -- Ajuste de las cuentas
  if v_anterior.cuenta_id is not null and v_actual.cuenta_id is not null and
     v_anterior.cuenta_id = v_actual.cuenta_id then
    update public.cuentas_bancarias
       set monto_disponible = monto_disponible + v_anterior.monto - v_actual.monto,
           actualizado_el = timezone('UTC', now())
     where id = v_actual.cuenta_id;
  else
    if v_anterior.cuenta_id is not null then
      update public.cuentas_bancarias
         set monto_disponible = monto_disponible + v_anterior.monto,
             actualizado_el = timezone('UTC', now())
       where id = v_anterior.cuenta_id;
    end if;

    if v_actual.cuenta_id is not null then
      update public.cuentas_bancarias
         set monto_disponible = monto_disponible - v_actual.monto,
             actualizado_el = timezone('UTC', now())
       where id = v_actual.cuenta_id;
    end if;
  end if;

  return v_actual;
end;
$$;

grant execute on function public.fn_gastos_actualizar(
  uuid,
  uuid,
  uuid,
  numeric,
  text,
  text,
  text,
  timestamptz,
  uuid,
  text,
  text
) to authenticated;

-- Función para eliminar gastos
create or replace function public.fn_gastos_eliminar(
  p_id uuid,
  p_usuario_id uuid
) returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_anterior public.gastos;
begin
  if auth.uid() is null then
    raise exception 'Acceso no autorizado.';
  end if;

  select *
    into v_anterior
    from public.gastos
   where id = p_id;

  if not found then
    return;
  end if;

  if v_anterior.usuario_id is distinct from auth.uid() or
     p_usuario_id is distinct from auth.uid() then
    raise exception 'No tienes permisos para eliminar este gasto.';
  end if;

  delete from public.gastos where id = p_id;

  update public.categorias_gasto
     set monto_gastado = greatest(0, coalesce(monto_gastado, 0) - v_anterior.monto),
         updated_at = timezone('UTC', now())
   where id = v_anterior.categoria_id;

  if v_anterior.cuenta_id is not null then
    update public.cuentas_bancarias
       set monto_disponible = monto_disponible + v_anterior.monto,
           actualizado_el = timezone('UTC', now())
     where id = v_anterior.cuenta_id;
  end if;
end;
$$;

grant execute on function public.fn_gastos_eliminar(uuid, uuid) to authenticated;
