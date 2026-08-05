-- ============================================================================
--  tudu — Resincroniza la secuencia de `services.id`
-- ============================================================================
--  Ejecutar UNA VEZ en el SQL Editor del dashboard de Supabase.
--
--  POR QUÉ
--  Las 10 filas semilla de `services` se insertaron con `id` explícito, sin
--  pasar por la secuencia (`services_id_seq`). La secuencia quedó en 1, así
--  que el primer INSERT nuevo (sin `id`, dejando que Postgres lo asigne)
--  intenta usar el 1 otra vez y choca con "Servicio de hogar":
--    duplicate key value violates unique constraint "services_pkey"
-- ============================================================================

select setval('services_id_seq', (select max(id) from services));

-- Comprobación: el próximo id que va a usar la secuencia.
select nextval('services_id_seq');
