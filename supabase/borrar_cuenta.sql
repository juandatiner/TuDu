-- ============================================================================
--  tudu — Borrado de cuenta de usuario en una sola transacción
-- ============================================================================
--  Ejecutar UNA VEZ en el SQL Editor del dashboard de Supabase.
--
--  POR QUÉ
--  `DELETE /users/:email` hacía siete borrados seguidos desde Node. Si uno
--  fallaba a mitad, los anteriores ya estaban aplicados: quedaban direcciones,
--  tarjetas o sesiones huérfanas apuntando a un usuario que ya no existe.
--
--  Una función de Postgres corre entera dentro de una transacción: o se borra
--  todo, o no se borra nada.
-- ============================================================================

create or replace function tudu_borrar_cuenta(p_email text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  existe boolean;
begin
  select exists(select 1 from users where email = p_email) into existe;

  if not existe then
    return json_build_object('success', false, 'message', 'Usuario no encontrado');
  end if;

  delete from user_addresses        where user_email = p_email;
  delete from user_phones           where user_email = p_email;
  delete from photo_change_requests where user_email = p_email;
  delete from user_cards            where user_email = p_email;
  delete from device_sessions       where user_email = p_email;
  delete from search_history        where user_email = p_email;
  delete from services_in_search    where user_email = p_email;
  delete from users                 where email      = p_email;

  return json_build_object('success', true, 'message', 'Cuenta eliminada');
end;
$$;

-- Solo el backend (service role) puede invocarla. Nunca los roles públicos:
-- es una operación destructiva e irreversible.
revoke all on function tudu_borrar_cuenta(text) from public;
revoke all on function tudu_borrar_cuenta(text) from anon;
revoke all on function tudu_borrar_cuenta(text) from authenticated;
grant execute on function tudu_borrar_cuenta(text) to service_role;

-- Comprobar que quedó creada:
--   select proname from pg_proc where proname = 'tudu_borrar_cuenta';
