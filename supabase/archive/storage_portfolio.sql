-- ============================================================================
--  tudu — Bucket de Storage para el portafolio de trabajos de los aliados
-- ============================================================================
--  Ejecutar UNA VEZ en el SQL Editor del dashboard de Supabase, DESPUÉS de
--  categorias_servicios.sql (necesita que exista `ally_portfolio_items` para
--  que tenga sentido, aunque no hay dependencia técnica entre los dos scripts).
--
--  Mismo patrón que storage.sql para el bucket 'avatars': público, porque las
--  fotos de trabajos se muestran en la app para que la gente vea la calidad
--  del servicio, no es información sensible.
-- ============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('portfolio', 'portfolio', true, 5242880,
   array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "portfolio lectura publica" on storage.objects;
create policy "portfolio lectura publica"
  on storage.objects for select
  using (bucket_id = 'portfolio');

drop policy if exists "backend gestiona portfolio" on storage.objects;
create policy "backend gestiona portfolio"
  on storage.objects for all
  to service_role
  using (bucket_id = 'portfolio')
  with check (bucket_id = 'portfolio');

-- ----------------------------------------------------------------------------
--  COMPROBACIÓN
-- ----------------------------------------------------------------------------
select id, public, file_size_limit from storage.buckets where id = 'portfolio';
