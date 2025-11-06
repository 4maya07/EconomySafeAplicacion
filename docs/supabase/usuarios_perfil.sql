-- Extiende la tabla de usuarios con campos adicionales para el perfil.
-- Ejecutar en Supabase tras revisar que los nombres no colisionen con datos previos.

alter table public.usuarios
  add column if not exists correo_secundario text,
  add column if not exists documento_identidad text,
  add column if not exists pais_residencia text,
  add column if not exists moneda_preferida text,
  add column if not exists foto_url text;
