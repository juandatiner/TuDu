-- ============================================================================
--  tudu — Trabajos de mantenimiento programados
-- ============================================================================
--  Ejecutar UNA VEZ en el SQL Editor del dashboard de Supabase.
--
--  Por qué acá y no en el backend: un `setInterval` de Node muere cuando el
--  proceso se reinicia y se ejecuta N veces si hay N instancias del servidor.
--  pg_cron vive dentro de Postgres: corre siempre, exactamente una vez, sin
--  depender de que ningún backend esté levantado.
--
--  Mientras esto no esté instalado, poner MANTENIMIENTO_EN_PROCESO=true en el
--  .env de cada backend para que el respaldo horario en proceso se encargue
--  (suficiente en desarrollo local, NO en producción).
-- ============================================================================

create extension if not exists pg_cron;

-- ----------------------------------------------------------------------------
-- 1. Caducidad de sesiones por inactividad (180 días)
--    Solo apaga la sesión. No borra datos del usuario ni sus publicaciones.
-- ----------------------------------------------------------------------------
create or replace function tudu_expirar_sesiones_inactivas()
returns void
language sql
as $$
  update device_sessions
     set is_active = 0
   where is_active = 1
     and last_activity < now() - interval '180 days';

  update ally_device_sessions
     set is_active = 0
   where is_active = 1
     and last_activity < now() - interval '180 days';
$$;

-- ----------------------------------------------------------------------------
-- 2. Registros de aliado abandonados (7 días sin enviar cédula)
--    Nunca toca a quien ya está en 'submitted' o 'approved': esa persona ya se
--    identificó ante la empresa y solo espera respuesta.
-- ----------------------------------------------------------------------------
create or replace function tudu_limpiar_registros_abandonados()
returns void
language plpgsql
as $$
declare
  correos text[];
begin
  select array_agg(email) into correos
    from allies
   where coalesce(kyc_status, 'pending') not in ('submitted', 'approved')
     and created_at < now() - interval '7 days';

  if correos is null then
    return;
  end if;

  delete from ally_service_profiles where ally_email = any(correos);
  delete from allies where email = any(correos);
end;
$$;

-- ----------------------------------------------------------------------------
-- 3. Solicitudes de cambio de foto ya notificadas (liberan el base64)
-- ----------------------------------------------------------------------------
create or replace function tudu_limpiar_fotos_notificadas()
returns void
language sql
as $$
  delete from photo_change_requests where user_notified = true;
$$;

-- ----------------------------------------------------------------------------
--  Programación — cada hora, en el minuto 0
-- ----------------------------------------------------------------------------
select cron.unschedule('tudu_expirar_sesiones')      where exists (select 1 from cron.job where jobname = 'tudu_expirar_sesiones');
select cron.unschedule('tudu_registros_abandonados') where exists (select 1 from cron.job where jobname = 'tudu_registros_abandonados');
select cron.unschedule('tudu_fotos_notificadas')     where exists (select 1 from cron.job where jobname = 'tudu_fotos_notificadas');

select cron.schedule('tudu_expirar_sesiones',      '0 * * * *', $$select tudu_expirar_sesiones_inactivas()$$);
select cron.schedule('tudu_registros_abandonados', '0 * * * *', $$select tudu_limpiar_registros_abandonados()$$);
select cron.schedule('tudu_fotos_notificadas',     '0 * * * *', $$select tudu_limpiar_fotos_notificadas()$$);

-- Comprobar que quedaron programados:
--   select jobname, schedule, active from cron.job where jobname like 'tudu_%';
