-- ============================================================================
--  Corrección: admin_allies_kyc_view expuesta con SECURITY DEFINER
-- ============================================================================
--  Ejecutar en el SQL Editor del dashboard de Supabase.
--
--  QUÉ PASA
--  Una vista sin `security_invoker` se evalúa con los permisos de QUIEN LA
--  CREÓ (normalmente `postgres`, que se salta RLS), no de quien la consulta.
--  Como vive en el esquema `public`, PostgREST la publica: cualquiera con la
--  clave anon del proyecto podría leerla y ver el listado de aliados con su
--  correo, fecha de nacimiento y estado de KYC, aunque `allies` tenga RLS.
--
--  Con `security_invoker = on` la vista pasa a respetar los permisos y las
--  políticas RLS del usuario que consulta, que es lo correcto.
-- ============================================================================

-- 1. Ver quién es el dueño y cómo está definida (opcional, para inspeccionar)
--    select viewowner, definition from pg_views where viewname = 'admin_allies_kyc_view';

-- 2. La corrección en sí
alter view public.admin_allies_kyc_view set (security_invoker = on);

-- 3. Cerrar el acceso desde los roles públicos de la API.
--    Los 3 backends usan la service role key, que no pasa por estos GRANT,
--    así que esto no rompe la aplicación.
revoke all on public.admin_allies_kyc_view from anon;
revoke all on public.admin_allies_kyc_view from authenticated;

-- 4. Comprobar que quedó aplicado: debe listar `security_invoker=true`
select relname, reloptions
  from pg_class
 where relname = 'admin_allies_kyc_view';

-- ----------------------------------------------------------------------------
--  ALTERNATIVA: si la vista no se usa, borrarla es más seguro que arreglarla.
--  Hoy no la consulta ningún backend ni ninguna app del repo.
-- ----------------------------------------------------------------------------
--  drop view public.admin_allies_kyc_view;
