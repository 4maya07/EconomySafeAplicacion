-- Permite lectura pública del bucket "perfiles".
create policy if not exists perfiles_public_read
on storage.objects for select
using (bucket_id = 'perfiles');

-- Permite a usuarios autenticados subir sus archivos bajo {uid}/...
create policy if not exists perfiles_owner_insert
on storage.objects for insert
with check (
  bucket_id = 'perfiles'
  and auth.role() = 'authenticated'
  and auth.uid()::text = split_part(name, '/', 1)
);

-- Permite a usuarios autenticados actualizar/eliminar sólo sus archivos.
create policy if not exists perfiles_owner_update
on storage.objects for update
using (
  bucket_id = 'perfiles'
  and auth.role() = 'authenticated'
  and auth.uid()::text = split_part(name, '/', 1)
)
with check (
  bucket_id = 'perfiles'
  and auth.role() = 'authenticated'
  and auth.uid()::text = split_part(name, '/', 1)
);

create policy if not exists perfiles_owner_delete
on storage.objects for delete
using (
  bucket_id = 'perfiles'
  and auth.role() = 'authenticated'
  and auth.uid()::text = split_part(name, '/', 1)
);
