-- ============================================================================
--  tudu — Eliminar las políticas que dejan entrar al rol público
-- ============================================================================
--  Ejecutar en el SQL Editor del dashboard de Supabase.
--
--  EL PROBLEMA
--  Existen políticas llamadas `service_role_all` que, pese al nombre, están
--  asignadas al rol `public` con la condición `true`:
--
--      roles = {public}   cmd = ALL   qual = true
--
--  En Postgres, `public` significa TODOS los roles, incluido `anon`. O sea que
--  esas políticas conceden acceso total a cualquiera con la clave publicable,
--  que es precisamente la que va embebida en las apps cliente. Activar RLS no
--  sirvió de nada: las políticas lo abren de par en par.
--
--  Alcance real comprobado: se podían leer `users`, `allies`, `user_cards` y
--  `admins` (con el hash de la contraseña) usando solo la clave publicable.
--
--  LA SOLUCIÓN
--  Borrarlas todas. Los tres backends usan la clave secreta (`sb_secret_…`),
--  y ese rol se salta RLS por diseño: no necesita ninguna política. Ninguna app
--  Flutter habla directamente con Supabase, así que nada más las requiere.
--
--  Resultado: RLS activo y SIN políticas = denegado para anon y authenticated,
--  intacto para los backends.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Las mal llamadas `service_role_all` (rol public, acceso total)
-- ----------------------------------------------------------------------------
drop policy if exists "service_role_all" on public.admins;
drop policy if exists "service_role_all" on public.allies;
drop policy if exists "service_role_all" on public.ally_services;
drop policy if exists "service_role_all" on public.cities;
drop policy if exists "service_role_all" on public.countries;
drop policy if exists "service_role_all" on public.departments;
drop policy if exists "service_role_all" on public.device_sessions;
drop policy if exists "service_role_all" on public.photo_change_requests;
drop policy if exists "service_role_all" on public.search_history;
drop policy if exists "service_role_all" on public.services;
drop policy if exists "service_role_all" on public.services_in_search;
drop policy if exists "service_role_all" on public.user_addresses;
drop policy if exists "service_role_all" on public.user_cards;
drop policy if exists "service_role_all" on public.user_phones;
drop policy if exists "service_role_all" on public.user_sessions;
drop policy if exists "service_role_all" on public.users;

-- ----------------------------------------------------------------------------
-- 2. Sesiones de aliado: acceso total al rol público, sin condición
-- ----------------------------------------------------------------------------
drop policy if exists "Todos pueden leer y escribir su propia sesion" on public.ally_device_sessions;

-- ----------------------------------------------------------------------------
-- 3. Perfiles de servicio de aliados
--    Comparan contra `auth.jwt()`, pensadas para un cliente que se autentica
--    directamente con Supabase Auth. Ese cliente no existe: las apps pasan por
--    los backends. La de INSERT además no tenía condición.
-- ----------------------------------------------------------------------------
drop policy if exists "Aliado puede ver sus propios perfiles" on public.ally_service_profiles;
drop policy if exists "Aliado puede editar sus propios perfiles" on public.ally_service_profiles;
drop policy if exists "Aliado puede insertar sus propios perfiles" on public.ally_service_profiles;

-- ----------------------------------------------------------------------------
-- 4. Catálogo de servicios
--    'Servicios visibles para todos' no expone datos personales, pero la app lo
--    consulta vía GET /services, no directamente. Y la de INSERT permitía a
--    cualquiera crear servicios en el catálogo compartido.
-- ----------------------------------------------------------------------------
drop policy if exists "Servicios visibles para todos" on public.services;
drop policy if exists "Aliados pueden crear servicios nuevos" on public.services;

-- ----------------------------------------------------------------------------
--  COMPROBACIÓN
--  Debe devolver CERO filas.
-- ----------------------------------------------------------------------------
select tablename, policyname, roles, cmd
  from pg_policies
 where schemaname = 'public'
 order by tablename;

-- ----------------------------------------------------------------------------
--  Y que RLS siga activo en todas (todas en true):
--    select tablename, rowsecurity from pg_tables
--     where schemaname = 'public' order by tablename;
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
--  Tabla obsoleta: user_sessions
--  Fue el control de sesiones de usuario antes de existir device_sessions y los
--  JWT. Ningún backend la referencia y está vacía (0 filas, comprobado).
-- ----------------------------------------------------------------------------
drop table if exists public.user_sessions;
