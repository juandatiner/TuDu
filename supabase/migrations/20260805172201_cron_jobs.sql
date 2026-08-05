-- Jobs de pg_cron. `cron.schedule` con nombre es idempotente: si el job ya
-- existe lo actualiza en vez de duplicarlo.

select cron.schedule(
  'tudu_expirar_sesiones',
  '0 * * * *',
  'select tudu_expirar_sesiones_inactivas()'
);

select cron.schedule(
  'tudu_registros_abandonados',
  '0 * * * *',
  'select tudu_limpiar_registros_abandonados()'
);

select cron.schedule(
  'tudu_fotos_notificadas',
  '0 * * * *',
  'select tudu_limpiar_fotos_notificadas()'
);
