-- ============================================================================
--  tudu — Correcciones al linter de seguridad de Supabase
-- ============================================================================
--  Ejecutar UNA VEZ en el SQL Editor del dashboard de Supabase.
--
--  Cubre 3 de los 4 tipos de warning reportados por el linter. El cuarto
--  (auth_leaked_password_protection) NO es SQL — es un toggle en el dashboard:
--  Authentication → Policies → "Leaked password protection" → activarlo a mano.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. function_search_path_mutable
--    Sin `search_path` fijo, una función SECURITY DEFINER (o cualquiera
--    ejecutada por un rol con más privilegios) puede ser engañada si alguien
--    crea un objeto con el mismo nombre en un schema que quede antes en el
--    search_path por defecto. Fijarlo a `public, pg_temp` lo cierra.
-- ----------------------------------------------------------------------------
alter function public.tudu_expirar_sesiones_inactivas()      set search_path = public, pg_temp;
alter function public.tudu_limpiar_registros_abandonados()   set search_path = public, pg_temp;
alter function public.tudu_limpiar_fotos_notificadas()       set search_path = public, pg_temp;
alter function public.update_updated_at_column()             set search_path = public, pg_temp;

-- ----------------------------------------------------------------------------
-- 2. public_bucket_allows_listing
--    Un bucket público ya sirve los objetos por URL directa
--    (`/storage/v1/object/public/...`) SIN necesitar ninguna política SELECT
--    en `storage.objects` — el flag `public: true` del bucket alcanza. La
--    política "lectura publica" que se agregó en storage.sql / storage_portfolio.sql
--    de más permite algo que nunca se usa: listar (`storage.list()`) todos los
--    archivos del bucket, exponiendo nombres de archivo de otros usuarios.
--    Ningún backend llama `.list()` (confirmado en storage.js), así que se
--    puede borrar sin romper nada.
-- ----------------------------------------------------------------------------
drop policy if exists "avatars lectura publica" on storage.objects;
drop policy if exists "portfolio lectura publica" on storage.objects;

-- ----------------------------------------------------------------------------
-- 3. pg_graphql_anon_table_exposed / pg_graphql_authenticated_table_exposed
--    Todas las tablas de `public` tienen el GRANT de SELECT por defecto que
--    Postgres/Supabase da a `anon` y `authenticated` al crearlas — eso es
--    independiente de RLS (que ya bloquea filas, ver rls.sql) pero permite que
--    el esquema GraphQL autogenerado las liste como consultables, exponiendo
--    su existencia y columnas (grave en el caso de `admins`).
--    Los backends usan SIEMPRE la service role key, nunca `anon`/`authenticated`,
--    así que revocar esto no rompe nada de la aplicación.
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  for t in
    select tablename from pg_tables where schemaname = 'public'
  loop
    execute format('revoke select on table public.%I from anon, authenticated;', t);
  end loop;
end $$;

-- ----------------------------------------------------------------------------
--  COMPROBACIÓN
-- ----------------------------------------------------------------------------
select p.proname, p.proconfig
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('tudu_expirar_sesiones_inactivas','tudu_limpiar_registros_abandonados','tudu_limpiar_fotos_notificadas','update_updated_at_column');
-- proconfig debe mostrar {search_path=public,pg_temp} en las 4 filas.

select tablename, has_table_privilege('anon', 'public.'||tablename, 'SELECT') as anon_puede_leer
  from pg_tables where schemaname = 'public' order by tablename;
-- anon_puede_leer debe ser `false` en todas.
