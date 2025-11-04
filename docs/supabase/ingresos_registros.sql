-- Configuración de la tabla de ingresos y lógica auxiliar.
-- Ejecutar este script después de haber creado las categorías de ingreso.

create table if not exists public.ingresos (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references auth.users (id) on delete cascade,
  categoria_id uuid not null references public.categorias_ingreso (id) on delete restrict,
  cuenta_id uuid references public.cuentas_bancarias (id) on delete set null,
  monto numeric(12, 2) not null check (monto > 0),
  descripcion text,
  tipo text not null check (tipo in ('efectivo', 'banco')),
  frecuencia text not null check (frecuencia in ('unaVez', 'semanal', 'mensual', 'trimestral', 'anual')),
  fecha timestamptz not null default timezone('UTC', now()),
  created_at timestamptz not null default timezone('UTC', now()),
  updated_at timestamptz not null default timezone('UTC', now())
);

comment on table public.ingresos is 'Registra los movimientos de ingreso de cada usuario.';
comment on column public.ingresos.tipo is 'Medio de recepción: efectivo o cuenta bancaria.';
comment on column public.ingresos.frecuencia is 'Periodicidad declarada del ingreso registrado.';

create index if not exists idx_ingresos_usuario_fecha on public.ingresos (usuario_id, fecha desc);
create index if not exists idx_ingresos_categoria on public.ingresos (categoria_id);
create index if not exists idx_ingresos_cuenta on public.ingresos (cuenta_id);

alter table public.ingresos enable row level security;

drop policy if exists "ingresos_select_propios" on public.ingresos;
create policy "ingresos_select_propios"
  on public.ingresos
  for select
  using (auth.uid() = usuario_id);

drop policy if exists "ingresos_insert_propios" on public.ingresos;
create policy "ingresos_insert_propios"
  on public.ingresos
  for insert
  with check (auth.uid() = usuario_id);

drop policy if exists "ingresos_update_propios" on public.ingresos;
create policy "ingresos_update_propios"
  on public.ingresos
  for update
  using (auth.uid() = usuario_id)
  with check (auth.uid() = usuario_id);

drop policy if exists "ingresos_delete_propios" on public.ingresos;
create policy "ingresos_delete_propios"
  on public.ingresos
  for delete
  using (auth.uid() = usuario_id);

-- Las funciones siguientes administran el ajuste de saldos de cuentas.
create or replace function public.fn_ingresos_crear(
  p_usuario_id uuid,
  p_categoria_id uuid,
  p_monto numeric,
  p_tipo text,
  p_frecuencia text,
  p_fecha timestamptz,
  p_descripcion text default null,
  p_cuenta_id uuid default null
) returns public.ingresos
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_ingreso public.ingresos;
begin
  if auth.uid() is null then
    raise exception 'Acceso no autorizado.';
  end if;

  if p_usuario_id is distinct from auth.uid() then
    raise exception 'No puedes registrar ingresos para otro usuario.';
  end if;

  insert into public.ingresos (
    usuario_id,
    categoria_id,
    monto,
    tipo,
    frecuencia,
    fecha,
    descripcion,
    cuenta_id
  ) values (
    p_usuario_id,
    p_categoria_id,
    round(p_monto::numeric, 2),
    p_tipo,
    p_frecuencia,
    p_fecha,
    p_descripcion,
    p_cuenta_id
  )
  returning * into v_ingreso;

  if v_ingreso.cuenta_id is not null then
    update public.cuentas_bancarias
      set monto_disponible = monto_disponible + v_ingreso.monto,
          actualizado_el = timezone('UTC', now())
      where id = v_ingreso.cuenta_id;
  end if;

  return v_ingreso;
end;
$$;

grant execute on function public.fn_ingresos_crear(
  uuid,
  uuid,
  numeric,
  text,
  text,
  timestamptz,
  text,
  uuid
) to authenticated;

create or replace function public.fn_ingresos_actualizar(
  p_id uuid,
  p_usuario_id uuid,
  p_categoria_id uuid,
  p_monto numeric,
  p_tipo text,
  p_frecuencia text,
  p_fecha timestamptz,
  p_descripcion text default null,
  p_cuenta_id uuid default null
) returns public.ingresos
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_anterior public.ingresos;
  v_actual public.ingresos;
begin
  if auth.uid() is null then
    raise exception 'Acceso no autorizado.';
  end if;

  select *
    into v_anterior
    from public.ingresos
   where id = p_id;

  if not found then
    raise exception 'El ingreso indicado no existe.';
  end if;

  if v_anterior.usuario_id is distinct from auth.uid() or
     p_usuario_id is distinct from auth.uid() then
    raise exception 'No tienes permisos para actualizar este ingreso.';
  end if;

  update public.ingresos
     set categoria_id = p_categoria_id,
         monto = round(p_monto::numeric, 2),
         tipo = p_tipo,
         frecuencia = p_frecuencia,
         fecha = p_fecha,
         descripcion = p_descripcion,
         cuenta_id = p_cuenta_id,
         updated_at = timezone('UTC', now())
   where id = p_id
  returning * into v_actual;

  if v_anterior.cuenta_id = v_actual.cuenta_id then
    if v_actual.cuenta_id is not null then
      update public.cuentas_bancarias
         set monto_disponible = monto_disponible - v_anterior.monto + v_actual.monto,
             actualizado_el = timezone('UTC', now())
       where id = v_actual.cuenta_id;
    end if;
  else
    if v_anterior.cuenta_id is not null then
      update public.cuentas_bancarias
         set monto_disponible = monto_disponible - v_anterior.monto,
             actualizado_el = timezone('UTC', now())
       where id = v_anterior.cuenta_id;
    end if;

    if v_actual.cuenta_id is not null then
      update public.cuentas_bancarias
         set monto_disponible = monto_disponible + v_actual.monto,
             actualizado_el = timezone('UTC', now())
       where id = v_actual.cuenta_id;
    end if;
  end if;

  return v_actual;
end;
$$;

grant execute on function public.fn_ingresos_actualizar(
  uuid,
  uuid,
  uuid,
  numeric,
  text,
  text,
  timestamptz,
  text,
  uuid
) to authenticated;

create or replace function public.fn_ingresos_eliminar(
  p_id uuid,
  p_usuario_id uuid
) returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_anterior public.ingresos;
begin
  if auth.uid() is null then
    raise exception 'Acceso no autorizado.';
  end if;

  select *
    into v_anterior
    from public.ingresos
   where id = p_id;

  if not found then
    return;
  end if;

  if v_anterior.usuario_id is distinct from auth.uid() or
     p_usuario_id is distinct from auth.uid() then
    raise exception 'No tienes permisos para eliminar este ingreso.';
  end if;

  delete from public.ingresos where id = p_id;

  if v_anterior.cuenta_id is not null then
    update public.cuentas_bancarias
       set monto_disponible = monto_disponible - v_anterior.monto,
           actualizado_el = timezone('UTC', now())
     where id = v_anterior.cuenta_id;
  end if;
end;
$$;

grant execute on function public.fn_ingresos_eliminar(uuid, uuid) to authenticated;
